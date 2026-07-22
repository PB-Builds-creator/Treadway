-- Cairn — reminders (Phase 1 tables). Paste into Supabase SQL Editor → Run.
-- Safe to re-run.

-- Devices subscribed to push (one per browser/home-screen install).
create table if not exists public.push_subscriptions (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  endpoint   text not null unique,
  p256dh     text not null,
  auth       text not null,
  updated_at timestamptz not null default now()
);
create index if not exists push_sub_user_idx on public.push_subscriptions(user_id);

-- Per-user reminder preferences.
create table if not exists public.reminder_settings (
  user_id      uuid primary key references auth.users(id) on delete cascade,
  enabled      boolean not null default true,
  summary_time text not null default '21:30',   -- nightly "unfinished" summary (Mountain Time)
  updated_at   timestamptz not null default now()
);

-- Dedupe log so the scheduler never sends the same reminder twice in a day.
create table if not exists public.reminder_log (
  id      uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind    text not null,        -- 'task:<uuid>' or 'summary'
  day     date not null,
  sent_at timestamptz not null default now(),
  unique (user_id, kind, day)
);

-- Row-level security: each person owns their own subscription + settings.
alter table public.push_subscriptions enable row level security;
alter table public.reminder_settings  enable row level security;
alter table public.reminder_log        enable row level security;

drop policy if exists own_rows on public.push_subscriptions;
create policy own_rows on public.push_subscriptions for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists own_rows on public.reminder_settings;
create policy own_rows on public.reminder_settings for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- reminder_log is written only by the scheduler (service role, which bypasses RLS),
-- so no client policy is needed.
