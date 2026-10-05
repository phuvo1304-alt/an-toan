-- An Toàn - Phone Checker: community reports about phone numbers.
--
-- Access model (CLAUDE.md section 6):
--   * RLS is ON and there are NO policies, and table privileges are revoked
--     from anon/authenticated. So the app can never read or write rows directly.
--   * The app only calls two SECURITY DEFINER functions (they run as the table
--     owner, so they can reach the table; the app cannot):
--       submit_phone_report(...)       validates, rate-limits, then inserts
--       get_phone_report_summary(...)  returns ONLY aggregates, never raw rows
--
-- Salt for reporter_hash. Set it ONCE, yourself, in the Supabase SQL editor.
-- Never put the real value in this file or in Git:
--
--   alter database postgres set app.report_salt = 'PASTE_A_LONG_RANDOM_STRING';
--
-- (SETUP.md shows how to generate a random string.) Until it is set,
-- submit_phone_report refuses to save anything ("server_misconfigured"),
-- so we never store weakly hashed device IDs.

create extension if not exists pgcrypto with schema extensions;

-- ---- Table -------------------------------------------------------------------
create table public.phone_reports (
  id uuid primary key default gen_random_uuid(),
  phone_normalized text not null
    check (phone_normalized ~ '^\+84[35789][0-9]{8}$'),
  category text not null
    check (category in ('impersonation', 'fake_bank', 'fake_job', 'investment',
                        'loan', 'shopping', 'spam', 'other')),
  description text null
    check (description is null or char_length(description) <= 300),
  created_at timestamptz not null default now(),
  -- sha256(device id + secret salt). The raw device id is never stored.
  reporter_hash text not null
);

create index phone_reports_phone_idx on public.phone_reports (phone_normalized);
create index phone_reports_reporter_idx on public.phone_reports (reporter_hash, created_at);

alter table public.phone_reports enable row level security;
-- No policies on purpose: anon/authenticated get no direct access at all.
revoke all on table public.phone_reports from anon, authenticated;

-- ---- Helper: normalize a Vietnamese mobile number ------------------------------
-- Same rules as normalizePhone() in lib/features/phone_checker/phone_api.dart:
-- strip spaces, dots and dashes; accept 0xxxxxxxxx, +84xxxxxxxxx or 84xxxxxxxxx;
-- output +84 + 9 digits starting with 3/5/7/8/9. Anything else -> null.
create or replace function public.normalize_vn_phone(p_phone text)
returns text
language sql
immutable
set search_path = ''
as $$
  with s as (
    select regexp_replace(coalesce(p_phone, ''), '[[:space:].-]', '', 'g') as d
  ),
  n as (
    select case
      when d ~ '^\+84[0-9]{9}$' then substr(d, 4)
      when d ~ '^84[0-9]{9}$' then substr(d, 3)
      when d ~ '^0[0-9]{9}$' then substr(d, 2)
    end as nine
    from s
  )
  select case when nine ~ '^[35789][0-9]{8}$' then '+84' || nine end from n;
$$;

-- Internal helper only: the app does not call it directly.
revoke all on function public.normalize_vn_phone(text) from public, anon, authenticated;

-- ---- RPC: submit a report ------------------------------------------------------
-- Errors are raised with a short code as the message; the app maps them to
-- friendly text: invalid_phone, invalid_category, description_too_long,
-- invalid_device, server_misconfigured, rate_limited.
create or replace function public.submit_phone_report(
  p_phone text,
  p_category text,
  p_description text,
  p_device_id text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_phone text := public.normalize_vn_phone(p_phone);
  v_desc text := nullif(btrim(coalesce(p_description, '')), '');
  v_salt text := current_setting('app.report_salt', true);
  v_hash text;
  v_recent int;
begin
  if v_phone is null then
    raise exception 'invalid_phone';
  end if;
  if p_category is null or p_category not in ('impersonation', 'fake_bank', 'fake_job',
      'investment', 'loan', 'shopping', 'spam', 'other') then
    raise exception 'invalid_category';
  end if;
  if v_desc is not null and char_length(v_desc) > 300 then
    raise exception 'description_too_long';
  end if;
  if p_device_id is null or char_length(p_device_id) not between 8 and 100 then
    raise exception 'invalid_device';
  end if;
  if v_salt is null or v_salt = '' then
    raise exception 'server_misconfigured';
  end if;

  v_hash := encode(extensions.digest(p_device_id || v_salt, 'sha256'), 'hex');

  -- Rate limit: at most 5 reports per device per hour. A database function
  -- keeps no memory between calls, so we count this device's recent rows.
  select count(*) into v_recent
  from public.phone_reports r
  where r.reporter_hash = v_hash
    and r.created_at > now() - interval '1 hour';
  if v_recent >= 5 then
    raise exception 'rate_limited';
  end if;

  insert into public.phone_reports (phone_normalized, category, description, reporter_hash)
  values (v_phone, p_category, v_desc, v_hash);
end;
$$;

revoke all on function public.submit_phone_report(text, text, text, text) from public;
grant execute on function public.submit_phone_report(text, text, text, text) to anon, authenticated;

-- ---- RPC: aggregate summary for one number --------------------------------------
-- Counts DISTINCT reporters (so one phone reporting 5 times counts once), which
-- is what the app shows as "Reported by N users". Returns zero rows when the
-- number has no reports.
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
