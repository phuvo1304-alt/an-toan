-- An Toàn - Phone Checker v2: dispute path, durable rate limits, one taxonomy.
--
-- What changes (CLAUDE.md sections 2.2, 6, 8):
--   1. Categories now use the same list as the Scam Checker's scam_type
--      (supabase/functions/analyze-scam/index.ts), minus "none".
--   2. The app sends SHA-256(device id), computed ON THE PHONE, so the raw id
--      never leaves the device. The server hashes it again with the private salt
--      (private.app_settings) before storing, so stored values cannot be matched
--      back to a phone's own hash.
--   3. report_rate_log: a real, durable rate log (replaces counting
--      phone_reports rows):
--        - reports:  max 5 per device per 24h, and max 1 per device per number per 24h
--        - disputes: max 5 per device per 24h, and max 1 per device per number, ever
--   4. dispute_phone_report: "report an error". Each dispute adds 1 to the most
--      recent report that still counts for that number. A report with
--      disputed_count >= 2 (two different devices) no longer counts publicly,
--      but stays in the table for a human to review in the Supabase dashboard.
--      Hiding N reports therefore needs 2N different devices.
--
-- Access model is unchanged: RLS on, no policies, no table grants to
-- anon/authenticated. The app only calls the SECURITY DEFINER functions, and
-- every one of them sets an explicit (empty) search_path, so every name inside
-- is schema-qualified and cannot be hijacked by objects in other schemas.

-- ---- 1. Categories ---------------------------------------------------------------
-- The live table has no rows yet, so swapping the allowed list is safe.
alter table public.phone_reports drop constraint if exists phone_reports_category_check;
alter table public.phone_reports add constraint phone_reports_category_check
  check (category in ('fake_job', 'fake_scholarship', 'phishing', 'impersonation',
                      'investment', 'romance', 'loan', 'other'));

-- ---- 2. Dispute counter ------------------------------------------------------------
alter table public.phone_reports
  add column if not exists disputed_count integer not null default 0
    check (disputed_count >= 0);

-- ---- 3. Rate log -------------------------------------------------------------------
create table if not exists public.report_rate_log (
  id bigint generated always as identity primary key,
  reporter_hash text not null,      -- salted hash, same value as phone_reports.reporter_hash
  action text not null check (action in ('report', 'dispute')),
  phone_normalized text not null,   -- needed for the per-number limits
  created_at timestamptz not null default now()
);
create index if not exists report_rate_log_reporter_idx
  on public.report_rate_log (reporter_hash, action, created_at);

alter table public.report_rate_log enable row level security;
-- No policies on purpose: anon/authenticated get no direct access at all.
revoke all on table public.report_rate_log from anon, authenticated;
revoke all on table public.phone_reports from anon, authenticated;

-- How many disputes (from different devices) make a report stop counting.
-- Kept in one helper so the summary and the dispute function always agree.
create or replace function public.phone_report_dispute_threshold()
returns integer
language sql
immutable
set search_path = ''
as $$ select 2 $$;
revoke all on function public.phone_report_dispute_threshold() from public, anon, authenticated;

-- ---- Helper: salted hash of the client's SHA-256(device id) ------------------------
-- Returns null when the input is not a 64-char lowercase hex SHA-256; raises
-- server_misconfigured when the salt is missing. Internal only: it is called by
-- the SECURITY DEFINER functions below (which run as the owner), not by the app.
create or replace function public.salted_reporter_hash(p_client_hash text)
returns text
language plpgsql
stable
set search_path = ''
as $$
declare
  v_salt text := (select s.value from private.app_settings s where s.key = 'report_salt');
begin
  if p_client_hash is null or p_client_hash !~ '^[0-9a-f]{64}$' then
    return null;
  end if;
  if v_salt is null or v_salt = '' then
    raise exception 'server_misconfigured';
  end if;
  return encode(extensions.digest(p_client_hash || v_salt, 'sha256'), 'hex');
end;
$$;
revoke all on function public.salted_reporter_hash(text) from public, anon, authenticated;

-- ---- RPC: submit a report (new signature: takes the client-side hash) -------------
-- The parameter is renamed (p_device_id -> p_reporter_hash), which CREATE OR
-- REPLACE cannot do, so the old function is dropped first (inside this migration's
-- transaction, so there is no moment without one).
drop function if exists public.submit_phone_report(text, text, text, text);

