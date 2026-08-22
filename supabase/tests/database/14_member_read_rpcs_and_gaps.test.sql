-- Prompt 04: Members Management — read RPCs (rpc_list_group_members,
-- rpc_get_group_member) plus a few previously-untested invariants the
-- prompt specifically calls out (member creation never touches
-- auth/profile data; member.edit structurally cannot mutate status).
begin;

select plan(40);

insert into auth.users (id, email) values
  ('d0000000-0000-0000-0000-000000000001', 'admin-a@example.com'),
  ('d0000000-0000-0000-0000-000000000002', 'secretary-a@example.com'),
  ('d0000000-0000-0000-0000-000000000003', 'norole-a@example.com'),
  ('d0000000-0000-0000-0000-000000000004', 'suspended-caller-a@example.com'),
  ('d0000000-0000-0000-0000-000000000005', 'admin-b@example.com');

insert into public.groups (id, name, status, created_by, code) values
  ('d1000000-0000-0000-0000-000000000001', 'Group Alpha', 'ACTIVE', 'd0000000-0000-0000-0000-000000000001', 'RDA1'),
  ('d1000000-0000-0000-0000-000000000002', 'Group Beta', 'ACTIVE', 'd0000000-0000-0000-0000-000000000005', 'RDA2'),
  ('d1000000-0000-0000-0000-000000000003', 'Group Suspended', 'SUSPENDED', 'd0000000-0000-0000-0000-000000000001', 'RDA3');

-- Callers.
insert into public.group_memberships (id, group_id, user_id, display_name, status, member_number) values
  ('d2000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', 'Admin A', 'ACTIVE', 'RDA1-2026-0001'),
  ('d2000000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000002', 'Secretary A', 'ACTIVE', 'RDA1-2026-0002'),
  ('d2000000-0000-0000-0000-000000000003', 'd1000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000003', 'No Role A', 'ACTIVE', 'RDA1-2026-0003'),
  ('d2000000-0000-0000-0000-000000000004', 'd1000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000004', 'Suspended Caller A', 'SUSPENDED', 'RDA1-2026-0004'),
  ('d2000000-0000-0000-0000-000000000005', 'd1000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000005', 'Admin B', 'ACTIVE', 'RDA2-2026-0001'),
  ('d2000000-0000-0000-0000-000000000006', 'd1000000-0000-0000-0000-000000000003', 'd0000000-0000-0000-0000-000000000001', 'Admin A (Suspended Group)', 'ACTIVE', 'RDA3-2026-0001');

insert into public.group_membership_roles (group_membership_id, role_id)
select 'd2000000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id)
select 'd2000000-0000-0000-0000-000000000002', id from public.roles where code = 'SECRETARY';
-- d2...0003 (No Role A) intentionally has no role assigned at all, so
-- it has no permissions, including member.view.
insert into public.group_membership_roles (group_membership_id, role_id)
select 'd2000000-0000-0000-0000-000000000004', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id)
select 'd2000000-0000-0000-0000-000000000005', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id)
select 'd2000000-0000-0000-0000-000000000006', id from public.roles where code = 'ADMIN';

-- Ordinary members of Group Alpha to list/search/filter over.
insert into public.group_memberships (id, group_id, user_id, display_name, member_number, phone, status) values
  ('d3000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000001', null, 'Amina Juma', 'M-001', '+255700000001', 'ACTIVE'),
  ('d3000000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000001', null, 'Baraka Msigwa', 'M-002', '+255700000002', 'ACTIVE'),
  ('d3000000-0000-0000-0000-000000000003', 'd1000000-0000-0000-0000-000000000001', null, 'Chiku Ally', 'M-003', '+255700000003', 'SUSPENDED'),
  ('d3000000-0000-0000-0000-000000000004', 'd1000000-0000-0000-0000-000000000001', null, 'Daudi Petro', 'M-004', '+255700000004', 'EXITED');

-- A member belonging to Group Beta, for cross-group leakage checks.
insert into public.group_memberships (id, group_id, user_id, display_name, member_number, status) values
  ('d3000000-0000-0000-0000-000000000005', 'd1000000-0000-0000-0000-000000000002', null, 'Zainab Foreign', 'M-900', 'ACTIVE');

-- Group Alpha now has 8 memberships total: 4 "caller" fixtures + 4
-- ordinary members (Amina/Baraka ACTIVE, Chiku SUSPENDED, Daudi EXITED).

set local role authenticated;

-- ---------------------------------------------------------------------
-- As Admin A (member.view + role.view in Group Alpha).
-- ---------------------------------------------------------------------
set local request.jwt.claim.sub to 'd0000000-0000-0000-0000-000000000001';

