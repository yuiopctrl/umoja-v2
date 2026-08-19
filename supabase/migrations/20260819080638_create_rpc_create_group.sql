-- rpc_create_group(): atomically create a group and make the calling
-- user its first (ADMIN) membership.
--
-- Flutter must never separately insert a group, then a membership, then
-- an ADMIN role assignment — a partial failure between those steps would
-- leave a group with no admin. This function performs all three writes
-- in one function invocation, which runs inside the single transaction
-- of the calling statement, so it either fully succeeds or fully rolls
-- back.
create or replace function public.rpc_create_group(
  p_name text,
  p_description text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_group_id uuid;
  v_membership_id uuid;
  v_admin_role_id uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  if p_name is null or btrim(p_name) = '' then
    raise exception 'Group name is required' using errcode = '22023';
  end if;

  select id into v_admin_role_id from public.roles where code = 'ADMIN';
  if v_admin_role_id is null then
    raise exception 'ADMIN role is not defined';
  end if;

  insert into public.groups (name, description, status, created_by)
  values (btrim(p_name), p_description, 'ACTIVE', v_uid)
  returning id into v_group_id;

  insert into public.group_memberships (
    group_id, user_id, display_name, status, joined_at, created_by
  )
  values (
    v_group_id,
    v_uid,
    coalesce(
      nullif(btrim((select full_name from public.profiles where id = v_uid)), ''),
      'Group admin'
    ),
    'ACTIVE',
    current_date,
    v_uid
  )
  returning id into v_membership_id;

  insert into public.group_membership_roles (group_membership_id, role_id, assigned_by)
  values (v_membership_id, v_admin_role_id, v_uid);

  return public.rpc_get_my_context();
end;
$$;

comment on function public.rpc_create_group(text, text) is
  'Atomically creates a group and assigns the calling user an ACTIVE '
  'ADMIN membership. Returns the caller''s updated application context.';

revoke all on function public.rpc_create_group(text, text) from public;
grant execute on function public.rpc_create_group(text, text) to authenticated;