create function public.submit_phone_report(
  p_phone text,
  p_category text,
  p_description text,
  p_reporter_hash text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_phone text := public.normalize_vn_phone(p_phone);
  v_desc text := nullif(btrim(coalesce(p_description, '')), '');
  v_hash text;
begin
  if v_phone is null then
    raise exception 'invalid_phone';
  end if;
  if p_category is null or p_category not in ('fake_job', 'fake_scholarship', 'phishing',
      'impersonation', 'investment', 'romance', 'loan', 'other') then
    raise exception 'invalid_category';
  end if;
  if v_desc is not null and char_length(v_desc) > 300 then
    raise exception 'description_too_long';
  end if;
  v_hash := public.salted_reporter_hash(p_reporter_hash);
  if v_hash is null then
    raise exception 'invalid_device';
  end if;

  -- Same device, same number, within 24h: stops one phone inflating one number.
  if exists (
    select 1 from public.report_rate_log l
    where l.reporter_hash = v_hash and l.action = 'report'
      and l.phone_normalized = v_phone
      and l.created_at > now() - interval '24 hours'
  ) then
    raise exception 'already_reported';
  end if;

  -- Overall limit: 5 reports per device per 24h.
  if (
    select count(*) from public.report_rate_log l
    where l.reporter_hash = v_hash and l.action = 'report'
      and l.created_at > now() - interval '24 hours'
  ) >= 5 then
    raise exception 'rate_limited';
  end if;

  insert into public.report_rate_log (reporter_hash, action, phone_normalized)
  values (v_hash, 'report', v_phone);

  insert into public.phone_reports (phone_normalized, category, description, reporter_hash)
  values (v_phone, p_category, v_desc, v_hash);
end;
$$;

revoke all on function public.submit_phone_report(text, text, text, text) from public;
grant execute on function public.submit_phone_report(text, text, text, text) to anon, authenticated;

-- ---- RPC: dispute ("this looks wrong") ---------------------------------------------
-- Adds 1 to the most recent report for this number that still counts. Never
-- reveals report ids or rows. Errors: invalid_phone, invalid_device,
-- no_reports, already_disputed, rate_limited, server_misconfigured.
create or replace function public.dispute_phone_report(
  p_phone text,
  p_reporter_hash text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_phone text := public.normalize_vn_phone(p_phone);
  v_hash text;
  v_target uuid;
begin
  if v_phone is null then
    raise exception 'invalid_phone';
  end if;
  v_hash := public.salted_reporter_hash(p_reporter_hash);
  if v_hash is null then
    raise exception 'invalid_device';
  end if;

  -- One dispute per device per number, ever: otherwise one phone could
  -- dispute twice and reach the threshold alone.
  if exists (
    select 1 from public.report_rate_log l
    where l.reporter_hash = v_hash and l.action = 'dispute'
      and l.phone_normalized = v_phone
  ) then
    raise exception 'already_disputed';
  end if;

  if (
    select count(*) from public.report_rate_log l
    where l.reporter_hash = v_hash and l.action = 'dispute'
      and l.created_at > now() - interval '24 hours'
  ) >= 5 then
    raise exception 'rate_limited';
  end if;

  select r.id into v_target
  from public.phone_reports r
  where r.phone_normalized = v_phone
    and r.disputed_count < public.phone_report_dispute_threshold()
  order by r.created_at desc
  limit 1
  for update;

  if v_target is null then
    raise exception 'no_reports';
  end if;

  insert into public.report_rate_log (reporter_hash, action, phone_normalized)
  values (v_hash, 'dispute', v_phone);

  update public.phone_reports
  set disputed_count = disputed_count + 1
  where id = v_target;
end;
$$;

revoke all on function public.dispute_phone_report(text, text) from public;
grant execute on function public.dispute_phone_report(text, text) to anon, authenticated;

-- ---- RPC: summary, now excluding disputed reports ----------------------------------
-- Same signature and output as before (CREATE OR REPLACE keeps the grants).
-- Counts DISTINCT reporters among reports that still count.
create or replace function public.get_phone_report_summary(p_phone text)
returns table (report_count int, categories jsonb, last_reported_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_phone text := public.normalize_vn_phone(p_phone);
begin
  if v_phone is null then
    raise exception 'invalid_phone';
  end if;

  return query
  with r as (
    select pr.category, pr.reporter_hash, pr.created_at
    from public.phone_reports pr
    where pr.phone_normalized = v_phone
      and pr.disputed_count < public.phone_report_dispute_threshold()
  ),
  c as (
    select r.category, count(distinct r.reporter_hash)::int as n
    from r
    group by r.category
  )
  select
    (select count(distinct r.reporter_hash)::int from r),
    (select jsonb_agg(jsonb_build_object('category', c.category, 'count', c.n)
                      order by c.n desc, c.category)
     from c),
    (select max(r.created_at) from r)
  where exists (select 1 from r);
end;
$$;

revoke all on function public.get_phone_report_summary(text) from public;
grant execute on function public.get_phone_report_summary(text) to anon, authenticated;
