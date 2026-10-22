// Tests for the voice guess (supabase/functions/_shared/voice_labels.ts), a port of data/voice_eval/cutoffs.py.
// Run: deno test test/voice_labels_test.ts --allow-read
//
// What they pin down: with the PRE-REGISTERED cut-offs there is no usable gap, so every clip is "cant_tell";
// the labels agree with the Python reference on 240 generated cases; bad input never produces a verdict.

import { assert, assertEquals } from "jsr:@std/assert@^1.0.0";
import {
  cutoffsFromEnv,
  hasUsableGap,
  labelVoice,
  MIN_LABEL_SECONDS,
  PREREGISTERED_CUTOFFS,
} from "../supabase/functions/_shared/voice_labels.ts";

const usable = { tHum: 0.14, tAi: 0.81 };

Deno.test("the pre-registered cut-offs are the evaluation's and have NO usable gap", () => {
  assertEquals(PREREGISTERED_CUTOFFS, { tHum: 0.1779, tAi: 0.002 });
  assertEquals(hasUsableGap(PREREGISTERED_CUTOFFS), false);
});

Deno.test("with the pre-registered cut-offs every clip is cant_tell, whatever the scores", () => {
  for (const pieces of [[0.0], [0.001], [0.5], [0.99], [0.99, 0.98, 0.97], [0.01, 0.02]]) {
    for (const dur of [1, 3, 10, 60]) {
      assertEquals(labelVoice(pieces, dur, PREREGISTERED_CUTOFFS), "cant_tell");
    }
  }
});

Deno.test("with a usable gap: human, ai, and the band between is cant_tell", () => {
  assert(hasUsableGap(usable));
  assertEquals(labelVoice([0.9, 0.95], 5, usable), "ai");
  assertEquals(labelVoice([0.05, 0.02], 5, usable), "human");
  assertEquals(labelVoice([0.4, 0.5], 5, usable), "cant_tell");
  assertEquals(labelVoice([0.81], 5, usable), "cant_tell"); // on the cut-off is not past it
  assertEquals(labelVoice([0.14], 5, usable), "cant_tell");
});

Deno.test("a piece on the opposite side blocks the label; short clips are cant_tell", () => {
  assertEquals(labelVoice([0.99, 0.05], 5, usable), "cant_tell"); // mean is high but one piece looks human
  assertEquals(labelVoice([0.01, 0.95], 5, usable), "cant_tell");
  assertEquals(labelVoice([0.9, 0.95], MIN_LABEL_SECONDS - 0.1, usable), "cant_tell");
  assertEquals(labelVoice([0.9, 0.95], MIN_LABEL_SECONDS, usable), "ai");
});

Deno.test("bad input is cant_tell, never a verdict", () => {
  for (const [pieces, dur] of [
    [[], 5], [null, 5], ["x", 5], [[NaN], 5], [[0.9, "a"], 5], [[0.9], NaN], [[0.9], "5"], [[0.9], undefined],
  ] as [unknown, unknown][]) {
    assertEquals(labelVoice(pieces, dur, usable), "cant_tell");
  }
});

Deno.test("overlapping cut-offs (t_hum > t_ai) are no gap: everything cant_tell", () => {
  assertEquals(labelVoice([0.99], 10, { tHum: 0.6, tAi: 0.4 }), "cant_tell");
  assertEquals(labelVoice([0.01], 10, { tHum: 0.6, tAi: 0.4 }), "cant_tell");
  assertEquals(hasUsableGap({ tHum: 0.5, tAi: 0.5 }), true); // touching is allowed (like cutoffs.py)
});

Deno.test("cutoffsFromEnv: both secrets valid -> used; anything else -> the pre-registered pair", () => {
  const env = (m: Record<string, string>) => (n: string) => m[n];
  assertEquals(cutoffsFromEnv(env({ VOICE_T_HUM: "0.14", VOICE_T_AI: "0.81" })), usable);
  assertEquals(cutoffsFromEnv(env({})), PREREGISTERED_CUTOFFS);
  assertEquals(cutoffsFromEnv(env({ VOICE_T_HUM: "0.14" })), PREREGISTERED_CUTOFFS); // one missing
  assertEquals(cutoffsFromEnv(env({ VOICE_T_HUM: "0.14", VOICE_T_AI: "abc" })), PREREGISTERED_CUTOFFS);
  assertEquals(cutoffsFromEnv(env({ VOICE_T_HUM: "-1", VOICE_T_AI: "0.8" })), PREREGISTERED_CUTOFFS);
  assertEquals(cutoffsFromEnv(env({ VOICE_T_HUM: "0.1", VOICE_T_AI: "7" })), PREREGISTERED_CUTOFFS);
  assertEquals(cutoffsFromEnv(env({ VOICE_T_HUM: "", VOICE_T_AI: "" })), PREREGISTERED_CUTOFFS);
});

Deno.test("agrees with the Python reference (cutoffs.py label) on 240 generated cases", () => {
  const cases = JSON.parse(Deno.readTextFileSync(new URL("./fixtures/voice_label_cases.json", import.meta.url)));
  assertEquals(cases.length, 240);
  const map: Record<string, string> = { leans_ai: "ai", leans_human: "human", cant_tell: "cant_tell" };
  const seen = new Set<string>();
  for (const c of cases) {
    const got = labelVoice(c.pieces, c.duration_s, { tHum: c.cut.t_hum, tAi: c.cut.t_ai });
    assertEquals(got, map[c.label], JSON.stringify(c));
    seen.add(got);
  }
  assertEquals(seen, new Set(["ai", "human", "cant_tell"])); // the fixture exercises all three outcomes
});
