// SQL tests for Phone Checker v3 (public comments), run against a real Postgres
// (PGlite, in memory) with the real migration files from supabase/migrations/.
// Run: npx deno test --allow-read --allow-env test/phone_comments_sql_test.ts

import { assert, assertEquals, assertNotEquals } from "jsr:@std/assert@^1.0.0";
import { PGlite } from "npm:@electric-sql/pglite@0.5.8";
import { pgcrypto } from "npm:@electric-sql/pglite@0.5.8/contrib/pgcrypto";

const dir = new URL("../supabase/migrations/", import.meta.url);
const migration = (name: string) => Deno.readTextFileSync(new URL(name, dir));
const OLD = [
  "20261005120000_phone_reports.sql",
  "20261005130000_report_salt_private_table.sql",
  "20261006120000_phone_reports_dispute_and_limits.sql",
];
const NEW = "20261007120000_phone_report_comments.sql";

const db = new PGlite({ extensions: { pgcrypto } });
// Same default privileges as the hosted Supabase project (read from its
// pg_default_acl on 2026-10-07): every NEW function in public is executable by
// anon/authenticated/service_role, and every new table is fully open to them.
// So any internal function or table a migration forgets to revoke shows up as
// exposed in these tests, exactly as it would in production.
await db.exec(`create schema extensions;
  create role anon nologin; create role authenticated nologin; create role service_role nologin;
  grant usage on schema public to anon, authenticated, service_role;
  alter default privileges in schema public grant execute on functions to anon, authenticated, service_role;
  alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
  alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;`);
for (const m of OLD) await db.exec(migration(m));

// ---- helpers -------------------------------------------------------------------------
async function sha(s: string): Promise<string> {
  const b = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(b)].map((x) => x.toString(16).padStart(2, "0")).join("");
}
const dev = (n: number) => sha(`device-${n}-0123456789abcdef`); // what the phone sends

type PgErr = { message: string; code?: string; detail?: string; hint?: string } | null;
async function run(sql: string, params: unknown[] = []): Promise<PgErr> {
  try {
    await db.query(sql, params);
    return null;
  } catch (e) {
    const x = e as { message: string; code?: string; detail?: string; hint?: string };
    return { message: x.message, code: x.code, detail: x.detail, hint: x.hint };
  }
}
const msg = async (sql: string, params: unknown[] = []) => (await run(sql, params))?.message ?? null;
async function asAnon<T>(fn: () => Promise<T>): Promise<T> {
  await db.exec("set role anon");
  try {
    return await fn();
  } finally {
    await db.exec("reset role");
  }
}
const rows = async <T>(sql: string, params: unknown[] = []) => (await db.query<T>(sql, params)).rows;

const submit = async (phone: string, cat: string, desc: string | null, device: number) =>
  msg("select public.submit_phone_report($1,$2,$3,$4)", [phone, cat, desc, await dev(device)]);
type Comment = { comment_token: string; category: string; description: string; created_at: Date };
const comments = (phone: string, cursor = 0) =>
  rows<Comment>("select * from public.get_phone_report_comments($1, $2)", [phone, cursor]);
const disputeComment = async (phone: string, token: string | null, device: number) =>
  run("select public.dispute_phone_comment($1,$2,$3)", [phone, token, await dev(device)]);
const disputeNumber = async (phone: string, device: number) =>
  msg("select public.dispute_phone_report($1,$2)", [phone, await dev(device)]);
const reset = () => db.exec("delete from public.report_rate_log; delete from public.phone_reports;");
/** Owner-only: the token of a row, to check what the app would get. */
const tokenOf = async (id: string) =>
  (await rows<{ t: string }>("select public.phone_report_comment_token($1) t", [id]))[0].t;
/** Inserts a report directly (as the owner), skipping the RPC and its limits. */
async function seed(phone: string, desc: string | null, opts: { visible?: boolean; disputed?: number; ageMin?: number } = {}) {
  const r = await rows<{ id: string }>(
    `insert into public.phone_reports (phone_normalized, category, description, reporter_hash, visible_to_public, disputed_count, created_at)
     values ($1, 'fake_job', $2, md5(random()::text), $3, $4, now() - make_interval(mins => $5)) returning id`,
    [phone, desc, opts.visible ?? true, opts.disputed ?? 0, opts.ageMin ?? 0],
  );
  return r[0].id;
}

