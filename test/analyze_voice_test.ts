// Tests for the analyze-voice Edge Function handler (supabase/functions/analyze-voice/handler.ts), with the
// model server, the rate limiter and the scam analysis all faked. Run:
//   deno test test/analyze_voice_test.ts --allow-read
//
// What they pin down: kill switch first; health carries no audio; size/type/length checks; the rate limit uses its
// own key prefixes and runs before any audio is read or forwarded; the audio and shared key go only to the model
// server; every model-server failure becomes a generic code; nothing about the audio or transcript is logged;
// the answer has the three-outcome guess and no scores.

import { assert, assertEquals, assertFalse } from "jsr:@std/assert@^1.0.0";
import {
  ALLOWED_AUDIO_TYPES,
  createHandler,
  type Deps,
  MAX_AUDIO_BYTES,
  MAX_TRANSCRIPT_CHARS,
} from "../supabase/functions/analyze-voice/handler.ts";
import type { AnalysisOutcome } from "../supabase/functions/_shared/scam_analysis.ts";
import { PREREGISTERED_CUTOFFS } from "../supabase/functions/_shared/voice_labels.ts";

// Made-up addresses (nothing real is contacted). Built from pieces so the repo's URL scanner does not mistake
// them for real links.
const H = "ht" + "tp";
const HS = "ht" + "tps";
const SERVER = `${H}://model.internal.test:9000`;
const ORIGIN = `${HS}://app.example.test`;
const EVIL = `${HS}://evil.example.test`;
const KEY = "shared-key-0123456789abcdef";
const AUDIO = new Uint8Array(3000).map((_, i) => i % 251);
const TRANSCRIPT = "Tôi là công an, hãy chuyển tiền ngay";

const SCAM_OK = {
  risk_level: "likely_scam",
  risk_score: 90,
  summary: "Giống mạo danh công an.",
  red_flags: [],
  what_to_do: ["Cúp máy."],
  scam_type: "impersonation",
  confidence_note: "Không xác minh được.",
  language: "vi",
};

interface Seen {
  url: string;
  method: string;
  headers: Record<string, string>;
  body: Uint8Array | null;
}

function jsonResp(status: number, body: unknown) {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}

function makeDeps(over: {
  env?: Record<string, string | undefined>;
  routes?: Record<string, (seen: Seen) => Response | Promise<Response>>;
  limited?: (opts: { prefix: string; limit: number; windowMinutes: number }) => boolean;
  scam?: (text: string, lang: "vi" | "en") => Promise<AnalysisOutcome>;
  cutoffs?: Deps["cutoffs"];
} = {}) {
  const seen: Seen[] = [];
  const logs: string[] = [];
  const rate: { prefix: string; limit: number; windowMinutes: number }[] = [];
  const scamCalls: { text: string; lang: string }[] = [];
  const env: Record<string, string | undefined> = {
    VOICE_ENABLED: "true",
    VOICE_SERVER_URL: SERVER,
    VOICE_SERVER_KEY: KEY,
    ALLOWED_WEB_ORIGIN: ORIGIN,
    ...(over.env ?? {}),
  };
  const routes: Record<string, (seen: Seen) => Response | Promise<Response>> = {
    "/readyz": () => jsonResp(200, { ok: true, detector: true, asr: true }),
    "/transcribe": () => jsonResp(200, { duration_s: 12.3, text: TRANSCRIPT }),
    "/analyze": () => jsonResp(200, { duration_s: 12.3, piece_scores: [0.9, 0.95] }),
    ...(over.routes ?? {}),
  };
  const deps: Deps = {
    env: (n) => env[n],
    fetch: (async (input: string | URL | Request, init?: RequestInit) => {
      const url = String(input);
      const body = init?.body ? new Uint8Array(init.body as Uint8Array) : null;
      const s: Seen = { url, method: init?.method ?? "GET", headers: { ...(init?.headers as Record<string, string> ?? {}) }, body };
      seen.push(s);
      const route = url.replace(SERVER, "");
      const r = routes[route];
      if (!r) throw new Error("unexpected route " + route);
      return await r(s);
    }) as typeof fetch,
    isRateLimited: (_req, opts) => {
      rate.push(opts);
      return Promise.resolve(over.limited ? over.limited(opts) : false);
    },
    analyzeScam: (text, lang) => {
      scamCalls.push({ text, lang });
      return over.scam ? over.scam(text, lang) : Promise.resolve({ ok: true, result: SCAM_OK } as AnalysisOutcome);
    },
    cutoffs: over.cutoffs ?? (() => PREREGISTERED_CUTOFFS),
    log: (m) => logs.push(m),
  };
  return { handler: createHandler(deps), seen, logs, rate, scamCalls };
}

