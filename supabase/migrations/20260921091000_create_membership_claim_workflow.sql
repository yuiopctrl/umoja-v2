-- Prompt 09G-B1-B: secure roster-membership claim & linking.
--
-- Locked business model (see docs/product/member-identity-model.md and
-- the 09G-B-01 architecture audit): a roster-only membership
-- (group_memberships.user_id IS NULL) must NEVER become linked to an
-- authenticated user automatically — never by phone match, name
-- match, member_number match, email match, or knowledge of the group
-- code. The only safe lifecycle is:
--
--   authenticated user -> requests claim of a specific roster
--   membership -> PENDING -> an authorized officer reviews ->
--   APPROVE (atomically sets group_memberships.user_id) or REJECT.
--
-- Ownership (is_own_membership(), 20260921090000) begins ONLY once an
-- APPROVE has actually run.
--
-- Discovery is deliberately OUT OF SCOPE for this migration: building
-- a "find my roster row" RPC without a concrete Flutter UX to shape it
-- risks introducing exactly the roster-enumeration surface this
-- prompt warns against (member_number is a small, sequential,
-- predictable format — "<group code>-<year>-<seq>" — so a bare
-- lookup-by-member-number oracle is a real enumeration risk). This
-- migration's RPCs take an opaque p_membership_id the caller must
-- already have obtained some other way (today: an officer tells the
-- claimant which membership to claim, e.g. from a physical roster/
-- receipt); a safe, generic-response, multi-factor discovery RPC can
-- be added later once the Flutter flow that needs it is actually
-- being built.

-- =========================================================================
-- A. group_memberships.user_id immutability — the ONE authorized
-- exception.
-- =========================================================================
--
-- public.prevent_membership_user_id_change() (20260819080632, deployed,
-- NOT edited by this migration) unconditionally rejects any change to
-- user_id via UPDATE, from any role, including from inside a SECURITY
-- DEFINER function — triggers are a table-level mechanism and are
-- never bypassed by SECURITY DEFINER. That is exactly correct for
-- every ordinary UPDATE path (rpc_update_group_member and friends
-- never touch user_id at all), but rpc_approve_membership_claim below
-- has exactly one legitimate reason to perform this transition and
-- needs a way through.
--
-- This redefinition narrows the trigger's exception to the absolute
-- minimum: NULL -> non-null is allowed ONLY when a transaction-local
-- marker (set via set_config(..., true), i.e. scoped to the current
-- transaction only and invisible outside it) is present. That marker
-- is set in exactly one place in the whole codebase —
-- rpc_approve_membership_claim, immediately before its own UPDATE —
-- and can never be set by a client: PostgREST only ever exposes
-- functions explicitly declared in the API schema, never
-- pg_catalog.set_config() itself, so no REST call can set this marker
-- without going through the approval RPC's own permission/eligibility
-- checks first. Every other transition this trigger already blocked
-- (non-null -> different, non-null -> null, or NULL -> non-null
-- without the marker) remains blocked exactly as before — this is a
-- narrow addition, never a weakening or removal.
create or replace function public.prevent_membership_user_id_change()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.user_id is distinct from old.user_id then
    if old.user_id is null
      and new.user_id is not null
      and coalesce(current_setting('umoja.membership_claim_approval', true), 'false') = 'true'
    then
      return new;
    end if;
    raise exception 'group_memberships.user_id cannot be changed by update' using errcode = '42501';
  end if;
  return new;
end;
$$;

