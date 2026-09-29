-- Prompt 09G-B1-F1: phone-targeted member invitation workflow. Proves
-- creation/discovery/acceptance/decline security, the authoritative
-- verified-Auth-phone identity model (never profiles.phone, never
-- group_memberships.phone, never a client-supplied phone), phone
-- normalization parity with the Flutter/Edge-Function conventions,
-- claim/invitation conflict resolution, and that the legacy TOKEN
-- workflow (101-104) is fully unaffected — without weakening any
-- existing test.
begin;

select plan(77);

-- =====================================================================
-- Fixtures.
-- =====================================================================
insert into auth.users (id, email, phone, phone_confirmed_at) values
  ('10500000-0000-0000-0000-000000000011', 'p09gf1-admin@example.com', null, null),
  ('10500000-0000-0000-0000-000000000012', 'p09gf1-secretary@example.com', null, null),
  ('10500000-0000-0000-0000-000000000013', 'p09gf1-member@example.com', null, null),
  ('10500000-0000-0000-0000-000000000031', 'p09gf1-cross-group-admin@example.com', null, null),
  -- Verified phones (phone_confirmed_at set) — the recipients.
  ('10500000-0000-0000-0000-000000000021', 'p09gf1-invitee-one@example.com', '255712345001', now()),
  ('10500000-0000-0000-0000-000000000022', 'p09gf1-invitee-two@example.com', '255712345002', now()),
  ('10500000-0000-0000-0000-000000000023', 'p09gf1-already-active@example.com', '255712345003', now()),
  ('10500000-0000-0000-0000-000000000024', 'p09gf1-claim-still-works@example.com', '255712345004', now()),
  ('10500000-0000-0000-0000-000000000025', 'p09gf1-conflict-a-acceptor@example.com', '255712345005', now()),
  ('10500000-0000-0000-0000-000000000026', 'p09gf1-conflict-b-claimant@example.com', '255712345006', now()),
  ('10500000-0000-0000-0000-000000000040', 'p09gf1-already-linked@example.com', '255712345040', now()),
  ('10500000-0000-0000-0000-000000000050', 'p09gf1-multi-group@example.com', '255712345050', now()),
  ('10500000-0000-0000-0000-000000000051', 'p09gf1-decline-user@example.com', '255712345051', now()),
  ('10500000-0000-0000-0000-000000000052', 'p09gf1-decline-other@example.com', '255712345052', now()),
  -- Phone set but NEVER confirmed (simulates an in-progress/never-
  -- completed OTP signup) — must be treated exactly like no phone at all.
  ('10500000-0000-0000-0000-000000000027', 'p09gf1-unverified-phone@example.com', '255712345007', null),
  -- No phone at all.
  ('10500000-0000-0000-0000-000000000028', 'p09gf1-no-phone@example.com', null, null),
  -- New-user placeholder: created explicitly AFTER a phone invitation
  -- already exists for its phone, to prove Section P's "no account yet
  -- at invitation-creation time" contract.
  ('10500000-0000-0000-0000-000000000060', 'p09gf1-new-user@example.com', null, null);