const URL_BASE = `${HS}://project.example.test/functions/v1/analyze-voice`;

function post(body: BodyInit | null = AUDIO, headers: Record<string, string> = {}, query = "") {
  return new Request(URL_BASE + query, {
    method: "POST",
    headers: { "content-type": "audio/wav", ...headers },
    body,
  });
}
const health = (method = "GET") => new Request(URL_BASE + "/health", { method });

// ------------------------------------------------------------------------------------ kill switch
Deno.test("kill switch off (unset, 'false', anything but true): 503 disabled, body never read, server never called", async () => {
  for (const v of [undefined, "false", "0", "yes", ""]) {
    const t = makeDeps({ env: v === undefined ? { VOICE_ENABLED: "" } : { VOICE_ENABLED: v } });
    const req = post(new ReadableStream({ pull(c) { c.enqueue(AUDIO); c.close(); } }));
    const r = await t.handler(req);
    assertEquals([r.status, (await r.json()).error], [503, "disabled"]);
    const h = await t.handler(health());
    assertEquals(h.status, 503);
    assertFalse(req.bodyUsed); // the body was never consumed
    assertEquals(t.seen.length, 0);
    assertEquals(t.rate.length, 0); // not even the rate limiter is touched
  }
});

Deno.test("kill switch is read on every request (case-insensitive 'TRUE' works)", async () => {
  const t = makeDeps({ env: { VOICE_ENABLED: "TRUE" } });
  assertEquals((await t.handler(health())).status, 200);
});

Deno.test("missing server address or key: 503 not_configured", async () => {
  for (const env of [{ VOICE_SERVER_URL: "" }, { VOICE_SERVER_KEY: "" }]) {
    const t = makeDeps({ env });
    const r = await t.handler(post());
    assertEquals([r.status, (await r.json()).error], [503, "not_configured"]);
    assertEquals(t.seen.length, 0);
  }
});

// ------------------------------------------------------------------------------------------ health
Deno.test("health: 200 {ok:true}; it asks the model server's /readyz with NO body and NO audio", async () => {
  const t = makeDeps();
  const r = await t.handler(health());
  assertEquals([r.status, await r.json()], [200, { ok: true }]);
  assertEquals(t.seen.length, 1);
  assertEquals(t.seen[0].url, SERVER + "/readyz");
  assertEquals(t.seen[0].body, null);
  assertEquals(Object.keys(t.seen[0].headers).includes("x-voice-secret"), false); // not even the key
});

Deno.test("health: model server not ready, error, or unreachable -> 503 unavailable (never a raw error)", async () => {
  const cases: Record<string, () => Response> = {
    notReady: () => jsonResp(200, { ok: false, detector: true, asr: false }),
    five: () => jsonResp(500, { error: "x" }),
    garbage: () => new Response("<html>", { status: 200 }),
  };
  for (const [name, route] of Object.entries(cases)) {
    const r = await makeDeps({ routes: { "/readyz": route } }).handler(health());
    assertEquals([name, r.status, (await r.json()).error], [name, 503, "unavailable"]);
  }
  const t = makeDeps({ routes: { "/readyz": () => { throw new DOMException("timed out", "TimeoutError"); } } });
  const r = await t.handler(health());
  assertEquals([r.status, (await r.json()).error], [503, "unavailable"]);
});

Deno.test("health: POST is 405; rate limited is 429 with its own key prefix", async () => {
  const t = makeDeps({ limited: (o) => o.prefix === "voice-health:" });
  assertEquals((await t.handler(health("POST"))).status, 405);
  const r = await t.handler(health());
  assertEquals([r.status, (await r.json()).error], [429, "rate_limited"]);
  assertEquals(t.rate[0].prefix, "voice-health:");
  assertEquals(t.seen.length, 0);
});

