// An Toàn - shared HTTP helpers for the Edge Functions (CORS pinning, the IP-based durable rate limit, JSON
// responses). Moved here unchanged from analyze-scam/index.ts so analyze-voice uses the exact same code.

// ---- CORS -------------------------------------------------------------------
// CORS headers only control whether a BROWSER's JavaScript is allowed to read
// the response -- they are not an access-control mechanism and do not stop a
// direct script/curl call (which sends no Origin header, or can set any
// value it likes). The real cost-abuse defence is the IP-based rate limit
// below. CORS pinning here only stops OTHER WEBSITES from embedding a call to
// this function in their own client-side JS and having a visitor's browser
// make the request on the site's behalf.
//
// ALLOWED_WEB_ORIGIN is set after the web app is deployed (its exact origin
// isn't known until then) -- see the deploy README. Until it is set, no
// browser origin is allowed through (native app calls, which send no Origin
// header at all, are unaffected either way).
const ALLOWED_WEB_ORIGIN = Deno.env.get("ALLOWED_WEB_ORIGIN") ?? "";

export function corsHeadersFor(req: Request) {
  const origin = req.headers.get("origin");
  const allow = origin && ALLOWED_WEB_ORIGIN && origin === ALLOWED_WEB_ORIGIN
    ? origin
    : "null";
  return {
    "Access-Control-Allow-Origin": allow,
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Vary": "Origin",
  };
}

// ---- Server-side rate limit, keyed by IP (not a client-supplied value) -----
// Durable (Postgres, see migrations/20261012120000_analysis_rate_log.sql),
// not an in-memory Map: survives cold starts and is correct across however
// many concurrent function instances are running. Keyed by the caller's real
// IP address, hashed before it ever reaches the database -- never a
// client-supplied field like the old device_id, which anyone calling the
// function directly (not through the app) could simply relabel per request.
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
// The new-style secret API key (sb_secret_...), not the legacy service_role
// JWT: same bypass-RLS server-side privilege, but individually rotatable
// without touching the project's shared JWT secret (which the legacy anon
// key the mobile app ships with is also derived from).
const DB_SECRET_KEY = Deno.env.get("SB_SECRET_API_KEY") ?? "";
const IP_HASH_SALT = Deno.env.get("IP_HASH_SALT") ?? "";
export const RATE_LIMIT = 30; // analyze-scam: requests per window per IP
export const RATE_WINDOW_MINUTES = 60;

function clientIp(req: Request): string {
  // cf-connecting-ip (Cloudflare's own header, set directly by Cloudflare and
  // not attacker-controlled) first; x-forwarded-for (the de facto standard
  // most reverse proxies set, first entry = original client) as a fallback.
  return req.headers.get("cf-connecting-ip")
    ?? req.headers.get("x-forwarded-for")?.split(",")[0]?.trim()
    ?? "unknown";
}

async function hashIp(ip: string): Promise<string> {
  const bytes = new TextEncoder().encode(`${ip}:${IP_HASH_SALT}`);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

// Returns true if the caller is over the limit. Fails CLOSED: if the rate
// check itself cannot run (network error, misconfigured secrets), this
// treats the request as rate-limited rather than letting paid API calls
// through with no cap in place -- an occasional false "try again later" is
// far cheaper than a limiter silently doing nothing.
async function isRateLimitedImpl(req: Request, prefix: string, limit: number, windowMinutes: number): Promise<boolean> {
  if (!SUPABASE_URL || !DB_SECRET_KEY) {
    console.error("rate limit misconfigured: missing SUPABASE_URL or SB_SECRET_API_KEY");
    return true;
  }
  try {
    const ipHash = await hashIp(`${prefix}${clientIp(req)}`);
    const resp = await fetch(`${SUPABASE_URL}/rest/v1/rpc/check_and_log_analysis_rate`, {
      method: "POST",
      headers: {
        apikey: DB_SECRET_KEY,
        Authorization: `Bearer ${DB_SECRET_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        p_ip_hash: ipHash,
        p_limit: limit,
        p_window_minutes: windowMinutes,
      }),
    });
    if (!resp.ok) {
      console.error("rate limit check failed", resp.status, await resp.text());
      return true;
    }
    return (await resp.json()) === true;
  } catch (e) {
    console.error("rate limit check threw", e);
    return true;
  }
}

export function jsonWith(headers: Record<string, string>) {
  return (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { ...headers, "Content-Type": "application/json" } });
}


/// analyze-scam keeps its exact key (empty prefix) and limits. Other functions pass their own prefix so
/// their budget is separate (the same table and the same fail-closed behaviour).
export function isRateLimited(
  req: Request,
  opts: { prefix?: string; limit?: number; windowMinutes?: number } = {},
): Promise<boolean> {
  return isRateLimitedImpl(req, opts.prefix ?? "", opts.limit ?? RATE_LIMIT, opts.windowMinutes ?? RATE_WINDOW_MINUTES);
}