-- 1. member.view caller can list members in own group.
create temporary table t_list_admin as
select public.rpc_list_group_members('d1000000-0000-0000-0000-000000000001') as result;

select is(
  ((select result from t_list_admin) ->> 'total_count')::int,
  8,
  'Admin A lists all 8 memberships in Group Alpha'
);

select is(
  jsonb_array_length((select result from t_list_admin) -> 'items'),
  8,
  'the default page returns all 8 items (page size 25 > 8)'
);

-- 2. role.view holder sees populated roles for a row that has a role.
select ok(
  (
    select m -> 'roles' @> '["ADMIN"]'::jsonb
    from jsonb_array_elements((select result from t_list_admin) -> 'items') m
    where m ->> 'membership_id' = 'd2000000-0000-0000-0000-000000000001'
  ),
  'a role.view holder sees Admin A''s own ADMIN role in the list'
);

-- 13. Cross-group detail request: Admin A has member.view in Group
-- Alpha, but Zainab belongs to Group Beta — mismatched group_id must
-- be treated as not found, not leaked.
select throws_ok(
  $$ select public.rpc_get_group_member('d1000000-0000-0000-0000-000000000001', 'd3000000-0000-0000-0000-000000000005') $$,
  '22023',
  null,
  'a membership from a different group is "not found", not returned, even to an authorized caller'
);

-- 14. Search by full name.
create temporary table t_search_name as
select public.rpc_list_group_members('d1000000-0000-0000-0000-000000000001', 'Amina') as result;

select is(
  ((select result from t_search_name) ->> 'total_count')::int,
  1,
  'search by name returns exactly one match'
);

select is(
  (select result from t_search_name) -> 'items' -> 0 ->> 'display_name',
  'Amina Juma',
  'search by name returns the correct member'
);

-- 15. Search by member_number.
select is(
  (
    (select public.rpc_list_group_members('d1000000-0000-0000-0000-000000000001', 'M-002')) -> 'items' -> 0 ->> 'display_name'
  ),
  'Baraka Msigwa',
  'search by member_number returns the correct member'
);

-- 16. Search by phone.
select is(
  (
    (select public.rpc_list_group_members('d1000000-0000-0000-0000-000000000001', '+255700000003')) -> 'items' -> 0 ->> 'display_name'
  ),
  'Chiku Ally',
  'search by phone returns the correct member'
);

-- 17, 18, 19. Status filter.
select is(
  ((select public.rpc_list_group_members('d1000000-0000-0000-0000-000000000001', null, 'ACTIVE')) ->> 'total_count')::int,
  5,
  'status filter ACTIVE returns exactly the 5 ACTIVE memberships'
);

select is(
  ((select public.rpc_list_group_members('d1000000-0000-0000-0000-000000000001', null, 'SUSPENDED')) ->> 'total_count')::int,
  2,
  'status filter SUSPENDED returns exactly the 2 SUSPENDED memberships'
);

select is(
  ((select public.rpc_list_group_members('d1000000-0000-0000-0000-000000000001', null, 'EXITED')) ->> 'total_count')::int,
  1,
  'status filter EXITED returns exactly the 1 EXITED membership'
);

-- 20. Pagination: page 1 and page 2 of size 2 are non-overlapping and total_count is stable.
create temporary table t_page1 as
select public.rpc_list_group_members('d1000000-0000-0000-0000-000000000001', null, null, 2, 0) as result;
create temporary table t_page4 as
select public.rpc_list_group_members('d1000000-0000-0000-0000-000000000001', null, null, 2, 6) as result;

select is(
  jsonb_array_length((select result from t_page1) -> 'items'),
  2,
  'page 1 (limit 2, offset 0) returns 2 items'
);

select is(
  jsonb_array_length((select result from t_page4) -> 'items'),
  2,
  'page 4 (limit 2, offset 6) returns the remaining 2 items'
);

select is(
  ((select result from t_page4) ->> 'total_count')::int,
  8,
  'total_count is stable across pages'
);

-- 22. Requested limit above the max is capped at 100.
select is(
  (((select public.rpc_list_group_members('d1000000-0000-0000-0000-000000000001', null, null, 500, 0))) ->> 'limit')::int,
  100,
  'a requested limit above 100 is capped at 100'
);

-- A search term over 100 characters is rejected outright, not silently
-- truncated.
select throws_ok(
  $$ select public.rpc_list_group_members('d1000000-0000-0000-0000-000000000001', repeat('a', 101)) $$,
  '22023',
  'Search term too long',
  'a search term longer than 100 characters is rejected, not truncated'
);

