-- Prompt 09G-B1-D1: safe membership claim initiation by human-readable
-- reference (group code + member number), without exposing roster
-- discovery/enumeration.
--
-- Schema facts confirmed from source before designing (not assumed):
--   * groups.code is NOT NULL, globally UNIQUE (groups_code_unique),
--     format-checked ^[A-Z0-9]{2,10}$, and immutable
--     (20260821100000_add_server_generated_member_numbers.sql).
--   * group_memberships.member_number is NOT NULL, unique per group
--     only (partial unique index on (group_id, member_number)),
--     server-generated in the fixed format "<group.code>-<year>-
--     <4-digit-seq>" (e.g. "UMJ-2026-0001") — always uppercase, since
--     group.code itself is uppercase-only by its own CHECK constraint
--     (20260821120000_enforce_membership_member_numbers.sql).
--   * profiles.phone is NOT continuously-verified/authoritative: it is
--     only ever mirrored from the OTP-verified auth.users.phone once,
--     at signup (handle_new_user trigger) — but `grant update
--     (full_name, phone, avatar_url) on public.profiles to
--     authenticated` (20260819083322_restrict_profile_self_update_
--     columns.sql) lets the SAME authenticated user overwrite their
--     own profiles.phone to ANY string afterward, with no OTP
--     re-verification at all. group_memberships.phone is even weaker:
--     free text, no format check, no uniqueness constraint, entered
--     by an officer and never itself verified against anything.
--     CONCLUSION: neither side of a "phone match" is trustworthy input
--     for a security decision here — phone is deliberately OMITTED
--     from this contract entirely (09G-B1-D1 section F's own escape
--     clause), never used as a claim reference, a match signal, or an
--     ownership factor. group_code + member_number only.
--   * No group-code/roster lookup RPC of any kind exists anywhere in
--     this codebase today — this migration is the first place a
--     client-supplied group_code is ever resolved server-side.
--
-- Design: ONE new internal helper (membership_claim_request_resolve)
-- extracted from rpc_request_membership_claim's existing body — the
-- SAME eligibility/locking/idempotency logic is now shared by BOTH the
-- opaque-ID RPC and the new reference-based RPC, so there is exactly
-- one claim-request engine, never two that could drift apart.
-- rpc_request_membership_claim's own EXTERNAL behavior (parameters,
-- success shape, every specific error code/message) is verified
-- byte-for-byte unchanged by the full existing 09G-B1-B pgTAP suite
-- (102_membership_claim_workflow.test.sql) after this redefinition.
--
-- The new rpc_request_membership_claim_by_reference wraps the SAME
-- shared engine but collapses EVERY possible failure — group not
-- found, member number not found, member number belongs to a
-- different group, membership already linked, membership/group not
-- ACTIVE, a different claimant's claim already pending on that exact
-- target, even the caller's OWN "already have an active membership in
-- this group" state — into one single generic, stable outcome:
-- MEMBERSHIP_CLAIM_REFERENCE_NOT_VERIFIED. A group-code lookup and a
-- member-number lookup are resolved together in ONE query (never two
-- sequential existence checks), so there is no code path anywhere
-- that can distinguish "wrong group" from "wrong number" from "right
-- reference, ineligible" from a caller's own perspective. A failed
-- guess creates no row at all — only a resolved, eligible target ever
-- produces a persisted, auditable membership_claim_requests row,
-- exactly as before.
--
-- Rate-limiting/abuse analysis (section K): grepped the whole
-- migrations/functions corpus — no rate-limit/cooldown/throttle
-- primitive exists anywhere in this project today (the PIN lockout
-- mechanism is a distinct, unrelated auth-credential concern). A
-- lightweight DB-backed cooldown was deliberately NOT added here: (a)
-- a failed guess persists nothing, so there is no accumulation to
-- exploit; (b) the generic failure carries zero gradient signal to
-- iterate against; (c) even a successful reference match still
-- requires mandatory officer approval before anything is linked — a
-- correct guess alone confers no access. Option chosen: generic
-- failure + mandatory officer approval is sufficient for this phase;
-- API/gateway-level request rate limiting is a documented, deferred
-- limitation, not something the database layer can or should
-- implement on its own.

-- =========================================================================
-- A. Shared internal claim-request engine (fully internal — never
-- client-callable, exactly the same lockdown precedent as e.g.
-- loan_write_off_compute_amounts).
-- =========================================================================
--
-- This is rpc_request_membership_claim's PRE-EXISTING body
-- (20260921091000), extracted verbatim with p_claimant_user_id as an
-- explicit parameter in place of reading auth.uid() directly — the
-- caller (either public RPC) is responsible for resolving/validating
-- the caller's own identity BEFORE invoking this; this function never
-- re-derives or re-checks identity itself, matching the existing
-- "auth checks happen once, at the public entry point" discipline.
create or replace function public.membership_claim_request_resolve(
  p_group_id uuid,
  p_membership_id uuid,
  p_claimant_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_membership record;
  v_existing_claim record;
  v_new_claim_id uuid;
  v_result jsonb;
begin
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
    where group_id = p_group_id and user_id = p_claimant_user_id and status = 'ACTIVE'
  ) then
    raise exception 'CLAIMANT_ALREADY_HAS_ACTIVE_MEMBERSHIP_IN_GROUP' using errcode = 'P0001';
  end if;

  select id, claimant_user_id into v_existing_claim
  from public.membership_claim_requests
  where membership_id = p_membership_id and status = 'PENDING';

  if v_existing_claim.id is not null then
    if v_existing_claim.claimant_user_id = p_claimant_user_id then
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
  values (p_group_id, p_membership_id, p_claimant_user_id)
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

