-- Cairn — Close, private partner nudges, and commercial access hardening.
-- One paste in Supabase SQL Editor. Safe to re-run.

-- ── Real membership boundary ───────────────────────────────────────
create table if not exists public.access (
  user_id      uuid primary key references auth.users(id) on delete cascade,
  email        text,
  status       text not null default 'pending' check (status in ('pending','approved','denied')),
  is_admin     boolean not null default false,
  requested_at timestamptz not null default now(),
  decided_at   timestamptz
);
alter table public.access enable row level security;

create or replace function public.is_admin()
returns boolean language sql security definer stable set search_path = public as $$
  select coalesce((select is_admin from public.access where user_id = auth.uid() and status = 'approved'), false);
$$;
create or replace function public.user_is_approved(p_user uuid)
returns boolean language sql security definer stable set search_path = public as $$
  select coalesce((select status = 'approved' from public.access where user_id = p_user), false);
$$;
create or replace function public.is_approved()
returns boolean language sql security definer stable set search_path = public as $$
  select public.user_is_approved(auth.uid());
$$;
revoke all on function public.is_admin() from public;
revoke all on function public.user_is_approved(uuid) from public;
revoke all on function public.is_approved() from public;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.user_is_approved(uuid) to authenticated;
grant execute on function public.is_approved() to authenticated;

drop policy if exists sel on public.access;
create policy sel on public.access for select to authenticated
  using (user_id = auth.uid() or public.is_admin());
drop policy if exists ins on public.access;
create policy ins on public.access for insert to authenticated
  with check (user_id = auth.uid() and status = 'pending' and is_admin = false);
drop policy if exists upd on public.access;
create policy upd on public.access for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

insert into public.access (user_id,email,status,is_admin,decided_at)
select id,email,'approved',(email = 'paxtonraithel@gmail.com'),now() from auth.users
on conflict (user_id) do update set
  email = excluded.email,
  status = case when public.access.status = 'pending' then 'approved' else public.access.status end,
  is_admin = public.access.is_admin or excluded.is_admin,
  decided_at = coalesce(public.access.decided_at,now());

-- Existing owner-only tables now enforce approval in Postgres, not just the UI.
do $$
declare t text;
begin
  foreach t in array array['profiles','tasks','completions','hydration','notes','task_values','push_subscriptions','reminder_settings'] loop
    execute format('drop policy if exists own_rows on public.%I',t);
    execute format('create policy own_rows on public.%I for all to authenticated using (user_id = auth.uid() and public.is_approved()) with check (user_id = auth.uid() and public.is_approved())',t);
  end loop;
end $$;

-- ── Cairn Close ────────────────────────────────────────────────────
alter table public.notes add column if not exists close_data jsonb not null default '{}'::jsonb;

-- ── Reciprocal couple privacy ──────────────────────────────────────
create or replace function public.are_partners(p_a uuid,p_b uuid)
returns boolean language sql security definer stable set search_path = public as $$
  select public.user_is_approved(p_a) and public.user_is_approved(p_b)
    and exists(select 1 from public.couple_links where user_id = p_a and partner_id = p_b)
    and exists(select 1 from public.couple_links where user_id = p_b and partner_id = p_a);
$$;
revoke all on function public.are_partners(uuid,uuid) from public;
grant execute on function public.are_partners(uuid,uuid) to authenticated;

drop policy if exists own_rows on public.couple_links;
create policy own_rows on public.couple_links for all to authenticated
  using (user_id = auth.uid() and public.is_approved())
  with check (user_id = auth.uid() and public.is_approved());

drop policy if exists own_write on public.daily_status;
create policy own_write on public.daily_status for all to authenticated
  using (user_id = auth.uid() and public.is_approved())
  with check (user_id = auth.uid() and public.is_approved());
drop policy if exists partner_read on public.daily_status;
create policy partner_read on public.daily_status for select to authenticated
  using (public.are_partners(auth.uid(),user_id));
drop policy if exists partner_read on public.profiles;
create policy partner_read on public.profiles for select to authenticated
  using (public.are_partners(auth.uid(),user_id));

create or replace function public.link_partner(p_code text)
returns json language plpgsql security definer set search_path = public as $$
declare target uuid;
begin
  if not public.is_approved() then return json_build_object('ok',false,'error','Account is not approved.'); end if;
  select user_id into target from public.couple_links
   where code = p_code and code_expires > now() and user_id <> auth.uid()
     and public.user_is_approved(user_id);
  if target is null then return json_build_object('ok',false,'error','That code is invalid or expired.'); end if;
  insert into public.couple_links(user_id,partner_id,code,code_expires,updated_at)
    values(auth.uid(),target,null,null,now())
    on conflict(user_id) do update set partner_id=excluded.partner_id,code=null,code_expires=null,updated_at=now();
  insert into public.couple_links(user_id,partner_id,code,code_expires,updated_at)
    values(target,auth.uid(),null,null,now())
    on conflict(user_id) do update set partner_id=excluded.partner_id,code=null,code_expires=null,updated_at=now();
  return json_build_object('ok',true);
end $$;

create or replace function public.unlink_partner()
returns json language plpgsql security definer set search_path = public as $$
declare caller uuid := auth.uid(); target uuid;
begin
  if caller is null then return json_build_object('ok',false); end if;
  select partner_id into target from public.couple_links where user_id = caller;
  update public.couple_links set partner_id=null,code=null,code_expires=null,updated_at=now()
    where user_id=caller or (target is not null and user_id=target and partner_id=caller);
  return json_build_object('ok',true);
end $$;

revoke all on function public.link_partner(text) from public;
revoke all on function public.unlink_partner() from public;
grant execute on function public.link_partner(text) to authenticated;
grant execute on function public.unlink_partner() to authenticated;

-- ── One private Proud nudge per partner/day ────────────────────────
create table if not exists public.nudges (
  id           uuid primary key default gen_random_uuid(),
  sender_id    uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  kind         text not null default 'proud' check (kind = 'proud'),
  day          date not null,
  status       text not null default 'pending' check (status in ('pending','sent','canceled')),
  created_at   timestamptz not null default now(),
  delivered_at timestamptz,
  unique(sender_id,recipient_id,kind,day)
);
create index if not exists nudges_pending_idx on public.nudges(status,created_at);
alter table public.nudges enable row level security;
drop policy if exists linked_read on public.nudges;
create policy linked_read on public.nudges for select to authenticated
  using ((sender_id=auth.uid() or recipient_id=auth.uid()) and public.are_partners(sender_id,recipient_id));
revoke insert,update,delete on public.nudges from anon,authenticated;
grant select on public.nudges to authenticated;

create or replace function public.send_partner_nudge()
returns json language plpgsql security definer set search_path = public as $$
declare caller uuid := auth.uid(); target uuid; mountain_day date; created uuid;
begin
  if caller is null or not public.is_approved() then return json_build_object('ok',false,'error','Account is not approved.'); end if;
  select partner_id into target from public.couple_links where user_id=caller;
  if target is null or not public.are_partners(caller,target) then
    return json_build_object('ok',false,'error','Your partner link is not active.');
  end if;
  mountain_day := (now() at time zone 'America/Denver')::date;
  insert into public.nudges(sender_id,recipient_id,kind,day)
    values(caller,target,'proud',mountain_day)
    on conflict(sender_id,recipient_id,kind,day) do nothing returning id into created;
  return json_build_object('ok',true,'already_sent',created is null);
end $$;
revoke all on function public.send_partner_nudge() from public;
grant execute on function public.send_partner_nudge() to authenticated;
