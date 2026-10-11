// An Toàn - eval harness for the analyze-scam Edge Function (TEXT INPUT ONLY).
//
// Runs every case in test_cases.json N times each (the model's output isn't
// fully deterministic, so a single-run rate isn't something you can cite),
// against your LOCAL `supabase functions serve` -- never production, see the
// guardrail below. Writes a timestamped, model-labeled raw-results JSON file
// plus a plain console summary.
//
// This is slice 1: it proves the request/response plumbing and gives you the
// raw per-run data. It deliberately does NOT yet compute overall accuracy,
// false-positive/false-negative rate, a confusion matrix, or the
// pre-check-correlation breakdown -- that's a follow-up step once this slice
// is confirmed working, built on top of the data this script already records.
//
// Run (from the repo root), against `supabase functions serve` on its default
// port:
//   $env:ANALYZE_SCAM_URL = "http://127.0.0.1:54321/functions/v1/analyze-scam"
//   npx deno run --allow-net --allow-env --allow-read --allow-write data/eval_analyze_scam.ts
//
// Required env:
//   ANALYZE_SCAM_URL   Must contain "localhost" or "127.0.0.1", or the script
//                       refuses to run. To point it at a remote/production
//                       function on purpose (spends real Anthropic API money),
//                       set ALLOW_REMOTE_EVAL=1 explicitly -- never the default.
// Optional env:
//   SUPABASE_ANON_KEY  Sent as Bearer + apikey headers, same as the app does.
//                       Only needed if `functions serve` enforces JWT (the
//                       default). Omit it if you started serve with
//                       --no-verify-jwt.
//   EVAL_CASES_FILE    Case file to load, relative to this script's own
//                       directory (default "test_cases.json"). Lets a
//                       different investigation (e.g. scam_type stability)
//                       reuse this harness without forking it.
//   EVAL_RUNS          Runs per case (default 3).
//   EVAL_DELAY_MS      Delay between calls in ms (default 300), so this is
//                       never hammering even a local server.
//   CLAUDE_MODEL       Only used to LABEL the results filename (default
//                       matches index.ts's own default). Set it to whatever
//                       you passed to `functions serve` so the filename is
//                       accurate -- this script cannot read the model name out
//                       of the running function, since they are separate
//                       processes.

import { preCheck } from "../supabase/functions/analyze-scam/patterns.ts";
import { keepVerifiedFlags, type QuotedFlag } from "../supabase/functions/analyze-scam/quotes.ts";

interface TestCase {
  id: string;
  text: string;
  language: "vi" | "en";
  expected_risk_level: "safe" | "suspicious" | "likely_scam";
  expected_scam_type?: string;
  note: string;
  input_type: "text";
}

interface AnalyzeResponse {
  risk_level: string;
  risk_score: number;
  summary: string;
  red_flags: QuotedFlag[];
  what_to_do: string[];
  scam_type: string;
  confidence_note: string;
  language: string;
}

interface RunResult {
  run: number;
  ok: boolean;
  error?: string;
  risk_level?: string;
  risk_score?: number;
  scam_type?: string;
  latency_ms: number;
  quotes_total?: number;
  quotes_dropped?: number; // red_flags whose quote wasn't found in the case text (quotes.ts)
}

interface CaseResult {
  id: string;
  expected_risk_level: string;
  expected_scam_type?: string;
  note: string;
  // Computed once from the input text, not per run: preCheck() is pure and
  // deterministic, so it can't differ between runs of the same case.
  pattern_precheck: string[];
  runs: RunResult[];
  aggregate: {
    risk_levels_seen: string[];
    modal_risk_level: string | null;
    disagreement: boolean;
    scam_types_seen: string[];
  };
}

const ANALYZE_SCAM_URL = Deno.env.get("ANALYZE_SCAM_URL") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const RUNS = Number(Deno.env.get("EVAL_RUNS") ?? "3") || 3;
const DELAY_MS = Number(Deno.env.get("EVAL_DELAY_MS") ?? "300") || 300;
const MODEL_LABEL = Deno.env.get("CLAUDE_MODEL") ?? "claude-haiku-4-5-20251001";
const ALLOW_REMOTE = Deno.env.get("ALLOW_REMOTE_EVAL") === "1";
const CASES_FILE = Deno.env.get("EVAL_CASES_FILE") ?? "test_cases.json";

