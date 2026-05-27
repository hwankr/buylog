-- Atomically leave a group. Owners delegate only when other members remain.
-- The app still uses the dev UUID fallback until Supabase Auth is wired.

begin;

create or replace function public.leave_group(
  target_group_id uuid,
  new_owner_user_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := coalesce(
    auth.uid(),
    '08cccfe3-766f-43bd-b06c-8d909e0f9fe8'::uuid
  );
  current_role text;
  member_count int;
begin
  select gm.role
  into current_role
  from public.group_members as gm
  where gm.group_id = target_group_id
    and gm.user_id = current_user_id;

  if current_role is null then
    raise exception 'not_a_group_member'
      using errcode = 'P0001';
  end if;

  select count(*)
  into member_count
  from public.group_members as gm
  where gm.group_id = target_group_id;

  if current_role = 'owner' and member_count > 1 then
    if new_owner_user_id is null then
      raise exception 'new_owner_required'
        using errcode = 'P0001';
    end if;

    if new_owner_user_id = current_user_id then
      raise exception 'new_owner_must_be_different'
        using errcode = 'P0001';
    end if;

    update public.group_members
    set role = 'owner'
    where group_id = target_group_id
      and user_id = new_owner_user_id;

    if not found then
      raise exception 'new_owner_not_group_member'
        using errcode = 'P0001';
    end if;
  end if;

  delete from public.group_members
  where group_id = target_group_id
    and user_id = current_user_id;

  if member_count <= 1 then
    delete from public.groups
    where id = target_group_id;
  end if;

  update public.users
  set default_group_id = (
    select gm.group_id
    from public.group_members as gm
    where gm.user_id = current_user_id
    order by gm.joined_at asc
    limit 1
  )
  where id = current_user_id
    and default_group_id = target_group_id;
end;
$$;

revoke all on function public.leave_group(uuid, uuid) from public, anon, authenticated;
grant execute on function public.leave_group(uuid, uuid) to anon, authenticated;

commit;
