-- An Toàn - Phone Checker v3: show report comments publicly, with safeguards.
--
-- This deliberately reverses ONE piece of the original rule "the app never reads
-- raw reports" (CLAUDE.md section 6): the free-text description of a report can
-- now be shown to anyone who looks up that number. Everything else stays private
-- (report ids, reporter_hash, the rate log, which device wrote what).
--
-- Safeguards, all enforced here in the database (the app cannot skip them):
--   1. visible_to_public: only reports submitted AFTER this migration can be
--      shown. Older reports were written under the old "never public" rule, so
--      their text stays private forever (they still count in the summary).
--      The column DEFAULT is false: any future insert path that forgets the
--      field stays private. submit_phone_report is the ONLY place that sets true.
--   2. PII stripping at READ time (strip_report_pii): phone numbers, email
--      addresses and bare 6+ digit runs (account/card numbers) become "***".
--      The original text is stored unchanged, so stripping can be improved later.
--   3. Disputed reports (disputed_count >= the existing threshold of 2) are
--      hidden from the comment list, exactly as they are excluded from the count.
--   4. Comments are identified by comment_token = HMAC-SHA256(report id) with a
--      secret key in private.app_settings (generated inside the database, never in
--      Git). The anon role can't read the key, so tokens can't be computed or
--      guessed, and the real row id is never sent to the app.
--   5. dispute_phone_comment: flag ONE comment by its token, with the same
--      dispute limits (report_rate_log) as dispute_phone_report. Every way a
--      token can fail gives the same error, "invalid_comment".
--
-- get_phone_report_summary is NOT changed: it counts every report, visible or not.

-- ---- 1. visible_to_public ---------------------------------------------------------
-- ADD COLUMN ... DEFAULT false fills existing rows with false.
alter table public.phone_reports
  add column if not exists visible_to_public boolean not null default false;

-- Backfill, explicitly (belt and braces with the default above): every report
-- that exists when this migration runs is private.
update public.phone_reports
set visible_to_public = false
where visible_to_public is distinct from false;

-- ---- 2. Secret key for comment tokens ---------------------------------------------
-- Same storage as report_salt (see 20261005130000_report_salt_private_table.sql):
-- the "private" schema is not exposed by the REST API and anon/authenticated have
-- no rights on it. A separate key from report_salt, so one secret has one job.
-- "on conflict do nothing": running this again never changes an existing key
-- (changing it would only invalidate tokens the app is currently showing).
insert into private.app_settings (key, value)
values ('comment_token_key', encode(extensions.gen_random_bytes(32), 'hex'))
on conflict (key) do nothing;

-- ---- 3. Rate log remembers WHICH report a dispute was for ----------------------------
-- Needed so one device can't flag the same report twice (once per number, once
-- per comment) and reach the threshold alone. Null on rows logged before this
-- migration. "on delete set null": if a moderator deletes a report in the
-- dashboard, the device's limit history is kept.
alter table public.report_rate_log
  add column if not exists report_id uuid null
    references public.phone_reports (id) on delete set null;
create index if not exists report_rate_log_report_idx
  on public.report_rate_log (reporter_hash, report_id);

-- ---- Helper: comment token -----------------------------------------------------------
-- 128 bits of HMAC-SHA256(report id, secret key), as 32 hex characters.
-- Internal only: called by the SECURITY DEFINER functions below, never by the app.
create or replace function public.phone_report_comment_token(p_id uuid)
returns text
language plpgsql
stable
set search_path = ''
as $$
declare
  v_key text := (select s.value from private.app_settings s where s.key = 'comment_token_key');
begin
  if v_key is null or v_key = '' then
    raise exception 'server_misconfigured';
  end if;
  return left(encode(extensions.hmac(p_id::text, v_key, 'sha256'), 'hex'), 32);
end;
$$;
revoke all on function public.phone_report_comment_token(uuid) from public, anon, authenticated;

-- ---- Helper: strip personal details from a comment before showing it -------------
-- Applied at read time. Order matters: emails first (they can contain digits),
-- then phone numbers (which may have separators), then bare digit runs.
--
--   * Email: name@domain.tld
--   * Vietnamese phone: 0 / 84 / +84, then 9-10 more digits, with optional single
--     spaces, dots or dashes between digits ("0912 345 678", "+84-912-345-678",
--     landlines "028 3823 4567").
--   * Bare 6+ digit run with NO separators (account / card numbers): "0123456789".
--
-- Money is LEFT ALONE, because a scam amount is useful detail:
--   * thousands separators ("500.000", "2,400,000") never form a 6+ digit run;
--   * a run followed by đ / vnd / vnđ / đồng (optionally after one space) is kept:
--     "1900000đ", "1900000 VND".
-- NOT caught (by design or limitation): names, addresses, social handles
-- (@user), links, spaced-out account numbers ("0123 4567 8901"), numbers written
-- in words, deliberately obfuscated digits ("09l2...").
create or replace function public.strip_report_pii(p_text text)
returns text
language sql
immutable
set search_path = ''
as $$
  select regexp_replace(
    regexp_replace(
      regexp_replace(
        p_text,
        -- email
        '[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}', '***', 'g'),
      -- Vietnamese phone number, separators allowed, not part of a longer
      -- number, not followed by a currency marker
      '(?<![0-9])(?<![0-9][.,])(?:\+?84|0)[ .-]?[1-9](?:[ .-]?[0-9]){7,9}(?![.,]?[0-9])(?! ?(?:[đĐ]|[vV][nN][dDđĐ]))',
      '***', 'g'),
    -- bare 6+ digit run, not part of a separated number, no currency marker
    '(?<![0-9])(?<![0-9][.,])[0-9]{6,}(?![0-9])(?![.,][0-9])(?! ?(?:[đĐ]|[vV][nN][dDđĐ]))',
    '***', 'g');