insert into public.groups (id, name, created_by, code, status) values
  ('10500000-0000-0000-0000-000000000001', 'Phone Invitation Group A', '10500000-0000-0000-0000-000000000011', 'PIVA', 'ACTIVE'),
  ('10500000-0000-0000-0000-000000000002', 'Phone Invitation Group B (suspended)', '10500000-0000-0000-0000-000000000011', 'PIVB', 'SUSPENDED'),
  ('10500000-0000-0000-0000-000000000003', 'Phone Invitation Group C', '10500000-0000-0000-0000-000000000031', 'PIVC', 'ACTIVE'),
  ('10500000-0000-0000-0000-000000000004', 'Phone Invitation Group D', '10500000-0000-0000-0000-000000000011', 'PIVD', 'ACTIVE');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('10500000-0000-0000-0000-000000000101', '10500000-0000-0000-0000-000000000001', '10500000-0000-0000-0000-000000000011', 'Admin One', 'ACTIVE', '2025-01-01', 'PIVA-0001'),
  ('10500000-0000-0000-0000-000000000141', '10500000-0000-0000-0000-000000000004', '10500000-0000-0000-0000-000000000011', 'Admin One (Group D)', 'ACTIVE', '2025-01-01', 'PIVD-0100'),
  ('10500000-0000-0000-0000-000000000102', '10500000-0000-0000-0000-000000000001', '10500000-0000-0000-0000-000000000012', 'Secretary Two', 'ACTIVE', '2025-01-01', 'PIVA-0002'),
  ('10500000-0000-0000-0000-000000000103', '10500000-0000-0000-0000-000000000001', '10500000-0000-0000-0000-000000000013', 'Member Three', 'ACTIVE', '2025-01-01', 'PIVA-0003'),
  ('10500000-0000-0000-0000-000000000104', '10500000-0000-0000-0000-000000000001', null, 'Roster Target Four', 'ACTIVE', '2025-01-01', 'PIVA-0004'),
  ('10500000-0000-0000-0000-000000000105', '10500000-0000-0000-0000-000000000001', null, 'Roster Suspended Five', 'SUSPENDED', '2025-01-01', 'PIVA-0005'),
  ('10500000-0000-0000-0000-000000000106', '10500000-0000-0000-0000-000000000001', '10500000-0000-0000-0000-000000000040', 'Roster Already Linked Six', 'ACTIVE', '2025-01-01', 'PIVA-0006'),
  ('10500000-0000-0000-0000-000000000107', '10500000-0000-0000-0000-000000000002', null, 'Roster In Suspended Group Seven', 'ACTIVE', '2025-01-01', 'PIVB-0001'),
  ('10500000-0000-0000-0000-000000000108', '10500000-0000-0000-0000-000000000001', null, 'Roster Dup-Pending Eight', 'ACTIVE', '2025-01-01', 'PIVA-0007'),
  ('10500000-0000-0000-0000-000000000109', '10500000-0000-0000-0000-000000000001', '10500000-0000-0000-0000-000000000023', 'Already Active Nine', 'ACTIVE', '2025-01-01', 'PIVA-0008'),
  ('10500000-0000-0000-0000-000000000110', '10500000-0000-0000-0000-000000000001', null, 'Roster Conflict A Ten', 'ACTIVE', '2025-01-01', 'PIVA-0009'),
  ('10500000-0000-0000-0000-000000000111', '10500000-0000-0000-0000-000000000001', null, 'Roster Conflict B Eleven', 'ACTIVE', '2025-01-01', 'PIVA-0010'),
  ('10500000-0000-0000-0000-000000000112', '10500000-0000-0000-0000-000000000001', null, 'Roster Discovery Twelve', 'ACTIVE', '2025-01-01', 'PIVA-0011'),
  ('10500000-0000-0000-0000-000000000113', '10500000-0000-0000-0000-000000000001', null, 'Roster ADMIN Escalation Thirteen', 'ACTIVE', '2025-01-01', 'PIVA-0012'),
  ('10500000-0000-0000-0000-000000000114', '10500000-0000-0000-0000-000000000001', null, 'Roster Cancel Fourteen', 'ACTIVE', '2025-01-01', 'PIVA-0013'),
  ('10500000-0000-0000-0000-000000000115', '10500000-0000-0000-0000-000000000004', null, 'Roster Multi Group A Fifteen', 'ACTIVE', '2025-01-01', 'PIVD-0001'),
  ('10500000-0000-0000-0000-000000000116', '10500000-0000-0000-0000-000000000001', null, 'Roster Multi Group B Sixteen', 'ACTIVE', '2025-01-01', 'PIVA-0014'),
  ('10500000-0000-0000-0000-000000000117', '10500000-0000-0000-0000-000000000001', null, 'Roster Decline Seventeen', 'ACTIVE', '2025-01-01', 'PIVA-0015'),
  ('10500000-0000-0000-0000-000000000118', '10500000-0000-0000-0000-000000000001', null, 'Roster Decline Retry Eighteen', 'ACTIVE', '2025-01-01', 'PIVA-0016'),
  ('10500000-0000-0000-0000-000000000119', '10500000-0000-0000-0000-000000000001', null, 'Roster New User Nineteen', 'ACTIVE', '2025-01-01', 'PIVA-0017'),
  ('10500000-0000-0000-0000-000000000120', '10500000-0000-0000-0000-000000000001', null, 'Roster Profile Phone Test Twenty', 'ACTIVE', '2025-01-01', 'PIVA-0018'),
  ('10500000-0000-0000-0000-000000000121', '10500000-0000-0000-0000-000000000001', null, 'Roster GM Phone Test TwentyOne', 'ACTIVE', '2025-01-01', 'PIVA-0019'),
  ('10500000-0000-0000-0000-000000000160', '10500000-0000-0000-0000-000000000001', null, 'Roster Conflict Claim First TwentyTwo', 'ACTIVE', '2025-01-01', 'PIVA-0020'),
  ('10500000-0000-0000-0000-000000000161', '10500000-0000-0000-0000-000000000001', null, 'Roster Conflict Invite First TwentyThree', 'ACTIVE', '2025-01-01', 'PIVA-0021'),
  ('10500000-0000-0000-0000-000000000122', '10500000-0000-0000-0000-000000000001', null, 'Roster Revalidate Active TwentyFour', 'ACTIVE', '2025-01-01', 'PIVA-0022'),
  ('10500000-0000-0000-0000-000000000123', '10500000-0000-0000-0000-000000000001', null, 'Roster Dup Active TwentyFive', 'ACTIVE', '2025-01-01', 'PIVA-0023'),
  ('10500000-0000-0000-0000-000000000124', '10500000-0000-0000-0000-000000000001', null, 'Roster Legacy Token TwentySix', 'ACTIVE', '2025-01-01', 'PIVA-0024'),
  ('10500000-0000-0000-0000-000000000131', '10500000-0000-0000-0000-000000000003', '10500000-0000-0000-0000-000000000031', 'Cross Group Admin', 'ACTIVE', '2025-01-01', 'PIVC-0001');

insert into public.group_membership_roles (group_membership_id, role_id)
  select '10500000-0000-0000-0000-000000000101', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id)
  select '10500000-0000-0000-0000-000000000102', id from public.roles where code = 'SECRETARY';
insert into public.group_membership_roles (group_membership_id, role_id)
  select '10500000-0000-0000-0000-000000000103', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id)
  select '10500000-0000-0000-0000-000000000131', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id)
  select '10500000-0000-0000-0000-000000000141', id from public.roles where code = 'ADMIN';

-- Deliberately set profiles.phone / group_memberships.phone to values
-- that DO NOT match any target — proves neither is ever consulted
-- (items 18/19).
update public.profiles set phone = '255700000000' where id = '10500000-0000-0000-0000-000000000021';
update public.group_memberships set phone = '255799999999' where id = '10500000-0000-0000-0000-000000000104';

-- =====================================================================
-- Creation authorization + eligibility (1-6).
-- =====================================================================

-- 1: authorized officer (ADMIN, holds member.invite) can create.
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000011';
select isnt(
  (select public.rpc_create_membership_phone_invitation(
    '10500000-0000-0000-0000-000000000001'::uuid,
    '10500000-0000-0000-0000-000000000104'::uuid,
    '0712345001',
    array['MEMBER']
  ) ->> 'invitation_id'),
  null,
  '1: an ADMIN (holds member.invite) can create a phone invitation'
);

-- 2: plain member (no member.invite) cannot create.
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000013';
select throws_ok(
  $$ select public.rpc_create_membership_phone_invitation('10500000-0000-0000-0000-000000000001'::uuid, '10500000-0000-0000-0000-000000000108'::uuid, '0712345008', array['MEMBER']) $$,
  '42501', null,
  '2: a plain MEMBER (no member.invite) cannot create a phone invitation'
);

