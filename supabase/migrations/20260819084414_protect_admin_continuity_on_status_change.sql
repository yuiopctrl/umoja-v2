-- Security correction (Prompt 02B): a group's sole ACTIVE ADMIN could
-- still be left without any active administrator through
-- rpc_change_group_member_status() (ACTIVE -> SUSPENDED/EXITED),
-- even though Prompt 02A already protected the equivalent path through
-- rpc_remove_group_role(). Both must enforce the same invariant: a
-- group always retains at least one ACTIVE membership holding ADMIN.
--
-- Fix: extract the last-admin check into a single shared, internal-only
-- helper and use it from both RPCs, so the rule cannot drift between
-- the two call sites. Also tighten rpc_change_group_member_status()'s
-- status transitions (EXITED is terminal for this RPC; same-status
-- calls are a safe no-op).

-- ---------------------------------------------------------------------
-- assert_last_active_admin_remains(): raises LAST_ADMIN_REQUIRED if
-- p_membership_id is currently the group's *only* ACTIVE membership
-- holding the ADMIN role. Callers are expected to invoke this BEFORE
-- removing the ADMIN role or deactivating the membership's status, so
-- the row-level locking below still sees the about-to-be-removed
-- assignment as part of the current ACTIVE ADMIN set.
--
-- Concurrency: locks every currently-ACTIVE ADMIN membership row in the
-- group (FOR UPDATE OF gm) before counting. Two concurrent calls
-- targeting overlapping ADMIN sets in the same group therefore
-- serialize — the second call blocks until the first commits/rolls
-- back, then re-counts against the post-commit state — so two
-- concurrent "last admin" removals can never both succeed.
--
-- Internal helper only: EXECUTE is revoked from anon, authenticated,
-- and public. It is still callable from rpc_remove_group_role() and
-- rpc_change_group_member_status() because a SECURITY DEFINER
-- function's nested calls run as the function owner, not the original
-- client role — this is not an oversight.
create or replace function public.assert_last_active_admin_remains(
  p_group_id uuid,
  p_membership_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_admin_count integer;
  v_target_is_admin boolean;
begin
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
end;
$$;

comment on function public.assert_last_active_admin_remains(uuid, uuid) is
  'Raises LAST_ADMIN_REQUIRED if p_membership_id is the group''s only '
  'ACTIVE ADMIN membership. Internal helper shared by '
  'rpc_remove_group_role() and rpc_change_group_member_status() so the '
  'invariant cannot drift between them. Not part of the public API.';

revoke all on function public.assert_last_active_admin_remains(uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- rpc_remove_group_role(): refactored to call the shared helper instead
-- of duplicating the lock-and-count logic inline. Behavior is
-- unchanged; the invariant now lives in one place.
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
    if not public.has_group_role(p_group_id, 'ADMIN') then
      raise exception 'Only an existing ADMIN may remove the ADMIN role' using errcode = '42501';
    end if;

    perform public.assert_last_active_admin_remains(p_group_id, p_membership_id);
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
  'zero ACTIVE ADMIN memberships (see assert_last_active_admin_remains).';

-- ---------------------------------------------------------------------
-- rpc_change_group_member_status(): now enforces the same
-- last-active-ADMIN invariant when a currently-ACTIVE ADMIN membership
-- is moved to SUSPENDED or EXITED, and tightens status transitions:
--   - same-status calls (ACTIVE->ACTIVE, SUSPENDED->SUSPENDED,
--     EXITED->EXITED) are a safe no-op that returns current state
--     without mutating exited_at/updated_at.
--   - EXITED is terminal for this RPC: EXITED->ACTIVE and
--     EXITED->SUSPENDED are rejected. A future rejoin workflow is out
--     of scope here.
-- ---------------------------------------------------------------------
create or replace function public.rpc_change_group_member_status(
  p_group_id uuid,
  p_membership_id uuid,
  p_status public.membership_status,
  p_exited_at date default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_target_group_id uuid;
  v_current_status public.membership_status;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  if not public.has_group_permission(p_group_id, 'member.change_status') then
    raise exception 'Not authorized to change member status in this group' using errcode = '42501';
  end if;

  -- Lock the target row now: both the no-op short-circuit below and
  -- the last-admin check need a stable view of its current status.
  select group_id, status into v_target_group_id, v_current_status
  from public.group_memberships
  where id = p_membership_id
  for update;

  if v_target_group_id is null or v_target_group_id <> p_group_id then
    raise exception 'Membership not found in group' using errcode = '22023';
  end if;

  -- Idempotent no-op: return current state untouched. This matters
  -- most for EXITED->EXITED, which must not disturb the original
  -- exited_at.
  if v_current_status = p_status then
    select jsonb_build_object(
      'membership_id', id,
      'group_id', group_id,
      'status', status,
      'exited_at', exited_at,
      'updated_at', updated_at
    )
    into v_result
    from public.group_memberships
    where id = p_membership_id;

    return v_result;
  end if;

  -- EXITED is terminal through this RPC. Rejoining after an exit is a
  -- deliberate future workflow, not a casual status toggle.
  if v_current_status = 'EXITED' then
    raise exception 'EXITED_MEMBERSHIP_IS_TERMINAL' using errcode = 'P0001';
  end if;

  -- Deactivating the group's sole ACTIVE ADMIN via status change must
  -- be blocked exactly like removing their ADMIN role would be.
  if v_current_status = 'ACTIVE' and exists (
    select 1
    from public.group_membership_roles gmr
    join public.roles r on r.id = gmr.role_id
    where gmr.group_membership_id = p_membership_id and r.code = 'ADMIN'
  ) then
    perform public.assert_last_active_admin_remains(p_group_id, p_membership_id);
  end if;

  update public.group_memberships
  set
    status = p_status,
    exited_at = case
      when p_status = 'EXITED' then coalesce(p_exited_at, current_date)
      else null
    end
  where id = p_membership_id
  returning jsonb_build_object(
    'membership_id', id,
    'group_id', group_id,
    'status', status,
    'exited_at', exited_at,
    'updated_at', updated_at
  )
  into v_result;

  return v_result;
end;
$$;

comment on function public.rpc_change_group_member_status(uuid, uuid, public.membership_status, date) is
  'Changes a membership''s lifecycle status. Requires '
  'member.change_status, distinct from member.edit. Same-status calls '
  'are a safe no-op; EXITED is terminal (EXITED->ACTIVE/SUSPENDED is '
  'rejected); deactivating the group''s sole ACTIVE ADMIN is rejected '
  'with LAST_ADMIN_REQUIRED, matching rpc_remove_group_role().';