-- 21. Listing Group Beta never includes a Group Alpha member. Admin A
-- (the actor above) has no membership in Group Beta at all, so this
-- must run as Admin B, who holds member.view there.
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to 'd0000000-0000-0000-0000-000000000005';

create temporary table t_list_beta as
select public.rpc_list_group_members('d1000000-0000-0000-0000-000000000002') as result;

select is(
  ((select result from t_list_beta) ->> 'total_count')::int,
  2,
  'Group Beta has exactly its own 2 memberships (Admin B + Zainab)'
);

select is(
  (
    select bool_and((m ->> 'group_id') = 'd1000000-0000-0000-0000-000000000002')
    from jsonb_array_elements((select result from t_list_beta) -> 'items') m
  ),
  true,
  'every item returned for Group Beta actually belongs to Group Beta'
);

-- Restore the actor to Admin A for the remaining Group Alpha happy-path
-- assertions below.
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to 'd0000000-0000-0000-0000-000000000001';

-- 23. rpc_get_group_member happy path.
create temporary table t_get_amina as
select public.rpc_get_group_member('d1000000-0000-0000-0000-000000000001', 'd3000000-0000-0000-0000-000000000001') as result;

select is(
  (select result from t_get_amina) ->> 'display_name',
  'Amina Juma',
  'rpc_get_group_member returns the correct member'
);

select is(
  ((select result from t_get_amina) ->> 'is_login_linked')::boolean,
  false,
  'a member created without an auth account reports is_login_linked = false'
);

select ok(
  (select result from t_get_amina) -> 'roles' @> '[]'::jsonb,
  'role.view holder sees a (possibly empty) roles array, not null'
);

-- 25. Creating a member never creates an auth.users/profiles row.
-- `authenticated` has no direct SELECT on auth.users by design (Supabase
-- restricts client access to the auth schema), so these integrity
-- counts run under the test-harness role instead of `authenticated`.
-- This does not change what the RPC itself is granted or how it
-- authorizes the caller — auth.uid() is resolved from the JWT claim GUC
-- either way, so rpc_create_group_member below still runs as Admin A.
reset role;

select is(
  (select count(*) from auth.users),
  5::bigint,
  'auth.users count before member creation'
);

create temporary table t_new_member as
select public.rpc_create_group_member('d1000000-0000-0000-0000-000000000001', 'Fresh Member') as result;

select is(
  (select count(*) from auth.users),
  5::bigint,
  'creating a member does not create an auth.users row'
);

select is(
  (select count(*) from public.profiles where id not in (select id from auth.users)),
  0::bigint,
  'creating a member does not create an orphan profiles row'
);

select is(
  ((select result from t_new_member) ->> 'status'),
  'ACTIVE',
  'the newly created member is ACTIVE with user_id left null (member.create still works)'
);

-- Restore the authenticated role for the remaining permission-sensitive
-- assertions below.
set local role authenticated;

-- 26. member.edit (rpc_update_group_member) cannot structurally mutate status.
select is(
  pg_get_function_identity_arguments('public.rpc_update_group_member(uuid, uuid, text, text, text, date)'::regprocedure) !~* 'status',
  true,
  'rpc_update_group_member''s signature has no status parameter — status can only change via rpc_change_group_member_status'
);

-- ---------------------------------------------------------------------
-- As Secretary A (member.view, but NOT role.view).
-- ---------------------------------------------------------------------
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to 'd0000000-0000-0000-0000-000000000002';

-- 3 & 4. member.view without role.view: list works, roles are null.
-- 9, not 8: the "Fresh Member" created just above (test 25) is a
-- permanent addition to Group Alpha for the rest of this script.
create temporary table t_list_secretary as
select public.rpc_list_group_members('d1000000-0000-0000-0000-000000000001') as result;

select is(
  ((select result from t_list_secretary) ->> 'total_count')::int,
  9,
  'Secretary A (member.view only) can still list all 9 members (8 original + Fresh Member)'
);

select is(
  (select result from t_list_secretary) -> 'items' -> 0 -> 'roles',
  'null'::jsonb,
  'roles is null (not []) for a caller without role.view'
);

-- 24. Same role.view gating applies to rpc_get_group_member.
select is(
  (
    select public.rpc_get_group_member('d1000000-0000-0000-0000-000000000001', 'd3000000-0000-0000-0000-000000000001')
  ) -> 'roles',
  'null'::jsonb,
  'rpc_get_group_member also hides roles from a caller without role.view'
);

-- ---------------------------------------------------------------------
-- As No Role A (ACTIVE membership, zero roles assigned -> no permissions).
-- ---------------------------------------------------------------------
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to 'd0000000-0000-0000-0000-000000000003';