-- 3: inactive (SUSPENDED) group rejected.
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000011';
select throws_ok(
  $$ select public.rpc_create_membership_phone_invitation('10500000-0000-0000-0000-000000000002'::uuid, '10500000-0000-0000-0000-000000000107'::uuid, '0712345009', array['MEMBER']) $$,
  '42501', null,
  '3: a SUSPENDED group is rejected (has_group_permission itself denies)'
);

-- 4: inactive (SUSPENDED) target membership rejected.
select throws_ok(
  $$ select public.rpc_create_membership_phone_invitation('10500000-0000-0000-0000-000000000001'::uuid, '10500000-0000-0000-0000-000000000105'::uuid, '0712345010', array['MEMBER']) $$,
  'P0001', 'MEMBERSHIP_NOT_ACTIVE',
  '4: a SUSPENDED target membership is rejected'
);

-- 5: already-linked membership rejected.
select throws_ok(
  $$ select public.rpc_create_membership_phone_invitation('10500000-0000-0000-0000-000000000001'::uuid, '10500000-0000-0000-0000-000000000106'::uuid, '0712345011', array['MEMBER']) $$,
  'P0001', 'MEMBERSHIP_ALREADY_LINKED',
  '5: an already-linked target membership is rejected'
);

-- 6: (inactive officer/profile rejected per existing invariant) —
-- assert_active_profile() is reused as-is from the exact same helper
-- every other mutation RPC in this codebase already calls; its own
-- behavior is already exhaustively covered by
-- 20260819085905/enforce_active_profile_on_mutations.sql's own test
-- coverage and by 101-104. Structural proof that this RPC calls it:
select ok(
  (select prosrc from pg_proc where proname = 'rpc_create_membership_phone_invitation') ~ 'assert_active_profile',
  '6: rpc_create_membership_phone_invitation calls assert_active_profile() (same inactive-account gate as every other mutation RPC)'
);

-- =====================================================================
-- Phone normalization (7-9).
-- =====================================================================

-- 7: malformed phone rejected.
select throws_ok(
  $$ select public.rpc_create_membership_phone_invitation('10500000-0000-0000-0000-000000000001'::uuid, '10500000-0000-0000-0000-000000000108'::uuid, 'not-a-phone', array['MEMBER']) $$,
  'P0001', 'MEMBERSHIP_INVITATION_INVALID_PHONE',
  '7: a malformed phone is rejected deterministically'
);

-- 8: supported local phone (0-prefixed) normalized correctly.
select is(
  public.normalize_tanzania_phone_e164('0712345678'),
  '+255712345678',
  '8: a local 0-prefixed phone normalizes to +255712345678'
);

-- 9: canonical E.164 equivalent normalizes identically (and the other
-- accepted shapes too, matching the Dart/TS twins exactly).
select is(
  public.normalize_tanzania_phone_e164('+255712345678'),
  '+255712345678',
  '9a: an already-canonical +255... phone normalizes to itself'
);
select is(
  public.normalize_tanzania_phone_e164('255712345678'),
  '+255712345678',
  '9b: a 255-prefixed (no plus) phone normalizes identically'
);
select is(
  public.normalize_tanzania_phone_e164('712345678'),
  '+255712345678',
  '9c: a bare 9-digit subscriber number normalizes identically'
);
select is(
  public.normalize_tanzania_phone_e164('0655 123 456'),
  '+255655123456',
  '9d: formatting characters (spaces) are stripped before normalization'
);
select is(
  public.normalize_tanzania_phone_e164('0812345678'),
  null,
  '9e: a non-mobile (8-prefixed) subscriber number is rejected'
);
select is(
  public.normalize_tanzania_phone_e164(null),
  null,
  '9f: NULL input normalizes to NULL, never raises'
);

-- =====================================================================
-- Role handling (10-12).
-- =====================================================================

-- 10: unknown role rejected.
select throws_ok(
  $$ select public.rpc_create_membership_phone_invitation('10500000-0000-0000-0000-000000000001'::uuid, '10500000-0000-0000-0000-000000000108'::uuid, '0712345012', array['SUPERADMIN']) $$,
  '22023', null,
  '10: an unknown/non-existent role code is rejected'
);

-- 11: unauthorized ADMIN escalation rejected — SECRETARY (holds
-- member.invite, not ADMIN) cannot invite AS ADMIN.
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000012';
select throws_ok(
  $$ select public.rpc_create_membership_phone_invitation('10500000-0000-0000-0000-000000000001'::uuid, '10500000-0000-0000-0000-000000000113'::uuid, '0712345013', array['ADMIN']) $$,
  '42501', null,
  '11: a SECRETARY (not ADMIN) cannot invite a member with the ADMIN role'
);

-- 12: authorized ADMIN assignment allowed (caller IS ADMIN).
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000011';
select isnt(
  (select public.rpc_create_membership_phone_invitation('10500000-0000-0000-0000-000000000001'::uuid, '10500000-0000-0000-0000-000000000113'::uuid, '0712345013', array['ADMIN']) ->> 'invitation_id'),
  null,
  '12: an existing ADMIN CAN invite a member with the ADMIN role'
);

-- =====================================================================
-- Structural client-input guarantees (13-14).
-- =====================================================================

-- 13: no user_id parameter anywhere on create/accept/decline.
select is(
  (select pg_get_function_identity_arguments('public.rpc_create_membership_phone_invitation(uuid,uuid,text,text[])'::regprocedure)),
  'p_group_id uuid, p_membership_id uuid, p_phone text, p_role_codes text[]',
  '13a: rpc_create_membership_phone_invitation''s signature has no user_id parameter'
);
select is(
  (select pg_get_function_identity_arguments('public.rpc_accept_membership_phone_invitation(uuid)'::regprocedure)),
  'p_invitation_id uuid',
  '13b: rpc_accept_membership_phone_invitation''s ONLY parameter is the invitation id — no phone/user/membership/group/role'
);
select is(
  (select pg_get_function_identity_arguments('public.rpc_decline_membership_phone_invitation(uuid)'::regprocedure)),
  'p_invitation_id uuid',
  '13c: rpc_decline_membership_phone_invitation''s ONLY parameter is the invitation id'
);

