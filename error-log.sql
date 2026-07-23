-- Treadway — OPTIONAL remote crash/error capture.
-- The app already logs errors locally (localStorage "cairn_errlog", last 25) and warns the user
-- with a toast, all WITHOUT this table. Run this only if you want a queryable server-side history
-- of glitches across devices. It is safe to run anytime and requires no app redeploy: the client
-- insert is fire-and-forget and silently ignored until this table exists.
--
-- Assumes the existing is_admin() SECURITY DEFINER function (created by cairn-product-upgrade.sql).

create table if not exists public.error_log (
  id         bigint generated always as identity primary key,
  user_id    uuid references auth.users(id) on delete set null,
  kind       text,          -- "error" (sync script error) | "promise" (unhandled rejection)
  message    text,
  source     text,          -- file:line, when available
  tab        text,          -- which screen the user was on
  ua         text,          -- user agent (truncated)
  created_at timestamptz not null default now()
);

alter table public.error_log enable row level security;

-- A signed-in user may record ONLY their own errors.
drop policy if exists error_insert_own on public.error_log;
create policy error_insert_own on public.error_log
  for insert to authenticated
  with check (auth.uid() = user_id);

-- Only an admin (you) may read them. No one can update or delete via the API.
drop policy if exists error_read_admin on public.error_log;
create policy error_read_admin on public.error_log
  for select to authenticated
  using (public.is_admin());

create index if not exists error_log_created_idx on public.error_log (created_at desc);

-- To read the latest glitches later, run in the SQL editor:
--   select created_at, kind, message, source, tab from public.error_log order by created_at desc limit 50;
--
-- OPTIONAL auto-prune (keeps the table tiny; needs pg_cron, already enabled for reminders):
--   select cron.schedule('error-log-prune','0 4 * * *',
--     $$delete from public.error_log where created_at < now() - interval '30 days'$$);
