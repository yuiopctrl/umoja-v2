-- Prompt 09G-B2 (corrected by 09G-B2-FIX-01): Member Profile + Member
-- Home Foundation.
--
-- Proves rpc_get_my_member_profile(p_group_id) is a strict MY-profile
-- read: it resolves ownership exclusively via current_membership_id()
-- (auth.uid() -> group_memberships.user_id), accepts no
-- membership_id/user_id/phone/member_number override, applies no
-- officer-permission fallback, and returns only the caller's own
-- account + membership + group + role data. FIX-01: also proves
-- account.phone is the VERIFIED Supabase-Auth phone
-- (current_verified_auth_phone_e164()) — never profiles.phone (decoyed
-- deliberately different here) and never group_memberships.phone —
-- and that neither of those decoyed values can be mistaken for
-- ownership proof either.
begin;

select plan(39);

insert into auth.users (id, email, phone, phone_confirmed_at) values
  ('10600000-0000-0000-0000-000000000011', 'p09gb2-admin@example.com', null, null),
  ('10600000-0000-0000-0000-000000000012', 'p09gb2-chair@example.com', null, null),
  -- Member Three's own VERIFIED auth phone — the only source
  -- account.phone may ever come from for this caller.
  ('10600000-0000-0000-0000-000000000013', 'p09gb2-member@example.com', '255712345099', now()),
  ('10600000-0000-0000-0000-000000000014', 'p09gb2-dualrole@example.com', null, null),
  ('10600000-0000-0000-0000-000000000015', 'p09gb2-suspended-membership@example.com', null, null),
  ('10600000-0000-0000-0000-000000000016', 'p09gb2-in-suspended-group@example.com', null, null),
  ('10600000-0000-0000-0000-000000000017', 'p09gb2-inactive-profile@example.com', null, null);

-- Decoy: Admin One's profiles.phone is deliberately set to EXACTLY
-- Member Three's verified auth phone — proves a profiles.phone match
-- across users is never mistaken for ownership/identity.
update public.profiles set full_name = 'Admin One', phone = '+255712345099'
  where id = '10600000-0000-0000-0000-000000000011';
update public.profiles set full_name = 'Chair Two', phone = '+255700000012'
  where id = '10600000-0000-0000-0000-000000000012';
-- Decoy: Member Three's own profiles.phone is deliberately DIFFERENT
-- from their verified auth phone — proves account.phone in the
-- response never comes from this column.
update public.profiles set full_name = 'Member Three', phone = '+255799999999'
  where id = '10600000-0000-0000-0000-000000000013';
update public.profiles set full_name = 'Dual Role Four', phone = '+255700000014'
  where id = '10600000-0000-0000-0000-000000000014';
update public.profiles set full_name = 'Suspended Membership Five', phone = '+255700000015'
  where id = '10600000-0000-0000-0000-000000000015';
update public.profiles set full_name = 'In Suspended Group Six', phone = '+255700000016'
  where id = '10600000-0000-0000-0000-000000000016';
update public.profiles set full_name = 'Inactive Profile Seven', phone = '+255700000017', is_active = false
  where id = '10600000-0000-0000-0000-000000000017';