// ---- 1. visible_to_public: backfill, default, submit -----------------------------------
// Two reports written under the OLD rule, before the new migration exists.
assertEquals(await submit("0901000001", "fake_job", "Tin cũ: mời làm CTV", 1), null);
assertEquals(await submit("0901000001", "loan", "Tin cũ thứ hai", 2), null);
await db.exec(migration(NEW));

Deno.test("backfill: every report that existed before the migration is private", async () => {
  const r = await rows<{ n: number; pub: number }>(
    "select count(*)::int n, count(*) filter (where visible_to_public)::int pub from public.phone_reports",
  );
  assertEquals(r[0], { n: 2, pub: 0 });
});

Deno.test("column is NOT NULL with DEFAULT false (fail-safe direction)", async () => {
  const c = await rows<{ column_default: string; is_nullable: string }>(
    `select column_default, is_nullable from information_schema.columns
     where table_name = 'phone_reports' and column_name = 'visible_to_public'`,
  );
  assertEquals(c[0], { column_default: "false", is_nullable: "NO" });
});

Deno.test("an insert that omits visible_to_public stays private", async () => {
  const r = await rows<{ v: boolean }>(
    `insert into public.phone_reports (phone_normalized, category, description, reporter_hash)
     values ('+84901000002', 'other', 'forgot the field', 'x') returning visible_to_public v`,
  );
  assertEquals(r[0].v, false);
  await db.exec("delete from public.phone_reports where phone_normalized = '+84901000002'");
});

Deno.test("submit_phone_report explicitly makes NEW reports public", async () => {
  assertEquals(await submit("0901000001", "phishing", "Tin mới sau khi có tính năng", 3), null);
  const r = await rows<{ d: string; v: boolean }>(
    "select description d, visible_to_public v from public.phone_reports order by created_at",
  );
  assertEquals(r.map((x) => x.v), [false, false, true]);
  assertEquals(r[2].d, "Tin mới sau khi có tính năng");
});

Deno.test("old private reports: still counted in the summary, text never shown", async () => {
  const s = await rows<{ report_count: number }>("select * from public.get_phone_report_summary('0901000001')");
  assertEquals(s[0].report_count, 3); // 2 old (private) + 1 new: unchanged counting
  const c = await asAnon(() => comments("0901000001"));
  assertEquals(c.map((x) => x.description), ["Tin mới sau khi có tính năng"]);
});

// ---- 2. Access ------------------------------------------------------------------------------
Deno.test("anon: can call the two comment RPCs, nothing internal", async () => {
  await asAnon(async () => {
    const denied = (m: string | null) => /permission denied/.test(m ?? "");
    assert(denied(await msg("select * from private.app_settings")), "read the secret");
    assert(denied(await msg("select * from public.phone_reports")), "read raw reports");
    assert(denied(await msg("select * from public.report_rate_log")), "read the rate log");
    assert(denied(await msg("select public.phone_report_comment_token(gen_random_uuid())")), "mint a token");
    assert(denied(await msg("select public.strip_report_pii('x')")), "call the stripper");
    assertEquals(await msg("select * from public.get_phone_report_comments('0901000001')"), null);
  });
});

Deno.test("the comment_token_key (row in private.app_settings) is unreachable for anon/authenticated", async () => {
  const one = async (sql: string) => (await rows<{ v: unknown }>(sql))[0].v;
  // RLS on, no policies at all, owner-only ACL, no column grants.
  assertEquals(await one("select relrowsecurity v from pg_class where oid = 'private.app_settings'::regclass"), true);
  assertEquals(await one("select count(*)::int v from pg_policy where polrelid = 'private.app_settings'::regclass"), 0);
  assertEquals(await one("select count(*)::int v from pg_attribute where attrelid = 'private.app_settings'::regclass and attacl is not null"), 0);
  for (const role of ["anon", "authenticated"]) {
    assertEquals(await one(`select has_schema_privilege('${role}', 'private', 'USAGE') v`), false, role);
    for (const priv of ["SELECT", "INSERT", "UPDATE", "DELETE", "TRUNCATE", "REFERENCES", "TRIGGER"]) {
      assertEquals(await one(`select has_table_privilege('${role}', 'private.app_settings', '${priv}') v`), false, `${role} ${priv}`);
    }
  }
  // Exactly two functions read app_settings, and neither is callable by the app.
  const readers = await rows<{ fn: string; anon: boolean; auth: boolean }>(
    `select p.oid::regprocedure::text fn, has_function_privilege('anon', p.oid, 'EXECUTE') anon,
            has_function_privilege('authenticated', p.oid, 'EXECUTE') auth
     from pg_proc p where p.prosrc ilike '%app_settings%' order by 1`,
  );
  assertEquals(readers, [
    { fn: "phone_report_comment_token(uuid)", anon: false, auth: false },
    { fn: "salted_reporter_hash(text)", anon: false, auth: false },
  ]);
  // The key's name appears in exactly one function body.
  const keyUsers = await rows<{ proname: string }>("select proname from pg_proc where prosrc ilike '%comment_token_key%'");
  assertEquals(keyUsers.map((x) => x.proname), ["phone_report_comment_token"]);
  // No view, rule or materialized view selects from it.
  assertEquals(await one(
    "select count(*)::int v from pg_depend d join pg_rewrite r on r.oid = d.objid where d.refobjid = 'private.app_settings'::regclass",
  ), 0);
});