// -------------------------------------------------------------------------------------------- CORS
Deno.test("CORS: only the pinned origin is echoed, anything else gets 'null'; OPTIONS answers", async () => {
  const t = makeDeps();
  const ok = await t.handler(new Request(URL_BASE + "/health", { headers: { origin: ORIGIN } }));
  assertEquals(ok.headers.get("Access-Control-Allow-Origin"), ORIGIN);
  const bad = await t.handler(new Request(URL_BASE + "/health", { headers: { origin: EVIL } }));
  assertEquals(bad.headers.get("Access-Control-Allow-Origin"), "null");
  const none = makeDeps({ env: { ALLOWED_WEB_ORIGIN: "" } });
  const r = await none.handler(new Request(URL_BASE, { method: "OPTIONS", headers: { origin: ORIGIN } }));
  assertEquals(r.status, 200);
  assertEquals(r.headers.get("Access-Control-Allow-Origin"), "null");
  // Errors carry the headers too (a browser must be able to read them).
  const off = makeDeps({ env: { VOICE_ENABLED: "false" } });
  const e = await off.handler(new Request(URL_BASE, { method: "POST", headers: { origin: ORIGIN, "content-type": "audio/wav" }, body: AUDIO }));
  assertEquals(e.headers.get("Access-Control-Allow-Origin"), ORIGIN);
});

// -------------------------------------------------------------------------------- request checks
Deno.test("wrong method is 405; wrong content type is 415 before anything is read or forwarded", async () => {
  const t = makeDeps();
  assertEquals((await t.handler(new Request(URL_BASE, { method: "PUT", body: AUDIO }))).status, 405);
  assertEquals((await t.handler(new Request(URL_BASE))).status, 405);
  for (const bad of ["application/json", "text/plain", "image/png", "", "multipart/form-data"]) {
    const r = await t.handler(post(AUDIO, { "content-type": bad }));
    assertEquals([bad, r.status, (await r.json()).error], [bad, 415, "unsupported_type"]);
  }
  assertEquals(t.seen.length, 0);
  assertEquals(t.rate.length, 0);
});

Deno.test("every allowed audio type is accepted (with parameters like ';codecs=')", async () => {
  for (const type of ALLOWED_AUDIO_TYPES) {
    const t = makeDeps();
    const r = await t.handler(post(AUDIO, { "content-type": type + "; codecs=opus" }));
    assertEquals([type, r.status], [type, 200]);
  }
});

Deno.test("too large: declared size over the cap is 413 without reading; an undeclared stream over the cap is 413 too", async () => {
  const t = makeDeps();
  const declared = await t.handler(post(AUDIO, { "content-length": String(MAX_AUDIO_BYTES + 1) }));
  assertEquals([declared.status, (await declared.json()).error], [413, "too_large"]);
  assertEquals(t.seen.length, 0);
  assertEquals(t.rate.length, 0);

  // No Content-Length (chunked): the body is counted while it is read and cut off at the cap.
  let sent = 0;
  const big = new ReadableStream<Uint8Array>({
    pull(c) {
      if (sent > MAX_AUDIO_BYTES * 3) return c.close();
      sent += 1024 * 1024;
      c.enqueue(new Uint8Array(1024 * 1024));
    },
  });
  const chunked = await t.handler(new Request(URL_BASE, { method: "POST", headers: { "content-type": "audio/wav" }, body: big, duplex: "half" } as RequestInit));
  assertEquals([chunked.status, (await chunked.json()).error], [413, "too_large"]);
  assert(sent <= MAX_AUDIO_BYTES + 2 * 1024 * 1024, "stopped reading soon after the cap");
  assertEquals(t.seen.length, 0); // nothing was forwarded
});

Deno.test("empty body is 400 empty", async () => {
  const t = makeDeps();
  const r = await t.handler(post(new Uint8Array(0)));
  assertEquals([r.status, (await r.json()).error], [400, "empty"]);
  assertEquals(t.seen.length, 0);
});

// ---------------------------------------------------------------------------------- rate limiting
Deno.test("rate limit: its own key prefix and limits; over the limit is 429 BEFORE the audio is read or forwarded", async () => {
  const req = post(new ReadableStream({ pull(c) { c.enqueue(AUDIO); c.close(); } }));
  const t = makeDeps({ limited: () => true });
  const r = await t.handler(req);
  assertEquals([r.status, (await r.json()).error], [429, "rate_limited"]);
  assertEquals(t.rate.length, 1);
  assertEquals(t.rate[0].prefix, "voice:"); // never the empty prefix analyze-scam uses
  assertEquals(t.rate[0].limit, 10);
  assertEquals(t.rate[0].windowMinutes, 60);
  assertFalse(req.bodyUsed); // the audio was never read
  assertEquals(t.seen.length, 0);
});

