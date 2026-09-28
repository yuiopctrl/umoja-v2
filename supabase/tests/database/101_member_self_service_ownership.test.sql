-- Prompt 09G-B1-A: Member Self-Service — canonical ownership/
-- authorization foundation. Proves current_membership_id()/
-- is_own_membership()/assert_self_or_permission() resolve ownership
-- purely from the group_memberships.user_id relationship (never role,
-- phone, or member_number), respect the exact same operational
-- invariant has_group_permission() already enforces, and change
-- nothing about has_group_permission() itself.
begin;

select plan(28);

insert into auth.users (id, email) values
  ('10100000-0000-0000-0000-000000000011', 'p09gb1a-admin@example.com'),
  ('10100000-0000-0000-0000-000000000012', 'p09gb1a-treasurer@example.com'),
  ('10100000-0000-0000-0000-000000000013', 'p09gb1a-member@example.com'),
  ('10100000-0000-0000-0000-000000000014', 'p09gb1a-suspended-member@example.com'),
  ('10100000-0000-0000-0000-000000000015', 'p09gb1a-in-suspended-group@example.com');

insert into public.groups (id, name, created_by, code, status) values
  ('10100000-0000-0000-0000-000000000001', 'Ownership Group A', '10100000-0000-0000-0000-000000000011', 'STB1A', 'ACTIVE'),
  ('10100000-0000-0000-0000-000000000002', 'Ownership Group B', '10100000-0000-0000-0000-000000000011', 'STB1B', 'ACTIVE'),
  ('10100000-0000-0000-0000-000000000003', 'Ownership Group C (suspended)', '10100000-0000-0000-0000-000000000011', 'STB1C', 'SUSPENDED');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number, phone) values
  ('10100000-0000-0000-0000-000000000101', '10100000-0000-0000-0000-000000000001', '10100000-0000-0000-0000-000000000011', 'Admin One', 'ACTIVE', '2025-01-01', 'STB1A-0001', null),
  ('10100000-0000-0000-0000-000000000102', '10100000-0000-0000-0000-000000000002', '10100000-0000-0000-0000-000000000011', 'Admin One (Group B)', 'ACTIVE', '2025-01-01', 'STB1B-0001', null),
  ('10100000-0000-0000-0000-000000000103', '10100000-0000-0000-0000-000000000001', '10100000-0000-0000-0000-000000000012', 'Treasurer Two', 'ACTIVE', '2025-01-01', 'STB1A-0002', '+255700000013'),
  ('10100000-0000-0000-0000-000000000104', '10100000-0000-0000-0000-000000000001', '10100000-0000-0000-0000-000000000013', 'Member Three', 'ACTIVE', '2025-01-01', 'STB1A-0003', '+255700000013'),
  ('10100000-0000-0000-0000-000000000105', '10100000-0000-0000-0000-000000000001', null, 'Roster Only Member', 'ACTIVE', '2025-01-01', 'STB1A-0004', null),
  ('10100000-0000-0000-0000-000000000106', '10100000-0000-0000-0000-000000000001', '10100000-0000-0000-0000-000000000014', 'Suspended Member Four', 'SUSPENDED', '2025-01-01', 'STB1A-0005', null),
  ('10100000-0000-0000-0000-000000000107', '10100000-0000-0000-0000-000000000003', '10100000-0000-0000-0000-000000000015', 'Member Five (Group C)', 'ACTIVE', '2025-01-01', 'STB1C-0001', null),
  ('10100000-0000-0000-0000-000000000108', '10100000-0000-0000-0000-000000000002', null, 'Roster Only (Group B, dup number)', 'ACTIVE', '2025-01-01', 'STB1A-0003', null);

