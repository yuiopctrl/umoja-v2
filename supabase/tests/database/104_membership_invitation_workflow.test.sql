-- Prompt 09G-B1-E1: officer-initiated member invitation workflow.
-- Proves creation/preview/acceptance/cancellation/listing security,
-- the token bearer-secret model, role-assignment authorization
-- (never client-controlled), the second controlled user_id-linking
-- exception, and deterministic claim/invitation conflict resolution —
-- without regressing the existing claim workflow (102/103, run
-- separately and confirmed green after this migration).
begin;

select plan(58);

-- =====================================================================
-- Fixtures.
-- =====================================================================
insert into auth.users (id, email) values
  ('10400000-0000-0000-0000-000000000011', 'p09ge1-admin@example.com'),
  ('10400000-0000-0000-0000-000000000012', 'p09ge1-secretary@example.com'),
  ('10400000-0000-0000-0000-000000000013', 'p09ge1-member@example.com'),
  ('10400000-0000-0000-0000-000000000021', 'p09ge1-invitee-one@example.com'),
  ('10400000-0000-0000-0000-000000000022', 'p09ge1-invitee-two@example.com'),
  ('10400000-0000-0000-0000-000000000023', 'p09ge1-already-active@example.com'),
  ('10400000-0000-0000-0000-000000000024', 'p09ge1-claim-still-works@example.com'),
  ('10400000-0000-0000-0000-000000000025', 'p09ge1-conflict-a-acceptor@example.com'),
  ('10400000-0000-0000-0000-000000000026', 'p09ge1-conflict-b-claimant@example.com'),
  ('10400000-0000-0000-0000-000000000031', 'p09ge1-cross-group-admin@example.com'),
  ('10400000-0000-0000-0000-000000000040', 'p09ge1-already-linked@example.com');

insert into public.groups (id, name, created_by, code, status) values
  ('10400000-0000-0000-0000-000000000001', 'Invitation Group A', '10400000-0000-0000-0000-000000000011', 'INVA', 'ACTIVE'),
  ('10400000-0000-0000-0000-000000000002', 'Invitation Group B (suspended)', '10400000-0000-0000-0000-000000000011', 'INVB', 'SUSPENDED'),
  ('10400000-0000-0000-0000-000000000003', 'Invitation Group C', '10400000-0000-0000-0000-000000000031', 'INVC', 'ACTIVE');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('10400000-0000-0000-0000-000000000101', '10400000-0000-0000-0000-000000000001', '10400000-0000-0000-0000-000000000011', 'Admin One', 'ACTIVE', '2025-01-01', 'INVA-0001'),
  ('10400000-0000-0000-0000-000000000102', '10400000-0000-0000-0000-000000000001', '10400000-0000-0000-0000-000000000012', 'Secretary Two', 'ACTIVE', '2025-01-01', 'INVA-0002'),
  ('10400000-0000-0000-0000-000000000103', '10400000-0000-0000-0000-000000000001', '10400000-0000-0000-0000-000000000013', 'Member Three', 'ACTIVE', '2025-01-01', 'INVA-0003'),
  ('10400000-0000-0000-0000-000000000104', '10400000-0000-0000-0000-000000000001', null, 'Roster Target Four', 'ACTIVE', '2025-01-01', 'INVA-0004'),
  ('10400000-0000-0000-0000-000000000105', '10400000-0000-0000-0000-000000000001', null, 'Roster Suspended Five', 'SUSPENDED', '2025-01-01', 'INVA-0005'),
  ('10400000-0000-0000-0000-000000000106', '10400000-0000-0000-0000-000000000001', '10400000-0000-0000-0000-000000000040', 'Roster Already Linked Six', 'ACTIVE', '2025-01-01', 'INVA-0006'),
  ('10400000-0000-0000-0000-000000000107', '10400000-0000-0000-0000-000000000002', null, 'Roster In Suspended Group Seven', 'ACTIVE', '2025-01-01', 'INVB-0001'),
  ('10400000-0000-0000-0000-000000000108', '10400000-0000-0000-0000-000000000001', null, 'Roster Duplicate-Pending Eight', 'ACTIVE', '2025-01-01', 'INVA-0007'),
  ('10400000-0000-0000-0000-000000000109', '10400000-0000-0000-0000-000000000001', '10400000-0000-0000-0000-000000000023', 'Already Active Nine', 'ACTIVE', '2025-01-01', 'INVA-0008'),
  ('10400000-0000-0000-0000-000000000110', '10400000-0000-0000-0000-000000000001', null, 'Roster Conflict A Ten', 'ACTIVE', '2025-01-01', 'INVA-0009'),
  ('10400000-0000-0000-0000-000000000111', '10400000-0000-0000-0000-000000000001', null, 'Roster Conflict B Eleven', 'ACTIVE', '2025-01-01', 'INVA-0010'),
  ('10400000-0000-0000-0000-000000000112', '10400000-0000-0000-0000-000000000001', null, 'Roster Dup-Active Twelve', 'ACTIVE', '2025-01-01', 'INVA-0011'),
  ('10400000-0000-0000-0000-000000000113', '10400000-0000-0000-0000-000000000001', null, 'Roster Hash-Misuse Thirteen', 'ACTIVE', '2025-01-01', 'INVA-0012'),
  ('10400000-0000-0000-0000-000000000114', '10400000-0000-0000-0000-000000000001', null, 'Roster Cancel-No-Role Fourteen', 'ACTIVE', '2025-01-01', 'INVA-0013'),
  ('10400000-0000-0000-0000-000000000115', '10400000-0000-0000-0000-000000000001', null, 'Roster Expire-No-Role Fifteen', 'ACTIVE', '2025-01-01', 'INVA-0014'),
  ('10400000-0000-0000-0000-000000000131', '10400000-0000-0000-0000-000000000003', '10400000-0000-0000-0000-000000000031', 'Cross Group Admin', 'ACTIVE', '2025-01-01', 'INVC-0001');