function fail(msg: string): never {
  console.error(`eval_analyze_scam: ${msg}`);
  Deno.exit(1);
}

if (!ANALYZE_SCAM_URL) {
  fail(
    "ANALYZE_SCAM_URL is not set. Point it at your LOCAL `supabase functions serve`, " +
      "e.g. http://127.0.0.1:54321/functions/v1/analyze-scam",
  );
}
const looksLocal = /localhost|127\.0\.0\.1/.test(ANALYZE_SCAM_URL);
if (!looksLocal && !ALLOW_REMOTE) {
  fail(
    `ANALYZE_SCAM_URL ("${ANALYZE_SCAM_URL}") does not look like a local address. ` +
      "Refusing to run, so this never spends real API money or hits production by accident. " +
      "If you really mean this, set ALLOW_REMOTE_EVAL=1 explicitly.",
  );
}

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

function modalValue(values: string[]): string | null {
  if (values.length === 0) return null;
  const counts = new Map<string, number>();
  for (const v of values) counts.set(v, (counts.get(v) ?? 0) + 1);
  let best = values[0];
  let bestCount = 0;
  for (const v of values) {
    const c = counts.get(v)!;
    if (c > bestCount) {
      best = v;
      bestCount = c;
    }
  }
  return best;
}

async function callOnce(testCase: TestCase, deviceId: string, run: number): Promise<RunResult> {
  const body = JSON.stringify({ language: testCase.language, device_id: deviceId, text: testCase.text });
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (ANON_KEY) {
    headers["Authorization"] = `Bearer ${ANON_KEY}`;
    headers["apikey"] = ANON_KEY;
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 60_000);
  const start = performance.now();
  try {
    const resp = await fetch(ANALYZE_SCAM_URL, { method: "POST", headers, body, signal: controller.signal });
    const latency_ms = Math.round(performance.now() - start);
    if (!resp.ok) {
      const errText = await resp.text().catch(() => "");
      return { run, ok: false, error: `HTTP ${resp.status}: ${errText.slice(0, 200)}`, latency_ms };
    }
    const data = (await resp.json()) as AnalyzeResponse;
    const { dropped } = keepVerifiedFlags(data.red_flags ?? [], testCase.text);
    return {
      run,
      ok: true,
      risk_level: data.risk_level,
      risk_score: data.risk_score,
      scam_type: data.scam_type,
      latency_ms,
      quotes_total: (data.red_flags ?? []).length,
      quotes_dropped: dropped,
    };
  } catch (e) {
    const latency_ms = Math.round(performance.now() - start);
    const msg = e instanceof DOMException && e.name === "AbortError" ? "timed out after 60s" : String(e);
    return { run, ok: false, error: msg, latency_ms };
  } finally {
    clearTimeout(timer);
  }
}

function printCaseLine(c: CaseResult) {
  const status = c.aggregate.modal_risk_level === c.expected_risk_level ? "MATCH" : "DIFF ";
  const disagreement = c.aggregate.disagreement ? " [DISAGREEMENT across runs]" : "";
  const totalDropped = c.runs.reduce((sum, r) => sum + (r.quotes_dropped ?? 0), 0);
  const failedRuns = c.runs.filter((r) => !r.ok).length;
  const failedNote = failedRuns > 0 ? ` [${failedRuns}/${c.runs.length} runs failed]` : "";
  console.log(
    `${status} ${c.id.padEnd(24)} expected=${c.expected_risk_level.padEnd(12)} ` +
      `actual=${(c.aggregate.modal_risk_level ?? "n/a").padEnd(12)} ` +
      `pre-check=[${c.pattern_precheck.join(",") || "-"}] quote_mismatches=${totalDropped}${disagreement}${failedNote}`,
  );
}