insert into public.group_membership_roles (group_membership_id, role_id) select '10100000-0000-0000-0000-000000000101', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select '10100000-0000-0000-0000-000000000102', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id) select '10100000-0000-0000-0000-000000000103', id from public.roles where code = 'TREASURER';
insert into public.group_membership_roles (group_membership_id, role_id) select '10100000-0000-0000-0000-000000000104', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id) select '10100000-0000-0000-0000-000000000106', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id) select '10100000-0000-0000-0000-000000000107', id from public.roles where code = 'MEMBER';

-- =====================================================================
-- 5: unauthenticated caller cannot obtain ownership (no jwt sub set).
-- =====================================================================
set local role authenticated;

select is(
  public.current_membership_id('10100000-0000-0000-0000-000000000001'::uuid),
  null::uuid,
  '5a: current_membership_id returns null for an unauthenticated caller'
);
select is(
  public.is_own_membership('10100000-0000-0000-0000-000000000001'::uuid, '10100000-0000-0000-0000-000000000104'::uuid),
  false,
  '5b: is_own_membership is false for an unauthenticated caller, even against a real membership id'
);

-- =====================================================================
-- As Member Three (u13) — plain MEMBER role, owns membership 104.
-- =====================================================================
set local request.jwt.claim.sub to '10100000-0000-0000-0000-000000000013';

-- 1: authenticated linked member resolves own membership.
select is(
  public.current_membership_id('10100000-0000-0000-0000-000000000001'::uuid),
  '10100000-0000-0000-0000-000000000104'::uuid,
  '1: current_membership_id resolves Member Three''s own membership in group A'
);

-- 2: roster-only membership (no user_id) is never treated as owned.
select is(
  public.is_own_membership('10100000-0000-0000-0000-000000000001'::uuid, '10100000-0000-0000-0000-000000000105'::uuid),
  false,
  '2: a roster-only membership (user_id is null) is never treated as owned'
);

-- 3: another member's membership returns false.
select is(
  public.is_own_membership('10100000-0000-0000-0000-000000000001'::uuid, '10100000-0000-0000-0000-000000000103'::uuid),
  false,
  '3: another member''s (Treasurer Two) membership is never treated as Member Three''s own'
);

-- 4: cross-group membership returns false (own membership id, wrong group).
select is(
  public.is_own_membership('10100000-0000-0000-0000-000000000002'::uuid, '10100000-0000-0000-0000-000000000104'::uuid),
  false,
  '4: Member Three''s own membership id is never "owned" when queried against a different group'
);

-- 12: MEMBER may pass assert_self_or_permission for their OWN
-- membership without holding any administrative permission.
select lives_ok(
  $$ select public.assert_self_or_permission(
    '10100000-0000-0000-0000-000000000001'::uuid,
    '10100000-0000-0000-0000-000000000104'::uuid,
    'zz.nonexistent_permission'
  ) $$,
  '12: a plain MEMBER passes assert_self_or_permission for their own membership even with a nonexistent/ungranted permission code'
);

-- 13: MEMBER fails assert_self_or_permission for another membership.
select throws_ok(
  $$ select public.assert_self_or_permission(
    '10100000-0000-0000-0000-000000000001'::uuid,
    '10100000-0000-0000-0000-000000000103'::uuid,
    'zz.nonexistent_permission'
  ) $$,
  '42501',
  'Not authorized for this membership in this group',
  '13: a plain MEMBER is rejected by assert_self_or_permission for another member''s membership'
);

-- 14: substituting an arbitrary/nonexistent membership id (changing
-- the membership UUID) never exposes another member.
select is(
  public.is_own_membership('10100000-0000-0000-0000-000000000001'::uuid, gen_random_uuid()),
  false,
  '14: an arbitrary/nonexistent membership id substituted in place of the real one is never treated as owned'
);

-- 15: substituting an arbitrary/nonexistent group id (changing the
-- group UUID) never exposes another group.
select is(
  public.is_own_membership(gen_random_uuid(), '10100000-0000-0000-0000-000000000104'::uuid),
  false,
  '15: Member Three''s own membership id is never "owned" when queried against an arbitrary/nonexistent group'
);