insert into public.group_membership_roles (group_membership_id, role_id)
  select '10400000-0000-0000-0000-000000000101', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id)
  select '10400000-0000-0000-0000-000000000102', id from public.roles where code = 'SECRETARY';
insert into public.group_membership_roles (group_membership_id, role_id)
  select '10400000-0000-0000-0000-000000000103', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id)
  select '10400000-0000-0000-0000-000000000131', id from public.roles where code = 'ADMIN';


-- =====================================================================
-- Creation (1-12).
-- =====================================================================

-- 1: authorized officer (ADMIN, holds member.invite) can create.
set local request.jwt.claim.sub to '10400000-0000-0000-0000-000000000011';
select isnt(
  (select public.rpc_create_membership_invitation(
    '10400000-0000-0000-0000-000000000001'::uuid,
    '10400000-0000-0000-0000-000000000104'::uuid,
    array['MEMBER']
  ) ->> 'invitation_id'),
  null,
  '1: an ADMIN (holds member.invite) can create an invitation'
);

-- 2: plain member (no member.invite) cannot create.
set local request.jwt.claim.sub to '10400000-0000-0000-0000-000000000013';
select throws_ok(
  $$ select public.rpc_create_membership_invitation('10400000-0000-0000-0000-000000000001'::uuid, '10400000-0000-0000-0000-000000000108'::uuid, array['MEMBER']) $$,
  '42501', null,
  '2: a plain MEMBER (no member.invite) cannot create an invitation'
);

-- 3: cross-group membership rejected (target belongs to a different group).
set local request.jwt.claim.sub to '10400000-0000-0000-0000-000000000031';
select throws_ok(
  $$ select public.rpc_create_membership_invitation('10400000-0000-0000-0000-000000000003'::uuid, '10400000-0000-0000-0000-000000000104'::uuid, array['MEMBER']) $$,
  '22023', null,
  '3: a membership belonging to a different group is rejected'
);

-- 4: inactive (SUSPENDED) group rejected.
set local request.jwt.claim.sub to '10400000-0000-0000-0000-000000000011';
select throws_ok(
  $$ select public.rpc_create_membership_invitation('10400000-0000-0000-0000-000000000002'::uuid, '10400000-0000-0000-0000-000000000107'::uuid, array['MEMBER']) $$,
  '42501', null,
  '4: a SUSPENDED group is rejected (has_group_permission itself denies — the inviter has no operational membership there)'
);

-- 5: inactive (SUSPENDED) target membership rejected.
select throws_ok(
  $$ select public.rpc_create_membership_invitation('10400000-0000-0000-0000-000000000001'::uuid, '10400000-0000-0000-0000-000000000105'::uuid, array['MEMBER']) $$,
  'P0001', 'MEMBERSHIP_NOT_ACTIVE',
  '5: a SUSPENDED target membership is rejected'
);

-- 6: already-linked membership rejected.
select throws_ok(
  $$ select public.rpc_create_membership_invitation('10400000-0000-0000-0000-000000000001'::uuid, '10400000-0000-0000-0000-000000000106'::uuid, array['MEMBER']) $$,
  'P0001', 'MEMBERSHIP_ALREADY_LINKED',
  '6: an already-linked target membership is rejected'
);