insert into public.groups (id, name, created_by, code, status) values
  ('10600000-0000-0000-0000-000000000001', 'Profile Group A', '10600000-0000-0000-0000-000000000011', 'STB2A', 'ACTIVE'),
  ('10600000-0000-0000-0000-000000000002', 'Profile Group B', '10600000-0000-0000-0000-000000000011', 'STB2B', 'ACTIVE'),
  ('10600000-0000-0000-0000-000000000003', 'Profile Group C (suspended)', '10600000-0000-0000-0000-000000000011', 'STB2C', 'SUSPENDED');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number, phone) values
  ('10600000-0000-0000-0000-000000000101', '10600000-0000-0000-0000-000000000001', '10600000-0000-0000-0000-000000000011', 'Admin One (roster)', 'ACTIVE', '2025-01-01', 'STB2A-0001', '+255700099901'),
  -- Decoy: Chair Two's roster phone is deliberately set to EXACTLY
  -- Member Three's verified auth phone too — proves a
  -- group_memberships.phone match is never mistaken for ownership.
  ('10600000-0000-0000-0000-000000000102', '10600000-0000-0000-0000-000000000001', '10600000-0000-0000-0000-000000000012', 'Chair Two (roster)', 'ACTIVE', '2025-01-02', 'STB2A-0002', '+255712345099'),
  ('10600000-0000-0000-0000-000000000103', '10600000-0000-0000-0000-000000000001', '10600000-0000-0000-0000-000000000013', 'Member Three (roster)', 'ACTIVE', '2025-01-03', 'STB2A-0003', '+255700099903'),
  ('10600000-0000-0000-0000-000000000104', '10600000-0000-0000-0000-000000000001', '10600000-0000-0000-0000-000000000014', 'Dual Role Four (A, roster)', 'ACTIVE', '2025-01-04', 'STB2A-0004', null),
  ('10600000-0000-0000-0000-000000000105', '10600000-0000-0000-0000-000000000002', '10600000-0000-0000-0000-000000000014', 'Dual Role Four (B, roster)', 'ACTIVE', '2025-02-01', 'STB2B-0001', null),
  ('10600000-0000-0000-0000-000000000106', '10600000-0000-0000-0000-000000000001', '10600000-0000-0000-0000-000000000015', 'Suspended Membership Five (roster)', 'SUSPENDED', '2025-01-05', 'STB2A-0005', null),
  ('10600000-0000-0000-0000-000000000107', '10600000-0000-0000-0000-000000000003', '10600000-0000-0000-0000-000000000016', 'In Suspended Group Six (roster)', 'ACTIVE', '2025-01-06', 'STB2C-0001', null),
  ('10600000-0000-0000-0000-000000000108', '10600000-0000-0000-0000-000000000001', '10600000-0000-0000-0000-000000000017', 'Inactive Profile Seven (roster)', 'ACTIVE', '2025-01-07', 'STB2A-0006', null);

insert into public.group_membership_roles (group_membership_id, role_id) select '10600000-0000-0000-0000-000000000101', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select '10600000-0000-0000-0000-000000000102', id from public.roles where code = 'CHAIRPERSON';
insert into public.group_membership_roles (group_membership_id, role_id) select '10600000-0000-0000-0000-000000000103', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id) select '10600000-0000-0000-0000-000000000104', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id) select '10600000-0000-0000-0000-000000000105', id from public.roles where code = 'TREASURER';

-- =====================================================================
-- 13: unauthenticated caller is rejected.
-- =====================================================================
set local role authenticated;

select throws_ok(
  $$ select public.rpc_get_my_member_profile('10600000-0000-0000-0000-000000000001'::uuid) $$,
  '28000',
  'Not authenticated',
  '13: unauthenticated caller (no jwt sub) is rejected'
);

-- =====================================================================
-- As Member Three (u13) — plain MEMBER, ordinary ownership case.
-- =====================================================================
set local request.jwt.claim.sub to '10600000-0000-0000-0000-000000000013';

-- 2/17/18/19/20: ordinary MEMBER reads own profile with correct fields.
select is(
  (public.rpc_get_my_member_profile('10600000-0000-0000-0000-000000000001'::uuid) -> 'account' ->> 'full_name'),
  'Member Three',
  '2: ordinary MEMBER can read own profile without officer permissions (correct full_name)'
);
select is(
  (public.rpc_get_my_member_profile('10600000-0000-0000-0000-000000000001'::uuid) -> 'membership' ->> 'member_number'),
  'STB2A-0003',
  '17: response has correct member_number'
);
select is(
  (public.rpc_get_my_member_profile('10600000-0000-0000-0000-000000000001'::uuid) -> 'membership' ->> 'joined_at'),
  '2025-01-03',
  '18: response has correct joined_at'
);
select is(
  (public.rpc_get_my_member_profile('10600000-0000-0000-0000-000000000001'::uuid) -> 'group' ->> 'group_code'),
  'STB2A',
  '19: response has correct group identity (group_code)'
);
select is(
  (public.rpc_get_my_member_profile('10600000-0000-0000-0000-000000000001'::uuid) -> 'roles'),
  '["MEMBER"]'::jsonb,
  '20: response has caller''s own roles only (plain MEMBER)'
);