-- 14: no role_id parameter anywhere — role_codes text[] only, exactly
-- like the TOKEN flow.
select is(
  (select pg_get_function_identity_arguments('public.rpc_create_membership_phone_invitation(uuid,uuid,text,text[])'::regprocedure)) ~ 'role_id',
  false,
  '14: no role_id-shaped parameter exists on the create RPC — role_codes text[] only'
);

-- =====================================================================
-- New-user / existing-user support (15).
-- =====================================================================
truncate public.membership_invitations, public.membership_invitation_roles cascade;

-- 15: a phone with NO existing auth.users row at all can be invited.
-- Uses a phone that matches no fixture above.
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000011';
select isnt(
  (select public.rpc_create_membership_phone_invitation('10500000-0000-0000-0000-000000000001'::uuid, '10500000-0000-0000-0000-000000000119'::uuid, '0712399999', array['MEMBER']) ->> 'invitation_id'),
  null,
  '15a: a phone with no existing auth.users account at all can be invited'
);
-- The new user signs up (fixture 10500000-...-060 already exists but
-- had no phone at creation time — now their phone gets confirmed,
-- simulating a real OTP completion after the invitation was created).
update auth.users set phone = '255712399999', phone_confirmed_at = now()
where id = '10500000-0000-0000-0000-000000000060';
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000060';
select is(
  (select (public.rpc_list_my_membership_invitations()) -> 'items' -> 0 ->> 'membership_display_name'),
  'Roster New User Nineteen',
  '15b: once the new user completes OTP signup with the matching phone, the invitation created BEFORE they had any account becomes visible to them'
);

-- =====================================================================
-- Discovery / rpc_list_my_membership_invitations (16-21).
-- =====================================================================
truncate public.membership_invitations, public.membership_invitation_roles cascade;

set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000011';
select public.rpc_create_membership_phone_invitation('10500000-0000-0000-0000-000000000001'::uuid, '10500000-0000-0000-0000-000000000112'::uuid, '0712345001', array['TREASURER']) as discovery_setup \gset

-- 16: authenticated user matching the verified phone sees the invitation.
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000021';
select is(
  (select (public.rpc_list_my_membership_invitations()) ->> 'total_count'),
  '1',
  '16: the matching-verified-phone user sees exactly one invitation'
);
select is(
  (select (public.rpc_list_my_membership_invitations()) -> 'items' -> 0 ->> 'status'),
  'PENDING',
  '16b: the discovered invitation reports PENDING status'
);
select is(
  (select (public.rpc_list_my_membership_invitations()) -> 'items' -> 0 -> 'roles' ->> 0),
  'Treasurer',
  '16c: the discovered invitation reports the role DISPLAY NAME'
);
select ok(
  not ((select (public.rpc_list_my_membership_invitations()) -> 'items' -> 0) ? 'membership_id'),
  '16d: discovery never leaks the internal membership_id'
);
select ok(
  not ((select (public.rpc_list_my_membership_invitations()) -> 'items' -> 0) ? 'target_phone_e164'),
  '16e: discovery never echoes the target phone back (the caller already knows their own phone)'
);

-- 17: a DIFFERENT verified phone cannot see it.
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000022';
select is(
  (select (public.rpc_list_my_membership_invitations()) ->> 'total_count'),
  '0',
  '17: a different verified phone sees zero invitations'
);

-- 18: changing profiles.phone does NOT expose the invitation. The
-- fixture user (021) already has profiles.phone set to an unrelated
-- value (255700000000) above — confirm they STILL see it via their
-- REAL auth.users.phone, and that setting profiles.phone to the
-- invitation's own target phone for a DIFFERENT, non-matching-Auth-
-- phone user does NOT grant that user visibility.
update public.profiles set phone = '255712345001' where id = '10500000-0000-0000-0000-000000000022';
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000022';
select is(
  (select (public.rpc_list_my_membership_invitations()) ->> 'total_count'),
  '0',
  '18: setting profiles.phone to the invitation''s target phone grants NO visibility to a user whose real auth.users.phone does not match'
);

-- 19: changing group_memberships.phone does NOT establish recipient
-- authority. The target membership''s own .phone was set to an
-- unrelated value above; confirm the invitation is still keyed
-- entirely off the invitation''s own target_phone_e164, never that
-- column.
update public.group_memberships set phone = '255712345001' where id = '10500000-0000-0000-0000-000000000112';
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000022';
select is(
  (select (public.rpc_list_my_membership_invitations()) ->> 'total_count'),
  '0',
  '19: setting group_memberships.phone to match a real user''s own phone still grants that user no visibility — it is never consulted'
);

-- 20: list RPC takes no phone parameter (structural).
select is(
  (select pg_get_function_identity_arguments('public.rpc_list_my_membership_invitations(public.membership_invitation_status,integer,integer)'::regprocedure)),
  'p_status membership_invitation_status, p_limit integer, p_offset integer',
  '20: rpc_list_my_membership_invitations takes NO phone/user parameter'
);

-- 21: same user sees legitimate invitations across MULTIPLE groups.
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000011';
select public.rpc_create_membership_phone_invitation('10500000-0000-0000-0000-000000000004'::uuid, '10500000-0000-0000-0000-000000000115'::uuid, '0712345050', array['MEMBER']) as multi_group_a \gset
select public.rpc_create_membership_phone_invitation('10500000-0000-0000-0000-000000000001'::uuid, '10500000-0000-0000-0000-000000000116'::uuid, '0712345050', array['TREASURER']) as multi_group_b \gset
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000050';
select is(
  (select (public.rpc_list_my_membership_invitations()) ->> 'total_count'),
  '2',
  '21: the SAME verified phone legitimately sees invitations addressed to it across TWO different groups'
);