-- 16: no ownership is inferred from a matching phone number — Treasurer
-- Two's membership shares the exact same phone as Member Three's own,
-- yet is still never treated as owned.
select is(
  public.is_own_membership('10100000-0000-0000-0000-000000000001'::uuid, '10100000-0000-0000-0000-000000000103'::uuid),
  false,
  '16: a membership sharing Member Three''s exact phone number is still never treated as owned'
);

-- 17: no ownership is inferred from a matching member_number — the
-- roster-only membership in Group B deliberately reuses Member
-- Three's own member_number string ("STB1A-0003"), yet is still never
-- treated as owned.
select is(
  public.is_own_membership('10100000-0000-0000-0000-000000000002'::uuid, '10100000-0000-0000-0000-000000000108'::uuid),
  false,
  '17: a membership in another group sharing Member Three''s member_number string is still never treated as owned'
);

-- 19b: has_group_permission's own behavior is unchanged for MEMBER.
select is(
  public.has_group_permission('10100000-0000-0000-0000-000000000001'::uuid, 'member.create'),
  false,
  '19b: has_group_permission still correctly denies member.create to a plain MEMBER (unchanged by this migration)'
);

-- =====================================================================
-- As Admin One (u11) — ADMIN role in group A, also a plain member of
-- group B.
-- =====================================================================
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to '10100000-0000-0000-0000-000000000011';

-- 8: a user with memberships in two groups resolves the correct
-- membership per group.
select is(
  public.current_membership_id('10100000-0000-0000-0000-000000000001'::uuid),
  '10100000-0000-0000-0000-000000000101'::uuid,
  '8a: current_membership_id resolves Admin One''s membership in group A'
);
select is(
  public.current_membership_id('10100000-0000-0000-0000-000000000002'::uuid),
  '10100000-0000-0000-0000-000000000102'::uuid,
  '8b: current_membership_id resolves Admin One''s DIFFERENT membership in group B'
);

-- 9/10: ownership works regardless of role — ADMIN's own membership
-- is recognized as owned exactly like a plain MEMBER's.
select is(
  public.is_own_membership('10100000-0000-0000-0000-000000000001'::uuid, '10100000-0000-0000-0000-000000000101'::uuid),
  true,
  '9a/10: an ADMIN''s own membership is recognized as owned'
);
select lives_ok(
  $$ select public.assert_self_or_permission(
    '10100000-0000-0000-0000-000000000001'::uuid,
    '10100000-0000-0000-0000-000000000101'::uuid,
    'zz.nonexistent_permission'
  ) $$,
  '10b: assert_self_or_permission passes for an ADMIN''s own membership via ownership alone, independent of role/permission'
);

-- 11: an ADMIN may pass assert_self_or_permission for ANOTHER member's
-- membership only when the supplied permission is genuinely granted —
-- self-ownership is additive to administrative permission, never a
-- replacement for it.
select lives_ok(
  $$ select public.assert_self_or_permission(
    '10100000-0000-0000-0000-000000000001'::uuid,
    '10100000-0000-0000-0000-000000000103'::uuid,
    'member.view'
  ) $$,
  '11a: an ADMIN passes assert_self_or_permission for another member''s membership when the permission (member.view) is genuinely granted'
);
select throws_ok(
  $$ select public.assert_self_or_permission(
    '10100000-0000-0000-0000-000000000001'::uuid,
    '10100000-0000-0000-0000-000000000103'::uuid,
    'zz.nonexistent_permission'
  ) $$,
  '42501',
  'Not authorized for this membership in this group',
  '11b: an ADMIN is rejected by assert_self_or_permission for another member''s membership when the supplied permission is not genuinely granted'
);

-- 19a: has_group_permission's own behavior is unchanged for ADMIN.
select is(
  public.has_group_permission('10100000-0000-0000-0000-000000000001'::uuid, 'member.view'),
  true,
  '19a: has_group_permission still correctly grants member.view to an ADMIN (unchanged by this migration)'
);