Deno.test("with Supabase's default grants, anon can execute ONLY the 5 app RPCs", async () => {
  const callable = await rows<{ fn: string }>(
    `select p.proname fn from pg_proc p
     where p.pronamespace = 'public'::regnamespace and has_function_privilege('anon', p.oid, 'EXECUTE')
     order by 1`,
  );
  assertEquals(callable.map((x) => x.fn), [
    "dispute_phone_comment", "dispute_phone_report", "get_phone_report_comments",
    "get_phone_report_summary", "submit_phone_report",
  ]);
  for (const t of ["phone_reports", "report_rate_log"]) {
    for (const priv of ["SELECT", "INSERT", "UPDATE", "DELETE"]) {
      const v = (await rows<{ v: boolean }>(`select has_table_privilege('anon', 'public.${t}', '${priv}') v`))[0].v;
      assertEquals(v, false, `anon ${priv} ${t}`);
    }
  }
});

Deno.test("every function in public (incl. SECURITY DEFINER ones) sets search_path", async () => {
  const fns = await rows<{ proname: string; prosecdef: boolean; proconfig: string[] | null }>(
    "select proname, prosecdef, proconfig from pg_proc where pronamespace = 'public'::regnamespace",
  );
  const definers = fns.filter((f) => f.prosecdef).map((f) => f.proname).sort();
  assertEquals(definers, [
    "dispute_phone_comment", "dispute_phone_report", "get_phone_report_comments",
    "get_phone_report_summary", "submit_phone_report",
  ]);
  for (const f of fns) assert((f.proconfig ?? []).some((c) => c.startsWith("search_path=")), f.proname);
});

Deno.test("comments return only token, category, text, date: no id or reporter", async () => {
  const fields = await rows<{ c: string }>(
    `select string_agg(a.attname, ',' order by a.attnum) c
     from pg_proc p, unnest(p.proargnames, p.proargmodes) with ordinality as a(attname, mode, attnum)
     where p.proname = 'get_phone_report_comments' and a.mode = 't'`,
  );
  assertEquals(fields[0].c, "comment_token,category,description,created_at");
});

// ---- 3. Which comments are shown ---------------------------------------------------------------
Deno.test("never shows private, disputed-away, or text-less reports", async () => {
  await reset();
  const P = "+84902000000";
  const shown = await seed(P, "Hiện: công khai", { ageMin: 1 });
  const once = await seed(P, "Hiện: mới bị báo lỗi 1 lần", { disputed: 1, ageMin: 2 });
  const priv = await seed(P, "ẨN: báo cáo cũ", { visible: false, ageMin: 3 });
  const gone = await seed(P, "ẨN: đã bị báo lỗi 2 lần", { disputed: 2, ageMin: 4 });
  await seed(P, null, { ageMin: 5 }); // public but no text: not a comment
  const c = await asAnon(() => comments(P));
  assertEquals(c.map((x) => x.description), ["Hiện: công khai", "Hiện: mới bị báo lỗi 1 lần"]);
  const tokens = c.map((x) => x.comment_token);
  assertEquals(tokens, [await tokenOf(shown), await tokenOf(once)]);
  assert(!tokens.includes(await tokenOf(priv)) && !tokens.includes(await tokenOf(gone)));
});

