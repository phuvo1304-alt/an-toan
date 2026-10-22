// An Toàn - Edge Function: analyze-scam
// The Flutter app calls THIS function. Only this function knows ANTHROPIC_API_KEY.
// Run on Supabase (Deno runtime).
//
// AI disclosure: Anthropic's usage policy requires telling users they are
// dealing with AI. The app already does this: the disclaimer on the Result and
// Settings screens says results are "AI-generated" / "do AI tạo ra", and the
// privacy note on the Checker screen says content is sent to an AI service.
// No UI change is needed right now. Keep those texts if you redesign screens.

import { corsHeadersFor, isRateLimited, jsonWith } from "../_shared/http.ts";
import { parseImages } from "../_shared/images.ts";
import { analyzeScamContent, ANTHROPIC_API_KEY, MAX_TEXT_CHARS } from "../_shared/scam_analysis.ts";

// ---- Handler ---------------------------------------------------------------
Deno.serve(async (req) => {
  const cors = corsHeadersFor(req);
  const json = jsonWith(cors);

  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  if (!ANTHROPIC_API_KEY) {
    console.error("ANTHROPIC_API_KEY is not set");
    return json({ error: "server_error" }, 500);
  }

  let body: any;
  try {
    body = await req.json();
  } catch {
    return json({ error: "bad_request" }, 400);
  }

  const lang: "vi" | "en" = body?.language === "en" ? "en" : "vi";
  const text = typeof body?.text === "string" ? body.text.trim() : "";
  // 0-3 screenshots; every image is checked (count, type, size). See images.ts.
  const imageCheck = parseImages(body);
  if (!imageCheck.ok) return json({ error: imageCheck.error }, imageCheck.status);
  const images = imageCheck.images;

  if (!text && images.length === 0) return json({ error: "empty_input" }, 400);
  if (text.length > MAX_TEXT_CHARS) return json({ error: "text_too_long" }, 413);

  if (await isRateLimited(req)) return json({ error: "rate_limited" }, 429);

  const outcome = await analyzeScamContent(text, images, lang);
  return outcome.ok ? json(outcome.result) : json({ error: outcome.error }, outcome.status);
});
