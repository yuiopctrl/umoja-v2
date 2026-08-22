-- Prompt 03A: operational mutations against a group must require
-- ALL of: authenticated + active profile + ACTIVE membership +
-- ACTIVE group + permission. This is now enforced centrally by
-- has_group_permission(), which every mutation RPC already gates on.
begin;

select plan(23);

insert into auth.users (id, email) values
  ('c0000000-0000-0000-0000-000000000001', 'admin@example.com'),
  ('c0000000-0000-0000-0000-000000000002', 'suspended-caller@example.com'),
  ('c0000000-0000-0000-0000-000000000003', 'exited-caller@example.com');

insert into public.groups (id, name, status, created_by, code) values
  ('c1000000-0000-0000-0000-000000000001', 'Group Active', 'ACTIVE', 'c0000000-0000-0000-0000-000000000001', 'GOE1'),
  ('c1000000-0000-0000-0000-000000000002', 'Group Suspended', 'SUSPENDED', 'c0000000-0000-0000-0000-000000000001', 'GOE2'),
  ('c1000000-0000-0000-0000-000000000003', 'Group Closed', 'CLOSED', 'c0000000-0000-0000-0000-000000000001', 'GOE3'),
  ('c1000000-0000-0000-0000-000000000004', 'Group Active 2', 'ACTIVE', 'c0000000-0000-0000-0000-000000000002', 'GOE4'),
  ('c1000000-0000-0000-0000-000000000005', 'Group Active 3', 'ACTIVE', 'c0000000-0000-0000-0000-000000000003', 'GOE5');

-- Admin (A) holds an ACTIVE ADMIN membership in all three status
-- variants of "their own" group.
insert into public.group_memberships (id, group_id, user_id, display_name, status, member_number) values
  ('c2000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'Admin', 'ACTIVE', 'GOE1-2026-0001'),
  ('c2000000-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000001', 'Admin', 'ACTIVE', 'GOE2-2026-0001'),
  ('c2000000-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000001', 'Admin', 'ACTIVE', 'GOE3-2026-0001');

-- Pre-existing target members inside the SUSPENDED/CLOSED groups, to
-- exercise update/status-change/role RPCs against them.
insert into public.group_memberships (id, group_id, user_id, display_name, status, member_number) values
  ('c2000000-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-000000000002', null, 'Target In Suspended Group', 'ACTIVE', 'GOE2-2026-0002'),
  ('c2000000-0000-0000-0000-000000000005', 'c1000000-0000-0000-0000-000000000003', null, 'Target In Closed Group', 'ACTIVE', 'GOE3-2026-0002');

insert into public.group_membership_roles (group_membership_id, role_id)
select 'c2000000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id)
select 'c2000000-0000-0000-0000-000000000002', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id)
select 'c2000000-0000-0000-0000-000000000003', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id)
select 'c2000000-0000-0000-0000-000000000004', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id)
select 'c2000000-0000-0000-0000-000000000005', id from public.roles where code = 'MEMBER';

-- B: SUSPENDED membership (with ADMIN role rows intact) in an
-- otherwise ACTIVE group.
insert into public.group_memberships (id, group_id, user_id, display_name, status, member_number) values
  ('c2000000-0000-0000-0000-000000000006', 'c1000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000002', 'Suspended Caller', 'SUSPENDED', 'GOE4-2026-0001');
insert into public.group_membership_roles (group_membership_id, role_id)
select 'c2000000-0000-0000-0000-000000000006', id from public.roles where code = 'ADMIN';

-- C: EXITED membership (with ADMIN role rows intact) in an otherwise
-- ACTIVE group.
insert into public.group_memberships (id, group_id, user_id, display_name, status, exited_at, member_number) values
  ('c2000000-0000-0000-0000-000000000007', 'c1000000-0000-0000-0000-000000000005', 'c0000000-0000-0000-0000-000000000003', 'Exited Caller', 'EXITED', current_date, 'GOE5-2026-0001');
insert into public.group_membership_roles (group_membership_id, role_id)
select 'c2000000-0000-0000-0000-000000000007', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to 'c0000000-0000-0000-0000-000000000001';