Deno.test("pagination: 20 per page, newest first, no overlap; bad cursor/phone rejected", async () => {
  await reset();
  const P = "+84902000001";
  for (let i = 0; i < 25; i++) await seed(P, `Nhận xét số ${i}`, { ageMin: i });
  const [p1, p2, p3] = await asAnon(async () => [await comments(P, 0), await comments(P, 20), await comments(P, 40)]);
  assertEquals([p1.length, p2.length, p3.length], [20, 5, 0]);
  assertEquals(p1[0].description, "Nhận xét số 0"); // newest
  assertEquals(p2[4].description, "Nhận xét số 24"); // oldest
  assertEquals(new Set([...p1, ...p2].map((x) => x.comment_token)).size, 25);
  await asAnon(async () => {
    for (const bad of [-1, 1001, null]) {
      assertEquals(await msg("select * from public.get_phone_report_comments($1, $2)", [P, bad]), "invalid_cursor");
    }
    assertEquals(await msg("select * from public.get_phone_report_comments('0281234567')"), "invalid_phone");
  });
  // The default cursor is 0.
  assertEquals((await rows("select * from public.get_phone_report_comments($1)", [P])).length, 20);
});

Deno.test("descriptions are PII-stripped on the way out, stored original", async () => {
  await reset();
  const P = "+84902000002";
  await seed(P, "Gọi từ 0912 345 678, bắt nạp 500.000đ vào STK 0123456789");
  const c = await asAnon(() => comments(P));
  assertEquals(c[0].description, "Gọi từ ***, bắt nạp 500.000đ vào STK ***");
  const stored = await rows<{ d: string }>("select description d from public.phone_reports where phone_normalized = $1", [P]);
  assertEquals(stored[0].d, "Gọi từ 0912 345 678, bắt nạp 500.000đ vào STK 0123456789");
});

// ---- 4. comment_token ------------------------------------------------------------------------
Deno.test("token: stable across calls, 128-bit hex, not the row id", async () => {
  await reset();
  const P = "+84902000003";
  const id = await seed(P, "Nhận xét");
  const a = await asAnon(() => comments(P));
  const b = await asAnon(() => comments(P));
  assertEquals(a[0].comment_token, b[0].comment_token);
  assert(/^[0-9a-f]{32}$/.test(a[0].comment_token));
  assert(!a[0].comment_token.includes(id.replaceAll("-", "").slice(0, 8)));
});

Deno.test("token can't be derived by hashing the id or guessed integers", async () => {
  await reset();
  const P = "+84902000004";
  const id = await seed(P, "Nhận xét");
  const token = (await asAnon(() => comments(P)))[0].comment_token;
  // Hashes of the real id without the secret key, and of guessed small integers.
  const guesses = await rows<{ g: string }>(
    `select left(g, 32) g from (
       select encode(extensions.digest($1::text, 'sha256'), 'hex') g
       union all select md5($1::text)
       union all select encode(extensions.hmac($1::text, '', 'sha256'), 'hex')
       union all select encode(extensions.hmac($1::text,
         (select value from private.app_settings where key = 'report_salt'), 'sha256'), 'hex')
       union all select encode(extensions.digest(i::text, 'sha256'), 'hex') from generate_series(1, 5000) i
       union all select md5(i::text) from generate_series(1, 5000) i
       union all select encode(extensions.hmac(i::text, $1::text, 'sha256'), 'hex') from generate_series(1, 100) i
     ) x`,
    [id],
  );
  assertEquals(guesses.length, 10104); // 4 + 5000 + 5000 + 100
  assert(!guesses.some((x) => x.g === token), "a guess matched the real token");
  // And a guessed token is refused by the dispute RPC.
  assertEquals((await asAnon(() => disputeComment(P, guesses[0].g, 50)))?.message, "invalid_comment");
});

// ---- 5. dispute_phone_comment ----------------------------------------------------------------
Deno.test("dispute by token flags THAT report, not the newest one", async () => {
  await reset();
  const P = "+84902000005";
  const newer = await seed(P, "Mới", { ageMin: 1 });
  const older = await seed(P, "Cũ", { ageMin: 60 });
  const olderToken = await tokenOf(older);
  assertEquals(await asAnon(() => disputeComment(P, olderToken, 60)), null);
  const d = await rows<{ id: string; disputed_count: number }>("select id, disputed_count from public.phone_reports");
  assertEquals(d.find((x) => x.id === older)?.disputed_count, 1);
  assertEquals(d.find((x) => x.id === newer)?.disputed_count, 0);
  const log = await rows<{ report_id: string }>("select report_id from public.report_rate_log");
  assertEquals(log.map((x) => x.report_id), [older]);
});

