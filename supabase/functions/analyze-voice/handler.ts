// An Toàn - Edge Function analyze-voice: the request handler, with every outside thing injected so it can be
// tested with `deno test` (index.ts wires the real ones and starts the server).
//
// Flow of a request: kill switch -> method/type/size checks -> rate limit -> read the audio (bounded) ->
// private model server (/transcribe, then /analyze) -> the shared scam analysis on the transcript -> ONE JSON:
//   { scam: <analyze-scam result>, transcript: "...", voice: { guess: "human" | "ai" | "cant_tell" } }
//
// Privacy by construction: the audio is held in memory only while the request runs; it is never written, never
// logged, and never echoed. Logs carry error codes and counts only, never audio, transcript or addresses.
// The model server is private: its address and shared key exist only in this function's secrets.

import { type Cutoffs, labelVoice } from "../_shared/voice_labels.ts";
import type { AnalysisOutcome } from "../_shared/scam_analysis.ts";

/// Hard limits (the app also checks). 60 s of 16 kHz mono WAV is about 1.9 MB; 8 MiB leaves room for
/// other containers and keeps memory far below the function's 256 MB.
export const MAX_AUDIO_BYTES = 8 * 1024 * 1024;
export const MAX_TRANSCRIPT_CHARS = 4000; // same as analyze-scam's text limit

/// Rate limits (their own key prefixes, so they never share a budget with analyze-scam).
export const VOICE_RATE_LIMIT = 10; // analyses per window per IP: each one costs CPU time on the model server
export const VOICE_RATE_WINDOW_MINUTES = 60;
export const HEALTH_RATE_LIMIT = 120; // health checks per window per IP (no audio, cheap)

/// Time budget. The platform allows 150 s on the free plan (request idle timeout 150 s): 85 + 15 here, plus the
/// scam analysis (its own 45 s ceiling, normally a few seconds), stays under it. A 60 s clip on a slow host can
/// exceed the transcription budget: then the answer is the generic 'unavailable' (see the hosting report).
export const TRANSCRIBE_TIMEOUT_MS = 85_000;
export const DETECT_TIMEOUT_MS = 15_000;
// Long on purpose: on a scale-to-zero host the first /readyz is what wakes the model server (about a minute).
// The app shows a "waking up" message meanwhile. 60 s leaves room under the 150 s function limit.
export const HEALTH_TIMEOUT_MS = 60_000;

export const ALLOWED_AUDIO_TYPES = [
  "audio/wav", "audio/x-wav", "audio/wave", "audio/mpeg", "audio/mp3", "audio/mp4", "audio/x-m4a",
  "audio/m4a", "audio/aac", "audio/ogg", "audio/opus", "audio/flac", "audio/x-flac", "audio/webm",
  "video/webm", "application/octet-stream",
];

export interface Deps {
  /** Secret/env reader (Deno.env.get in production). */
  env: (name: string) => string | undefined;
  fetch: typeof fetch;
  /** The shared IP-based, fail-closed rate limit; true = over the limit. */
  isRateLimited: (req: Request, opts: { prefix: string; limit: number; windowMinutes: number }) => Promise<boolean>;
  /** The shared scam analysis (analyze-scam's core). */
  analyzeScam: (text: string, lang: "vi" | "en") => Promise<AnalysisOutcome>;
  cutoffs: () => Cutoffs;
  /** Log sink; only ever called with codes and counts. */
  log: (msg: string) => void;
}

function corsFor(req: Request, env: Deps["env"]): Record<string, string> {
  const origin = req.headers.get("origin");
  const allowed = env("ALLOWED_WEB_ORIGIN") ?? "";
  return {
    "Access-Control-Allow-Origin": origin && allowed && origin === allowed ? origin : "null",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Vary": "Origin",
  };
}

class ModelServerError extends Error {
  constructor(public code: string, public status: number) {
    super(code);
  }
}

async function readBounded(req: Request, max: number): Promise<Uint8Array<ArrayBuffer> | "too_large"> {
  if (!req.body) return new Uint8Array(0);
  const reader = req.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.length;
    if (size > max) {
      await reader.cancel();
      return "too_large";
    }
    chunks.push(value);
  }
  const out = new Uint8Array(size);
  let off = 0;
  for (const c of chunks) {
    out.set(c, off);
    off += c.length;
  }
  return out;
}