-- 4/5. caller without member.view is rejected.
select throws_ok(
  $$ select public.rpc_list_group_members('d1000000-0000-0000-0000-000000000001') $$,
  '42501',
  null,
  'a membership with no assigned role (no member.view) cannot list members'
);

select throws_ok(
  $$ select public.rpc_get_group_member('d1000000-0000-0000-0000-000000000001', 'd3000000-0000-0000-0000-000000000001') $$,
  '42501',
  null,
  'a membership with no assigned role (no member.view) cannot get member detail'
);

-- ---------------------------------------------------------------------
-- As Suspended Caller A (SUSPENDED membership, holds ADMIN role rows).
-- ---------------------------------------------------------------------
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to 'd0000000-0000-0000-0000-000000000004';

-- 5. suspended caller membership cannot use operational permissions.
select throws_ok(
  $$ select public.rpc_list_group_members('d1000000-0000-0000-0000-000000000001') $$,
  '42501',
  null,
  'a SUSPENDED caller membership cannot list members, despite holding ADMIN role rows'
);

-- ---------------------------------------------------------------------
-- As Admin A, but targeting the SUSPENDED group (Admin A is ACTIVE
-- ADMIN there too).
-- ---------------------------------------------------------------------
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to 'd0000000-0000-0000-0000-000000000001';

-- 7/9. a SUSPENDED group cannot be read, matching the existing
-- operational-status invariant for mutations (Prompt 03A).
select throws_ok(
  $$ select public.rpc_list_group_members('d1000000-0000-0000-0000-000000000003') $$,
  '42501',
  null,
  'an ACTIVE ADMIN cannot list members of a SUSPENDED group'
);

select throws_ok(
  $$ select public.rpc_get_group_member('d1000000-0000-0000-0000-000000000003', 'd2000000-0000-0000-0000-000000000006') $$,
  '42501',
  null,
  'an ACTIVE ADMIN cannot get member detail in a SUSPENDED group'
);

-- ---------------------------------------------------------------------
-- As Admin B (a member of Group Beta only).
-- ---------------------------------------------------------------------
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to 'd0000000-0000-0000-0000-000000000005';

-- 2/11. caller cannot list/get another group's members.
select throws_ok(
  $$ select public.rpc_list_group_members('d1000000-0000-0000-0000-000000000001') $$,
  '42501',
  null,
  'Admin B cannot list Group Alpha''s members'
);

select throws_ok(
  $$ select public.rpc_get_group_member('d1000000-0000-0000-0000-000000000001', 'd3000000-0000-0000-0000-000000000001') $$,
  '42501',
  null,
  'Admin B cannot get a Group Alpha member''s detail'
);

-- ---------------------------------------------------------------------
-- Inactive profile (Admin A, deactivated).
-- ---------------------------------------------------------------------
-- `authenticated` cannot update is_active on its own profile (by
-- design — see restrict_profile_self_update_columns), so this test
-- setup mutation (simulating an out-of-band deactivation) runs under
-- the harness role instead, then restores `authenticated` for the
-- actual RPC calls under test.
reset role;
update public.profiles set is_active = false where id = 'd0000000-0000-0000-0000-000000000001';
set local role authenticated;

reset request.jwt.claim.sub;
set local request.jwt.claim.sub to 'd0000000-0000-0000-0000-000000000001';

select throws_ok(
  $$ select public.rpc_list_group_members('d1000000-0000-0000-0000-000000000001') $$,
  'P0001',
  'ACCOUNT_DISABLED',
  'an inactive profile cannot list members'
);

select throws_ok(
  $$ select public.rpc_get_group_member('d1000000-0000-0000-0000-000000000001', 'd3000000-0000-0000-0000-000000000001') $$,
  'P0001',
  'ACCOUNT_DISABLED',
  'an inactive profile cannot get member detail'
);

-- ---------------------------------------------------------------------
-- anon cannot invoke either RPC (grant-level, matching Prompt 03A).
-- ---------------------------------------------------------------------
reset request.jwt.claim.sub;
set local role anon;

select throws_ok(
  $$ select public.rpc_list_group_members('d1000000-0000-0000-0000-000000000001') $$,
  '42501',
  null,
  'anon cannot invoke rpc_list_group_members'
);

select throws_ok(
  $$ select public.rpc_get_group_member('d1000000-0000-0000-0000-000000000001', 'd3000000-0000-0000-0000-000000000001') $$,
  '42501',
  null,
  'anon cannot invoke rpc_get_group_member'
);

select * from finish();

rollback;