-- 1 & 14. ACTIVE ADMIN + ACTIVE group + permission can create a member
-- (ordinary operation continues to work).
select lives_ok(
  $$ select public.rpc_create_group_member('c1000000-0000-0000-0000-000000000001', 'New Member') $$,
  'ACTIVE ADMIN in an ACTIVE group can create a member'
);

-- 2. SUSPENDED group blocks member creation.
select throws_ok(
  $$ select public.rpc_create_group_member('c1000000-0000-0000-0000-000000000002', 'Should Not Exist') $$,
  '42501',
  null,
  'the same ADMIN cannot create a member in a SUSPENDED group'
);

-- 3. CLOSED group blocks member creation.
select throws_ok(
  $$ select public.rpc_create_group_member('c1000000-0000-0000-0000-000000000003', 'Should Not Exist') $$,
  '42501',
  null,
  'the same ADMIN cannot create a member in a CLOSED group'
);

-- 4. SUSPENDED group blocks member update.
select throws_ok(
  $$ select public.rpc_update_group_member('c1000000-0000-0000-0000-000000000002', 'c2000000-0000-0000-0000-000000000004', 'Renamed') $$,
  '42501',
  null,
  'ACTIVE ADMIN in a SUSPENDED group cannot update a member'
);

-- 5. CLOSED group blocks status change.
select throws_ok(
  $$ select public.rpc_change_group_member_status('c1000000-0000-0000-0000-000000000003', 'c2000000-0000-0000-0000-000000000005', 'SUSPENDED') $$,
  '42501',
  null,
  'ACTIVE ADMIN in a CLOSED group cannot change membership status'
);

-- 6. SUSPENDED/CLOSED group blocks role assignment.
select throws_ok(
  $$ select public.rpc_assign_group_role('c1000000-0000-0000-0000-000000000002', 'c2000000-0000-0000-0000-000000000004', 'TREASURER') $$,
  '42501',
  null,
  'ACTIVE ADMIN in a SUSPENDED group cannot assign roles'
);

select throws_ok(
  $$ select public.rpc_assign_group_role('c1000000-0000-0000-0000-000000000003', 'c2000000-0000-0000-0000-000000000005', 'TREASURER') $$,
  '42501',
  null,
  'ACTIVE ADMIN in a CLOSED group cannot assign roles'
);

-- 7. SUSPENDED/CLOSED group blocks role removal.
select throws_ok(
  $$ select public.rpc_remove_group_role('c1000000-0000-0000-0000-000000000002', 'c2000000-0000-0000-0000-000000000004', 'MEMBER') $$,
  '42501',
  null,
  'ACTIVE ADMIN in a SUSPENDED group cannot remove roles'
);

select throws_ok(
  $$ select public.rpc_remove_group_role('c1000000-0000-0000-0000-000000000003', 'c2000000-0000-0000-0000-000000000005', 'MEMBER') $$,
  '42501',
  null,
  'ACTIVE ADMIN in a CLOSED group cannot remove roles'
);

-- 12 & 13. has_group_permission is false purely because of group status.
select is(
  public.has_group_permission('c1000000-0000-0000-0000-000000000002', 'member.create'),
  false,
  'has_group_permission is false for a SUSPENDED group'
);

select is(
  public.has_group_permission('c1000000-0000-0000-0000-000000000003', 'member.create'),
  false,
  'has_group_permission is false for a CLOSED group'
);

-- 17 & 18. rpc_get_my_context still reports the real group status.
create temporary table t_admin_ctx as
select public.rpc_get_my_context() as ctx;

select is(
  (
    select m ->> 'group_status'
    from jsonb_array_elements((select ctx from t_admin_ctx) -> 'memberships') m
    where (m ->> 'group_id') = 'c1000000-0000-0000-0000-000000000002'
  ),
  'SUSPENDED',
  'rpc_get_my_context still reports the SUSPENDED group status'
);

select is(
  (
    select m ->> 'group_status'
    from jsonb_array_elements((select ctx from t_admin_ctx) -> 'memberships') m
    where (m ->> 'group_id') = 'c1000000-0000-0000-0000-000000000003'
  ),
  'CLOSED',
  'rpc_get_my_context still reports the CLOSED group status'
);

