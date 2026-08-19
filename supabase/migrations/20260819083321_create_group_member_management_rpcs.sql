-- Security correction (Prompt 02A), issue 2: member.edit vs
-- member.change_status must be distinctly enforced, and member
-- mutations must go through controlled RPCs rather than a direct
-- client UPDATE that only checked "member.edit OR member.change_status"
-- for every column (including status/exited_at).

-- ---------------------------------------------------------------------
-- rpc_update_group_member(): editable identity/profile metadata only.
-- Requires member.edit. Never accepts/changes user_id, status,
-- exited_at, group_id, created_by, or created_at.
-- ---------------------------------------------------------------------
create or replace function public.rpc_update_group_member(
  p_group_id uuid,
  p_membership_id uuid,
  p_display_name text default null,
  p_phone text default null,
  p_member_number text default null,
  p_joined_at date default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_target_group_id uuid;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  if not public.has_group_permission(p_group_id, 'member.edit') then
    raise exception 'Not authorized to edit members in this group' using errcode = '42501';
  end if;

  select group_id into v_target_group_id
  from public.group_memberships
  where id = p_membership_id;

  if v_target_group_id is null or v_target_group_id <> p_group_id then
    raise exception 'Membership not found in group' using errcode = '22023';
  end if;

  if p_display_name is not null and btrim(p_display_name) = '' then
    raise exception 'Member display name cannot be blank' using errcode = '22023';
  end if;

  if p_member_number is not null and exists (
    select 1
    from public.group_memberships
    where group_id = p_group_id
      and member_number = p_member_number
      and id <> p_membership_id
  ) then
    raise exception 'member_number already exists in this group' using errcode = '23505';
  end if;

  update public.group_memberships
  set
    display_name = coalesce(nullif(btrim(p_display_name), ''), display_name),
    phone = coalesce(p_phone, phone),
    member_number = coalesce(p_member_number, member_number),
    joined_at = coalesce(p_joined_at, joined_at)
  where id = p_membership_id
  returning jsonb_build_object(
    'membership_id', id,
    'group_id', group_id,
    'display_name', display_name,
    'phone', phone,
    'member_number', member_number,
    'status', status,
    'joined_at', joined_at,
    'exited_at', exited_at,
    'updated_at', updated_at
  )
  into v_result;

  return v_result;
end;
$$;

comment on function public.rpc_update_group_member(uuid, uuid, text, text, text, date) is
  'Updates a member''s editable identity/profile metadata. Requires '
  'member.edit. Cannot change user_id, status, exited_at, group_id, '
  'created_by, or created_at — see rpc_change_group_member_status() for '
  'lifecycle/status changes.';

revoke all on function public.rpc_update_group_member(uuid, uuid, text, text, text, date) from public;
grant execute on function public.rpc_update_group_member(uuid, uuid, text, text, text, date) to authenticated;

-- ---------------------------------------------------------------------
-- rpc_change_group_member_status(): lifecycle/status changes only.
-- Requires member.change_status — deliberately distinct from
-- member.edit, so e.g. a SECRETARY (member.edit but not
-- member.change_status) cannot suspend or exit a member.
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
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  if not public.has_group_permission(p_group_id, 'member.change_status') then
    raise exception 'Not authorized to change member status in this group' using errcode = '42501';
  end if;

  select group_id into v_target_group_id
  from public.group_memberships
  where id = p_membership_id
  for update;

  if v_target_group_id is null or v_target_group_id <> p_group_id then
    raise exception 'Membership not found in group' using errcode = '22023';
  end if;

  -- No financial history exists yet, so returning from SUSPENDED (or
  -- EXITED) to ACTIVE is a plain status change here — no financial
  -- effects to invent. exited_at is set only while EXITED, and cleared
  -- otherwise, preserving history rather than hard-deleting anything.
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
  'Changes a membership''s lifecycle status (ACTIVE/SUSPENDED/EXITED). '
  'Requires member.change_status, distinct from member.edit. Sets '
  'exited_at when moving to EXITED, clears it otherwise.';

revoke all on function public.rpc_change_group_member_status(uuid, uuid, public.membership_status, date) from public;
grant execute on function public.rpc_change_group_member_status(uuid, uuid, public.membership_status, date) to authenticated;

-- ---------------------------------------------------------------------
-- Member mutations now go exclusively through rpc_create_group_member,
-- rpc_update_group_member, and rpc_change_group_member_status (all
-- SECURITY DEFINER, unaffected by this revoke). Direct authenticated
-- INSERT/UPDATE on group_memberships is no longer needed and is
-- revoked; SELECT (gated by the existing RLS policy) remains. The
-- existing RLS INSERT/UPDATE policies remain as defense-in-depth.
-- ---------------------------------------------------------------------
revoke insert, update on public.group_memberships from authenticated;
