-- Explicit rejoin workflow for EXITED members.
--
-- rpc_change_group_member_status remains intentionally terminal for
-- EXITED (see docs/product/members.md and
-- supabase/tests/database/10_admin_continuity_and_status_transitions.test.sql,
-- neither of which this migration touches). Rejoining is a distinct,
-- explicit action with its own permission/validation logic, per
-- prompt 05B §21-23.
--
-- History: clearing exited_at on rejoin would otherwise destroy the
-- fact that the member had ever exited. A narrowly-scoped, immutable
-- history row preserves it (previous_exited_at + effective_at) without
-- building a general audit subsystem — this is intentionally the only
-- lifecycle transition that writes to this table; it is not
-- retrofitted onto rpc_change_group_member_status.
--
-- Contribution Engine note (documented here since no such module
-- exists yet to hold it): a rejoin must never cause automatic
-- back-charging for periods opened while the member was EXITED. Any
-- future contribution-eligibility logic should treat a member as
-- ineligible for periods between exited_at and the rejoin's
-- effective_at, using this history table (or the membership's current
-- joined_at, which rejoin does NOT modify) to determine eligibility —
-- never inferring eligibility purely from status = 'ACTIVE' today.

create table public.group_membership_status_history (
  id uuid primary key default gen_random_uuid(),
  group_membership_id uuid not null references public.group_memberships (id),
  group_id uuid not null references public.groups (id),
  from_status public.membership_status not null,
  to_status public.membership_status not null,
  previous_exited_at date,
  effective_at date not null,
  changed_by uuid references auth.users (id),
  action text not null,
  created_at timestamptz not null default now()
);

comment on table public.group_membership_status_history is
  'Immutable, append-only record of explicit membership lifecycle '
  'transitions that would otherwise lose history (currently: rejoin '
  'only). Not a general audit log — do not extend to log every status '
  'change; rpc_change_group_member_status intentionally does not write '
  'here.';

create index group_membership_status_history_membership_idx
  on public.group_membership_status_history (group_membership_id);

alter table public.group_membership_status_history enable row level security;

-- No grants to anon/authenticated at all: this table has no direct
-- client read/write use yet (see Contribution Engine note above). The
-- only writer is rpc_rejoin_group_member (SECURITY DEFINER, so it
-- writes as the function owner regardless of these grants).
revoke all on public.group_membership_status_history from anon, authenticated;

-- ---------------------------------------------------------------------
-- rpc_rejoin_group_member
-- ---------------------------------------------------------------------
--
-- Gated by the existing member.change_status permission — prompt 05B
-- §21 calls for "the correct member status-management permission",
-- and rejoin is a member-status-management action, so this reuses that
-- permission rather than introducing a new one that would need its own
-- role_permissions seeding.
create or replace function public.rpc_rejoin_group_member(
  p_group_id uuid,
  p_membership_id uuid,
  p_rejoined_at date default current_date
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
  v_user_id uuid;
  v_previous_exited_at date;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'member.change_status') then
    raise exception 'Not authorized to change member status in this group' using errcode = '42501';
  end if;

  select group_id, status, user_id, exited_at
  into v_target_group_id, v_current_status, v_user_id, v_previous_exited_at
  from public.group_memberships
  where id = p_membership_id
  for update;

  if v_target_group_id is null or v_target_group_id <> p_group_id then
    raise exception 'Membership not found in group' using errcode = '22023';
  end if;

  if v_current_status <> 'EXITED' then
    raise exception 'MEMBERSHIP_NOT_EXITED' using errcode = 'P0001';
  end if;

  -- Mirrors group_memberships_user_active_unique: a linked auth user
  -- must not end up with two ACTIVE memberships in the same group.
  if v_user_id is not null and exists (
    select 1
    from public.group_memberships
    where group_id = p_group_id
      and user_id = v_user_id
      and status = 'ACTIVE'
      and id <> p_membership_id
  ) then
    raise exception 'USER_ALREADY_HAS_ACTIVE_MEMBERSHIP' using errcode = 'P0001';
  end if;

  update public.group_memberships
  set status = 'ACTIVE', exited_at = null
  where id = p_membership_id;

  insert into public.group_membership_status_history (
    group_membership_id, group_id, from_status, to_status,
    previous_exited_at, effective_at, changed_by, action
  ) values (
    p_membership_id, p_group_id, 'EXITED', 'ACTIVE',
    v_previous_exited_at, coalesce(p_rejoined_at, current_date), v_uid, 'REJOIN'
  );

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
end;
$$;

revoke all on function public.rpc_rejoin_group_member(uuid, uuid, date) from public;
grant execute on function public.rpc_rejoin_group_member(uuid, uuid, date) to authenticated;
revoke execute on function public.rpc_rejoin_group_member(uuid, uuid, date) from anon;
