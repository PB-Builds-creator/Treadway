-- Cairn — grace (rest days) + couple layer. One paste. Safe to re-run.
-- Supabase → SQL Editor → New query → paste all → Run.

-- ── Grace: store planned rest days on the profile ───────────────────
alter table public.profiles
  add column if not exists rest_days jsonb not null default '[]'::jsonb;

-- ── Couple: link the two accounts ───────────────────────────────────
create table if not exists public.couple_links (
  user_id      uuid primary key references auth.users(id) on delete cascade,
  partner_id   uuid references auth.users(id) on delete set null,
  code         text,
  code_expires timestamptz,
  updated_at   timestamptz not null default now()
);

-- A tiny per-day summary each person shares with their partner (counts only —
-- never the tasks themselves).
create table if not exists public.daily_status (
  user_id    uuid not null references auth.users(id) on delete cascade,
  day        date not null,
  done       int  not null default 0,
  total      int  not null default 0,
  all_done   boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (user_id, day)
);

alter table public.couple_links enable row level security;
alter table public.daily_status enable row level security;

-- couple_links: manage only your own row.
drop policy if exists own_rows on public.couple_links;
create policy own_rows on public.couple_links for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- daily_status: write your own; read your own OR your partner's summary.
drop policy if exists own_write on public.daily_status;
create policy own_write on public.daily_status for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists partner_read on public.daily_status;
create policy partner_read on public.daily_status for select to authenticated
  using (user_id = (select partner_id from public.couple_links where user_id = auth.uid()));

-- profiles: let your partner read your name/accent (not your tasks).
drop policy if exists partner_read on public.profiles;
create policy partner_read on public.profiles for select to authenticated
  using (user_id = (select partner_id from public.couple_links where user_id = auth.uid()));

-- Linking function: given a valid pairing code, link BOTH accounts to each other.
-- SECURITY DEFINER so it can set the other person's row (RLS can't cross users).
create or replace function public.link_partner(p_code text)
returns json language plpgsql security definer set search_path = public as $$
declare target uuid;
begin
  select user_id into target
    from public.couple_links
   where code = p_code and code_expires > now() and user_id <> auth.uid();
  if target is null then
    return json_build_object('ok', false, 'error', 'That code is invalid or expired.');
  end if;
  insert into public.couple_links(user_id, partner_id, code, code_expires)
    values (auth.uid(), target, null, null)
    on conflict (user_id) do update set partner_id = excluded.partner_id, code = null, code_expires = null;
  insert into public.couple_links(user_id, partner_id, code, code_expires)
    values (target, auth.uid(), null, null)
    on conflict (user_id) do update set partner_id = excluded.partner_id, code = null, code_expires = null;
  return json_build_object('ok', true);
end $$;
grant execute on function public.link_partner(text) to authenticated;
