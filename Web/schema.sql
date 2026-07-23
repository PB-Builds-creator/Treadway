-- Trailhead — Supabase schema + row-level security (legacy filename retained).
-- Paste this whole file into the Supabase SQL Editor (New query → Run).
-- It creates the four tables and locks every row to its owner: each signed-in
-- person can only ever read or write their OWN data. Safe to re-run.

-- ── Profile settings (one row per user) ─────────────────────────────
create table if not exists public.profiles (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  name       text not null default 'Me',
  accent     text not null default 'slate',
  goal_oz    integer not null default 200,
  updated_at timestamptz not null default now()
);

-- ── Tasks ───────────────────────────────────────────────────────────
create table if not exists public.tasks (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  title      text not null,
  sym        text not null default 'check',
  group_key  text not null default 'anytime',
  time       text default '',
  pri        boolean not null default false,
  rule       jsonb not null default '{"type":"daily"}'::jsonb,
  hydration  boolean not null default false,
  sort_index integer not null default 0,
  archived   boolean not null default false,
  updated_at timestamptz not null default now()
);
create index if not exists tasks_user_idx on public.tasks(user_id);

-- ── Completion records (one per task per day) ───────────────────────
create table if not exists public.completions (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  task_id    uuid not null references public.tasks(id) on delete cascade,
  day        date not null,
  status     text not null default 'done',
  updated_at timestamptz not null default now(),
  unique (user_id, task_id, day)            -- prevents duplicate completions
);
create index if not exists completions_user_day_idx on public.completions(user_id, day);

-- ── Hydration (one row per day, total ounces) ───────────────────────
create table if not exists public.hydration (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  day        date not null,
  oz         numeric not null default 0,
  updated_at timestamptz not null default now(),
  unique (user_id, day)
);

-- ── Row-Level Security: you can only touch rows where user_id = you ──
alter table public.profiles    enable row level security;
alter table public.tasks       enable row level security;
alter table public.completions enable row level security;
alter table public.hydration   enable row level security;

do $$
declare t text;
begin
  foreach t in array array['profiles','tasks','completions','hydration'] loop
    execute format('drop policy if exists own_rows on public.%I', t);
    execute format(
      'create policy own_rows on public.%I
         for all to authenticated
         using (user_id = auth.uid())
         with check (user_id = auth.uid())', t);
  end loop;
end $$;
