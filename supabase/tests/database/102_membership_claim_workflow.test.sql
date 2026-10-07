-- Prompt 09G-B1-B: secure roster-membership claim & linking — request/
-- approve/reject/cancel, uniqueness/concurrency guards, permission
-- boundaries, and the user_id immutability trigger's one narrow
-- exception.
begin;

select plan(54);

insert into auth.users (id, email) values
  ('10200000-0000-0000-0000-000000000011', 'p09gb1b-admin@example.com'),
  ('10200000-0000-0000-0000-000000000012', 'p09gb1b-treasurer@example.com'),
  ('10200000-0000-0000-0000-000000000013', 'p09gb1b-member@example.com'),
  ('10200000-0000-0000-0000-000000000014', 'p09gb1b-adminb@example.com'),
  ('10200000-0000-0000-0000-000000000021', 'p09gb1b-claimant1@example.com'),
  ('10200000-0000-0000-0000-000000000022', 'p09gb1b-claimant2@example.com'),
  ('10200000-0000-0000-0000-000000000023', 'p09gb1b-existing@example.com'),
  ('10200000-0000-0000-0000-000000000024', 'p09gb1b-claimanty@example.com'),
  ('10200000-0000-0000-0000-000000000025', 'p09gb1b-claimant3@example.com'),
  ('10200000-0000-0000-0000-000000000026', 'p09gb1b-claimant4@example.com'),
  ('10200000-0000-0000-0000-000000000027', 'p09gb1b-claimant5-reject@example.com');

insert into public.groups (id, name, created_by, code, status) values
  ('10200000-0000-0000-0000-000000000001', 'Claim Group A', '10200000-0000-0000-0000-000000000011', 'CLMA', 'ACTIVE'),
  ('10200000-0000-0000-0000-000000000002', 'Claim Group B', '10200000-0000-0000-0000-000000000011', 'CLMB', 'ACTIVE'),
  ('10200000-0000-0000-0000-000000000003', 'Claim Group C (suspended)', '10200000-0000-0000-0000-000000000011', 'CLMC', 'SUSPENDED');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number, phone) values
  ('10200000-0000-0000-0000-000000000101', '10200000-0000-0000-0000-000000000001', '10200000-0000-0000-0000-000000000011', 'Admin One', 'ACTIVE', '2025-01-01', 'CLMA-0001', null),
  ('10200000-0000-0000-0000-000000000102', '10200000-0000-0000-0000-000000000001', '10200000-0000-0000-0000-000000000012', 'Treasurer Two', 'ACTIVE', '2025-01-01', 'CLMA-0002', null),
  ('10200000-0000-0000-0000-000000000103', '10200000-0000-0000-0000-000000000001', '10200000-0000-0000-0000-000000000013', 'Member Three', 'ACTIVE', '2025-01-01', 'CLMA-0003', null),
  ('10200000-0000-0000-0000-000000000104', '10200000-0000-0000-0000-000000000002', '10200000-0000-0000-0000-000000000014', 'Admin B', 'ACTIVE', '2025-01-01', 'CLMB-0001', null),
  ('10200000-0000-0000-0000-000000000105', '10200000-0000-0000-0000-000000000001', null, 'Roster One', 'ACTIVE', '2025-01-01', 'CLMA-0010', '+255711000001'),
  ('10200000-0000-0000-0000-000000000106', '10200000-0000-0000-0000-000000000001', null, 'Roster Two', 'ACTIVE', '2025-01-01', 'CLMA-0011', null),
  ('10200000-0000-0000-0000-000000000107', '10200000-0000-0000-0000-000000000001', null, 'Roster Three (suspended)', 'SUSPENDED', '2025-01-01', 'CLMA-0012', null),
  ('10200000-0000-0000-0000-000000000108', '10200000-0000-0000-0000-000000000003', null, 'Roster (suspended group)', 'ACTIVE', '2025-01-01', 'CLMC-0001', null),
  ('10200000-0000-0000-0000-000000000109', '10200000-0000-0000-0000-000000000001', '10200000-0000-0000-0000-000000000023', 'Existing Member (A)', 'ACTIVE', '2025-01-01', 'CLMA-0004', null),
  ('10200000-0000-0000-0000-000000000110', '10200000-0000-0000-0000-000000000002', '10200000-0000-0000-0000-000000000023', 'Existing Member (B)', 'ACTIVE', '2025-01-01', 'CLMB-0002', null),
  ('10200000-0000-0000-0000-000000000111', '10200000-0000-0000-0000-000000000001', null, 'Roster Four', 'ACTIVE', '2025-01-01', 'CLMA-0013', null),
  ('10200000-0000-0000-0000-000000000112', '10200000-0000-0000-0000-000000000001', null, 'Roster Five', 'ACTIVE', '2025-01-01', 'CLMA-0014', null),
  ('10200000-0000-0000-0000-000000000113', '10200000-0000-0000-0000-000000000001', null, 'Roster Six (reject flow)', 'ACTIVE', '2025-01-01', 'CLMA-0015', null),
  ('10200000-0000-0000-0000-000000000114', '10200000-0000-0000-0000-000000000001', null, 'Roster Seven (cancel flow)', 'ACTIVE', '2025-01-01', 'CLMA-0016', null);

