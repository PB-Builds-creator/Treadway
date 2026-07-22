-- Cairn — ALL the reminder database setup in one paste.
-- Supabase → SQL Editor → New query → paste this whole thing → Run.
-- Safe to re-run.

-- ── Tables ──────────────────────────────────────────────────────────
create table if not exists public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  updated_at timestamptz not null default now()
);
create index if not exists push_sub_user_idx on public.push_subscriptions(user_id);

create table if not exists public.reminder_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  enabled boolean not null default true,
  summary_time text not null default '21:30',
  updated_at timestamptz not null default now()
);

create table if not exists public.reminder_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null,
  day date not null,
  sent_at timestamptz not null default now(),
  unique (user_id, kind, day)
);

-- ── Security: each person owns only their own rows ──────────────────
alter table public.push_subscriptions enable row level security;
alter table public.reminder_settings  enable row level security;
alter table public.reminder_log        enable row level security;

drop policy if exists own_rows on public.push_subscriptions;
create policy own_rows on public.push_subscriptions for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists own_rows on public.reminder_settings;
create policy own_rows on public.reminder_settings for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ── Schedule the sender every 5 minutes ─────────────────────────────
create extension if not exists pg_cron;
create extension if not exists pg_net;

select cron.unschedule('cairn-reminders')
where exists (select 1 from cron.job where jobname = 'cairn-reminders');

select cron.schedule(
  'cairn-reminders',
  '*/5 * * * *',
  $$
  select net.http_post(
    url := 'https://bckcawaiyybrjsphiqdc.supabase.co/functions/v1/send-reminders',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', '<CRON_SECRET>'
    )
  );
  $$
);
