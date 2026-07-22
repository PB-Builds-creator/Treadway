-- Cairn — per-task "open app" link + monthly streak-save. One paste. Safe to re-run.
-- Supabase → SQL Editor → New query → paste → Run.

alter table public.tasks
  add column if not exists app_url text;

alter table public.profiles
  add column if not exists saved_days jsonb not null default '[]'::jsonb;