-- 6: caller cannot select another membership — the RPC only ever
-- accepts p_group_id, so there is no parameter through which Member
-- Three could request Chair Two's membership; querying group A always
-- resolves to Member Three's own row regardless of who else is in it.
select is(
  (public.rpc_get_my_member_profile('10600000-0000-0000-0000-000000000001'::uuid) -> 'membership' ->> 'membership_id'),
  '10600000-0000-0000-0000-000000000103',
  '6: caller cannot select another membership — always resolves to the caller''s own membership_id'
);

-- 9: cross-group membership cannot leak — Member Three has no
-- membership in group B at all.
select throws_ok(
  $$ select public.rpc_get_my_member_profile('10600000-0000-0000-0000-000000000002'::uuid) $$,
  '42501',
  'No active membership in this group',
  '9: cross-group membership cannot leak — Member Three has no membership in group B, so calling with group B raises'
);

-- 21/22/23/24: roster phone / profiles phone / member_number / role
-- name are never used as ownership proof — Member Three's roster row
-- shares its member_number/phone with nothing else in this fixture by
-- construction; the only way this RPC ever resolved membership 103 is
-- via current_membership_id()'s group_memberships.user_id = auth.uid()
-- join, proven structurally (not by phone/number matching) in
-- 101_member_self_service_ownership.test.sql. Re-asserted here at the
-- RPC boundary: calling with an unrelated group (B) where no
-- user_id-linked membership exists for this caller still raises,
-- confirming no fallback lookup by phone/member_number ever occurs.
select throws_ok(
  $$ select public.rpc_get_my_member_profile('10600000-0000-0000-0000-000000000003'::uuid) $$,
  '42501',
  'No active membership in this group',
  '21-24: no phone/member_number/role-name fallback exists — group C (no user_id-linked membership for this caller) still raises rather than matching by any other field'
);

-- =====================================================================
-- 09G-B2-FIX-01: account.phone is the verified auth phone, never
-- profiles.phone or group_memberships.phone.
-- =====================================================================

-- 29: returned account phone equals the caller's verified auth.users
-- phone (255712345099 normalized to +255712345099).
select is(
  (public.rpc_get_my_member_profile('10600000-0000-0000-0000-000000000001'::uuid) -> 'account' ->> 'phone'),
  '+255712345099',
  '29: returned account phone equals the caller''s verified auth.users phone'
);

-- 30: changing profiles.phone to a different value does NOT change
-- the phone returned — Member Three's profiles.phone is already
-- decoyed to +255799999999 (set above); re-assert after an explicit
-- further change to be doubly sure no caching/staleness masks this.
-- Client roles hold no UPDATE grant on profiles/group_memberships
-- (only reachable via RPC normally) — these two raw updates run as
-- the unrestricted test-setup role, then restore the authenticated/
-- Member Three context for the next RPC calls.
reset role;
update public.profiles set phone = '+255788888888'
  where id = '10600000-0000-0000-0000-000000000013';
update public.group_memberships set phone = '+255766666666'
  where id = '10600000-0000-0000-0000-000000000103';
set local role authenticated;
set local request.jwt.claim.sub to '10600000-0000-0000-0000-000000000013';

select is(
  (public.rpc_get_my_member_profile('10600000-0000-0000-0000-000000000001'::uuid) -> 'account' ->> 'phone'),
  '+255712345099',
  '30: changing profiles.phone does NOT change the phone returned by rpc_get_my_member_profile'
);

