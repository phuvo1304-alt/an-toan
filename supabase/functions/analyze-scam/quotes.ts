// An Toàn - analyze-scam: check that each red flag's quote really appears in
// what the user sent (pure functions, unit-tested in test/quotes_test.ts).
//
// Why: the model's "quote" is shown to the user as proof. A quote that is not in
// their message (invented, misread, or paraphrased) must never reach them as if
// it were real. This check is mechanical, so it keeps working even if the prompt
// drifts or a scenario was never tested.
//
// Limits (be honest about them):
// - It needs the input as text, so it runs for Text and Voice checks. Screenshot
//   checks send only images; there is no text to compare against, so it is skipped.
// - It proves the quote is REAL, not that the title/explanation describe it
//   correctly. That part is handled by the prompt.

/// Normalizes text for matching: Unicode NFC, lowercase, unified quotes and
/// dashes, collapsed whitespace. Accents are KEPT: "gốc" and "góc" differ.
export function normalizeForMatch(s: string): string {
  return s
    .normalize("NFC")
    .toLowerCase()
    .replace(/[“”„«»]/g, '"')
    .replace(/[‘’‚]/g, "'")
    .replace(/[–—]/g, "-")
    .replace(/\s+/g, " ")
    .trim();
}

/// Strips quote marks and end punctuation the model may add around a snippet.
function trimEdges(s: string): string {
  return s.replace(/^[\s"'.,:;!?…-]+|[\s"'.,:;!?…]+$/g, "");
}

/// True if [quote] appears in [source]. The model sometimes joins two separate
/// lines with "..." or "…"; then every part must appear, in order.
export function quoteFoundIn(quote: string, source: string): boolean {
  const src = normalizeForMatch(source);
  const parts = normalizeForMatch(quote)
    .split(/\.\.\.|…/)
    .map(trimEdges)
    .filter((p) => p.length > 0);
  if (parts.length === 0) return true; // an empty quote claims nothing
  let from = 0;
  for (const part of parts) {
    const at = src.indexOf(part, from);
    if (at < 0) return false;
    from = at + part.length;
  }
  return true;
}

export interface QuotedFlag {
  title: string;
  explanation: string;
  quote: string;
}

/// Keeps flags whose quote is found in [source]; drops the others.
/// Returns how many were dropped, so the caller can log the rate (never the text).
export function keepVerifiedFlags<T extends QuotedFlag>(
  flags: T[],
  source: string,
): { kept: T[]; dropped: number } {
  const kept = flags.filter((f) => quoteFoundIn(f.quote, source));
  return { kept, dropped: flags.length - kept.length };
}
