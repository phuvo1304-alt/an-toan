-- An Toàn - Server-side rate limiting for analyze-scam (web-deploy prep).
--
-- Why: the previous rate limit lived entirely in the edge function's
-- in-memory process (a `Map` keyed by a `device_id` the CLIENT supplies in
-- the request body). That is not a real limit once the app is web-public:
-- anyone can read the Supabase anon key and the function URL straight out
-- of browser dev tools, then script direct calls with a fresh random
-- device_id on every request -- the in-memory counter never accumulates for
-- any single key, and even for an honest caller the counter resets on every
-- cold start / scales incorrectly across concurrent function instances.
--
-- This replaces it with a durable, Postgres-backed limit keyed by the
-- caller's IP address (hashed, never stored raw -- same discipline as
-- phone_reports.reporter_hash), which the client cannot relabel by changing
-- a request body field.
--
-- Access model, same as report_rate_log: RLS on, no policies, no table
-- grants to anon/authenticated. Only the edge function calls the
-- SECURITY DEFINER function below, using the service-role key (which
-- bypasses RLS) -- never a direct table grant to anon.

create table if not exists public.analysis_log (
  id bigint generated always as identity primary key,
  ip_hash text not null,
  created_at timestamptz not null default now()
);
create index if not exists analysis_log_ip_hash_created_at_idx
  on public.analysis_log (ip_hash, created_at);

alter table public.analysis_log enable row level security;
revoke all on table public.analysis_log from anon, authenticated;

-- Atomic check-and-log: counts this ip_hash's rows in the last
-- p_window_minutes, blocks (returns true) if at or over p_limit, otherwise
-- logs this request (so it counts toward the next check) and returns false.
-- One round trip, one transaction -- no separate count-then-insert race.
--
-- Also prunes rows older than 24h on every call, so the table stays small
-- without needing a separate cron job (cheap at this project's traffic
-- volume; the index makes the delete scan fast).
create or replace function public.check_and_log_analysis_rate(
  p_ip_hash text,
  p_limit integer,
  p_window_minutes integer
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  delete from public.analysis_log where created_at < now() - interval '24 hours';

  select count(*) into v_count
  from public.analysis_log
  where ip_hash = p_ip_hash
    and created_at > now() - (p_window_minutes || ' minutes')::interval;

  if v_count >= p_limit then
    return true;
  end if;

  insert into public.analysis_log (ip_hash) values (p_ip_hash);
  return false;
end;
$$;

revoke all on function public.check_and_log_analysis_rate(text, integer, integer)
  from public, anon, authenticated;