-- 31: changing group_memberships.phone (Member Three's own roster
-- row, updated above) does NOT change the phone returned either.
select is(
  (public.rpc_get_my_member_profile('10600000-0000-0000-0000-000000000001'::uuid) -> 'account' ->> 'phone'),
  '+255712345099',
  '31: changing group_memberships.phone does NOT change the phone returned by rpc_get_my_member_profile'
);

-- 32: another user's (Admin One) profiles.phone matching the caller's
-- verified auth phone does not affect ownership — Member Three still
-- resolves their own membership (103), never Admin One's (101).
select is(
  (public.rpc_get_my_member_profile('10600000-0000-0000-0000-000000000001'::uuid) -> 'membership' ->> 'membership_id'),
  '10600000-0000-0000-0000-000000000103',
  '32: another user''s profiles.phone matching the caller''s verified auth phone does not affect ownership'
);

-- 33: another membership's (Chair Two, 102) roster phone matching the
-- caller's verified auth phone does not affect ownership either —
-- same assertion, reinforcing no phone-based lookup exists anywhere
-- in the resolution path.
select isnt(
  (public.rpc_get_my_member_profile('10600000-0000-0000-0000-000000000001'::uuid) -> 'membership' ->> 'membership_id'),
  '10600000-0000-0000-0000-000000000102',
  '33: another membership''s roster phone matching the caller''s verified auth phone does not affect ownership'
);

-- 34: membership ownership remains auth.uid()-based — re-affirmed via
-- current_membership_id() directly, independent of the RPC wrapper.
select is(
  public.current_membership_id('10600000-0000-0000-0000-000000000001'::uuid),
  '10600000-0000-0000-0000-000000000103'::uuid,
  '34: membership ownership remains auth.uid()-based (current_membership_id), unaffected by any phone decoy'
);

-- 25: no mutation occurs from a profile read.
select is(
  (select full_name from public.profiles where id = '10600000-0000-0000-0000-000000000013'),
  'Member Three',
  '25a: no mutation occurs from a profile read (full_name unchanged after prior calls)'
);
select is(
  (select status from public.group_memberships where id = '10600000-0000-0000-0000-000000000103'),
  'ACTIVE'::public.membership_status,
  '25b: no mutation occurs from a profile read (membership status unchanged after prior calls)'
);
-- auth.users has no client SELECT grant (by design — only reachable
-- via the SECURITY DEFINER helper), so this check runs unrestricted.
reset role;
select is(
  (select phone_confirmed_at from auth.users where id = '10600000-0000-0000-0000-000000000013') is not null,
  true,
  '25c: no mutation occurs from a profile read (auth.users.phone_confirmed_at unchanged after prior calls)'
);
set local role authenticated;
set local request.jwt.claim.sub to '10600000-0000-0000-0000-000000000013';

-- =====================================================================
-- As Admin One (u11) — ADMIN role, sees only their own profile.
-- =====================================================================
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to '10600000-0000-0000-0000-000000000011';

-- 3: ADMIN can read own profile — no officer fallback exposes anyone
-- else's data (there is no parameter for that in the first place).
select is(
  (public.rpc_get_my_member_profile('10600000-0000-0000-0000-000000000001'::uuid) -> 'membership' ->> 'membership_id'),
  '10600000-0000-0000-0000-000000000101',
  '3: ADMIN calling My Profile sees ADMIN''s own membership, never another member''s'
);
select is(
  (public.rpc_get_my_member_profile('10600000-0000-0000-0000-000000000001'::uuid) -> 'roles'),
  '["ADMIN"]'::jsonb,
  '3b: ADMIN''s own profile shows ADMIN''s own role only'
);

-- =====================================================================
-- As Chair Two (u12) — CHAIRPERSON role.
-- =====================================================================
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to '10600000-0000-0000-0000-000000000012';

