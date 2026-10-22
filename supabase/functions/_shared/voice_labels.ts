// An Toàn - the voice guess: clip score, cut-offs and the three outcomes. A TypeScript port of
// data/voice_eval/cutoffs.py (label(), as corrected by deviation D8). Pure functions, no network.
//
// The detector is NOT validated (CLAUDE.md 14.11). The cut-offs below are the ones the pre-registered Vietnamese
// evaluation computed from the clean arm's tuning clips: t_hum 0.1779, t_ai 0.002. They overlap
// (t_hum > t_ai), so there is NO usable gap and every clip is "cant_tell". They can be replaced only through the
// VOICE_T_HUM / VOICE_T_AI secrets, which must come from a NEW pre-registered evaluation.

export type VoiceGuess = "human" | "ai" | "cant_tell";

export interface Cutoffs {
  /** A clip scoring below this (and with no piece above t_ai) is "human". */
  tHum: number;
  /** A clip scoring above this (and with no piece below t_hum) is "ai". */
  tAi: number;
}

/// From data/voice_eval/results/metrics.json (cutoffs_from_clean_arm_tuning).
export const PREREGISTERED_CUTOFFS: Cutoffs = { tHum: 0.1779, tAi: 0.002 };

/// A clip shorter than this is always "cant_tell".
export const MIN_LABEL_SECONDS = 3.0;

/// The gap is usable only if the human zone ends at or below where the AI zone starts.
export function hasUsableGap(c: Cutoffs): boolean {
  return Number.isFinite(c.tHum) && Number.isFinite(c.tAi) && c.tHum <= c.tAi;
}

/// Reads VOICE_T_HUM / VOICE_T_AI. Both must be numbers in [0, 1]; anything else falls back to the
/// pre-registered values (never to a made-up default).
export function cutoffsFromEnv(get: (name: string) => string | undefined): Cutoffs {
  const parse = (v: string | undefined): number | null => {
    if (v === undefined || v.trim() === "") return null;
    const n = Number(v);
    return Number.isFinite(n) && n >= 0 && n <= 1 ? n : null;
  };
  const tHum = parse(get("VOICE_T_HUM"));
  const tAi = parse(get("VOICE_T_AI"));
  return tHum !== null && tAi !== null ? { tHum, tAi } : PREREGISTERED_CUTOFFS;
}

export function clipScore(pieces: number[]): number {
  return pieces.reduce((a, b) => a + b, 0) / pieces.length;
}

/// Mean of the piece scores against the cut-offs; a "human"/"ai" label also needs that no piece sits on the
/// opposite side. No usable gap, a short clip or bad input: "cant_tell".
export function labelVoice(pieces: unknown, durationS: unknown, c: Cutoffs): VoiceGuess {
  if (!Array.isArray(pieces) || pieces.length === 0 || !pieces.every((p) => typeof p === "number" && Number.isFinite(p))) {
    return "cant_tell";
  }
  if (typeof durationS !== "number" || !Number.isFinite(durationS) || durationS < MIN_LABEL_SECONDS) return "cant_tell";
  if (!hasUsableGap(c)) return "cant_tell";
  const s = clipScore(pieces as number[]);
  const ps = pieces as number[];
  if (s > c.tAi && !ps.some((p) => p < c.tHum)) return "ai";
  if (s < c.tHum && !ps.some((p) => p > c.tAi)) return "human";
  return "cant_tell";
}