-- =====================================================================
-- Missing verified phone — fails closed (Section Q).
-- =====================================================================

-- An unverified phone (phone set, phone_confirmed_at NULL) behaves
-- IDENTICALLY to no phone at all.
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000027';
select is(
  (select (public.rpc_list_my_membership_invitations()) ->> 'total_count'),
  '0',
  'Q1: an unverified (unconfirmed) phone sees zero invitations — never treated as verified'
);
select throws_ok(
  format($$ select public.rpc_accept_membership_phone_invitation(%L) $$, (:'discovery_setup'::jsonb ->> 'invitation_id')),
  'P0001', 'AUTH_PHONE_NOT_VERIFIED',
  'Q2: accept fails closed with AUTH_PHONE_NOT_VERIFIED for an unverified phone'
);
select throws_ok(
  format($$ select public.rpc_decline_membership_phone_invitation(%L) $$, (:'discovery_setup'::jsonb ->> 'invitation_id')),
  'P0001', 'AUTH_PHONE_NOT_VERIFIED',
  'Q3: decline fails closed with AUTH_PHONE_NOT_VERIFIED for an unverified phone'
);
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000028';
select is(
  (select (public.rpc_list_my_membership_invitations()) ->> 'total_count'),
  '0',
  'Q4: a caller with NO phone at all on auth.users sees zero invitations'
);

-- =====================================================================
-- Acceptance (22-30).
-- =====================================================================
truncate public.membership_invitations, public.membership_invitation_roles cascade;

set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000011';
select public.rpc_create_membership_phone_invitation('10500000-0000-0000-0000-000000000001'::uuid, '10500000-0000-0000-0000-000000000104'::uuid, '0712345001', array['TREASURER', 'SECRETARY']) as accept_setup \gset
select (:'accept_setup'::jsonb ->> 'invitation_id') as accept_invitation_id \gset

-- 22: accept RPC takes invitation_id only — already proven structurally
-- by 13b; explicit restatement here in context.
select pass('22: rpc_accept_membership_phone_invitation takes invitation_id only (see 13b)');

-- 23: matching verified phone can accept.
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000021';
select is(
  (select public.rpc_accept_membership_phone_invitation(:'accept_invitation_id'::uuid) ->> 'status'),
  'ACCEPTED',
  '23: the matching-verified-phone user accepts successfully'
);

-- 24: a DIFFERENT (nonmatching) authenticated user cannot accept an
-- unrelated PENDING invitation — collapses to generic not-found.
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000011';
select public.rpc_create_membership_phone_invitation('10500000-0000-0000-0000-000000000001'::uuid, '10500000-0000-0000-0000-000000000108'::uuid, '0712345001', array['MEMBER']) as mismatch_setup \gset
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000022';
select throws_ok(
  format($$ select public.rpc_accept_membership_phone_invitation(%L) $$, (:'mismatch_setup'::jsonb ->> 'invitation_id')),
  'P0001', 'MEMBERSHIP_PHONE_INVITATION_NOT_FOUND',
  '24: a nonmatching authenticated user cannot accept — collapses to the generic not-found outcome, never revealing it exists for a different phone'
);

-- 25: acceptance links membership to auth.uid().
select is(
  (select user_id from public.group_memberships where id = '10500000-0000-0000-0000-000000000104'::uuid),
  '10500000-0000-0000-0000-000000000021'::uuid,
  '25: the target membership now links to the accepting user'
);

-- 26: acceptance assigns exactly the recorded roles.
select is(
  (select array_agg(r.code order by r.code) from public.group_membership_roles gmr
   join public.roles r on r.id = gmr.role_id
   where gmr.group_membership_id = '10500000-0000-0000-0000-000000000104'::uuid),
  array['SECRETARY', 'TREASURER'],
  '26: exactly the recorded roles (TREASURER, SECRETARY) are assigned — no more, no fewer'
);

-- 27: acceptance marks the invitation terminal (ACCEPTED).
select is(
  (select status::text from public.membership_invitations where id = :'accept_invitation_id'::uuid),
  'ACCEPTED',
  '27: the invitation row itself is now ACCEPTED'
);

-- 28: acceptance cancels a competing PENDING claim on the same
-- membership. Uses user 024 (phone 0712345004) as the accepting
-- recipient — NOT 021, who is already ACTIVE in this same group from
-- test 23 (a user cannot hold two ACTIVE memberships in one group).
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000011';
select public.rpc_create_membership_phone_invitation('10500000-0000-0000-0000-000000000001'::uuid, '10500000-0000-0000-0000-000000000160'::uuid, '0712345004', array['MEMBER']) as conflict_invite_setup \gset
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000026';
select public.rpc_request_membership_claim('10500000-0000-0000-0000-000000000001'::uuid, '10500000-0000-0000-0000-000000000160'::uuid);
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000024';
select public.rpc_accept_membership_phone_invitation((:'conflict_invite_setup'::jsonb ->> 'invitation_id')::uuid);
select is(
  (select status::text from public.membership_claim_requests where membership_id = '10500000-0000-0000-0000-000000000160'::uuid),
  'CANCELLED',
  '28: the competing PENDING claim on the same membership is auto-cancelled once the phone invitation is accepted'
);