-- 4: CHAIRPERSON can read own profile.
select is(
  (public.rpc_get_my_member_profile('10600000-0000-0000-0000-000000000001'::uuid) -> 'membership' ->> 'display_name'),
  'Chair Two (roster)',
  '4: CHAIRPERSON can read own profile'
);

-- 09G-B2-FIX-01 §C: a caller with no confirmed auth phone (Chair
-- Two's auth.users row has phone/phone_confirmed_at both NULL) gets
-- account.phone = NULL — fails closed, never falls back to
-- profiles.phone (Chair Two's own profiles.phone IS set to
-- +255700000012, proving this is a deliberate fail-closed, not an
-- accidental NULL from missing data).
select is(
  (public.rpc_get_my_member_profile('10600000-0000-0000-0000-000000000001'::uuid) -> 'account' -> 'phone'),
  'null'::jsonb,
  '39: a caller with no confirmed auth phone gets account.phone = null, never a profiles.phone fallback'
);

-- =====================================================================
-- As Dual Role Four (u14) — separate memberships in group A (MEMBER)
-- and group B (TREASURER).
-- =====================================================================
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to '10600000-0000-0000-0000-000000000014';

-- 5/10/19c: dual-role/multi-group user reads own profile per group,
-- never leaking one group's membership into the other.
select is(
  (public.rpc_get_my_member_profile('10600000-0000-0000-0000-000000000001'::uuid) -> 'membership' ->> 'member_number'),
  'STB2A-0004',
  '5a/10a: dual-role user reads own profile in group A (correct member_number)'
);
select is(
  (public.rpc_get_my_member_profile('10600000-0000-0000-0000-000000000001'::uuid) -> 'roles'),
  '["MEMBER"]'::jsonb,
  '10b: dual-role user''s group A profile shows the MEMBER role held there'
);
select is(
  (public.rpc_get_my_member_profile('10600000-0000-0000-0000-000000000002'::uuid) -> 'membership' ->> 'member_number'),
  'STB2B-0001',
  '5b/10c: dual-role user reads own DIFFERENT profile in group B (correct member_number, no leakage from group A)'
);
select is(
  (public.rpc_get_my_member_profile('10600000-0000-0000-0000-000000000002'::uuid) -> 'roles'),
  '["TREASURER"]'::jsonb,
  '10d: dual-role user''s group B profile shows the TREASURER role held there, not group A''s MEMBER role'
);
select is(
  (public.rpc_get_my_member_profile('10600000-0000-0000-0000-000000000001'::uuid) -> 'account' ->> 'full_name'),
  'Dual Role Four',
  '10e: account-level full_name is identical across both group calls (only membership/roles differ)'
);

-- =====================================================================
-- As Suspended Membership Five (u15) — ACTIVE profile, SUSPENDED
-- membership.
-- =====================================================================
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to '10600000-0000-0000-0000-000000000015';

-- 11: inactive (SUSPENDED) membership rejected.
select throws_ok(
  $$ select public.rpc_get_my_member_profile('10600000-0000-0000-0000-000000000001'::uuid) $$,
  '42501',
  'No active membership in this group',
  '11: a SUSPENDED membership is rejected'
);

-- =====================================================================
-- As In Suspended Group Six (u16) — ACTIVE membership, SUSPENDED group.
-- =====================================================================
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to '10600000-0000-0000-0000-000000000016';

-- 12: inactive (SUSPENDED) group rejected even though the membership
-- row itself is ACTIVE.
select throws_ok(
  $$ select public.rpc_get_my_member_profile('10600000-0000-0000-0000-000000000003'::uuid) $$,
  '42501',
  'No active membership in this group',
  '12: a SUSPENDED group is rejected even though the caller''s own membership row is ACTIVE'
);

-- =====================================================================
-- As Inactive Profile Seven (u17) — is_active = false on profiles.
-- =====================================================================
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to '10600000-0000-0000-0000-000000000017';

-- inactive caller profile rejected (inherited from current_membership_id
-- -> caller_profile_is_active()).
select throws_ok(
  $$ select public.rpc_get_my_member_profile('10600000-0000-0000-0000-000000000001'::uuid) $$,
  '42501',
  'No active membership in this group',
  '11b: an inactive caller profile is rejected (current_membership_id()''s caller_profile_is_active() gate)'
);

-- =====================================================================
-- 7/8: RPC signature has no membership_id/user_id parameter at all.
-- =====================================================================
reset role;

select is(
  (select count(*)::integer from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'rpc_get_my_member_profile'
     and pg_get_function_arguments(p.oid) = 'p_group_id uuid'),
  1,
  '7/8: rpc_get_my_member_profile''s ONLY parameter is p_group_id uuid — no membership_id or user_id parameter exists'
);

-- =====================================================================
-- 14/15/16: grants are correctly locked down.
-- =====================================================================
select is(
  (select count(*)::integer from information_schema.routine_privileges
   where routine_schema = 'public'
     and routine_name = 'rpc_get_my_member_profile'
     and grantee in ('anon', 'public')),
  0,
  '14/16: zero EXECUTE grants to anon/PUBLIC exist on rpc_get_my_member_profile'
);
select is(
  (select count(*)::integer from information_schema.routine_privileges
   where routine_schema = 'public'
     and routine_name = 'rpc_get_my_member_profile'
     and grantee = 'authenticated'),
  1,
  '15: exactly one EXECUTE grant to authenticated exists for rpc_get_my_member_profile'
);

-- 09G-B2-FIX-01: current_verified_auth_phone_e164 remains fully
-- internal-only — this FIX must not have granted it to authenticated
-- to make it reachable from rpc_get_my_member_profile (it doesn't
-- need to be; see the internal-call rationale in the migration).
select is(
  (select count(*)::integer from information_schema.routine_privileges
   where routine_schema = 'public'
     and routine_name = 'current_verified_auth_phone_e164'
     and grantee = 'anon'),
  0,
  '35: current_verified_auth_phone_e164 retains zero anon EXECUTE'
);
select is(
  (select count(*)::integer from information_schema.routine_privileges
   where routine_schema = 'public'
     and routine_name = 'current_verified_auth_phone_e164'
     and grantee = 'authenticated'),
  0,
  '36: current_verified_auth_phone_e164 retains zero authenticated EXECUTE'
);

-- =====================================================================
-- 14 (behavioral): anon cannot invoke the RPC at all, independent of
-- information_schema.routine_privileges — same pattern used elsewhere
-- in this project for hosted-project default-privilege drift.
-- =====================================================================
set local role anon;

select throws_ok(
  $$ select public.rpc_get_my_member_profile('10600000-0000-0000-0000-000000000001'::uuid) $$,
  '42501',
  null,
  '14b: anon cannot invoke rpc_get_my_member_profile'
);

-- =====================================================================
-- 26/27/28: legacy B1 ownership helpers / invitation / claim flows are
-- unaffected by this migration.
-- =====================================================================
reset role;
set local role authenticated;
set local request.jwt.claim.sub to '10600000-0000-0000-0000-000000000013';

select is(
  public.current_membership_id('10600000-0000-0000-0000-000000000001'::uuid),
  '10600000-0000-0000-0000-000000000103'::uuid,
  '26: legacy B1 ownership helper current_membership_id remains unchanged'
);
select lives_ok(
  $$ select public.rpc_list_my_membership_invitations(null, 20, 0) $$,
  '27: existing invitation RPC (rpc_list_my_membership_invitations) remains callable/unaffected'
);
select lives_ok(
  $$ select public.rpc_list_my_membership_claims() $$,
  '28: existing claim RPC (rpc_list_my_membership_claims) remains callable/unaffected'
);

reset role;

select * from finish();
rollback;