function printTotals(results: CaseResult[]) {
  const matches = results.filter((c) => c.aggregate.modal_risk_level === c.expected_risk_level).length;
  const disagreements = results.filter((c) => c.aggregate.disagreement).length;
  const totalDropped = results.reduce(
    (sum, c) => sum + c.runs.reduce((s, r) => s + (r.quotes_dropped ?? 0), 0),
    0,
  );
  const totalFailedRuns = results.reduce((sum, c) => sum + c.runs.filter((r) => !r.ok).length, 0);
  console.log("");
  console.log(
    `${matches}/${results.length} cases: modal actual risk_level matched expected_risk_level exactly ` +
      "(a simple exact-match count only -- the real accuracy/FP/FN/confusion breakdown is a follow-up step).",
  );
  console.log(`${disagreements}/${results.length} cases had disagreement across the ${RUNS} runs.`);
  console.log(`${totalDropped} quote mismatches total across all runs.`);
  if (totalFailedRuns > 0) {
    console.log(`${totalFailedRuns} runs failed outright (HTTP error or timeout) -- see the results file.`);
  }
}

async function writeResultsFile(results: CaseResult[]): Promise<string> {
  const dirUrl = new URL("./eval_results/", import.meta.url);
  await Deno.mkdir(dirUrl, { recursive: true });
  const stamp = new Date().toISOString().replace(/[:.]/g, "-");
  const modelSlug = MODEL_LABEL.replace(/[^a-zA-Z0-9_.-]/g, "_");
  const casesSlug = CASES_FILE.replace(/\.json$/, "").replace(/[^a-zA-Z0-9_.-]/g, "_");
  const fileUrl = new URL(`./${stamp}_${casesSlug}_${modelSlug}.json`, dirUrl);
  const payload = {
    generated_at: new Date().toISOString(),
    model: MODEL_LABEL,
    target_url: ANALYZE_SCAM_URL,
    cases_file: CASES_FILE,
    runs_per_case: RUNS,
    cases: results,
  };
  await Deno.writeTextFile(fileUrl, JSON.stringify(payload, null, 2));
  return fileUrl.toString();
}

async function run() {
  const casesUrl = new URL(`./${CASES_FILE}`, import.meta.url);
  const cases: TestCase[] = JSON.parse(await Deno.readTextFile(casesUrl));

  console.log(`eval_analyze_scam: ${cases.length} cases from ${CASES_FILE} x ${RUNS} runs -> ${ANALYZE_SCAM_URL}`);
  console.log(`model label (for the results filename only, not sent to the server): ${MODEL_LABEL}`);
  if (!ANON_KEY) {
    console.log(
      "SUPABASE_ANON_KEY not set: calls will have no auth header " +
        "(only works if `functions serve` was started with --no-verify-jwt).",
    );
  }
  console.log("");

  const results: CaseResult[] = [];

  for (const testCase of cases) {
    const deviceId = `eval-${testCase.id}`;
    const patternPrecheck = preCheck(testCase.text).map((m) => m.scamType);
    const runs: RunResult[] = [];

    for (let i = 1; i <= RUNS; i++) {
      runs.push(await callOnce(testCase, deviceId, i));
      await sleep(DELAY_MS);
    }

    const okRuns = runs.filter((r) => r.ok);
    const riskLevelsSeen = [...new Set(okRuns.map((r) => r.risk_level!))];
    const scamTypesSeen = [...new Set(okRuns.map((r) => r.scam_type!))];

    const caseResult: CaseResult = {
      id: testCase.id,
      expected_risk_level: testCase.expected_risk_level,
      expected_scam_type: testCase.expected_scam_type,
      note: testCase.note,
      pattern_precheck: patternPrecheck,
      runs,
      aggregate: {
        risk_levels_seen: riskLevelsSeen,
        modal_risk_level: modalValue(okRuns.map((r) => r.risk_level!)),
        disagreement: riskLevelsSeen.length > 1,
        scam_types_seen: scamTypesSeen,
      },
    };
    results.push(caseResult);
    printCaseLine(caseResult);
  }

  const path = await writeResultsFile(results);
  printTotals(results);
  console.log(`\nWrote ${path}`);
}

await run();