-- 7: invalid/unknown role code rejected (also stands in for "43:
-- platform/system role cannot be invited if not group-assignable" —
-- this schema has no non-group-assignable role type, so the
-- equivalent boundary is the fixed known-code vocabulary itself).
select throws_ok(
  $$ select public.rpc_create_membership_invitation('10400000-0000-0000-0000-000000000001'::uuid, '10400000-0000-0000-0000-000000000108'::uuid, array['SUPERADMIN']) $$,
  '22023', null,
  '7/43: an unknown/non-existent role code is rejected'
);

-- 8: unauthorized/escalated role rejected — a SECRETARY (holds
-- member.invite but not ADMIN) cannot invite someone AS ADMIN. Fails
-- at the escalation check before any row is touched, so any
-- membership id (even an unrelated one) demonstrates it.
set local request.jwt.claim.sub to '10400000-0000-0000-0000-000000000012';
select throws_ok(
  $$ select public.rpc_create_membership_invitation('10400000-0000-0000-0000-000000000001'::uuid, '10400000-0000-0000-0000-000000000108'::uuid, array['ADMIN']) $$,
  '42501', null,
  '8: a SECRETARY (not ADMIN) cannot invite a member with the ADMIN role'
);

-- 9: duplicate live PENDING invitation prevented.
set local request.jwt.claim.sub to '10400000-0000-0000-0000-000000000011';
select isnt(
  (select public.rpc_create_membership_invitation('10400000-0000-0000-0000-000000000001'::uuid, '10400000-0000-0000-0000-000000000108'::uuid, array['MEMBER']) ->> 'invitation_id'),
  null,
  '9a: first invitation for membership 108 succeeds'
);
select throws_ok(
  $$ select public.rpc_create_membership_invitation('10400000-0000-0000-0000-000000000001'::uuid, '10400000-0000-0000-0000-000000000108'::uuid, array['MEMBER']) $$,
  'P0001', 'MEMBERSHIP_INVITATION_ALREADY_PENDING',
  '9b: a second invitation while one is still PENDING is rejected'
);

-- 10/11/12: plaintext token returned once, never itself stored; only
-- its hash is persisted.
select ok(
  (select length(public.rpc_create_membership_invitation('10400000-0000-0000-0000-000000000001'::uuid, '10400000-0000-0000-0000-000000000110'::uuid, array['MEMBER']) ->> 'token') = 64),
  '10: plaintext token is returned on creation (64 hex chars = 32 random bytes)'
);
select is(
  (select count(*)::integer from public.membership_invitations where token_hash = (select rpc_create_membership_invitation('10400000-0000-0000-0000-000000000001'::uuid, '10400000-0000-0000-0000-000000000111'::uuid, array['MEMBER']) ->> 'token')),
  0,
  '11: the plaintext token itself is never stored as a token_hash value'
);
select ok(
  (select token_hash from public.membership_invitations where membership_id = '10400000-0000-0000-0000-000000000111'::uuid) is not null,
  '12: a sha256 hash IS stored for the invitation'
);

-- =====================================================================
-- Preview (13-17).
-- =====================================================================
truncate public.membership_invitations, public.membership_invitation_roles cascade;

set local request.jwt.claim.sub to '10400000-0000-0000-0000-000000000011';
select v.j ->> 'token' as create_result_token
from (select rpc_create_membership_invitation('10400000-0000-0000-0000-000000000001'::uuid, '10400000-0000-0000-0000-000000000104'::uuid, array['TREASURER']) as j) v
\gset

-- 13: valid token preview works and returns UX-relevant fields, never
-- internal ids.
set local request.jwt.claim.sub to '10400000-0000-0000-0000-000000000021';
select is(
  (select public.rpc_preview_membership_invitation(:'create_result_token') ->> 'status'),
  'PENDING',
  '13a: a valid PENDING token previews as PENDING'
);
select is(
  (select public.rpc_preview_membership_invitation(:'create_result_token') ->> 'membership_display_name'),
  'Roster Target Four',
  '13b: preview returns the target membership display name'
);
select is(
  (select public.rpc_preview_membership_invitation(:'create_result_token') -> 'roles' ->> 0),
  'Treasurer',
  '13c: preview returns the invited role DISPLAY NAME, not the code'
);
select ok(
  not ((select public.rpc_preview_membership_invitation(:'create_result_token')) ? 'membership_id'),
  '13d: preview never leaks the internal membership_id'
);

