-- Cairn — all remaining Tier 2 schema, one paste. Safe to re-run.
-- Supabase → SQL Editor → New query → paste → Run.

-- Non-negotiables, measured tasks, per-task reminder toggle
alter table public.tasks add column if not exists keystone     boolean not null default false;
alter table public.tasks add column if not exists measure_unit text;
alter table public.tasks add column if not exists remind       boolean not null default true;

-- Daily notes / journal
create table if not exists public.notes (
  user_id    uuid not null references auth.users(id) on delete cascade,
  day        date not null,
  text       text not null default '',
  updated_at timestamptz not null default now(),
  primary key (user_id, day)
);
alter table public.notes enable row level security;
drop policy if exists own_rows on public.notes;
create policy own_rows on public.notes for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Measured values (sleep hours, gym minutes, etc.), one per task per day
create table if not exists public.task_values (
  user_id    uuid not null references auth.users(id) on delete cascade,
  task_id    uuid not null references public.tasks(id) on delete cascade,
  day        date not null,
  value      numeric not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, task_id, day)
);
alter table public.task_values enable row level security;
drop policy if exists own_rows on public.task_values;
create policy own_rows on public.task_values for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Quiet hours for reminders
alter table public.reminder_settings add column if not exists quiet_start text;  -- 'HH:MM'
alter table public.reminder_settings add column if not exists quiet_end   text;  -- 'HH:MM'
