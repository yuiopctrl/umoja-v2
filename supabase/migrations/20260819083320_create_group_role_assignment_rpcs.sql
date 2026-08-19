-- Security correction (Prompt 02A), issue 1: ADMIN role privilege
-- escalation.
--
-- Previously, any holder of `role.assign` (e.g. CHAIRPERSON) could
-- assign or remove ANY role, including ADMIN, to/from any membership in
-- their group via a direct INSERT/DELETE on
-- public.group_membership_roles. That let a non-ADMIN grant themselves
-- (or anyone else) full administrative access, and let a non-ADMIN
-- strip ADMIN from the group's actual administrators.
--
-- Fix: role mutations now go exclusively through
-- rpc_assign_group_role()/rpc_remove_group_role() (SECURITY DEFINER),
-- which additionally require that granting/revoking the ADMIN role
-- specifically requires the caller to already hold ADMIN in that group,
-- and which protect the group's last remaining ADMIN from removal.
-- Direct INSERT/DELETE grants on group_membership_roles are revoked
-- from authenticated below; the existing RLS policies on that table are
-- left in place as defense-in-depth, not as the mutation API.

-- ---------------------------------------------------------------------
-- has_group_role(): whether the caller currently holds a specific role
-- (by code) via an ACTIVE membership in the group. Same shape/safety
-- rationale as is_group_member()/has_group_permission() — SECURITY
-- DEFINER to avoid RLS-policy recursion, hard-scoped to auth.uid(),
-- explicit search_path, EXECUTE restricted to authenticated.
-- ---------------------------------------------------------------------
create or replace function public.has_group_role(p_group_id uuid, p_role_code text)
returns boolean
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.group_memberships gm
    join public.group_membership_roles gmr on gmr.group_membership_id = gm.id
    join public.roles r on r.id = gmr.role_id
    where gm.group_id = p_group_id
      and gm.user_id = auth.uid()
      and gm.status = 'ACTIVE'
      and r.code = p_role_code
  );
$$;

comment on function public.has_group_role(uuid, text) is
  'Whether the caller (auth.uid()) holds the given role code via an '
  'ACTIVE membership in the group.';

revoke all on function public.has_group_role(uuid, text) from public;
grant execute on function public.has_group_role(uuid, text) to authenticated;

