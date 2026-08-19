-- rpc_create_group_member(): register a group member who may not yet
-- (or may never) have a Supabase auth account.
--
-- This is a backend-foundation command only, not the Members feature.
-- It never creates an auth.users row, never sends an OTP, and never
-- issues login credentials — user_id is left null by design. See
-- docs/product/member-identity-model.md.
create or replace function public.rpc_create_group_member(
  p_group_id uuid,
  p_display_name text,
  p_phone text default null,
  p_member_number text default null,
  p_joined_at date default current_date
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_membership_id uuid;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  if not public.has_group_permission(p_group_id, 'member.create') then
    raise exception 'Not authorized to create members in this group' using errcode = '42501';
  end if;

  if p_display_name is null or btrim(p_display_name) = '' then
    raise exception 'Member display name is required' using errcode = '22023';
  end if;

  if p_member_number is not null and exists (
    select 1
    from public.group_memberships
    where group_id = p_group_id and member_number = p_member_number
  ) then
    raise exception 'member_number already exists in this group' using errcode = '23505';
  end if;

  insert into public.group_memberships (
    group_id, user_id, display_name, phone, member_number, status, joined_at, created_by
  )
  values (
    p_group_id, null, btrim(p_display_name), p_phone, p_member_number, 'ACTIVE', p_joined_at, v_uid
  )
  returning id into v_membership_id;

  select jsonb_build_object(
    'membership_id', gm.id,
    'group_id', gm.group_id,
    'display_name', gm.display_name,
    'phone', gm.phone,
    'member_number', gm.member_number,
    'status', gm.status,
    'joined_at', gm.joined_at,
    'created_at', gm.created_at
  )
  into v_result
  from public.group_memberships gm
  where gm.id = v_membership_id;

  return v_result;
end;
$$;

comment on function public.rpc_create_group_member(uuid, text, text, text, date) is
  'Registers a group member without an auth account (user_id stays '
  'null). Requires member.create in the target group.';

revoke all on function public.rpc_create_group_member(uuid, text, text, text, date) from public;
grant execute on function public.rpc_create_group_member(uuid, text, text, text, date) to authenticated;
