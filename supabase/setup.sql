-- Shared customer list for the Tri-Cities map.
-- Run once in Supabase: SQL Editor -> New query -> paste -> Run.
-- Then add each teammate's email to public.members (last line).

-- Who may see and change the shared list
create table if not exists public.members (
  email text primary key
);

-- Customers, drawn lots and groups, one row each
create table if not exists public.records (
  kind text not null check (kind in ('customer','lot','group')),
  id text not null,
  data jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by text default (auth.jwt() ->> 'email'),
  primary key (kind, id)
);

create or replace function public.touch_record() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  new.updated_by := auth.jwt() ->> 'email';
  return new;
end $$;
drop trigger if exists records_touch on public.records;
create trigger records_touch before update on public.records
  for each row execute function public.touch_record();

-- True when the signed-in user's email is on the members list
create or replace function public.is_member() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.members where lower(email) = lower(auth.jwt() ->> 'email'));
$$;

alter table public.members enable row level security;
alter table public.records enable row level security;

drop policy if exists "members read members" on public.members;
create policy "members read members" on public.members for select to authenticated using (public.is_member());

drop policy if exists "members read" on public.records;
drop policy if exists "members add" on public.records;
drop policy if exists "members change" on public.records;
drop policy if exists "members remove" on public.records;
create policy "members read" on public.records for select to authenticated using (public.is_member());
create policy "members add" on public.records for insert to authenticated with check (public.is_member());
create policy "members change" on public.records for update to authenticated using (public.is_member()) with check (public.is_member());
create policy "members remove" on public.records for delete to authenticated using (public.is_member());

revoke all on public.members, public.records from anon;
grant select on public.members to authenticated;
grant select, insert, update, delete on public.records to authenticated;

-- Live updates between devices
do $$ begin
  alter publication supabase_realtime add table public.records;
exception when duplicate_object then null; end $$;

-- Add your team (replace with real emails):
-- insert into public.members (email) values ('you@example.com'), ('employee@example.com');