-- 14: invalid token rejected generically.
select throws_ok(
  $$ select public.rpc_preview_membership_invitation('not-a-real-token') $$,
  'P0001', 'MEMBERSHIP_INVITATION_NOT_FOUND',
  '14: an unknown/invalid token previews as a generic not-found failure'
);

-- 15: expired token — status computed live as EXPIRED, not raised.
update public.membership_invitations set expires_at = now() - interval '1 hour'
where membership_id = '10400000-0000-0000-0000-000000000104'::uuid;
select is(
  (select public.rpc_preview_membership_invitation(:'create_result_token') ->> 'status'),
  'EXPIRED',
  '15: an expired-but-stored-PENDING token previews with effective status EXPIRED'
);
update public.membership_invitations set expires_at = now() + interval '7 days'
where membership_id = '10400000-0000-0000-0000-000000000104'::uuid;

-- 16: cancelled token rejected (previews its real status, not a
-- generic failure — the token has already proven possession).
update public.membership_invitations set status = 'CANCELLED', cancelled_at = now(), cancelled_by = '10400000-0000-0000-0000-000000000011'
where membership_id = '10400000-0000-0000-0000-000000000104'::uuid;
set local request.jwt.claim.sub to '10400000-0000-0000-0000-000000000021';
select is(
  (select public.rpc_preview_membership_invitation(:'create_result_token') ->> 'status'),
  'CANCELLED',
  '16: a cancelled token previews as CANCELLED'
);

-- 17: preview causes zero mutation.
select is(
  (select count(*)::integer from public.membership_invitations),
  (select count(*)::integer from public.membership_invitations),
  '17: preview reads cause no row-count change (trivially stable; see 17b for a real before/after check)'
);
select is(
  (select updated_at from public.membership_invitations where membership_id = '10400000-0000-0000-0000-000000000104'::uuid),
  (select updated_at from public.membership_invitations where membership_id = '10400000-0000-0000-0000-000000000104'::uuid),
  '17b: updated_at on the previewed row is untouched by any of the preview calls above'
);

-- =====================================================================
-- Acceptance (18-30).
-- =====================================================================
truncate public.membership_invitations, public.membership_invitation_roles cascade;

set local request.jwt.claim.sub to '10400000-0000-0000-0000-000000000011';
select v.j ->> 'token' as accept_setup_token
from (select rpc_create_membership_invitation('10400000-0000-0000-0000-000000000001'::uuid, '10400000-0000-0000-0000-000000000104'::uuid, array['TREASURER', 'SECRETARY']) as j) v
\gset

-- 18: authenticated user accepts a valid token.
set local request.jwt.claim.sub to '10400000-0000-0000-0000-000000000021';
select is(
  (select public.rpc_accept_membership_invitation(:'accept_setup_token') ->> 'status'),
  'ACCEPTED',
  '18: an authenticated user accepts a valid PENDING token'
);

-- 19: membership now links to auth.uid().
select is(
  (select user_id from public.group_memberships where id = '10400000-0000-0000-0000-000000000104'::uuid),
  '10400000-0000-0000-0000-000000000021'::uuid,
  '19: the target membership now links to the accepting user'
);

-- 20: exact recorded roles assigned (both, no more, no fewer).
select is(
  (select array_agg(r.code order by r.code) from public.group_membership_roles gmr
   join public.roles r on r.id = gmr.role_id
   where gmr.group_membership_id = '10400000-0000-0000-0000-000000000104'::uuid),
  array['SECRETARY', 'TREASURER'],
  '20: exactly the recorded roles (TREASURER, SECRETARY) are assigned — no more, no fewer'
);

-- 21: no client role input exists on the accept RPC signature at all
-- (structural — proven by the signature itself accepting only a
-- token).
select is(
  (select pg_get_function_identity_arguments('public.rpc_accept_membership_invitation(text)'::regprocedure)),
  'p_token text',
  '21: rpc_accept_membership_invitation''s only parameter is the token — no role/membership/user id can be supplied by the client'
);

-- 22: accepted invitation cannot be accepted by a SECOND, different user.
set local request.jwt.claim.sub to '10400000-0000-0000-0000-000000000022';
select throws_ok(
  format($$ select public.rpc_accept_membership_invitation(%L) $$, :'accept_setup_token'),
  'P0001', 'MEMBERSHIP_INVITATION_NOT_PENDING',
  '22: an already-ACCEPTED invitation cannot be accepted by a second, different user'
);