comment on function public.membership_claim_request_resolve(uuid, uuid, uuid) is
  'Locked-down internal engine shared by rpc_request_membership_claim '
  '(opaque id) and rpc_request_membership_claim_by_reference (group '
  'code + member number) — the ONE claim-request eligibility/locking/'
  'idempotency implementation, never duplicated. Never client-'
  'callable; the caller is responsible for its own auth/active-profile '
  'checks before invoking this.';

revoke all on function public.membership_claim_request_resolve(uuid, uuid, uuid) from public, anon, authenticated;

-- =========================================================================
-- B. rpc_request_membership_claim — redefined to delegate to the
-- shared engine above. External contract (parameters, return shape,
-- every specific error code/message) is UNCHANGED — verified by the
-- full pre-existing 09G-B1-B pgTAP suite passing byte-for-byte as-is
-- after this redefinition.
-- =========================================================================

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
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  return public.membership_claim_request_resolve(p_group_id, p_membership_id, v_uid);
end;
$$;

comment on function public.rpc_request_membership_claim(uuid, uuid) is
  'Requests to link the caller''s own auth.uid() to an existing '
  'roster-only (user_id IS NULL) ACTIVE membership in an ACTIVE group, '
  'addressed by its opaque id. Idempotent. Delegates to '
  'membership_claim_request_resolve() — see rpc_request_membership_'
  'claim_by_reference() for the human-reference equivalent, which '
  'shares this exact same engine.';

revoke all on function public.rpc_request_membership_claim(uuid, uuid) from public;
grant execute on function public.rpc_request_membership_claim(uuid, uuid) to authenticated;
revoke execute on function public.rpc_request_membership_claim(uuid, uuid) from anon;

-- =========================================================================
-- C. rpc_request_membership_claim_by_reference — the new safe
-- initiation path.
-- =========================================================================

create or replace function public.rpc_request_membership_claim_by_reference(
  p_group_code text,
  p_member_number text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_group_code text;
  v_member_number text;
  v_membership record;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  v_group_code := upper(btrim(coalesce(p_group_code, '')));
  v_member_number := upper(btrim(coalesce(p_member_number, '')));

  if v_group_code = '' or v_member_number = '' then
    raise exception 'MEMBERSHIP_CLAIM_REFERENCE_NOT_VERIFIED' using errcode = 'P0001';
  end if;

  -- ONE atomic lookup joining both the group-code and member-number
  -- conditions — a nonexistent group, a nonexistent member_number,
  -- and a member_number that genuinely exists but in a DIFFERENT
  -- group all collapse into the identical "no row found" outcome. No
  -- branch anywhere checks "does the group exist" as a separate,
  -- distinguishable step. Locks the membership row (when found) for
  -- the same reason rpc_request_membership_claim does.
  select gm.id, gm.group_id
  into v_membership
  from public.group_memberships gm
  join public.groups g on g.id = gm.group_id
  where g.code = v_group_code and gm.member_number = v_member_number
  for update of gm;

  if v_membership.id is null then
    raise exception 'MEMBERSHIP_CLAIM_REFERENCE_NOT_VERIFIED' using errcode = 'P0001';
  end if;

  -- Every failure the shared engine can raise from here on — already
  -- linked, membership/group not ACTIVE, a DIFFERENT claimant's claim
  -- already pending on this exact target, or the caller's own
  -- "already ACTIVE in this group" state — is deliberately collapsed
  -- into the same single generic outcome. Only a genuine SUCCESS
  -- (fresh claim created, or the caller's own existing pending claim
  -- returned) is ever allowed to surface a distinguishable result
  -- through this endpoint.
  begin
    v_result := public.membership_claim_request_resolve(v_membership.group_id, v_membership.id, v_uid);
  exception when others then
    raise exception 'MEMBERSHIP_CLAIM_REFERENCE_NOT_VERIFIED' using errcode = 'P0001';
  end;

  return v_result;
end;
$$;

comment on function public.rpc_request_membership_claim_by_reference(text, text) is
  'Safe claim initiation for a signed-in user who does not know their '
  'own membership_id: resolves an ACTIVE, unlinked membership purely '
  'from group_code + member_number (never phone — see this migration''s '
  'own header comment for why), then delegates to the exact same '
  'membership_claim_request_resolve() engine rpc_request_membership_'
  'claim() uses. EVERY failure mode collapses into the single generic '
  'MEMBERSHIP_CLAIM_REFERENCE_NOT_VERIFIED (P0001) outcome — this '
  'endpoint never reveals whether a group/member number exists, '
  'whether a membership is already linked, or any other roster-state '
  'distinction. A failed reference persists no row at all; only a '
  'successfully resolved, eligible target ever creates an auditable '
  'membership_claim_requests row. Officer approval remains mandatory '
  'regardless of how the claim was initiated — this RPC never links '
  'anything itself.';

revoke all on function public.rpc_request_membership_claim_by_reference(text, text) from public;
grant execute on function public.rpc_request_membership_claim_by_reference(text, text) to authenticated;
revoke execute on function public.rpc_request_membership_claim_by_reference(text, text) from anon;