Deno.test("invalid token: identical error for garbage, almost-valid, hidden, other number", async () => {
  await reset();
  const P = "+84902000006";
  const real = await tokenOf(await seed(P, "Hiện"));
  const hiddenPriv = await tokenOf(await seed(P, "Riêng tư", { visible: false }));
  const hiddenGone = await tokenOf(await seed(P, "Đã bị báo lỗi", { disputed: 2 }));
  const otherNum = await tokenOf(await seed("+84902000099", "Số khác"));
  const flip = (t: string) => t.slice(0, -1) + (t.endsWith("0") ? "1" : "0");
  const bad: (string | null)[] = [
    "xyz", "", null, "0".repeat(32), flip(real), real.toUpperCase(), real + "0", real.slice(0, 31),
    hiddenPriv, hiddenGone, otherNum, "' or 1=1 --",
  ];
  const errors: PgErr[] = [];
  for (const t of bad) errors.push(await asAnon(() => disputeComment(P, t, 70)));
  for (const e of errors) assertEquals(e, errors[0]);
  assertEquals(errors[0]?.message, "invalid_comment");
  assertEquals(errors[0]?.detail, undefined); // nothing extra in the error
  // Nothing was logged or counted for any failed attempt.
  assertEquals((await rows("select 1 from public.report_rate_log")).length, 0);
  const counts = await rows<{ s: number }>("select sum(disputed_count)::int s from public.phone_reports");
  assertEquals(counts[0].s, 2); // only the seeded disputed_count: 2
  assertNotEquals(real, flip(real));

  // Informational only (not asserted, PGlite timing is noisy): average time per
  // call for garbage vs almost-valid tokens.
  const time = async (t: string) => {
    const s = performance.now();
    for (let i = 0; i < 100; i++) await asAnon(() => disputeComment(P, t, 70));
    return ((performance.now() - s) / 100).toFixed(2);
  };
  console.log(`    avg ms per call: garbage ${await time("xyz")}, almost-valid ${await time(flip(real))}`);
});

Deno.test("one dispute per device per comment; two devices hide it from list and count", async () => {
  await reset();
  const P = "+84902000007";
  const t = await tokenOf(await seed(P, "Bị báo lỗi"));
  await seed(P, "Còn lại", { ageMin: 5 });
  await asAnon(async () => {
    assertEquals(await disputeComment(P, t, 80), null);
    assertEquals((await disputeComment(P, t, 80))?.message, "already_disputed");
    assertEquals((await comments(P)).length, 2); // 1 dispute: still shown
    assertEquals(await disputeComment(P, t, 81), null);
    assertEquals((await comments(P)).map((x) => x.description), ["Còn lại"]);
    // Hidden now, so its token no longer resolves.
    assertEquals((await disputeComment(P, t, 82))?.message, "invalid_comment");
  });
  const s = await rows<{ report_count: number }>("select * from public.get_phone_report_summary($1)", [P]);
  assertEquals(s[0].report_count, 1); // was 2; the disputed-away report no longer counts
});

Deno.test("rate limit: 5 disputes per day across both paths; checked before the token", async () => {
  await reset();
  const nums = Array.from({ length: 6 }, (_, i) => `+8490300000${i}`);
  const toks: string[] = [];
  for (const n of nums) toks.push(await tokenOf(await seed(n, "Nhận xét")));
  await asAnon(async () => {
    for (let i = 0; i < 4; i++) assertEquals(await disputeComment(nums[i], toks[i], 90), null);
    assertEquals(await disputeNumber(nums[4], 90), null); // 5th, other path
    assertEquals((await disputeComment(nums[5], toks[5], 90))?.message, "rate_limited");
    assertEquals((await disputeComment(nums[5], "garbage", 90))?.message, "rate_limited");
    assertEquals(await disputeNumber(nums[5], 90), "rate_limited");
    assertEquals(await disputeComment(nums[5], toks[5], 91), null); // other device fine
    const badDevice = await run("select public.dispute_phone_comment($1,$2,$3)", [nums[5], toks[5], "nope"]);
    assertEquals(badDevice?.message, "invalid_device");
  });
  await db.query("update public.report_rate_log set created_at = now() - interval '25 hours'");
  assertEquals(await asAnon(() => disputeComment(nums[5], toks[5], 90)), null); // after 24h
});