-- =====================================================================
-- As Treasurer Two (u12) — TREASURER role in group A.
-- =====================================================================
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to '10100000-0000-0000-0000-000000000012';

-- 9b: ownership works regardless of role — TREASURER.
select is(
  public.is_own_membership('10100000-0000-0000-0000-000000000001'::uuid, '10100000-0000-0000-0000-000000000103'::uuid),
  true,
  '9b: a TREASURER''s own membership is recognized as owned'
);

-- =====================================================================
-- As Suspended Member Four (u14) — membership itself is SUSPENDED in
-- an otherwise-ACTIVE group.
-- =====================================================================
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to '10100000-0000-0000-0000-000000000014';

-- 6: a SUSPENDED membership is never accepted as current ownership,
-- matching has_group_permission's own ACTIVE-membership requirement.
select is(
  public.current_membership_id('10100000-0000-0000-0000-000000000001'::uuid),
  null::uuid,
  '6: current_membership_id returns null for a caller whose own membership is SUSPENDED'
);

-- =====================================================================
-- As Member Five (u15) — ACTIVE membership, but the GROUP itself is
-- SUSPENDED.
-- =====================================================================
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to '10100000-0000-0000-0000-000000000015';

-- 7: an ACTIVE membership in a SUSPENDED group is never accepted as
-- current ownership, matching has_group_permission's own ACTIVE-group
-- requirement.
select is(
  public.current_membership_id('10100000-0000-0000-0000-000000000003'::uuid),
  null::uuid,
  '7: current_membership_id returns null when the membership''s own group is SUSPENDED, even though the membership row itself is ACTIVE'
);

-- =====================================================================
-- 18: helper execute grants are correctly locked down.
-- =====================================================================
reset role;

select is(
  (select count(*)::integer from information_schema.routine_privileges
   where routine_schema = 'public'
     and routine_name in ('current_membership_id', 'is_own_membership', 'assert_self_or_permission')
     and grantee in ('anon', 'public')),
  0,
  '18a: zero EXECUTE grants to anon/public exist on any of the three new ownership helpers'
);
select is(
  (select count(*)::integer from information_schema.routine_privileges
   where routine_schema = 'public'
     and routine_name in ('current_membership_id', 'is_own_membership', 'assert_self_or_permission')
     and grantee = 'authenticated'),
  3,
  '18b: exactly one EXECUTE grant to authenticated exists for each of the three new ownership helpers'
);

-- =====================================================================
-- 09G-DEPLOY-03: behavioral proof that anon cannot execute the three
-- helpers at all, independent of `information_schema.routine_
-- privileges` (which only reflects explicit GRANT/REVOKE statements —
-- it never captures a hosted-project default-privilege grant recorded
-- directly against a named role in pg_proc.proacl, which is exactly
-- how production carried a live anon EXECUTE grant despite 18a passing
-- locally). This calls each function AS anon and asserts PostgreSQL
-- itself raises 42501 permission-denied before the function body ever
-- runs, the same pattern already used for the claim-workflow RPCs in
-- 102/103.
reset role;
set local role anon;

select throws_ok(
  $$ select public.current_membership_id('10100000-0000-0000-0000-000000000001'::uuid) $$,
  '42501',
  null,
  '20a: anon cannot invoke current_membership_id'
);
select throws_ok(
  $$ select public.is_own_membership('10100000-0000-0000-0000-000000000001'::uuid, '10100000-0000-0000-0000-000000000104'::uuid) $$,
  '42501',
  null,
  '20b: anon cannot invoke is_own_membership'
);
select throws_ok(
  $$ select public.assert_self_or_permission('10100000-0000-0000-0000-000000000001'::uuid, '10100000-0000-0000-0000-000000000104'::uuid, 'member.view') $$,
  '42501',
  null,
  '20c: anon cannot invoke assert_self_or_permission'
);

reset role;

select * from finish();
rollback;