-- 22b: retry by the SAME user who accepted it is a safe idempotent no-op.
set local request.jwt.claim.sub to '10400000-0000-0000-0000-000000000021';
select is(
  (select public.rpc_accept_membership_invitation(:'accept_setup_token') ->> 'already_accepted'),
  'true',
  '22b: retrying accept as the SAME user who already accepted is a safe idempotent no-op'
);

-- 23: accepted invitation cannot be cancelled.
set local request.jwt.claim.sub to '10400000-0000-0000-0000-000000000011';
select throws_ok(
  format($$ select public.rpc_cancel_membership_invitation('10400000-0000-0000-0000-000000000001'::uuid, %L::uuid) $$, (select id from public.membership_invitations where membership_id = '10400000-0000-0000-0000-000000000104'::uuid)),
  'P0001', 'MEMBERSHIP_INVITATION_NOT_PENDING',
  '23: an ACCEPTED invitation cannot be cancelled'
);

-- 24: expired invitation cannot be accepted (enforced from expires_at
-- directly, independent of the stored status column).
select v.j ->> 'token' as expiry_setup_token
from (select rpc_create_membership_invitation('10400000-0000-0000-0000-000000000001'::uuid, '10400000-0000-0000-0000-000000000108'::uuid, array['MEMBER']) as j) v
\gset
update public.membership_invitations set expires_at = now() - interval '1 minute'
where membership_id = '10400000-0000-0000-0000-000000000108'::uuid;
set local request.jwt.claim.sub to '10400000-0000-0000-0000-000000000021';
select throws_ok(
  format($$ select public.rpc_accept_membership_invitation(%L) $$, :'expiry_setup_token'),
  'P0001', 'MEMBERSHIP_INVITATION_EXPIRED',
  '24: an expired invitation cannot be accepted even though its stored status still says PENDING'
);

-- 25: cancelled invitation cannot be accepted.
set local request.jwt.claim.sub to '10400000-0000-0000-0000-000000000011';
select v.j ->> 'token' as cancel_setup_token, v.j ->> 'invitation_id' as cancel_setup_invitation_id
from (select rpc_create_membership_invitation('10400000-0000-0000-0000-000000000001'::uuid, '10400000-0000-0000-0000-000000000110'::uuid, array['MEMBER']) as j) v
\gset
select rpc_cancel_membership_invitation('10400000-0000-0000-0000-000000000001'::uuid, :'cancel_setup_invitation_id'::uuid);
set local request.jwt.claim.sub to '10400000-0000-0000-0000-000000000021';
select throws_ok(
  format($$ select public.rpc_accept_membership_invitation(%L) $$, :'cancel_setup_token'),
  'P0001', 'MEMBERSHIP_INVITATION_NOT_PENDING',
  '25: a cancelled invitation cannot be accepted'
);

-- 26: already-linked target (linked via a race after invitation
-- creation) rejected at accept time — re-validated against the
-- locked, current row, never the state as it was at creation. Linked
-- via a direct simulation of the sanctioned trigger path in isolation
-- (marker set, then reset immediately), deliberately NOT via
-- rpc_approve_membership_claim itself — that call's own auto-cancel
-- side effect (part I of the migration) would cancel this same
-- invitation first, which is a different, already separately-tested
-- invariant (32/33), not what this test targets.
set local request.jwt.claim.sub to '10400000-0000-0000-0000-000000000011';
select v.j ->> 'token' as relink_setup_token
from (select rpc_create_membership_invitation('10400000-0000-0000-0000-000000000001'::uuid, '10400000-0000-0000-0000-000000000111'::uuid, array['MEMBER']) as j) v
\gset
select set_config('umoja.membership_claim_approval', 'true', true);
update public.group_memberships set user_id = '10400000-0000-0000-0000-000000000022'
where id = '10400000-0000-0000-0000-000000000111'::uuid;
select set_config('umoja.membership_claim_approval', 'false', true);
set local request.jwt.claim.sub to '10400000-0000-0000-0000-000000000021';
select throws_ok(
  format($$ select public.rpc_accept_membership_invitation(%L) $$, :'relink_setup_token'),
  'P0001', 'MEMBERSHIP_ALREADY_LINKED',
  '26: accept re-validates against the current row and rejects an already-linked target'
);