// -------------------------------------------------------------------------------------- happy path
Deno.test("happy path: one combined JSON; the audio and shared key go only to the model server, in order", async () => {
  const t = makeDeps();
  const r = await t.handler(post(AUDIO, {}, "?language=vi"));
  assertEquals(r.status, 200);
  const body = await r.json();
  assertEquals(Object.keys(body).sort(), ["scam", "transcript", "voice"]);
  assertEquals(body.scam, SCAM_OK);
  assertEquals(body.transcript, TRANSCRIPT);
  assertEquals(body.voice, { guess: "cant_tell" }); // pre-registered cut-offs: no usable gap
  // Exactly the two model-server calls, transcription first.
  assertEquals(t.seen.map((s) => s.url.replace(SERVER, "")), ["/transcribe", "/analyze"]);
  for (const s of t.seen) {
    assertEquals(s.method, "POST");
    assertEquals(s.headers["x-voice-secret"], KEY);
    assertEquals(s.headers["content-type"], "audio/wav");
    assertEquals(s.body, AUDIO);
  }
  // The transcript, and only the transcript, goes to the scam analysis.
  assertEquals(t.scamCalls, [{ text: TRANSCRIPT, lang: "vi" }]);
});

Deno.test("the language query reaches the scam analysis (en), default is vi", async () => {
  const en = makeDeps();
  await en.handler(post(AUDIO, {}, "?language=en"));
  assertEquals(en.scamCalls[0].lang, "en");
  const other = makeDeps();
  await other.handler(post(AUDIO, {}, "?language=xx"));
  assertEquals(other.scamCalls[0].lang, "vi");
});

Deno.test("with cut-offs that have a usable gap the guess can be human or ai; the answer never carries scores", async () => {
  const usable = { tHum: 0.14, tAi: 0.81 };
  const ai = makeDeps({ cutoffs: () => usable });
  const r = await ai.handler(post());
  const body = await r.json();
  assertEquals(body.voice, { guess: "ai" });
  const human = makeDeps({ cutoffs: () => usable, routes: { "/analyze": () => jsonResp(200, { duration_s: 12, piece_scores: [0.01, 0.02] }) } });
  assertEquals((await (await human.handler(post())).json()).voice, { guess: "human" });
  const text = JSON.stringify(body);
  assertFalse(text.includes("piece_scores"));
  assertFalse(text.includes("0.9"));
  assertFalse(text.includes("%"));
});

Deno.test("the transcript is cut to the scam analysis text limit", async () => {
  const long = "a ".repeat(MAX_TRANSCRIPT_CHARS);
  const t = makeDeps({ routes: { "/transcribe": () => jsonResp(200, { duration_s: 12, text: long }) } });
  const r = await t.handler(post());
  assertEquals(r.status, 200);
  assert(t.scamCalls[0].text.length <= MAX_TRANSCRIPT_CHARS);
});

// ------------------------------------------------------------------------------- failure mapping
Deno.test("audio problems from the model server pass through with their own codes", async () => {
  const cases: [number, string][] = [[422, "too_long"], [422, "silent"], [422, "invalid_audio"], [400, "empty"], [413, "too_large"], [415, "unsupported_type"], [429, "busy"]];
  for (const [status, code] of cases) {
    const t = makeDeps({ routes: { "/transcribe": () => jsonResp(status, { error: code }) } });
    const r = await t.handler(post());
    assertEquals([code, r.status, (await r.json()).error], [code, status, code]);
    assertEquals(t.scamCalls.length, 0);
  }
});