Deno.test("both dispute paths together can't let one device flag one report twice", async () => {
  await reset();
  const P = "+84902000008";
  const newest = await tokenOf(await seed(P, "Mới nhất", { ageMin: 1 }));
  const older = await tokenOf(await seed(P, "Cũ hơn", { ageMin: 30 }));
  await asAnon(async () => {
    // Whole-number dispute hits the newest report; the same device can't flag it again by token.
    assertEquals(await disputeNumber(P, 100), null);
    assertEquals((await disputeComment(P, newest, 100))?.message, "already_disputed");
    assertEquals(await disputeComment(P, older, 100), null); // a different report is fine
    // Comment dispute first, then the whole-number path: blocked (one per number).
    assertEquals(await disputeComment(P, newest, 101), null);
    assertEquals(await disputeNumber(P, 101), "already_disputed");
  });
  const d = await rows<{ description: string; disputed_count: number }>(
    "select description, disputed_count from public.phone_reports order by created_at desc",
  );
  assertEquals(d.map((x) => x.disputed_count), [2, 1]);
});

Deno.test("a dispute logged before report_id existed blocks token disputes on that number", async () => {
  await reset();
  const P = "+84902000009";
  const t = await tokenOf(await seed(P, "Nhận xét"));
  const h = (await rows<{ h: string }>("select public.salted_reporter_hash($1) h", [await dev(110)]))[0].h;
  await db.query(
    "insert into public.report_rate_log (reporter_hash, action, phone_normalized) values ($1, 'dispute', $2)",
    [h, P],
  );
  assertEquals((await asAnon(() => disputeComment(P, t, 110)))?.message, "already_disputed");
});

// ---- 6. PII stripping, both directions -------------------------------------------------------
const strip = async (s: string) => (await rows<{ r: string }>("select public.strip_report_pii($1) r", [s]))[0].r;

Deno.test("PII: phone numbers, emails and bare account/card numbers ARE stripped", async () => {
  const cases: [string, string][] = [
    ["Gọi từ 0912345678 nhé", "Gọi từ *** nhé"],
    ["số 0912 345 678", "số ***"],
    ["số 0912.345.678", "số ***"],
    ["số 0912-345-678", "số ***"],
    ["+84912345678", "***"],
    ["+84 912 345 678 gọi đến", "*** gọi đến"],
    ["84912345678", "***"],
    ["máy bàn 028 3823 4567", "máy bàn ***"],
    ["(số 0912345678)", "(số ***)"],
    ["email lienhe.tuyendung@gmail.com nhé", "email *** nhé"],
    ["ABC.xyz+1@cong-ty.com.vn", "***"],
    ["STK 0123456789 Vietcombank", "STK *** Vietcombank"],
    ["số thẻ 9704123412341234", "số thẻ ***"],
    ["mã 123456", "mã ***"],
    ["Bảo chuyển 500.000đ vào STK 0123456789 tên NGUYEN VAN A",
      "Bảo chuyển 500.000đ vào STK *** tên NGUYEN VAN A"],
  ];
  for (const [input, want] of cases) assertEquals(await strip(input), want, input);
});

Deno.test("PII: scam amounts and ordinary numbers are LEFT ALONE", async () => {
  const kept = [
    "Bắt nạp 500.000đ", "Lừa tôi 2,400,000 VND", "nạp trước 1.900.000đ", "1900000đ", "1900000 đ",
    "1900000 VND", "1900000 vnd", "1900000 vnđ", "1500000 đồng", "500.000", "2.400.000",
    "84.500.000.000đ", "lãi 30%", "năm 2026", "mã 12345", "trong 15 phút", "1,5 triệu",
  ];
  for (const s of kept) assertEquals(await strip(s), s, s);
});

Deno.test("PII: known gaps (NOT stripped), so nobody oversells this", async () => {
  const notCaught = [
    "chị Lan ở quận 7",                // names, places
    "Zalo @shop_hotro_xx",             // social handles
    "link bit.ly/abc123",              // links
    "STK 0123 4567 8901",              // account number with spaces
    "không chín một hai ba bốn năm",   // digits in words
    "09l2 345 678",                    // letters swapped in for digits
  ];
  for (const s of notCaught) assertEquals(await strip(s), s, s);
  assertEquals(await strip(""), "");
  assertEquals((await rows<{ r: string | null }>("select public.strip_report_pii(null) r"))[0].r, null);
});