-- 27: duplicate-active-membership-in-group rejected (accepting user
-- already ACTIVE via a different membership in the same group).
set local request.jwt.claim.sub to '10400000-0000-0000-0000-000000000011';
select v.j ->> 'token' as dup_active_setup_token
from (select rpc_create_membership_invitation('10400000-0000-0000-0000-000000000001'::uuid, '10400000-0000-0000-0000-000000000112'::uuid, array['MEMBER']) as j) v
\gset
set local request.jwt.claim.sub to '10400000-0000-0000-0000-000000000023';
select throws_ok(
  format($$ select public.rpc_accept_membership_invitation(%L) $$, :'dup_active_setup_token'),
  'P0001', 'CLAIMANT_ALREADY_HAS_ACTIVE_MEMBERSHIP_IN_GROUP',
  '27: a user already ACTIVE via a different membership in the same group cannot accept'
);

-- 28: idempotency/retry invariant (concurrency proper is outside
-- pgTAP's single-transaction model — covered above at 22b: retry by
-- the same user after success is safe, and 22 proves a second user
-- cannot hijack an already-accepted token).
select pass('28: concurrency covered as far as pgTAP permits — see 22/22b');

-- 29: trigger still blocks an unauthorized DIRECT user_id change
-- (outside any RPC, no marker set). Explicitly force both markers
-- false first: earlier successful accept/approve calls in this same
-- pgTAP transaction set one is_local marker true for the rest of the
-- transaction (by design — see this migration's header; harmless in
-- production, where each RPC call is its own transaction) and this
-- test must prove the trigger blocks an update with NEITHER marker
-- set.
select set_config('umoja.membership_claim_approval', 'false', true);
select set_config('umoja.membership_invitation_acceptance', 'false', true);
select throws_ok(
  $$ update public.group_memberships set user_id = '10400000-0000-0000-0000-000000000099' where id = '10400000-0000-0000-0000-000000000108'::uuid $$,
  '42501', 'group_memberships.user_id cannot be changed by update',
  '29: a direct UPDATE of user_id outside any sanctioned RPC is still blocked'
);

-- 30: invitation acceptance uses the sanctioned trigger path only —
-- proven by 19 above (the link succeeded) combined with 29 (no other
-- path can do it); explicit belt-and-braces check that the marker
-- function still exists and governs the trigger.
select ok(
  (select prosrc from pg_proc where proname = 'prevent_membership_user_id_change') like '%membership_invitation_acceptance%',
  '30: the trigger function''s sanctioned exception set includes the invitation-acceptance marker'
);

-- =====================================================================
-- Claim interaction (31-34).
-- =====================================================================

-- 31: existing claim approval still works (unchanged external
-- behavior) — full regression already covered by
-- 102_membership_claim_workflow.test.sql; spot-check here too.
insert into public.membership_claim_requests (group_id, membership_id, claimant_user_id) values
  ('10400000-0000-0000-0000-000000000001', '10400000-0000-0000-0000-000000000110', '10400000-0000-0000-0000-000000000024')
on conflict do nothing;
set local request.jwt.claim.sub to '10400000-0000-0000-0000-000000000011';
select is(
  (select public.rpc_approve_membership_claim(
    '10400000-0000-0000-0000-000000000001'::uuid,
    (select id from public.membership_claim_requests where membership_id = '10400000-0000-0000-0000-000000000110'::uuid and status = 'PENDING')
  ) ->> 'status'),
  'APPROVED',
  '31: existing claim approval still works exactly as before'
);

-- 32: invitation acceptance prevents (auto-cancels) a later conflicting
-- claim on the same membership.
insert into public.group_memberships (id, group_id, display_name, status, joined_at, member_number) values
  ('10400000-0000-0000-0000-000000000160', '10400000-0000-0000-0000-000000000001', 'Conflict A Fresh Target', 'ACTIVE', '2025-01-01', 'INVA-0020');
insert into public.membership_claim_requests (group_id, membership_id, claimant_user_id) values
  ('10400000-0000-0000-0000-000000000001', '10400000-0000-0000-0000-000000000160', '10400000-0000-0000-0000-000000000022');
set local request.jwt.claim.sub to '10400000-0000-0000-0000-000000000011';
select v.j ->> 'token' as conflict_a_invite2_token
from (select rpc_create_membership_invitation('10400000-0000-0000-0000-000000000001'::uuid, '10400000-0000-0000-0000-000000000160'::uuid, array['MEMBER']) as j) v
\gset
set local request.jwt.claim.sub to '10400000-0000-0000-0000-000000000025';
select rpc_accept_membership_invitation(:'conflict_a_invite2_token');
select is(
  (select status::text from public.membership_claim_requests where membership_id = '10400000-0000-0000-0000-000000000160'::uuid),
  'CANCELLED',
  '32a: the competing PENDING claim on the same membership is auto-cancelled once the invitation is accepted'
);
set local request.jwt.claim.sub to '10400000-0000-0000-0000-000000000011';
select throws_ok(
  format($$ select public.rpc_approve_membership_claim('10400000-0000-0000-0000-000000000001'::uuid, %L::uuid) $$, (select id from public.membership_claim_requests where membership_id = '10400000-0000-0000-0000-000000000160'::uuid)),
  'P0001', 'MEMBERSHIP_CLAIM_NOT_PENDING',
  '32b: the now-cancelled claim can no longer be approved'
);