-- ---------------------------------------------------------------------
-- rpc_assign_group_role()
-- ---------------------------------------------------------------------
create or replace function public.rpc_assign_group_role(
  p_group_id uuid,
  p_membership_id uuid,
  p_role_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_target_group_id uuid;
  v_role_id uuid;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  if not public.has_group_permission(p_group_id, 'role.assign') then
    raise exception 'Not authorized to assign roles in this group' using errcode = '42501';
  end if;

  select group_id into v_target_group_id
  from public.group_memberships
  where id = p_membership_id;

  if v_target_group_id is null or v_target_group_id <> p_group_id then
    raise exception 'Membership not found in group' using errcode = '22023';
  end if;

  select id into v_role_id from public.roles where code = p_role_code;
  if v_role_id is null then
    raise exception 'Unknown role code: %', p_role_code using errcode = '22023';
  end if;

  -- ADMIN can only be granted by someone who already holds ADMIN in
  -- this group. Holding role.assign (e.g. as CHAIRPERSON) is not
  -- sufficient on its own for this specific role.
  if p_role_code = 'ADMIN' and not public.has_group_role(p_group_id, 'ADMIN') then
    raise exception 'Only an existing ADMIN may assign the ADMIN role' using errcode = '42501';
  end if;

  insert into public.group_membership_roles (group_membership_id, role_id, assigned_by)
  values (p_membership_id, v_role_id, v_uid)
  on conflict (group_membership_id, role_id) do nothing;

  select jsonb_build_object(
    'membership_id', gm.id,
    'roles', coalesce((
      select jsonb_agg(distinct r.code)
      from public.group_membership_roles gmr
      join public.roles r on r.id = gmr.role_id
      where gmr.group_membership_id = gm.id
    ), '[]'::jsonb)
  )
  into v_result
  from public.group_memberships gm
  where gm.id = p_membership_id;

  return v_result;
end;
$$;

comment on function public.rpc_assign_group_role(uuid, uuid, text) is
  'Assigns a role to a membership. Requires role.assign; assigning '
  'ADMIN additionally requires the caller to already hold ADMIN in the '
  'group. Idempotent (assigning an already-held role is a no-op).';

revoke all on function public.rpc_assign_group_role(uuid, uuid, text) from public;
grant execute on function public.rpc_assign_group_role(uuid, uuid, text) to authenticated;

-- ---------------------------------------------------------------------
-- rpc_remove_group_role()
-- ---------------------------------------------------------------------
create or replace function public.rpc_remove_group_role(
  p_group_id uuid,
  p_membership_id uuid,
  p_role_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_target_group_id uuid;
  v_role_id uuid;
  v_admin_count integer;
  v_target_is_admin boolean;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  if not public.has_group_permission(p_group_id, 'role.assign') then
    raise exception 'Not authorized to remove roles in this group' using errcode = '42501';
  end if;

  select group_id into v_target_group_id
  from public.group_memberships
  where id = p_membership_id;

  if v_target_group_id is null or v_target_group_id <> p_group_id then
    raise exception 'Membership not found in group' using errcode = '22023';
  end if;

  select id into v_role_id from public.roles where code = p_role_code;
  if v_role_id is null then
    raise exception 'Unknown role code: %', p_role_code using errcode = '22023';
  end if;

  if p_role_code = 'ADMIN' then
    -- ADMIN can only be revoked by someone who already holds ADMIN.
    if not public.has_group_role(p_group_id, 'ADMIN') then
      raise exception 'Only an existing ADMIN may remove the ADMIN role' using errcode = '42501';
    end if;

    -- Last-ADMIN protection, made concurrency-safe: lock every ACTIVE
    -- ADMIN membership row in this group before counting, so a
    -- concurrent removal targeting the same group's ADMIN set cannot
    -- race past this check (it blocks until this transaction commits
    -- or rolls back, then re-counts against the post-commit state).
    perform gm.id
    from public.group_memberships gm
    join public.group_membership_roles gmr on gmr.group_membership_id = gm.id
    join public.roles r on r.id = gmr.role_id
    where gm.group_id = p_group_id and r.code = 'ADMIN' and gm.status = 'ACTIVE'
    for update of gm;

    select count(*), bool_or(gm.id = p_membership_id)
    into v_admin_count, v_target_is_admin
    from public.group_memberships gm
    join public.group_membership_roles gmr on gmr.group_membership_id = gm.id
    join public.roles r on r.id = gmr.role_id
    where gm.group_id = p_group_id and r.code = 'ADMIN' and gm.status = 'ACTIVE';

    if coalesce(v_target_is_admin, false) and v_admin_count <= 1 then
      raise exception 'LAST_ADMIN_REQUIRED' using errcode = 'P0001';
    end if;
  end if;

  delete from public.group_membership_roles
  where group_membership_id = p_membership_id and role_id = v_role_id;

  select jsonb_build_object(
    'membership_id', gm.id,
    'roles', coalesce((
      select jsonb_agg(distinct r.code)
      from public.group_membership_roles gmr
      join public.roles r on r.id = gmr.role_id
      where gmr.group_membership_id = gm.id
    ), '[]'::jsonb)
  )
  into v_result
  from public.group_memberships gm
  where gm.id = p_membership_id;

  return v_result;
end;
$$;

comment on function public.rpc_remove_group_role(uuid, uuid, text) is
  'Removes a role from a membership. Requires role.assign; removing '
  'ADMIN additionally requires the caller to already hold ADMIN, and is '
  'rejected with LAST_ADMIN_REQUIRED if it would leave the group with '
  'zero ACTIVE ADMIN memberships.';

revoke all on function public.rpc_remove_group_role(uuid, uuid, text) from public;
grant execute on function public.rpc_remove_group_role(uuid, uuid, text) to authenticated;

-- ---------------------------------------------------------------------
-- Role mutations now go exclusively through the RPCs above. Existing
-- RLS policies on group_membership_roles (from the Prompt 02 migration)
-- remain in place as defense-in-depth, but ordinary authenticated
-- clients no longer have the table-level grant needed to reach them
-- directly.
-- ---------------------------------------------------------------------
revoke insert, delete on public.group_membership_roles from authenticated;
