-- Cairn — access hub (owner approves/denies who can use the app). One paste. Safe to re-run.
-- Supabase → SQL Editor → New query → paste → Run.
--
-- ⚠️ EDIT THIS if the email you use to sign into Cairn is different:
--    (it decides who becomes the admin/owner)
--    → change 'paxtonraithel@gmail.com' below to your Cairn login email.

create table if not exists public.access (
  user_id      uuid primary key references auth.users(id) on delete cascade,
  email        text,
  status       text not null default 'pending',   -- pending | approved | denied
  is_admin     boolean not null default false,
  requested_at timestamptz not null default now(),
  decided_at   timestamptz
);
alter table public.access enable row level security;

-- Am I an admin? (SECURITY DEFINER so RLS policies can call it without recursion.)
create or replace function public.is_admin()
  returns boolean language sql security definer stable set search_path = public as $$
  select coalesce((select is_admin from public.access where user_id = auth.uid()), false);
$$;
grant execute on function public.is_admin() to authenticated;

-- Read your own row; admins read everyone's.
drop policy if exists sel on public.access;
create policy sel on public.access for select to authenticated
  using (user_id = auth.uid() or public.is_admin());

-- You may only create your OWN request, and only as pending (no self-approving).
drop policy if exists ins on public.access;
create policy ins on public.access for insert to authenticated
  with check (user_id = auth.uid() and status = 'pending' and is_admin = false);

-- Only admins can approve/deny (update rows).
drop policy if exists upd on public.access;
create policy upd on public.access for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Seed existing users as approved; make the owner an admin.
insert into public.access (user_id, email, status, is_admin, decided_at)
select id, email, 'approved', (email = 'paxtonraithel@gmail.com'), now()
from auth.users
on conflict (user_id) do update
  set status = 'approved',
      is_admin = (excluded.email = 'paxtonraithel@gmail.com'),
      decided_at = now();

-- Handy fallback: if you didn't become admin, run this with your email:
--   update public.access set is_admin = true where email = 'YOUR_EMAIL_HERE';