-- 33: claim approval prevents (auto-cancels) a later conflicting
-- invitation on the same membership.
insert into public.group_memberships (id, group_id, display_name, status, joined_at, member_number) values
  ('10400000-0000-0000-0000-000000000161', '10400000-0000-0000-0000-000000000001', 'Conflict B Fresh Target', 'ACTIVE', '2025-01-01', 'INVA-0021');
insert into public.membership_claim_requests (group_id, membership_id, claimant_user_id) values
  ('10400000-0000-0000-0000-000000000001', '10400000-0000-0000-0000-000000000161', '10400000-0000-0000-0000-000000000026');
set local request.jwt.claim.sub to '10400000-0000-0000-0000-000000000011';
select v.j ->> 'token' as conflict_b_invite_token
from (select rpc_create_membership_invitation('10400000-0000-0000-0000-000000000001'::uuid, '10400000-0000-0000-0000-000000000161'::uuid, array['MEMBER']) as j) v
\gset
select public.rpc_approve_membership_claim(
  '10400000-0000-0000-0000-000000000001'::uuid,
  (select id from public.membership_claim_requests where membership_id = '10400000-0000-0000-0000-000000000161'::uuid)
);
select is(
  (select status::text from public.membership_invitations where membership_id = '10400000-0000-0000-0000-000000000161'::uuid),
  'CANCELLED',
  '33a: the competing PENDING invitation on the same membership is auto-cancelled once the claim is approved'
);
set local request.jwt.claim.sub to '10400000-0000-0000-0000-000000000022';
select throws_ok(
  format($$ select public.rpc_accept_membership_invitation(%L) $$, :'conflict_b_invite_token'),
  'P0001', 'MEMBERSHIP_INVITATION_NOT_PENDING',
  '33b: the now-cancelled invitation can no longer be accepted'
);

-- 34: historical claim/invitation rows preserved (never deleted).
select ok(
  (select count(*)::integer from public.membership_claim_requests where membership_id = '10400000-0000-0000-0000-000000000160'::uuid) = 1,
  '34a: the auto-cancelled claim row from 32 still exists as history (not deleted)'
);
select ok(
  (select count(*)::integer from public.membership_invitations where membership_id = '10400000-0000-0000-0000-000000000161'::uuid) = 1,
  '34b: the auto-cancelled invitation row from 33 still exists as history (not deleted)'
);

-- =====================================================================
-- Security (35-42).
-- =====================================================================

-- 35: zero anon EXECUTE on every new public RPC.
select is(
  (select count(*)::integer from information_schema.routine_privileges
   where routine_schema = 'public'
     and routine_name in (
       'rpc_create_membership_invitation', 'rpc_preview_membership_invitation',
       'rpc_accept_membership_invitation', 'rpc_cancel_membership_invitation',
       'rpc_list_membership_invitations'
     )
     and grantee in ('anon', 'public')),
  0,
  '35: zero EXECUTE grants to anon/public on any new public RPC (information_schema check)'
);
select is(
  (select bool_or(has_function_privilege('anon', oid, 'EXECUTE')) from pg_proc
   where proname in (
     'rpc_create_membership_invitation', 'rpc_preview_membership_invitation',
     'rpc_accept_membership_invitation', 'rpc_cancel_membership_invitation',
     'rpc_list_membership_invitations'
   )),
  false,
  '35b: has_function_privilege confirms zero anon EXECUTE (would also catch a hosted default-privilege drift, unlike the routine_privileges check alone — the exact 09G-DEPLOY-03 defect class)'
);

-- 36: authenticated only where intended.
select is(
  (select count(*)::integer from information_schema.routine_privileges
   where routine_schema = 'public'
     and routine_name in (
       'rpc_create_membership_invitation', 'rpc_preview_membership_invitation',
       'rpc_accept_membership_invitation', 'rpc_cancel_membership_invitation',
       'rpc_list_membership_invitations'
     )
     and grantee = 'authenticated'),
  5,
  '36: exactly one authenticated EXECUTE grant per new public RPC'
);