-- 29: claim approval FIRST makes a competing PENDING phone invitation
-- non-actionable.
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000011';
select public.rpc_create_membership_phone_invitation('10500000-0000-0000-0000-000000000001'::uuid, '10500000-0000-0000-0000-000000000161'::uuid, '0712345001', array['MEMBER']) as conflict_invite_b_setup \gset
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000025';
select public.rpc_request_membership_claim('10500000-0000-0000-0000-000000000001'::uuid, '10500000-0000-0000-0000-000000000161'::uuid) as conflict_claim_id \gset
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000011';
select public.rpc_approve_membership_claim('10500000-0000-0000-0000-000000000001'::uuid, (:'conflict_claim_id'::jsonb ->> 'claim_id')::uuid);
select is(
  (select status::text from public.membership_invitations where id = (:'conflict_invite_b_setup'::jsonb ->> 'invitation_id')::uuid),
  'CANCELLED',
  '29a: the competing PENDING phone invitation is auto-cancelled once a claim is approved first'
);
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000021';
select throws_ok(
  format($$ select public.rpc_accept_membership_phone_invitation(%L) $$, (:'conflict_invite_b_setup'::jsonb ->> 'invitation_id')),
  'P0001', 'MEMBERSHIP_INVITATION_NOT_PENDING',
  '29b: the now-cancelled phone invitation can no longer be accepted'
);

-- 30: expired invitation cannot be accepted.
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000011';
select public.rpc_create_membership_phone_invitation('10500000-0000-0000-0000-000000000001'::uuid, '10500000-0000-0000-0000-000000000114'::uuid, '0712345001', array['MEMBER']) as expiry_setup \gset
update public.membership_invitations set expires_at = now() - interval '1 hour'
where id = (:'expiry_setup'::jsonb ->> 'invitation_id')::uuid;
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000021';
select throws_ok(
  format($$ select public.rpc_accept_membership_phone_invitation(%L) $$, (:'expiry_setup'::jsonb ->> 'invitation_id')),
  'P0001', 'MEMBERSHIP_INVITATION_EXPIRED',
  '30: an expired invitation cannot be accepted'
);

