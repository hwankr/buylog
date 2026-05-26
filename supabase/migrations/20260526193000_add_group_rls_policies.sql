-- Enforce authenticated-only group access. The current Flutter app still uses
-- a hard-coded dev UUID until real auth is wired, so remote smoke testing group
-- creation requires an authenticated session whose auth.uid() matches the
-- corresponding public.users row. Do not weaken these policies to anon to work
-- around that temporary app limitation.

begin;

create schema if not exists private;

create or replace function private.is_group_member(target_group_id uuid, target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.group_members as gm
    where gm.group_id = target_group_id
      and gm.user_id = target_user_id
  );
$$;

create or replace function private.is_group_owner(target_group_id uuid, target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.group_members as gm
    where gm.group_id = target_group_id
      and gm.user_id = target_user_id
      and gm.role = 'owner'
  );
$$;

revoke all on function private.is_group_member(uuid, uuid) from public, anon, authenticated;
revoke all on function private.is_group_owner(uuid, uuid) from public, anon, authenticated;

create or replace function public.create_group_with_owner(group_name text, group_invite_code text)
returns setof public.groups
language plpgsql
security invoker
set search_path = ''
as $$
declare
  new_group_id uuid := gen_random_uuid();
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  insert into public.groups (id, name, invite_code, created_by)
  values (new_group_id, group_name, group_invite_code, current_user_id);

  insert into public.group_members (group_id, user_id, role)
  values (new_group_id, current_user_id, 'owner');

  update public.users
  set default_group_id = new_group_id
  where id = current_user_id;

  return query
  select g.*
  from public.groups as g
  where g.id = new_group_id;
end;
$$;

revoke all on function public.create_group_with_owner(text, text) from public, anon, authenticated;
grant execute on function public.create_group_with_owner(text, text) to authenticated;

alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.users enable row level security;

drop policy if exists "Group members can view groups" on public.groups;
drop policy if exists "Authenticated users can create groups" on public.groups;
drop policy if exists "Group owners can update groups" on public.groups;

create policy "Group members can view groups"
on public.groups
for select
to authenticated
using (
  private.is_group_member(id, (select auth.uid()))
);

create policy "Authenticated users can create groups"
on public.groups
for insert
to authenticated
with check (
  created_by = (select auth.uid())
);

create policy "Group owners can update groups"
on public.groups
for update
to authenticated
using (
  private.is_group_owner(id, (select auth.uid()))
)
with check (
  private.is_group_owner(id, (select auth.uid()))
);

drop policy if exists "Users can view relevant group memberships" on public.group_members;
drop policy if exists "Group creators can add their owner membership" on public.group_members;
drop policy if exists "Group owners can add group members" on public.group_members;

create policy "Users can view relevant group memberships"
on public.group_members
for select
to authenticated
using (
  user_id = (select auth.uid())
  or private.is_group_member(group_id, (select auth.uid()))
);

create policy "Group creators can add their owner membership"
on public.group_members
for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and role = 'owner'
  and exists (
    select 1
    from public.groups as g
    where g.id = group_id
      and g.created_by = (select auth.uid())
  )
);

create policy "Group owners can add group members"
on public.group_members
for insert
to authenticated
with check (
  private.is_group_owner(group_id, (select auth.uid()))
);

drop policy if exists "Users can view their own profile" on public.users;
drop policy if exists "Users can update their own profile" on public.users;

create policy "Users can view their own profile"
on public.users
for select
to authenticated
using (
  id = (select auth.uid())
);

create policy "Users can update their own profile"
on public.users
for update
to authenticated
using (
  id = (select auth.uid())
)
with check (
  id = (select auth.uid())
  and (
    default_group_id is null
    or private.is_group_member(default_group_id, (select auth.uid()))
  )
);

commit;
