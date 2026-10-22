// An Toàn - Edge Function: analyze-voice (Voice scam detection).
// The Flutter app calls THIS function with raw audio. Only this function knows the model server's address and
// shared key (secrets VOICE_SERVER_URL and VOICE_SERVER_KEY). Kill switch: VOICE_ENABLED must be "true".
// NOT DEPLOYED yet (owner decision, 2026-10-22). See handler.ts for the flow and the privacy rules.
//
// AI disclosure: the app tells users that audio is sent to our server for analysis and that results are
// AI-generated guidance (consent notice and disclaimer on the voice screen and its result).

import { createHandler } from "./handler.ts";
import { isRateLimited } from "../_shared/http.ts";
import { analyzeScamContent, ANTHROPIC_API_KEY } from "../_shared/scam_analysis.ts";
import { cutoffsFromEnv } from "../_shared/voice_labels.ts";

const env = (name: string) => Deno.env.get(name);

Deno.serve(createHandler({
  env,
  fetch,
  isRateLimited,
  analyzeScam: (text, lang) => {
    if (!ANTHROPIC_API_KEY) {
      console.error("ANTHROPIC_API_KEY is not set");
      return Promise.resolve({ ok: false, error: "server_error", status: 500 });
    }
    return analyzeScamContent(text, [], lang);
  },
  cutoffs: () => cutoffsFromEnv(env),
  log: (msg) => console.error(msg), // codes and counts only: never audio, transcript or addresses
}));