insert into public.group_membership_roles (group_membership_id, role_id) select '10200000-0000-0000-0000-000000000101', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select '10200000-0000-0000-0000-000000000102', id from public.roles where code = 'TREASURER';
insert into public.group_membership_roles (group_membership_id, role_id) select '10200000-0000-0000-0000-000000000103', id from public.roles where code = 'MEMBER' on conflict (group_membership_id, role_id) do nothing;
insert into public.group_membership_roles (group_membership_id, role_id) select '10200000-0000-0000-0000-000000000104', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select '10200000-0000-0000-0000-000000000109', id from public.roles where code = 'MEMBER' on conflict (group_membership_id, role_id) do nothing;
insert into public.group_membership_roles (group_membership_id, role_id) select '10200000-0000-0000-0000-000000000110', id from public.roles where code = 'MEMBER' on conflict (group_membership_id, role_id) do nothing;

set local role authenticated;

-- =====================================================================
-- 09G-B1-C security closeout: prove the transaction marker is
-- genuinely REQUIRED (not merely present) for the one authorized
-- user_id transition, and that an independent, unrelated layer of
-- defense (the table's own GRANT privileges) blocks a direct client
-- UPDATE regardless of the trigger/marker entirely. Placed here,
-- before ANY RPC call has run in this file, so the marker is
-- provably absent (never yet touched in this transaction).
-- =====================================================================
reset role;

-- The marker alone, if it could somehow be set, is not sufficient
-- either — the trigger requires marker=true together with
-- old.user_id IS NULL, so with the marker genuinely absent, even a
-- would-be-eligible NULL -> non-null change on a still-unlinked
-- roster row is rejected.
select throws_ok(
  $$ update public.group_memberships set user_id = '10200000-0000-0000-0000-000000000021'::uuid where id = '10200000-0000-0000-0000-000000000113'::uuid $$,
  '42501',
  'group_memberships.user_id cannot be changed by update',
  'closeout-a: a NULL -> non-null change is rejected when the approval marker is genuinely absent (the marker is required, not merely sufficient)'
);

-- Independent defense layer: `authenticated` holds no UPDATE grant on
-- group_memberships at all — a direct client UPDATE is denied at the
-- GRANT level before the trigger is ever reached, regardless of the
-- marker or of old.user_id.
set local role authenticated;
set local request.jwt.claim.sub to '10200000-0000-0000-0000-000000000011';
select throws_ok(
  $$ update public.group_memberships set user_id = '10200000-0000-0000-0000-000000000021'::uuid where id = '10200000-0000-0000-0000-000000000113'::uuid $$,
  '42501',
  null,
  'closeout-b: authenticated has no UPDATE grant on group_memberships at all — denied independently of the trigger/marker'
);
reset request.jwt.claim.sub;
reset role;

-- =====================================================================
-- 12/13: anon/unauthenticated cannot request.
-- =====================================================================
reset role;
set local role anon;
select throws_ok(
  $$ select public.rpc_request_membership_claim('10200000-0000-0000-0000-000000000001'::uuid, '10200000-0000-0000-0000-000000000105'::uuid) $$,
  '42501',
  null,
  '12: anon cannot invoke rpc_request_membership_claim'
);

reset role;
set local role authenticated;
select throws_ok(
  $$ select public.rpc_request_membership_claim('10200000-0000-0000-0000-000000000001'::uuid, '10200000-0000-0000-0000-000000000105'::uuid) $$,
  '28000',
  'Not authenticated',
  '13: an authenticated-role call with no resolved auth.uid() cannot request'
);

-- =====================================================================
-- As Claimant One — the main happy-path claimant.
-- =====================================================================
set local request.jwt.claim.sub to '10200000-0000-0000-0000-000000000021';

-- 4: already-linked membership cannot be claimed.
select throws_ok(
  $$ select public.rpc_request_membership_claim('10200000-0000-0000-0000-000000000001'::uuid, '10200000-0000-0000-0000-000000000109'::uuid) $$,
  'P0001',
  'MEMBERSHIP_ALREADY_LINKED',
  '4: an already-linked membership cannot be claimed'
);

-- 5: inactive (SUSPENDED) membership cannot be claimed.
select throws_ok(
  $$ select public.rpc_request_membership_claim('10200000-0000-0000-0000-000000000001'::uuid, '10200000-0000-0000-0000-000000000107'::uuid) $$,
  'P0001',
  'MEMBERSHIP_NOT_ACTIVE',
  '5: a SUSPENDED membership cannot be claimed'
);

-- 6: inactive (SUSPENDED) group cannot be claimed.
select throws_ok(
  $$ select public.rpc_request_membership_claim('10200000-0000-0000-0000-000000000003'::uuid, '10200000-0000-0000-0000-000000000108'::uuid) $$,
  'P0001',
  'GROUP_NOT_ACTIVE',
  '6: a membership in a SUSPENDED group cannot be claimed'
);

-- 1: authenticated unlinked user can request an eligible membership.
create temporary table t_claim1 as
select public.rpc_request_membership_claim('10200000-0000-0000-0000-000000000001'::uuid, '10200000-0000-0000-0000-000000000105'::uuid) as result;
select (result->>'claim_id')::uuid as claim1_id from t_claim1 \gset

select is(
  (select result->>'status' from t_claim1),
  'PENDING',
  '1: an authenticated unlinked user can request an eligible roster membership'
);

reset role;

-- 2/3: claimant_user_id is derived from auth.uid, never spoofable
-- (the RPC signature has no claimant parameter at all — confirmed by
-- checking the actual inserted row belongs to the real caller).
select is(
  (select claimant_user_id from public.membership_claim_requests where id = :'claim1_id'::uuid),
  '10200000-0000-0000-0000-000000000021'::uuid,
  '2/3: the inserted claim''s claimant_user_id is exactly the real caller''s auth.uid(), never client-suppliable'
);

set local role authenticated;
set local request.jwt.claim.sub to '10200000-0000-0000-0000-000000000021';

-- 7/8: duplicate retry is idempotent — no duplicate row is created.
create temporary table t_claim1_retry as
select public.rpc_request_membership_claim('10200000-0000-0000-0000-000000000001'::uuid, '10200000-0000-0000-0000-000000000105'::uuid) as result;

select is(
  (select (result->>'claim_id')::uuid from t_claim1_retry),
  :'claim1_id'::uuid,
  '7: retrying the same request returns the SAME existing claim id (idempotent)'
);
select is(
  (select (result->>'already_requested')::boolean from t_claim1_retry),
  true,
  '7b: the retry response is explicitly marked already_requested'
);

reset role;
select is(
  (select count(*)::integer from public.membership_claim_requests where membership_id = '10200000-0000-0000-0000-000000000105'::uuid),
  1,
  '8: exactly one claim row exists for the membership despite two request calls'
);
set local role authenticated;

-- =====================================================================
-- As Existing Member (already has an ACTIVE membership in group A).
-- =====================================================================
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to '10200000-0000-0000-0000-000000000023';

-- 9: a claimant already linked/ACTIVE in the same group cannot claim
-- another active membership there.
select throws_ok(
  $$ select public.rpc_request_membership_claim('10200000-0000-0000-0000-000000000001'::uuid, '10200000-0000-0000-0000-000000000106'::uuid) $$,
  'P0001',
  'CLAIMANT_ALREADY_HAS_ACTIVE_MEMBERSHIP_IN_GROUP',
  '9: a claimant already ACTIVE in the group cannot claim another membership there'
);

reset role;

-- 10: the same user may already own memberships in different groups
-- (Existing Member has real linked memberships in both A and B) — and
-- B1-A's current_membership_id resolves each correctly.
set local role authenticated;
set local request.jwt.claim.sub to '10200000-0000-0000-0000-000000000023';
select is(
  public.current_membership_id('10200000-0000-0000-0000-000000000001'::uuid),
  '10200000-0000-0000-0000-000000000109'::uuid,
  '10a: Existing Member''s own membership resolves correctly in group A'
);
select is(
  public.current_membership_id('10200000-0000-0000-0000-000000000002'::uuid),
  '10200000-0000-0000-0000-000000000110'::uuid,
  '10b: the SAME user''s DIFFERENT membership resolves correctly in group B'
);

-- =====================================================================
-- 11/42: another user cannot read Claimant One's private claim.
-- =====================================================================
set local request.jwt.claim.sub to '10200000-0000-0000-0000-000000000022';
select is(
  (select public.rpc_list_my_membership_claims()),
  '[]'::jsonb,
  '11/42: another user (Claimant Two) sees an empty list — never Claimant One''s private claim'
);

-- =====================================================================
-- Approval — as Admin One (holds member.claim.approve).
-- =====================================================================
set local request.jwt.claim.sub to '10200000-0000-0000-0000-000000000011';

-- 14/15: an authorized officer can approve; it links the EXACT
-- membership to the EXACT claimant.
create temporary table t_approve1 as
select public.rpc_approve_membership_claim('10200000-0000-0000-0000-000000000001'::uuid, :'claim1_id'::uuid) as result;

select is(
  (select result->>'status' from t_approve1),
  'APPROVED',
  '14: an authorized officer (ADMIN) can approve a pending claim'
);

reset role;
select is(
  (select user_id from public.group_memberships where id = '10200000-0000-0000-0000-000000000105'::uuid),
  '10200000-0000-0000-0000-000000000021'::uuid,
  '15: approval links exactly this membership to exactly this claimant'
);

-- 18: approval is atomic — the resolved claim's own fields are fully
-- consistent (status/resolved_at/resolved_by all set together; a
-- partial failure anywhere in the function body would have rolled
-- back the entire single-statement transaction, per ordinary
-- PL/pgSQL function semantics, leaving no row at all in this state).
select ok(
  (select status = 'APPROVED' and resolved_at is not null and resolved_by is not null
   from public.membership_claim_requests where id = :'claim1_id'::uuid),
  '18: the approved claim''s status/resolved_at/resolved_by are all set together (atomic)'
);

set local role authenticated;
set local request.jwt.claim.sub to '10200000-0000-0000-0000-000000000021';

-- 16/17: B1-A's ownership primitives immediately reflect the new link.
select is(
  public.current_membership_id('10200000-0000-0000-0000-000000000001'::uuid),
  '10200000-0000-0000-0000-000000000105'::uuid,
  '16: current_membership_id immediately resolves the newly-linked membership'
);
select is(
  public.is_own_membership('10200000-0000-0000-0000-000000000001'::uuid, '10200000-0000-0000-0000-000000000105'::uuid),
  true,
  '17: is_own_membership immediately becomes true for the newly-linked membership'
);

-- 21: an already-resolved (APPROVED) claim cannot be approved again.
set local request.jwt.claim.sub to '10200000-0000-0000-0000-000000000011';
select throws_ok(
  format($sql$ select public.rpc_approve_membership_claim('10200000-0000-0000-0000-000000000001'::uuid, %L::uuid) $sql$, :'claim1_id'),
  'P0001',
  'MEMBERSHIP_CLAIM_NOT_PENDING',
  '21: an already-APPROVED claim cannot be approved again'
);

-- 25: user_id immutability remains enforced OUTSIDE the approved
-- workflow. Explicitly reset the marker first — a prior successful
-- approval in THIS SAME wrapping pgTAP transaction would otherwise
-- leave it 'true' (set_config(..., true) scopes to the transaction,
-- and pgTAP wraps the whole file in one), which would make this
-- assertion pass for the wrong reason (non-null -> different is
-- rejected regardless of the marker — see 25b below) rather than the
-- intended reason (marker genuinely absent).
select set_config('umoja.membership_claim_approval', 'false', true);
reset role;
select throws_ok(
  $$ update public.group_memberships set user_id = '10200000-0000-0000-0000-000000000022'::uuid where id = '10200000-0000-0000-0000-000000000105'::uuid $$,
  '42501',
  'group_memberships.user_id cannot be changed by update',
  '25a: a direct UPDATE outside the approval workflow is still rejected by the immutability trigger (marker genuinely absent)'
);
-- Also: even inside the approval workflow, changing an ALREADY-linked
-- user_id remains impossible (the trigger only ever allows NULL ->
-- non-null, never non-null -> different).
select set_config('umoja.membership_claim_approval', 'true', true);
select throws_ok(
  $$ update public.group_memberships set user_id = '10200000-0000-0000-0000-000000000022'::uuid where id = '10200000-0000-0000-0000-000000000105'::uuid $$,
  '42501',
  'group_memberships.user_id cannot be changed by update',
  '25b: even with the approval marker set, a non-null -> different user_id change is still rejected'
);
-- 25c: the marker also cannot authorize UNLINKING (non-null -> NULL)
-- — the trigger's allow-branch requires old.user_id IS NULL, which is
-- false here regardless of the marker.
select throws_ok(
  $$ update public.group_memberships set user_id = null where id = '10200000-0000-0000-0000-000000000105'::uuid $$,
  '42501',
  'group_memberships.user_id cannot be changed by update',
  '25c: even with the approval marker set, a non-null -> NULL (unlink) change is still rejected'
);
select set_config('umoja.membership_claim_approval', 'false', true);

set local role authenticated;

-- =====================================================================
-- 19/20: unauthorized officer boundaries on approval.
-- =====================================================================

-- Build a second pending claim (Roster Two, by Claimant Two) to use
-- as the target of the negative approval tests below.
set local request.jwt.claim.sub to '10200000-0000-0000-0000-000000000022';
create temporary table t_claim2 as
select public.rpc_request_membership_claim('10200000-0000-0000-0000-000000000001'::uuid, '10200000-0000-0000-0000-000000000106'::uuid) as result;
select (result->>'claim_id')::uuid as claim2_id from t_claim2 \gset

-- 19: a plain MEMBER cannot approve.
set local request.jwt.claim.sub to '10200000-0000-0000-0000-000000000013';
select throws_ok(
  format($sql$ select public.rpc_approve_membership_claim('10200000-0000-0000-0000-000000000001'::uuid, %L::uuid) $sql$, :'claim2_id'),
  '42501',
  'Not authorized to approve membership claims in this group',
  '19: a plain MEMBER cannot approve a pending claim'
);

-- 20: an officer from a DIFFERENT group cannot approve.
set local request.jwt.claim.sub to '10200000-0000-0000-0000-000000000014';
select throws_ok(
  format($sql$ select public.rpc_approve_membership_claim('10200000-0000-0000-0000-000000000001'::uuid, %L::uuid) $sql$, :'claim2_id'),
  '42501',
  'Not authorized to approve membership claims in this group',
  '20: an ADMIN of a different group cannot approve a claim in this group'
);

-- =====================================================================
-- 22/23: membership linked (by any means) after request but before
-- approval causes approval to fail, never overwriting the existing
-- link.
-- =====================================================================
reset role;
select set_config('umoja.membership_claim_approval', 'true', true);
update public.group_memberships set user_id = '10200000-0000-0000-0000-000000000025'::uuid where id = '10200000-0000-0000-0000-000000000106'::uuid;
select set_config('umoja.membership_claim_approval', 'false', true);
set local role authenticated;
set local request.jwt.claim.sub to '10200000-0000-0000-0000-000000000011';

select throws_ok(
  format($sql$ select public.rpc_approve_membership_claim('10200000-0000-0000-0000-000000000001'::uuid, %L::uuid) $sql$, :'claim2_id'),
  'P0001',
  'MEMBERSHIP_ALREADY_LINKED',
  '22: approval fails when the membership became linked (by any means) after the request was created'
);

reset role;
select is(
  (select user_id from public.group_memberships where id = '10200000-0000-0000-0000-000000000106'::uuid),
  '10200000-0000-0000-0000-000000000025'::uuid,
  '23: the pre-existing link is never overwritten by the failed approval attempt'
);
set local role authenticated;

-- =====================================================================
-- 24: same-group duplicate active linkage is blocked at APPROVAL
-- time, even when it was NOT yet true at request time.
-- =====================================================================

-- Claimant Y requests Roster Five first (while still unlinked
-- anywhere in group A) ...
set local request.jwt.claim.sub to '10200000-0000-0000-0000-000000000024';
create temporary table t_claim_y1 as
select public.rpc_request_membership_claim('10200000-0000-0000-0000-000000000001'::uuid, '10200000-0000-0000-0000-000000000112'::uuid) as result;
select (result->>'claim_id')::uuid as claim_y1_id from t_claim_y1 \gset

-- ... then separately requests and gets APPROVED for Roster Four,
-- which now makes them ACTIVE in group A.
create temporary table t_claim_y2 as
select public.rpc_request_membership_claim('10200000-0000-0000-0000-000000000001'::uuid, '10200000-0000-0000-0000-000000000111'::uuid) as result;
select (result->>'claim_id')::uuid as claim_y2_id from t_claim_y2 \gset

set local request.jwt.claim.sub to '10200000-0000-0000-0000-000000000011';
select public.rpc_approve_membership_claim('10200000-0000-0000-0000-000000000001'::uuid, :'claim_y2_id'::uuid);

-- Approving the ORIGINAL (still-pending) claim on Roster Five must
-- now fail, since Claimant Y already holds an ACTIVE membership in
-- group A.
select throws_ok(
  format($sql$ select public.rpc_approve_membership_claim('10200000-0000-0000-0000-000000000001'::uuid, %L::uuid) $sql$, :'claim_y1_id'),
  'P0001',
  'CLAIMANT_ALREADY_HAS_ACTIVE_MEMBERSHIP_IN_GROUP',
  '24: approving a second membership for a claimant who is now already ACTIVE in the same group is blocked'
);

-- =====================================================================
-- Rejection.
-- =====================================================================

set local request.jwt.claim.sub to '10200000-0000-0000-0000-000000000027';
create temporary table t_claim3 as
select public.rpc_request_membership_claim('10200000-0000-0000-0000-000000000001'::uuid, '10200000-0000-0000-0000-000000000113'::uuid) as result;
select (result->>'claim_id')::uuid as claim3_id from t_claim3 \gset

-- 30: a plain MEMBER cannot reject.
set local request.jwt.claim.sub to '10200000-0000-0000-0000-000000000013';
select throws_ok(
  format($sql$ select public.rpc_reject_membership_claim('10200000-0000-0000-0000-000000000001'::uuid, %L::uuid, 'test') $sql$, :'claim3_id'),
  '42501',
  'Not authorized to approve membership claims in this group',
  '30: a plain MEMBER cannot reject a pending claim'
);

-- 31: an officer from a different group cannot reject.
set local request.jwt.claim.sub to '10200000-0000-0000-0000-000000000014';
select throws_ok(
  format($sql$ select public.rpc_reject_membership_claim('10200000-0000-0000-0000-000000000001'::uuid, %L::uuid, 'test') $sql$, :'claim3_id'),
  '42501',
  'Not authorized to approve membership claims in this group',
  '31: an ADMIN of a different group cannot reject a claim in this group'
);

set local request.jwt.claim.sub to '10200000-0000-0000-0000-000000000011';

-- 27: rejection reason is required.
select throws_ok(
  format($sql$ select public.rpc_reject_membership_claim('10200000-0000-0000-0000-000000000001'::uuid, %L::uuid, '') $sql$, :'claim3_id'),
  '22023',
  'MEMBERSHIP_CLAIM_REJECTION_REASON_REQUIRED',
  '27: rejecting without a reason is rejected'
);

-- 26: an authorized officer can reject with a reason.
create temporary table t_reject3 as
select public.rpc_reject_membership_claim('10200000-0000-0000-0000-000000000001'::uuid, :'claim3_id'::uuid, 'Could not verify identity') as result;
select is(
  (select result->>'status' from t_reject3),
  'REJECTED',
  '26: an authorized officer can reject a pending claim with a reason'
);

reset role;
-- 28: rejection never links the membership.
select is(
  (select user_id from public.group_memberships where id = '10200000-0000-0000-0000-000000000113'::uuid),
  null::uuid,
  '28: a rejected claim never links the membership'
);
set local role authenticated;

-- 29: a rejected claim cannot later be approved.
select throws_ok(
  format($sql$ select public.rpc_approve_membership_claim('10200000-0000-0000-0000-000000000001'::uuid, %L::uuid) $sql$, :'claim3_id'),
  'P0001',
  'MEMBERSHIP_CLAIM_NOT_PENDING',
  '29: a rejected claim cannot later be approved'
);

-- =====================================================================
-- Cancellation.
-- =====================================================================

set local request.jwt.claim.sub to '10200000-0000-0000-0000-000000000026';
create temporary table t_claim4 as
select public.rpc_request_membership_claim('10200000-0000-0000-0000-000000000001'::uuid, '10200000-0000-0000-0000-000000000114'::uuid) as result;
select (result->>'claim_id')::uuid as claim4_id from t_claim4 \gset

-- 33: another user cannot cancel someone else's pending claim.
set local request.jwt.claim.sub to '10200000-0000-0000-0000-000000000022';
select throws_ok(
  format($sql$ select public.rpc_cancel_membership_claim(%L::uuid) $sql$, :'claim4_id'),
  '22023',
  'Membership claim not found',
  '33: another user cannot cancel someone else''s pending claim'
);

-- 32: the claimant can cancel their own pending claim.
set local request.jwt.claim.sub to '10200000-0000-0000-0000-000000000026';
create temporary table t_cancel4 as
select public.rpc_cancel_membership_claim(:'claim4_id'::uuid) as result;
select is(
  (select result->>'status' from t_cancel4),
  'CANCELLED',
  '32: the claimant can cancel their own pending claim'
);

-- 34: a resolved (already-cancelled) claim cannot be cancelled again.
select throws_ok(
  format($sql$ select public.rpc_cancel_membership_claim(%L::uuid) $sql$, :'claim4_id'),
  'P0001',
  'MEMBERSHIP_CLAIM_NOT_PENDING',
  '34: an already-resolved claim cannot be cancelled again'
);

-- 34b: a resolved (APPROVED) claim cannot be cancelled by the
-- claimant either.
set local request.jwt.claim.sub to '10200000-0000-0000-0000-000000000021';
select throws_ok(
  format($sql$ select public.rpc_cancel_membership_claim(%L::uuid) $sql$, :'claim1_id'),
  'P0001',
  'MEMBERSHIP_CLAIM_NOT_PENDING',
  '34b: an already-APPROVED claim cannot be cancelled'
);

-- =====================================================================
-- Officer queue read contract.
-- =====================================================================

-- 41: officer read is permission-gated.
set local request.jwt.claim.sub to '10200000-0000-0000-0000-000000000013';
select throws_ok(
  $$ select public.rpc_list_membership_claims('10200000-0000-0000-0000-000000000001'::uuid, null) $$,
  '42501',
  'Not authorized to view membership claims in this group',
  '41: a plain MEMBER cannot read the officer claim queue'
);

set local request.jwt.claim.sub to '10200000-0000-0000-0000-000000000011';
create temporary table t_officer_queue as
select public.rpc_list_membership_claims('10200000-0000-0000-0000-000000000001'::uuid, 'REJECTED') as result;

select ok(
  (select jsonb_array_length(result->'items') from t_officer_queue) >= 1,
  'officer queue: the rejected claim (Roster Six) is visible when filtering by REJECTED'
);

-- 43: no auth.users-sensitive field is exposed by the officer queue —
-- only membership fields and the claimant's profile full_name/phone.
select ok(
  not exists (
    select 1 from t_officer_queue, jsonb_array_elements(result->'items') e
    where e ? 'claimant_user_id' or e ? 'claimant_email'
  ),
  '43: the officer queue never exposes a raw claimant_user_id or email field'
);

-- =====================================================================
-- Security: table lockdown.
-- =====================================================================
reset role;

-- 35: RLS is enabled on the claim table.
select ok(
  (select relrowsecurity from pg_class where oid = 'public.membership_claim_requests'::regclass),
  '35: row level security is enabled on membership_claim_requests'
);

-- 36/37/38: no direct client mutation grants.
select is(
  (select count(*)::integer from information_schema.role_table_grants
   where table_schema = 'public' and table_name = 'membership_claim_requests'
     and grantee in ('anon', 'authenticated') and privilege_type = 'INSERT'),
  0,
  '36: no INSERT grant to anon/authenticated exists on membership_claim_requests'
);
select is(
  (select count(*)::integer from information_schema.role_table_grants
   where table_schema = 'public' and table_name = 'membership_claim_requests'
     and grantee in ('anon', 'authenticated') and privilege_type = 'UPDATE'),
  0,
  '37: no UPDATE grant to anon/authenticated exists on membership_claim_requests'
);
select is(
  (select count(*)::integer from information_schema.role_table_grants
   where table_schema = 'public' and table_name = 'membership_claim_requests'
     and grantee in ('anon', 'authenticated') and privilege_type = 'DELETE'),
  0,
  '38: no DELETE grant to anon/authenticated exists on membership_claim_requests'
);

-- 39: anon cannot execute any of the mutation RPCs.
set local role anon;
select throws_ok(
  $$ select public.rpc_approve_membership_claim(gen_random_uuid(), gen_random_uuid()) $$,
  '42501', null, '39a: anon cannot invoke rpc_approve_membership_claim'
);
select throws_ok(
  $$ select public.rpc_reject_membership_claim(gen_random_uuid(), gen_random_uuid(), 'x') $$,
  '42501', null, '39b: anon cannot invoke rpc_reject_membership_claim'
);
select throws_ok(
  $$ select public.rpc_cancel_membership_claim(gen_random_uuid()) $$,
  '42501', null, '39c: anon cannot invoke rpc_cancel_membership_claim'
);
select throws_ok(
  $$ select public.rpc_list_membership_claims(gen_random_uuid(), null) $$,
  '42501', null, '39d: anon cannot invoke rpc_list_membership_claims'
);

reset role;

-- 45: has_group_permission's own behavior is unchanged by this
-- migration (spot check, complementing B1-A's own 19a/19b).
set local role authenticated;
set local request.jwt.claim.sub to '10200000-0000-0000-0000-000000000011';
select is(
  public.has_group_permission('10200000-0000-0000-0000-000000000001'::uuid, 'member.view'),
  true,
  '45: has_group_permission still correctly grants member.view to an ADMIN'
);

reset role;

-- member.claim.approve role-grant matrix.
select is(
  (select count(*)::integer from public.role_permissions rp
   join public.roles r on r.id = rp.role_id
   join public.permissions p on p.id = rp.permission_id
   where p.code = 'member.claim.approve' and r.code in ('ADMIN', 'CHAIRPERSON')),
  2,
  'member.claim.approve is granted to exactly ADMIN and CHAIRPERSON'
);
select is(
  (select count(*)::integer from public.role_permissions rp
   join public.roles r on r.id = rp.role_id
   join public.permissions p on p.id = rp.permission_id
   where p.code = 'member.claim.approve' and r.code in ('TREASURER', 'SECRETARY', 'MEMBER')),
  0,
  'member.claim.approve is granted to none of TREASURER/SECRETARY/MEMBER'
);

select * from finish();
rollback;