comment on function public.prevent_membership_user_id_change() is
  'Blocks every change to group_memberships.user_id via UPDATE, with '
  'exactly one narrow exception: a NULL -> non-null transition when the '
  'transaction-local umoja.membership_claim_approval marker is set to '
  '''true'' — set only by rpc_approve_membership_claim, immediately '
  'before its own UPDATE, never settable by a client. Every other '
  'transition remains unconditionally rejected.';

-- =========================================================================
-- B. membership_claim_requests — append-only-in-spirit audit/
-- authorization record. Never stores a password/OTP/PIN/secret; only
-- who requested what, against which roster row, and how it was
-- resolved.
-- =========================================================================

create type public.membership_claim_status as enum ('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED');

create table public.membership_claim_requests (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id),
  membership_id uuid not null references public.group_memberships (id),
  claimant_user_id uuid not null references auth.users (id),
  status public.membership_claim_status not null default 'PENDING',
  requested_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid references auth.users (id),
  rejection_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint membership_claim_requests_rejection_reason_required
    check (status <> 'REJECTED' or btrim(coalesce(rejection_reason, '')) <> ''),
  constraint membership_claim_requests_resolved_fields_consistent
    check (
      (status = 'PENDING' and resolved_at is null and resolved_by is null)
      or (status <> 'PENDING' and resolved_at is not null and resolved_by is not null)
    )
);

comment on table public.membership_claim_requests is
  'Authorization/audit record for the roster-membership claim '
  'workflow (Prompt 09G-B1-B). Never stores a password/OTP/PIN or any '
  'authentication secret — only the request/resolution facts. Rows '
  'are never hard-deleted or edited outside the RPCs in this '
  'migration; resolved rows (APPROVED/REJECTED/CANCELLED) are '
  'permanent history.';

create trigger membership_claim_requests_set_updated_at
  before update on public.membership_claim_requests
  for each row
  execute function public.set_updated_at();

-- E1/E2: a membership can never have more than one PENDING claim at a
-- time (this alone also makes a duplicate PENDING claim from the same
-- claimant for the same membership structurally impossible).
create unique index membership_claim_requests_one_pending_per_membership
  on public.membership_claim_requests (membership_id)
  where status = 'PENDING';

create index membership_claim_requests_claimant_idx
  on public.membership_claim_requests (claimant_user_id);
create index membership_claim_requests_group_idx
  on public.membership_claim_requests (group_id);

alter table public.membership_claim_requests enable row level security;

-- Same lockdown precedent as group_membership_status_history
-- (20260821090000): zero RLS policies, zero direct grants to
-- anon/authenticated. Every read and write goes exclusively through
-- the SECURITY DEFINER RPCs below, which run as the function owner
-- regardless of these grants.
revoke all on public.membership_claim_requests from anon, authenticated;

-- =========================================================================
-- C. member.claim.approve — a dedicated permission, not an overload of
-- member.edit/member.change_status.
-- =========================================================================
--
-- Approving a claim grants a real authenticated user standing access
-- to the group (whatever that membership's own roles/permissions
-- allow from then on) — a materially more sensitive action than
-- editing a display_name/phone field or suspending/reactivating a
-- member, so it is not folded into member.edit or
-- member.change_status. Granted to ADMIN and CHAIRPERSON only,
-- deliberately mirroring role.assign's existing boundary (the only
-- other permission in this schema that already gates a
-- security/access-granting decision rather than an ordinary record
-- edit) — NOT granted to SECRETARY or TREASURER, exactly as neither
-- holds role.assign today despite SECRETARY holding member.create/
-- member.edit.
insert into public.permissions (code, name, description) values
  ('member.claim.approve', 'Approve membership claims', 'Approve or reject a roster member''s request to link their authenticated account.');

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r, public.permissions p
where r.code = 'ADMIN' and p.code = 'member.claim.approve';

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r, public.permissions p
where r.code = 'CHAIRPERSON' and p.code = 'member.claim.approve';

-- =========================================================================
-- D. rpc_request_membership_claim
-- =========================================================================
--
-- claimant_user_id is ALWAYS auth.uid() — never a client-supplied
-- value. Locks the target membership row for the duration of the
-- eligibility check (mirroring rpc_rejoin_group_member's own
-- for-update discipline), which also serializes concurrent claim
-- attempts against the same membership: a second concurrent caller
-- blocks until the first transaction commits/rolls back, then
-- re-reads the now-current state rather than racing on a stale read.
create or replace function public.rpc_request_membership_claim(
  p_group_id uuid,
  p_membership_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_membership record;
  v_existing_claim record;
  v_new_claim_id uuid;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  select gm.id, gm.group_id, gm.user_id, gm.status as membership_status, g.status as group_status
  into v_membership
  from public.group_memberships gm
  join public.groups g on g.id = gm.group_id
  where gm.id = p_membership_id
  for update of gm;

  if v_membership.id is null or v_membership.group_id <> p_group_id then
    raise exception 'Membership not found in group' using errcode = '22023';
  end if;

  if v_membership.user_id is not null then
    raise exception 'MEMBERSHIP_ALREADY_LINKED' using errcode = 'P0001';
  end if;

  if v_membership.membership_status <> 'ACTIVE' then
    raise exception 'MEMBERSHIP_NOT_ACTIVE' using errcode = 'P0001';
  end if;

  if v_membership.group_status <> 'ACTIVE' then
    raise exception 'GROUP_NOT_ACTIVE' using errcode = 'P0001';
  end if;

  if exists (
    select 1 from public.group_memberships
    where group_id = p_group_id and user_id = v_uid and status = 'ACTIVE'
  ) then
    raise exception 'CLAIMANT_ALREADY_HAS_ACTIVE_MEMBERSHIP_IN_GROUP' using errcode = 'P0001';
  end if;

  -- The membership row is locked above, so at most one PENDING claim
  -- can ever exist for it at this point — either none (create one) or
  -- exactly one (return it if it's this same caller's own retry,
  -- otherwise reject).
  select id, claimant_user_id into v_existing_claim
  from public.membership_claim_requests
  where membership_id = p_membership_id and status = 'PENDING';

  if v_existing_claim.id is not null then
    if v_existing_claim.claimant_user_id = v_uid then
      select jsonb_build_object(
        'claim_id', id, 'group_id', group_id, 'membership_id', membership_id,
        'status', status, 'requested_at', requested_at, 'already_requested', true
      )
      into v_result
      from public.membership_claim_requests
      where id = v_existing_claim.id;
      return v_result;
    end if;
    raise exception 'MEMBERSHIP_CLAIM_ALREADY_PENDING' using errcode = 'P0001';
  end if;

  insert into public.membership_claim_requests (group_id, membership_id, claimant_user_id)
  values (p_group_id, p_membership_id, v_uid)
  returning id into v_new_claim_id;

  select jsonb_build_object(
    'claim_id', id, 'group_id', group_id, 'membership_id', membership_id,
    'status', status, 'requested_at', requested_at, 'already_requested', false
  )
  into v_result
  from public.membership_claim_requests
  where id = v_new_claim_id;

  return v_result;
end;
$$;

comment on function public.rpc_request_membership_claim(uuid, uuid) is
  'Requests to link the caller''s own auth.uid() to an existing '
  'roster-only (user_id IS NULL) ACTIVE membership in an ACTIVE group. '
  'Idempotent: retrying with the same membership returns the caller''s '
  'own existing PENDING claim rather than creating a duplicate. Never '
  'links anything itself — see rpc_approve_membership_claim.';

revoke all on function public.rpc_request_membership_claim(uuid, uuid) from public;
grant execute on function public.rpc_request_membership_claim(uuid, uuid) to authenticated;
revoke execute on function public.rpc_request_membership_claim(uuid, uuid) from anon;

-- =========================================================================
-- E. rpc_approve_membership_claim
-- =========================================================================

create or replace function public.rpc_approve_membership_claim(
  p_group_id uuid,
  p_claim_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_claim record;
  v_membership record;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'member.claim.approve') then
    raise exception 'Not authorized to approve membership claims in this group' using errcode = '42501';
  end if;

  select id, group_id, membership_id, claimant_user_id, status
  into v_claim
  from public.membership_claim_requests
  where id = p_claim_id
  for update;

  if v_claim.id is null or v_claim.group_id <> p_group_id then
    raise exception 'Membership claim not found in group' using errcode = '22023';
  end if;

  if v_claim.status <> 'PENDING' then
    raise exception 'MEMBERSHIP_CLAIM_NOT_PENDING' using errcode = 'P0001';
  end if;

  select gm.id, gm.group_id, gm.user_id, gm.status as membership_status, g.status as group_status
  into v_membership
  from public.group_memberships gm
  join public.groups g on g.id = gm.group_id
  where gm.id = v_claim.membership_id
  for update of gm;

  if v_membership.id is null or v_membership.group_id <> p_group_id then
    raise exception 'Membership not found in group' using errcode = '22023';
  end if;

  -- Re-check every eligibility condition against the CURRENT,
  -- now-locked row — never trust the state as it was when the claim
  -- was requested. Covers: someone else linked it since, the
  -- membership/group became non-operational since, etc.
  if v_membership.user_id is not null then
    raise exception 'MEMBERSHIP_ALREADY_LINKED' using errcode = 'P0001';
  end if;

  if v_membership.membership_status <> 'ACTIVE' then
    raise exception 'MEMBERSHIP_NOT_ACTIVE' using errcode = 'P0001';
  end if;

  if v_membership.group_status <> 'ACTIVE' then
    raise exception 'GROUP_NOT_ACTIVE' using errcode = 'P0001';
  end if;

  -- Mirrors group_memberships_user_active_unique / the identical
  -- guard in rpc_rejoin_group_member: the claimant must not end up
  -- with two ACTIVE memberships in the same group.
  if exists (
    select 1 from public.group_memberships
    where group_id = p_group_id and user_id = v_claim.claimant_user_id and status = 'ACTIVE'
  ) then
    raise exception 'CLAIMANT_ALREADY_HAS_ACTIVE_MEMBERSHIP_IN_GROUP' using errcode = 'P0001';
  end if;

  perform set_config('umoja.membership_claim_approval', 'true', true);

  update public.group_memberships
  set user_id = v_claim.claimant_user_id
  where id = v_claim.membership_id;

  update public.membership_claim_requests
  set status = 'APPROVED', resolved_at = now(), resolved_by = v_uid
  where id = p_claim_id;

  select jsonb_build_object(
    'claim_id', id, 'group_id', group_id, 'membership_id', membership_id,
    'claimant_user_id', claimant_user_id, 'status', status,
    'resolved_at', resolved_at, 'resolved_by', resolved_by
  )
  into v_result
  from public.membership_claim_requests
  where id = p_claim_id;

  return v_result;
end;
$$;

comment on function public.rpc_approve_membership_claim(uuid, uuid) is
  'Approves a PENDING membership claim: re-validates every eligibility '
  'condition against the locked, current row state, then atomically '
  'links group_memberships.user_id = claimant AND marks the claim '
  'APPROVED in the same transaction — if either half fails, neither '
  'happens (no partial state). Requires member.claim.approve.';

revoke all on function public.rpc_approve_membership_claim(uuid, uuid) from public;
grant execute on function public.rpc_approve_membership_claim(uuid, uuid) to authenticated;
revoke execute on function public.rpc_approve_membership_claim(uuid, uuid) from anon;

-- =========================================================================
-- F. rpc_reject_membership_claim
-- =========================================================================

create or replace function public.rpc_reject_membership_claim(
  p_group_id uuid,
  p_claim_id uuid,
  p_rejection_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_claim record;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'member.claim.approve') then
    raise exception 'Not authorized to approve membership claims in this group' using errcode = '42501';
  end if;

  if btrim(coalesce(p_rejection_reason, '')) = '' then
    raise exception 'MEMBERSHIP_CLAIM_REJECTION_REASON_REQUIRED' using errcode = '22023';
  end if;

  select id, group_id, status into v_claim
  from public.membership_claim_requests
  where id = p_claim_id
  for update;

  if v_claim.id is null or v_claim.group_id <> p_group_id then
    raise exception 'Membership claim not found in group' using errcode = '22023';
  end if;

  if v_claim.status <> 'PENDING' then
    raise exception 'MEMBERSHIP_CLAIM_NOT_PENDING' using errcode = 'P0001';
  end if;

  update public.membership_claim_requests
  set status = 'REJECTED', resolved_at = now(), resolved_by = v_uid, rejection_reason = p_rejection_reason
  where id = p_claim_id;

  select jsonb_build_object(
    'claim_id', id, 'group_id', group_id, 'membership_id', membership_id,
    'status', status, 'resolved_at', resolved_at, 'resolved_by', resolved_by,
    'rejection_reason', rejection_reason
  )
  into v_result
  from public.membership_claim_requests
  where id = p_claim_id;

  return v_result;
end;
$$;

comment on function public.rpc_reject_membership_claim(uuid, uuid, text) is
  'Rejects a PENDING membership claim with a required reason. Never '
  'touches group_memberships. Requires member.claim.approve (the same '
  'boundary as approval).';

revoke all on function public.rpc_reject_membership_claim(uuid, uuid, text) from public;
grant execute on function public.rpc_reject_membership_claim(uuid, uuid, text) to authenticated;
revoke execute on function public.rpc_reject_membership_claim(uuid, uuid, text) from anon;

-- =========================================================================
-- G. rpc_cancel_membership_claim — claimant-only, ownership of the
-- CLAIM alone, never an administrative permission.
-- =========================================================================

create or replace function public.rpc_cancel_membership_claim(
  p_claim_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_claim record;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  select id, claimant_user_id, status into v_claim
  from public.membership_claim_requests
  where id = p_claim_id
  for update;

  if v_claim.id is null or v_claim.claimant_user_id <> v_uid then
    raise exception 'Membership claim not found' using errcode = '22023';
  end if;

  if v_claim.status <> 'PENDING' then
    raise exception 'MEMBERSHIP_CLAIM_NOT_PENDING' using errcode = 'P0001';
  end if;

  update public.membership_claim_requests
  set status = 'CANCELLED', resolved_at = now(), resolved_by = v_uid
  where id = p_claim_id;

  select jsonb_build_object(
    'claim_id', id, 'group_id', group_id, 'membership_id', membership_id,
    'status', status, 'resolved_at', resolved_at
  )
  into v_result
  from public.membership_claim_requests
  where id = p_claim_id;

  return v_result;
end;
$$;

comment on function public.rpc_cancel_membership_claim(uuid) is
  'Lets the claimant withdraw their own still-PENDING claim. Ownership '
  'of the claim row (claimant_user_id = auth.uid()) is the sole check '
  '— never an administrative permission. Cannot cancel another '
  'user''s claim or one already APPROVED/REJECTED.';

revoke all on function public.rpc_cancel_membership_claim(uuid) from public;
grant execute on function public.rpc_cancel_membership_claim(uuid) to authenticated;
revoke execute on function public.rpc_cancel_membership_claim(uuid) from anon;

-- =========================================================================
-- H. Read RPCs
-- =========================================================================

-- Claimant read: only ever the caller's own claims, across every
-- group they've ever attempted to claim into.
create or replace function public.rpc_list_my_membership_claims()
returns jsonb
language sql
security definer
stable
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'claim_id', c.id,
    'group_id', c.group_id,
    'membership_id', c.membership_id,
    'status', c.status,
    'requested_at', c.requested_at,
    'resolved_at', c.resolved_at,
    'rejection_reason', c.rejection_reason
  ) order by c.requested_at desc), '[]'::jsonb)
  from public.membership_claim_requests c
  where c.claimant_user_id = auth.uid();
$$;

comment on function public.rpc_list_my_membership_claims() is
  'The caller''s own membership claim requests, any status, any group '
  '— filtered exclusively by claimant_user_id = auth.uid(). Never '
  'returns another user''s claim.';

revoke all on function public.rpc_list_my_membership_claims() from public;
grant execute on function public.rpc_list_my_membership_claims() to authenticated;
revoke execute on function public.rpc_list_my_membership_claims() from anon;

-- Officer queue: group-scoped, permission-gated, and deliberately
-- exposes only what is needed to decide — the roster's own already-
-- member.view-visible fields, plus the claimant's PROFILE full_name/
-- phone (never any raw auth.users field) so the officer can visually
-- cross-check the claimant against the roster row they're claiming.
create or replace function public.rpc_list_membership_claims(
  p_group_id uuid,
  p_status public.membership_claim_status default 'PENDING',
  p_limit integer default 20,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_items jsonb;
  v_total bigint;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'member.claim.approve') then
    raise exception 'Not authorized to view membership claims in this group' using errcode = '42501';
  end if;

  select count(*) into v_total
  from public.membership_claim_requests c
  where c.group_id = p_group_id and (p_status is null or c.status = p_status);

  select coalesce(jsonb_agg(jsonb_build_object(
    'claim_id', c.id,
    'membership_id', c.membership_id,
    'membership_display_name', gm.display_name,
    'membership_member_number', gm.member_number,
    'membership_phone', gm.phone,
    'claimant_full_name', p.full_name,
    'claimant_phone', p.phone,
    'status', c.status,
    'requested_at', c.requested_at,
    'resolved_at', c.resolved_at,
    'rejection_reason', c.rejection_reason
  ) order by c.requested_at asc), '[]'::jsonb)
  into v_items
  from (
    select *
    from public.membership_claim_requests c
    where c.group_id = p_group_id and (p_status is null or c.status = p_status)
    order by c.requested_at asc
    limit p_limit offset p_offset
  ) c
  join public.group_memberships gm on gm.id = c.membership_id
  join public.profiles p on p.id = c.claimant_user_id;

  return jsonb_build_object(
    'items', v_items, 'total_count', v_total, 'limit', p_limit, 'offset', p_offset
  );
end;
$$;

comment on function public.rpc_list_membership_claims(uuid, public.membership_claim_status, integer, integer) is
  'Group-scoped, member.claim.approve-gated officer queue. Exposes '
  'only the roster row''s own fields (already member.view-visible) '
  'plus the claimant''s public.profiles full_name/phone — never a raw '
  'auth.users field.';

revoke all on function public.rpc_list_membership_claims(uuid, public.membership_claim_status, integer, integer) from public;
grant execute on function public.rpc_list_membership_claims(uuid, public.membership_claim_status, integer, integer) to authenticated;
revoke execute on function public.rpc_list_membership_claims(uuid, public.membership_claim_status, integer, integer) from anon;
