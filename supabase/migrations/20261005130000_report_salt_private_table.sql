-- An Toàn - Phone Checker: move the reporter_hash salt into a private table.
--
-- Why: the first migration read the salt with current_setting('app.report_salt'),
-- set via `alter database postgres set app.report_salt = ...`. Hosted Supabase
-- refuses that ("permission denied to set parameter"), because the postgres
-- role there is not a superuser.
--
-- Now the salt lives in private.app_settings:
--   * The "private" schema is not exposed by Supabase's REST API (only "public"
--     is), and anon/authenticated have no rights on it. Only SECURITY DEFINER
--     functions owned by postgres can read it.
--   * The salt is generated INSIDE the database when this migration runs
--     (gen_random_bytes), so the value is never in Git, chat or on a laptop.
--   * "on conflict do nothing": running this again never changes an existing
--     salt (changing it would reset everyone's report limit).

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table if not exists private.app_settings (
  key text primary key,
  value text not null
);
alter table private.app_settings enable row level security;
revoke all on table private.app_settings from public, anon, authenticated;

insert into private.app_settings (key, value)
values ('report_salt', encode(extensions.gen_random_bytes(32), 'hex'))
on conflict (key) do nothing;

-- Same function as before; only the line that reads the salt changed.
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
  v_salt text := (select s.value from private.app_settings s where s.key = 'report_salt');
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

-- create or replace keeps existing grants, but state them again to be explicit.
revoke all on function public.submit_phone_report(text, text, text, text) from public;
grant execute on function public.submit_phone_report(text, text, text, text) to anon, authenticated;