export function createHandler(deps: Deps): (req: Request) => Promise<Response> {
  return async (req: Request): Promise<Response> => {
    const cors = corsFor(req, deps.env);
    const json = (body: unknown, status = 200) =>
      new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

    if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

    const path = new URL(req.url).pathname.replace(/\/+$/, "");
    const isHealth = path.endsWith("/health");

    // 1. Kill switch, before anything else is read or done.
    if ((deps.env("VOICE_ENABLED") ?? "").trim().toLowerCase() !== "true") return json({ error: "disabled" }, 503);
    const serverUrl = (deps.env("VOICE_SERVER_URL") ?? "").replace(/\/+$/, "");
    const serverKey = deps.env("VOICE_SERVER_KEY") ?? "";
    if (!serverUrl || !serverKey) {
      deps.log("not configured");
      return json({ error: "not_configured" }, 503);
    }

    // ---- Health: no audio, no user data. -------------------------------------------------------------
    if (isHealth) {
      if (req.method !== "GET") return json({ error: "method_not_allowed" }, 405);
      if (await deps.isRateLimited(req, { prefix: "voice-health:", limit: HEALTH_RATE_LIMIT, windowMinutes: VOICE_RATE_WINDOW_MINUTES })) {
        return json({ error: "rate_limited" }, 429);
      }
      try {
        const r = await deps.fetch(`${serverUrl}/readyz`, { signal: AbortSignal.timeout(HEALTH_TIMEOUT_MS) });
        const body = r.ok ? await r.json() : null;
        return body && body.ok === true ? json({ ok: true }) : json({ error: "unavailable" }, 503);
      } catch {
        return json({ error: "unavailable" }, 503);
      }
    }

    // ---- Analysis ------------------------------------------------------------------------------------
    if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

    const lang: "vi" | "en" = new URL(req.url).searchParams.get("language") === "en" ? "en" : "vi";
    const ctype = (req.headers.get("content-type") ?? "").split(";")[0].trim().toLowerCase();
    if (!ALLOWED_AUDIO_TYPES.includes(ctype)) return json({ error: "unsupported_type" }, 415);
    const declared = Number(req.headers.get("content-length") ?? "");
    if (Number.isFinite(declared) && declared > MAX_AUDIO_BYTES) return json({ error: "too_large" }, 413);
    if (Number.isFinite(declared) && req.headers.get("content-length") !== null && declared === 0) {
      return json({ error: "empty" }, 400);
    }

    if (await deps.isRateLimited(req, { prefix: "voice:", limit: VOICE_RATE_LIMIT, windowMinutes: VOICE_RATE_WINDOW_MINUTES })) {
      return json({ error: "rate_limited" }, 429);
    }

    let audio: Uint8Array<ArrayBuffer>;
    {
      const read = await readBounded(req, MAX_AUDIO_BYTES);
      if (read === "too_large") return json({ error: "too_large" }, 413);
      if (read.length === 0) return json({ error: "empty" }, 400);
      audio = read;
    }

    const call = async (route: string, timeoutMs: number) => {
      let resp: Response;
      try {
        resp = await deps.fetch(`${serverUrl}${route}`, {
          method: "POST",
          headers: { "x-voice-secret": serverKey, "content-type": ctype },
          body: audio,
          signal: AbortSignal.timeout(timeoutMs),
        });
      } catch {
        throw new ModelServerError("unavailable", 503);
      }
      if (resp.ok) {
        try {
          return await resp.json();
        } catch {
          throw new ModelServerError("unavailable", 503);
        }
      }
      let code = "";
      try {
        code = String((await resp.json())?.error ?? "");
      } catch { /* not JSON */ }
      // Errors about THE AUDIO pass through with the server's code; everything else is "unavailable".
      if (resp.status === 422 && ["too_long", "silent", "invalid_audio"].includes(code)) throw new ModelServerError(code, 422);
      if (resp.status === 400 && code === "empty") throw new ModelServerError("empty", 400);
      if (resp.status === 413) throw new ModelServerError("too_large", 413);
      if (resp.status === 415) throw new ModelServerError("unsupported_type", 415);
      if (resp.status === 429) throw new ModelServerError("busy", 429);
      deps.log(`model server ${route} answered ${resp.status}`);
      throw new ModelServerError("unavailable", 503);
    };

    try {
      // 2. Transcription (also validates the audio: silent, too long, unreadable).
      const stt = await call("/transcribe", TRANSCRIBE_TIMEOUT_MS);
      const transcript = typeof stt?.text === "string" ? stt.text.trim().slice(0, MAX_TRANSCRIPT_CHARS) : "";

      // 3. The detector. If only the detector fails, the guess is "cant_tell" and the scam analysis still runs.
      let guess: "human" | "ai" | "cant_tell" = "cant_tell";
      try {
        const det = await call("/analyze", DETECT_TIMEOUT_MS);
        guess = labelVoice(det?.piece_scores, det?.duration_s, deps.cutoffs());
      } catch (e) {
        deps.log(`detector failed: ${e instanceof ModelServerError ? e.code : "error"}`);
      }

      // 4. Nothing was heard: there is nothing to analyze (no invented text).
      if (transcript.length === 0) return json({ error: "no_speech" }, 422);

      // 5. The shared scam analysis on the transcript.
      const outcome = await deps.analyzeScam(transcript, lang);
      if (!outcome.ok) return json({ error: outcome.error }, outcome.status);
      return json({ scam: outcome.result, transcript, voice: { guess } });
    } catch (e) {
      if (e instanceof ModelServerError) return json({ error: e.code }, e.status);
      deps.log("analyze-voice failed");
      return json({ error: "server_error" }, 500);
    }
  };
}