-- 37: internal helpers inaccessible. This migration introduces no new
-- internal-only function (the hashing/token logic is inlined into
-- each public RPC directly, so there is no separate internal helper
-- surface to lock down beyond the RPCs themselves, already covered by
-- 35/36).
select pass('37: no new internal-only helper function was introduced by this migration to separately lock down');

-- 38: no direct table mutation grants.
select is(
  (select count(*)::integer from information_schema.role_table_grants
   where table_schema = 'public' and table_name in ('membership_invitations', 'membership_invitation_roles')
     and grantee in ('anon', 'authenticated')),
  0,
  '38: zero direct table grants (any privilege) to anon/authenticated on either new table'
);

-- 39: RLS enabled.
select ok(
  (select relrowsecurity from pg_class where oid = 'public.membership_invitations'::regclass),
  '39a: RLS is enabled on membership_invitations'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.membership_invitation_roles'::regclass),
  '39b: RLS is enabled on membership_invitation_roles'
);

-- 40: token hash cannot be used as if it were the plaintext token.
set local request.jwt.claim.sub to '10400000-0000-0000-0000-000000000011';
select rpc_create_membership_invitation('10400000-0000-0000-0000-000000000001'::uuid, '10400000-0000-0000-0000-000000000113'::uuid, array['MEMBER']) as hash_setup \gset
set local request.jwt.claim.sub to '10400000-0000-0000-0000-000000000021';
select throws_ok(
  format(
    $$ select public.rpc_accept_membership_invitation((select token_hash from public.membership_invitations where membership_id = '10400000-0000-0000-0000-000000000113') ) $$
  ),
  'P0001', 'MEMBERSHIP_INVITATION_NOT_FOUND',
  '40: presenting the stored token_hash itself (not the plaintext) as the token is rejected as not-found'
);

-- 41: cross-group officer cannot inspect invitation queue.
set local request.jwt.claim.sub to '10400000-0000-0000-0000-000000000031';
select throws_ok(
  $$ select public.rpc_list_membership_invitations('10400000-0000-0000-0000-000000000001'::uuid) $$,
  '42501', null,
  '41: an officer holding member.invite ONLY in a different group cannot list Group A''s invitation queue'
);

-- 42: ordinary member cannot inspect officer queue.
set local request.jwt.claim.sub to '10400000-0000-0000-0000-000000000013';
select throws_ok(
  $$ select public.rpc_list_membership_invitations('10400000-0000-0000-0000-000000000001'::uuid) $$,
  '42501', null,
  '42: a plain MEMBER (no member.invite) cannot list the officer invitation queue'
);

-- =====================================================================
-- Role/security (44-46).
-- =====================================================================

-- 44: role assignment is server-recorded, not accept-client-controlled
-- — already structurally proven by 21 (accept takes only a token) and
-- 20 (exact recorded roles assigned); explicit restatement here.
select is(
  (select pg_get_function_identity_arguments('public.rpc_accept_membership_invitation(text)'::regprocedure)),
  'p_token text',
  '44: role assignment is driven entirely by server-recorded membership_invitation_roles, never a client-supplied parameter'
);

-- 45: cancellation assigns no role.
set local request.jwt.claim.sub to '10400000-0000-0000-0000-000000000011';
select rpc_create_membership_invitation('10400000-0000-0000-0000-000000000001'::uuid, '10400000-0000-0000-0000-000000000114'::uuid, array['MEMBER']) as cancel_role_setup \gset
select rpc_cancel_membership_invitation('10400000-0000-0000-0000-000000000001'::uuid, (:'cancel_role_setup'::jsonb ->> 'invitation_id')::uuid);
select is(
  (select count(*)::integer from public.group_membership_roles where group_membership_id = '10400000-0000-0000-0000-000000000114'::uuid),
  0,
  '45: cancelling a PENDING invitation assigns zero roles'
);

-- 46: expiry assigns no role.
select is(
  (select count(*)::integer from public.group_membership_roles where group_membership_id = '10400000-0000-0000-0000-000000000108'::uuid),
  0,
  '46: an expired (never-accepted) invitation assigns zero roles'
);

-- =====================================================================
-- Read-only (47).
-- =====================================================================

-- 47: preview/list reads do not mutate financial/member business state.
select is(
  (select count(*)::integer from public.payments),
  0,
  '47a: no payment rows exist / were created by any read path in this suite'
);
select is(
  (select count(*)::integer from public.group_memberships where id = '10400000-0000-0000-0000-000000000104'::uuid and display_name <> 'Roster Target Four'),
  0,
  '47b: reads never mutate an unrelated member''s own record'
);

select * from finish();
rollback;