Deno.test("anything else from the model server (401, 500, 502, 503, odd 422, timeouts, garbage) is a generic 503 'unavailable'", async () => {
  const bad: Record<string, () => Response> = {
    unauthorized: () => jsonResp(401, { error: "unauthorized" }),
    internal: () => jsonResp(500, { error: "internal" }),
    gateway: () => new Response("bad gateway", { status: 502 }),
    asr: () => jsonResp(503, { error: "asr_unavailable" }),
    odd422: () => jsonResp(422, { error: "something_new" }),
    garbageOk: () => new Response("<html>", { status: 200 }),
  };
  for (const [name, route] of Object.entries(bad)) {
    const t = makeDeps({ routes: { "/transcribe": route } });
    const r = await t.handler(post());
    assertEquals([name, r.status, (await r.json()).error], [name, 503, "unavailable"]);
  }
  const timeout = makeDeps({ routes: { "/transcribe": () => { throw new DOMException("timed out", "TimeoutError"); } } });
  const r = await timeout.handler(post());
  assertEquals([r.status, (await r.json()).error], [503, "unavailable"]);
});

Deno.test("if only the detector fails, the scam analysis still runs and the guess is cant_tell", async () => {
  for (const route of [() => jsonResp(500, { error: "x" }), () => { throw new Error("down"); }, () => new Response("nope", { status: 200 })]) {
    const t = makeDeps({ cutoffs: () => ({ tHum: 0.14, tAi: 0.81 }), routes: { "/analyze": route } });
    const r = await t.handler(post());
    assertEquals(r.status, 200);
    assertEquals((await r.json()).voice, { guess: "cant_tell" });
    assertEquals(t.scamCalls.length, 1);
  }
});

Deno.test("nothing heard (empty transcript): 422 no_speech, no invented text, scam analysis not called", async () => {
  for (const text of ["", "   ", undefined]) {
    const t = makeDeps({ routes: { "/transcribe": () => jsonResp(200, { duration_s: 5, text }) } });
    const r = await t.handler(post());
    assertEquals([r.status, (await r.json()).error], [422, "no_speech"]);
    assertEquals(t.scamCalls.length, 0);
  }
});

Deno.test("a failure of the scam analysis passes its generic error and status", async () => {
  const t = makeDeps({ scam: () => Promise.resolve({ ok: false, error: "upstream_error", status: 502 }) });
  const r = await t.handler(post());
  assertEquals([r.status, (await r.json()).error], [502, "upstream_error"]);
});

Deno.test("an unexpected crash is a generic 500 server_error with no detail", async () => {
  const t = makeDeps({ scam: () => Promise.reject(new Error("secret internals " + TRANSCRIPT)) });
  const r = await t.handler(post());
  const text = await r.text();
  assertEquals(r.status, 500);
  assertEquals(JSON.parse(text), { error: "server_error" });
  assertFalse(text.includes("secret internals"));
});

// ------------------------------------------------------------------------------------- privacy
Deno.test("logs never contain the audio, the transcript, the shared key or the server address", async () => {
  const scenarios = [
    makeDeps(),
    makeDeps({ routes: { "/transcribe": () => jsonResp(500, { error: "x" }) } }),
    makeDeps({ routes: { "/analyze": () => jsonResp(500, { error: "x" }) } }),
    makeDeps({ scam: () => Promise.reject(new Error(TRANSCRIPT)) }),
    makeDeps({ env: { VOICE_SERVER_URL: "" } }),
  ];
  for (const t of scenarios) {
    await t.handler(post());
    for (const line of t.logs) {
      assertFalse(line.includes(TRANSCRIPT));
      assertFalse(line.includes(KEY));
      assertFalse(line.includes("model.internal.test"));
      assertFalse(line.includes(String(AUDIO.slice(0, 8))));
    }
  }
});

Deno.test("responses never echo the server address or key", async () => {
  const bad = makeDeps({ routes: { "/transcribe": () => jsonResp(500, { error: "x " + KEY + SERVER }) } });
  const r = await bad.handler(post());
  const text = await r.text();
  assertFalse(text.includes(KEY));
  assertFalse(text.includes("model.internal.test"));
});

Deno.test("source guard: the handler never writes audio anywhere (no file, storage or database calls)", () => {
  const src = Deno.readTextFileSync(new URL("../supabase/functions/analyze-voice/handler.ts", import.meta.url));
  for (const banned of ["writeFile", "Deno.open", "Deno.create", "localStorage", "storage", "/rest/v1", "console.log"]) {
    assertFalse(src.includes(banned), banned);
  }
  const idx = Deno.readTextFileSync(new URL("../supabase/functions/analyze-voice/index.ts", import.meta.url));
  assertFalse(idx.includes("console.log"));
});