$$;
revoke all on function public.strip_report_pii(text) from public, anon, authenticated;

-- ---- RPC: submit a report (same as v2, plus visible_to_public = true) ----------------
create or replace function public.submit_phone_report(
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

  -- The ONLY place that makes a report's text public.
  insert into public.phone_reports
    (phone_normalized, category, description, reporter_hash, visible_to_public)
  values (v_phone, p_category, v_desc, v_hash, true);
end;
$$;

revoke all on function public.submit_phone_report(text, text, text, text) from public;
grant execute on function public.submit_phone_report(text, text, text, text) to anon, authenticated;

-- ---- RPC: dispute the number's newest report (same as v2, now logs report_id) ------
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

  -- One whole-number dispute per device per number, ever. This also counts
  -- comment disputes on this number (they log the same phone_normalized).
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

  insert into public.report_rate_log (reporter_hash, action, phone_normalized, report_id)
  values (v_hash, 'dispute', v_phone, v_target);

  update public.phone_reports
  set disputed_count = disputed_count + 1
  where id = v_target;
end;
$$;

revoke all on function public.dispute_phone_report(text, text) from public;
grant execute on function public.dispute_phone_report(text, text) to anon, authenticated;

-- ---- RPC: one page of public comments for a number -------------------------------------
-- Newest first, 20 per page; p_cursor is how many to skip (0, 20, 40, ...).
-- Only reports that are public, still counted (not disputed away) and have text.
-- Returns NO id, reporter_hash or dispute count: only what the app shows.
-- Errors: invalid_phone, invalid_cursor, server_misconfigured.
create or replace function public.get_phone_report_comments(
  p_phone text,
  p_cursor int default 0
)
returns table (comment_token text, category text, description text, created_at timestamptz)
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
  -- 1000 = 50 pages; nobody scrolls further, and it bounds the work per call.
  if p_cursor is null or p_cursor < 0 or p_cursor > 1000 then
    raise exception 'invalid_cursor';
  end if;

  return query
  select
    public.phone_report_comment_token(pr.id),
    pr.category,
    public.strip_report_pii(pr.description),
    pr.created_at
  from public.phone_reports pr
  where pr.phone_normalized = v_phone
    and pr.visible_to_public
    and pr.disputed_count < public.phone_report_dispute_threshold()
    and pr.description is not null
  order by pr.created_at desc, pr.id desc
  limit 20
  offset p_cursor;
end;
$$;

revoke all on function public.get_phone_report_comments(text, int) from public;
grant execute on function public.get_phone_report_comments(text, int) to anon, authenticated;

-- ---- RPC: dispute ONE comment by its token ------------------------------------------------
-- Errors: invalid_phone, invalid_device, rate_limited, invalid_comment,
-- already_disputed, server_misconfigured.
--
-- "invalid_comment" covers every way a token can fail: garbage, wrong length,
-- one character off, a real token for another number, a comment that is hidden
-- or already disputed away. The token is resolved by ONE query that computes the
-- HMAC for every visible comment of this number and compares; there is no early
-- exit on the token's format, so the work done doesn't depend on how close the
-- token is to a real one. The rate limit is checked BEFORE the token, so a
-- rate-limited caller learns nothing about the token either.
create or replace function public.dispute_phone_comment(
  p_phone text,
  p_comment_token text,
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

  -- Same daily limit as dispute_phone_report (both log action = 'dispute').
  if (
    select count(*) from public.report_rate_log l
    where l.reporter_hash = v_hash and l.action = 'dispute'
      and l.created_at > now() - interval '24 hours'
  ) >= 5 then
    raise exception 'rate_limited';
  end if;

  -- Same filter as get_phone_report_comments: only a comment that is shown can
  -- be flagged.
  select pr.id into v_target
  from public.phone_reports pr
  where pr.phone_normalized = v_phone
    and pr.visible_to_public
    and pr.disputed_count < public.phone_report_dispute_threshold()
    and pr.description is not null
    and public.phone_report_comment_token(pr.id) = coalesce(p_comment_token, '')
  limit 1
  for update;

  if v_target is null then
    raise exception 'invalid_comment';
  end if;

  -- One dispute per device per report, ever, counting both paths. Rows logged
  -- before report_id existed (null) were whole-number disputes on this number:
  -- they might have hit this report, so treat them as if they did.
  if exists (
    select 1 from public.report_rate_log l
    where l.reporter_hash = v_hash and l.action = 'dispute'
      and (l.report_id = v_target
           or (l.report_id is null and l.phone_normalized = v_phone))
  ) then
    raise exception 'already_disputed';
  end if;

  insert into public.report_rate_log (reporter_hash, action, phone_normalized, report_id)
  values (v_hash, 'dispute', v_phone, v_target);

  update public.phone_reports
  set disputed_count = disputed_count + 1
  where id = v_target;
end;
$$;

revoke all on function public.dispute_phone_comment(text, text, text) from public;
grant execute on function public.dispute_phone_comment(text, text, text) to anon, authenticated;