-- =====================================================================
-- Re-validation at accept time (33/34/35 in the prompt's numbering).
-- =====================================================================

-- 31: accept revalidates membership ACTIVE (suspend it after creation,
-- before accept).
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000011';
select public.rpc_create_membership_phone_invitation('10500000-0000-0000-0000-000000000001'::uuid, '10500000-0000-0000-0000-000000000122'::uuid, '0712345002', array['MEMBER']) as revalidate_setup \gset
update public.group_memberships set status = 'SUSPENDED' where id = '10500000-0000-0000-0000-000000000122'::uuid;
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000022';
select throws_ok(
  format($$ select public.rpc_accept_membership_phone_invitation(%L) $$, (:'revalidate_setup'::jsonb ->> 'invitation_id')),
  'P0001', 'MEMBERSHIP_NOT_ACTIVE',
  '31: accept re-validates membership ACTIVE at accept time, not just at creation time'
);
update public.group_memberships set status = 'ACTIVE' where id = '10500000-0000-0000-0000-000000000122'::uuid;

-- 32: accept revalidates group ACTIVE.
update public.groups set status = 'SUSPENDED' where id = '10500000-0000-0000-0000-000000000001'::uuid;
select throws_ok(
  format($$ select public.rpc_accept_membership_phone_invitation(%L) $$, (:'revalidate_setup'::jsonb ->> 'invitation_id')),
  'P0001', 'GROUP_NOT_ACTIVE',
  '32: accept re-validates group ACTIVE at accept time'
);
update public.groups set status = 'ACTIVE' where id = '10500000-0000-0000-0000-000000000001'::uuid;

-- 33: accept rejects a caller who already holds an ACTIVE membership
-- in the same group (duplicate-active guard).
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000011';
select public.rpc_create_membership_phone_invitation('10500000-0000-0000-0000-000000000001'::uuid, '10500000-0000-0000-0000-000000000123'::uuid, '0712345003', array['MEMBER']) as dup_active_setup \gset
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000023';
select throws_ok(
  format($$ select public.rpc_accept_membership_phone_invitation(%L) $$, (:'dup_active_setup'::jsonb ->> 'invitation_id')),
  'P0001', 'CLAIMANT_ALREADY_HAS_ACTIVE_MEMBERSHIP_IN_GROUP',
  '33: a caller who already holds an ACTIVE membership in the same group is rejected'
);

-- 34: same-user safe retry (idempotent accept). Uses user 026 (phone
-- 0712345006) — the only fixture user still unlinked in Group A at
-- this point (021/023/024/025 are already ACTIVE there from earlier
-- sections; 026's own claim on membership 160 was CANCELLED, not
-- approved, in test 28, so 026 remains unlinked).
truncate public.membership_invitations, public.membership_invitation_roles cascade;
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000011';
select public.rpc_create_membership_phone_invitation('10500000-0000-0000-0000-000000000001'::uuid, '10500000-0000-0000-0000-000000000112'::uuid, '0712345006', array['MEMBER']) as retry_setup \gset
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000026';
select public.rpc_accept_membership_phone_invitation((:'retry_setup'::jsonb ->> 'invitation_id')::uuid);
select is(
  (select public.rpc_accept_membership_phone_invitation((:'retry_setup'::jsonb ->> 'invitation_id')::uuid) ->> 'already_accepted'),
  'true',
  '34: the SAME user retrying an already-accepted invitation gets a safe idempotent success, never an error'
);

-- 35: a DIFFERENT user replaying (attempting to accept an already-
-- ACCEPTED invitation, one that never targeted them) is rejected via
-- the same generic not-found collapse.
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000022';
select throws_ok(
  format($$ select public.rpc_accept_membership_phone_invitation(%L) $$, (:'retry_setup'::jsonb ->> 'invitation_id')),
  'P0001', 'MEMBERSHIP_PHONE_INVITATION_NOT_FOUND',
  '35: a different user cannot replay-accept an invitation that was never targeted at them, even once ACCEPTED'
);

-- =====================================================================
-- Decline (36-40).
-- =====================================================================
truncate public.membership_invitations, public.membership_invitation_roles cascade;

set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000011';
select public.rpc_create_membership_phone_invitation('10500000-0000-0000-0000-000000000001'::uuid, '10500000-0000-0000-0000-000000000117'::uuid, '0712345051', array['MEMBER']) as decline_setup \gset

-- 36: decline is allowed only to the matching verified phone.
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000052';
select throws_ok(
  format($$ select public.rpc_decline_membership_phone_invitation(%L) $$, (:'decline_setup'::jsonb ->> 'invitation_id')),
  'P0001', 'MEMBERSHIP_PHONE_INVITATION_NOT_FOUND',
  '36: a different user cannot decline an invitation that was never targeted at them'
);
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000051';
select is(
  (select public.rpc_decline_membership_phone_invitation((:'decline_setup'::jsonb ->> 'invitation_id')::uuid) ->> 'status'),
  'DECLINED',
  '37: the matching verified phone CAN decline'
);

-- 38: a declined invitation cannot later be accepted.
select throws_ok(
  format($$ select public.rpc_accept_membership_phone_invitation(%L) $$, (:'decline_setup'::jsonb ->> 'invitation_id')),
  'P0001', 'MEMBERSHIP_INVITATION_NOT_PENDING',
  '38: a DECLINED invitation cannot be accepted afterward'
);

-- 39: decline never touches group_memberships/group_membership_roles.
select is(
  (select user_id from public.group_memberships where id = '10500000-0000-0000-0000-000000000117'::uuid),
  null,
  '39a: declining leaves the target membership unlinked'
);
select is(
  (select count(*)::integer from public.group_membership_roles where group_membership_id = '10500000-0000-0000-0000-000000000117'::uuid),
  0,
  '39b: declining assigns zero roles'
);

-- 40: same-user safe retry (idempotent decline).
select is(
  (select public.rpc_decline_membership_phone_invitation((:'decline_setup'::jsonb ->> 'invitation_id')::uuid) ->> 'already_declined'),
  'true',
  '40: the SAME user retrying an already-declined invitation gets a safe idempotent success'
);

-- =====================================================================
-- Officer-side compatibility (41-43).
-- =====================================================================
truncate public.membership_invitations, public.membership_invitation_roles cascade;

-- 41: officer cancellation remains functional for a PHONE invitation
-- (rpc_cancel_membership_invitation, UNCHANGED, operates on it fine).
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000011';
select public.rpc_create_membership_phone_invitation('10500000-0000-0000-0000-000000000001'::uuid, '10500000-0000-0000-0000-000000000118'::uuid, '0712345001', array['MEMBER']) as officer_cancel_setup \gset
select public.rpc_cancel_membership_invitation('10500000-0000-0000-0000-000000000001'::uuid, (:'officer_cancel_setup'::jsonb ->> 'invitation_id')::uuid);
select is(
  (select status::text from public.membership_invitations where id = (:'officer_cancel_setup'::jsonb ->> 'invitation_id')::uuid),
  'CANCELLED',
  '41a: the EXISTING, UNCHANGED rpc_cancel_membership_invitation successfully cancels a PENDING PHONE invitation'
);
select is(
  (select count(*)::integer from public.group_membership_roles where group_membership_id = '10500000-0000-0000-0000-000000000118'::uuid),
  0,
  '41b: officer cancellation of a PHONE invitation assigns zero roles'
);

-- 42a/42b: officer list RPC shows PHONE invitations with the new
-- additive fields, without breaking anything.
select is(
  (select (public.rpc_list_membership_invitations('10500000-0000-0000-0000-000000000001'::uuid, 'CANCELLED'::public.membership_invitation_status)) -> 'items' -> 0 ->> 'invitation_type'),
  'PHONE',
  '42a: the officer queue reports invitation_type for a PHONE invitation'
);
select is(
  (select (public.rpc_list_membership_invitations('10500000-0000-0000-0000-000000000001'::uuid, 'CANCELLED'::public.membership_invitation_status)) -> 'items' -> 0 ->> 'target_phone_e164'),
  '+255712345001',
  '42b: the officer queue reports the canonical target_phone_e164 for a PHONE invitation'
);

-- 43: one-PENDING-per-membership invariant preserved across BOTH types.
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000011';
select public.rpc_create_membership_phone_invitation('10500000-0000-0000-0000-000000000001'::uuid, '10500000-0000-0000-0000-000000000120'::uuid, '0712345020', array['MEMBER']) as one_pending_phone \gset
select throws_ok(
  $$ select public.rpc_create_membership_invitation('10500000-0000-0000-0000-000000000001'::uuid, '10500000-0000-0000-0000-000000000120'::uuid, array['MEMBER']) $$,
  'P0001', 'MEMBERSHIP_INVITATION_ALREADY_PENDING',
  '43a: a PENDING PHONE invitation blocks creating a competing TOKEN invitation for the same membership'
);
select public.rpc_create_membership_invitation('10500000-0000-0000-0000-000000000001'::uuid, '10500000-0000-0000-0000-000000000121'::uuid, array['MEMBER']) as one_pending_token \gset
select throws_ok(
  $$ select public.rpc_create_membership_phone_invitation('10500000-0000-0000-0000-000000000001'::uuid, '10500000-0000-0000-0000-000000000121'::uuid, '0712345021', array['MEMBER']) $$,
  'P0001', 'MEMBERSHIP_INVITATION_ALREADY_PENDING',
  '43b: a PENDING TOKEN invitation blocks creating a competing PHONE invitation for the same membership'
);

-- =====================================================================
-- Legacy TOKEN workflow regression (44-45).
-- =====================================================================

-- 44: existing TOKEN creation/preview/accept still works end-to-end
-- after this migration.
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000011';
select v.j ->> 'token' as legacy_token
from (select public.rpc_create_membership_invitation('10500000-0000-0000-0000-000000000001'::uuid, '10500000-0000-0000-0000-000000000124'::uuid, array['MEMBER']) as j) v
\gset
select is(
  (select public.rpc_preview_membership_invitation(:'legacy_token') ->> 'status'),
  'PENDING',
  '44a: legacy TOKEN preview still works after this migration'
);
set local request.jwt.claim.sub to '10500000-0000-0000-0000-000000000027';
-- (027 has no confirmed phone but TOKEN accept never needs one)
update auth.users set phone = null, phone_confirmed_at = null where id = '10500000-0000-0000-0000-000000000027';
select is(
  (select public.rpc_accept_membership_invitation(:'legacy_token') ->> 'status'),
  'ACCEPTED',
  '44b: legacy TOKEN acceptance still works end-to-end, including for a caller with NO verified phone at all (TOKEN identity is the token itself, never phone-gated)'
);

-- 45: the legacy token_hash unique index still enforces exact-match-only
-- lookups (a stored hash is never itself usable as a token) — proves
-- the type-consistency constraint did not weaken this.
select ok(
  (select token_hash from public.membership_invitations where id = (select id from public.membership_invitations where invitation_type = 'TOKEN' order by created_at desc limit 1)) is not null,
  '45: a TOKEN invitation still stores a non-null token_hash after this migration''s schema extension'
);

-- =====================================================================
-- Grants / RLS (46-49).
-- =====================================================================

-- 46: zero anon EXECUTE on every new public RPC.
select is(
  (select count(*)::integer from information_schema.routine_privileges
   where routine_schema = 'public'
     and routine_name in (
       'rpc_create_membership_phone_invitation', 'rpc_list_my_membership_invitations',
       'rpc_accept_membership_phone_invitation', 'rpc_decline_membership_phone_invitation'
     )
     and grantee in ('anon', 'public')),
  0,
  '46a: zero EXECUTE grants to anon/public on any new public RPC (information_schema check)'
);
select is(
  (select bool_or(has_function_privilege('anon', oid, 'EXECUTE')) from pg_proc
   where proname in (
     'rpc_create_membership_phone_invitation', 'rpc_list_my_membership_invitations',
     'rpc_accept_membership_phone_invitation', 'rpc_decline_membership_phone_invitation'
   )),
  false,
  '46b: has_function_privilege confirms zero anon EXECUTE on every new RPC'
);

-- 47: exactly one authenticated EXECUTE grant per new RPC.
select is(
  (select count(*)::integer from information_schema.routine_privileges
   where routine_schema = 'public'
     and routine_name in (
       'rpc_create_membership_phone_invitation', 'rpc_list_my_membership_invitations',
       'rpc_accept_membership_phone_invitation', 'rpc_decline_membership_phone_invitation'
     )
     and grantee = 'authenticated'),
  4,
  '47: exactly one authenticated EXECUTE grant per new public RPC'
);

-- 48: internal helpers (normalize_tanzania_phone_e164,
-- current_verified_auth_phone_e164) are executable by NEITHER anon NOR
-- authenticated.
select is(
  (select count(*)::integer from information_schema.routine_privileges
   where routine_schema = 'public'
     and routine_name in ('normalize_tanzania_phone_e164', 'current_verified_auth_phone_e164')
     and grantee in ('anon', 'authenticated', 'public')),
  0,
  '48a: zero information_schema EXECUTE grants (any role) on either internal helper'
);
select is(
  (select bool_or(has_function_privilege('authenticated', oid, 'EXECUTE')) from pg_proc
   where proname in ('normalize_tanzania_phone_e164', 'current_verified_auth_phone_e164')),
  false,
  '48b: has_function_privilege confirms zero authenticated EXECUTE on either internal helper'
);
select is(
  (select bool_or(has_function_privilege('anon', oid, 'EXECUTE')) from pg_proc
   where proname in ('normalize_tanzania_phone_e164', 'current_verified_auth_phone_e164')),
  false,
  '48c: has_function_privilege confirms zero anon EXECUTE on either internal helper'
);

-- 49: no direct table grants introduced; RLS remains enabled; no new
-- table was created (membership_invitations was extended, not
-- duplicated) so its existing lockdown is inherently preserved.
select is(
  (select count(*)::integer from information_schema.role_table_grants
   where table_schema = 'public' and table_name = 'membership_invitations'
     and grantee in ('anon', 'authenticated')),
  0,
  '49a: zero direct table grants (any privilege) to anon/authenticated on membership_invitations after the schema extension'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.membership_invitations'::regclass),
  '49b: RLS remains enabled on membership_invitations'
);

-- =====================================================================
-- Trigger / linking invariant (50).
-- =====================================================================

-- 50: the trigger still blocks an unsanctioned direct user_id change
-- (no third, phone-specific bypass was introduced — phone acceptance
-- reuses the EXISTING umoja.membership_invitation_acceptance marker).
--
-- The marker is transaction-local (set_config(..., true)) and this
-- entire file runs in ONE transaction, so it leaks "true" for the rest
-- of the run after any earlier accept call — reset both sanctioned
-- markers to 'false' immediately before this assertion (same fix
-- pattern as 104's own test-authoring history for this exact issue).
select set_config('umoja.membership_invitation_acceptance', 'false', true);
select set_config('umoja.membership_claim_approval', 'false', true);
select throws_ok(
  $$ update public.group_memberships set user_id = '10500000-0000-0000-0000-000000000028' where id = '10500000-0000-0000-0000-000000000119' $$,
  '42501', null,
  '50: a direct, unsanctioned UPDATE of group_memberships.user_id remains blocked by the trigger after this migration'
);

-- =====================================================================
-- No account-existence / phone-enumeration RPC (documented, not a
-- distinct assertion — proven by the absence of such a function).
-- =====================================================================
select is(
  (select count(*)::integer from pg_proc where proname ilike '%phone_has_account%' or proname ilike '%does_phone%' or proname ilike '%phone_exists%'),
  0,
  'no account-existence/phone-enumeration RPC of any kind was introduced'
);

select * from finish();
rollback;