-- 20. groups.status cannot be changed by a direct authenticated update.
select throws_ok(
  $$ update public.groups set status = 'CLOSED' where id = 'c1000000-0000-0000-0000-000000000001' $$,
  '42501',
  null,
  'ordinary authenticated clients cannot directly update groups.status'
);

-- 21. Safe group metadata remains updateable under the intended
-- permission rules (group.manage + ACTIVE group)...
select lives_ok(
  $$ update public.groups set name = 'Group Active Renamed' where id = 'c1000000-0000-0000-0000-000000000001' $$,
  'group.manage in an ACTIVE group can still update safe metadata (name)'
);

-- ...but the same safe field is not updateable once the group is not
-- ACTIVE (RLS silently matches zero rows rather than erroring).
create temporary table t_suspended_name_update as
with updated as (
  update public.groups set name = 'Should Not Apply'
  where id = 'c1000000-0000-0000-0000-000000000002'
  returning id
)
select count(*) as n from updated;

select is(
  (select n from t_suspended_name_update),
  0::bigint,
  'group.manage cannot update even safe metadata once the group is SUSPENDED'
);

-- ---------------------------------------------------------------------
-- As B (SUSPENDED membership in an otherwise ACTIVE group).
-- ---------------------------------------------------------------------
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to 'c0000000-0000-0000-0000-000000000002';

-- 8. SUSPENDED caller membership blocks member creation.
select throws_ok(
  $$ select public.rpc_create_group_member('c1000000-0000-0000-0000-000000000004', 'Should Not Exist') $$,
  '42501',
  null,
  'a SUSPENDED caller membership cannot create a member, even in an ACTIVE group'
);

-- 10. SUSPENDED caller membership does not receive effective permissions.
select is(
  public.has_group_permission('c1000000-0000-0000-0000-000000000004', 'group.view'),
  false,
  'a SUSPENDED membership does not receive effective permissions despite holding ADMIN'
);

-- 15. rpc_get_my_context still reports the SUSPENDED membership status.
create temporary table t_b_ctx as
select public.rpc_get_my_context() as ctx;

select is(
  (
    select m ->> 'membership_status'
    from jsonb_array_elements((select ctx from t_b_ctx) -> 'memberships') m
    where (m ->> 'group_id') = 'c1000000-0000-0000-0000-000000000004'
  ),
  'SUSPENDED',
  'rpc_get_my_context still reports the SUSPENDED membership status'
);

-- 19. An active profile with only a SUSPENDED membership can still
-- create a separate new group and become its ADMIN.
create temporary table t_b_new_group as
select public.rpc_create_group('B''s New Group') as result;

select ok(
  ((select result from t_b_new_group) -> 'memberships' -> 0 -> 'roles') @> '["ADMIN"]'::jsonb,
  'a user with only a SUSPENDED membership can still create a new group and become its ADMIN'
);

-- ---------------------------------------------------------------------
-- As C (EXITED membership in an otherwise ACTIVE group).
-- ---------------------------------------------------------------------
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to 'c0000000-0000-0000-0000-000000000003';

-- 9. EXITED caller membership blocks member creation.
select throws_ok(
  $$ select public.rpc_create_group_member('c1000000-0000-0000-0000-000000000005', 'Should Not Exist') $$,
  '42501',
  null,
  'an EXITED caller membership cannot create a member, even in an ACTIVE group'
);

-- 11. EXITED caller membership does not receive effective permissions.
select is(
  public.has_group_permission('c1000000-0000-0000-0000-000000000005', 'group.view'),
  false,
  'an EXITED membership does not receive effective permissions despite holding ADMIN'
);

-- 16. rpc_get_my_context still reports the EXITED membership status.
create temporary table t_c_ctx as
select public.rpc_get_my_context() as ctx;

select is(
  (
    select m ->> 'membership_status'
    from jsonb_array_elements((select ctx from t_c_ctx) -> 'memberships') m
    where (m ->> 'group_id') = 'c1000000-0000-0000-0000-000000000005'
  ),
  'EXITED',
  'rpc_get_my_context still reports the EXITED membership status'
);

select * from finish();

rollback;
