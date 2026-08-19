-- Prompt 02A, issue 1: ADMIN role privilege escalation and last-ADMIN
-- protection, enforced by rpc_assign_group_role() / rpc_remove_group_role().
begin;

select plan(11);

insert into auth.users (id, email) values
  ('10000000-0000-0000-0000-000000000001', 'admin1@example.com'),
  ('10000000-0000-0000-0000-000000000002', 'admin2@example.com'),
  ('10000000-0000-0000-0000-000000000003', 'chair@example.com'),
  ('10000000-0000-0000-0000-000000000004', 'member1@example.com'),
  ('10000000-0000-0000-0000-000000000005', 'admin-h@example.com');

insert into public.groups (id, name, created_by) values
  ('20000000-0000-0000-0000-000000000001', 'Group G', '10000000-0000-0000-0000-000000000001'),
  ('20000000-0000-0000-0000-000000000002', 'Group H', '10000000-0000-0000-0000-000000000005');

insert into public.group_memberships (id, group_id, user_id, display_name, status) values
  ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Admin1', 'ACTIVE'),
  ('30000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', 'Admin2', 'ACTIVE'),
  ('30000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000003', 'Chair', 'ACTIVE'),
  ('30000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000004', 'Member1', 'ACTIVE'),
  ('30000000-0000-0000-0000-000000000005', '20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000005', 'AdminH', 'ACTIVE'),
  ('30000000-0000-0000-0000-000000000006', '20000000-0000-0000-0000-000000000002', null, 'BystanderH', 'ACTIVE');

insert into public.group_membership_roles (group_membership_id, role_id)
select '30000000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id)
select '30000000-0000-0000-0000-000000000002', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id)
select '30000000-0000-0000-0000-000000000003', id from public.roles where code = 'CHAIRPERSON';
insert into public.group_membership_roles (group_membership_id, role_id)
select '30000000-0000-0000-0000-000000000004', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id)
select '30000000-0000-0000-0000-000000000005', id from public.roles where code = 'ADMIN';

-- ---------------------------------------------------------------------
-- As CHAIRPERSON (has role.assign, but not ADMIN).
-- ---------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claim.sub to '10000000-0000-0000-0000-000000000003';

-- 1. CHAIRPERSON with role.assign cannot assign ADMIN to self.
select throws_ok(
  $$ select public.rpc_assign_group_role('20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000003', 'ADMIN') $$,
  '42501',
  null,
  'CHAIRPERSON cannot assign ADMIN to self'
);

-- 2. CHAIRPERSON cannot assign ADMIN to another member.
select throws_ok(
  $$ select public.rpc_assign_group_role('20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000004', 'ADMIN') $$,
  '42501',
  null,
  'CHAIRPERSON cannot assign ADMIN to another member'
);

-- 3. CHAIRPERSON cannot remove ADMIN.
select throws_ok(
  $$ select public.rpc_remove_group_role('20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'ADMIN') $$,
  '42501',
  null,
  'CHAIRPERSON cannot remove ADMIN'
);

-- 5. Non-ADMIN role assignment still works for an authorized caller.
select lives_ok(
  $$ select public.rpc_assign_group_role('20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000004', 'TREASURER') $$,
  'CHAIRPERSON can assign a non-ADMIN role (TREASURER)'
);

select ok(
  exists (
    select 1
    from public.group_membership_roles gmr
    join public.roles r on r.id = gmr.role_id
    where gmr.group_membership_id = '30000000-0000-0000-0000-000000000004'
      and r.code = 'TREASURER'
  ),
  'Member1 now holds the TREASURER role after the CHAIRPERSON''s assignment'
);

-- 9. Cross-group role assignment fails (target membership belongs to
-- Group H, not Group G).
select throws_ok(
  $$ select public.rpc_assign_group_role('20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000006', 'MEMBER') $$,
  '22023',
  null,
  'cross-group role assignment fails when the membership does not belong to p_group_id'
);

-- ---------------------------------------------------------------------
-- As ADMIN (Admin1).
-- ---------------------------------------------------------------------
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to '10000000-0000-0000-0000-000000000001';

-- 4. ADMIN can assign ADMIN to another eligible membership.
select lives_ok(
  $$ select public.rpc_assign_group_role('20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000004', 'ADMIN') $$,
  'an existing ADMIN can assign ADMIN to another membership'
);

-- 8. Removing ADMIN works when another ADMIN remains (3 admins: 1, 2, 4
-- -> removing Admin2 leaves 2).
select lives_ok(
  $$ select public.rpc_remove_group_role('20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000002', 'ADMIN') $$,
  'removing ADMIN succeeds while another ADMIN remains'
);

-- Reduce down to exactly one remaining ADMIN (Admin1) before the
-- last-ADMIN test.
select lives_ok(
  $$ select public.rpc_remove_group_role('20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000004', 'ADMIN') $$,
  'removing ADMIN from the second-to-last admin still succeeds while one remains'
);

-- 7. Last ADMIN cannot be removed.
select throws_ok(
  $$ select public.rpc_remove_group_role('20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'ADMIN') $$,
  'P0001',
  'LAST_ADMIN_REQUIRED',
  'the group''s last remaining ADMIN cannot be removed'
);

-- ---------------------------------------------------------------------
-- As MEMBER (no role.assign).
-- ---------------------------------------------------------------------
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to '10000000-0000-0000-0000-000000000004';

-- 6. MEMBER cannot assign roles.
select throws_ok(
  $$ select public.rpc_assign_group_role('20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000003', 'SECRETARY') $$,
  '42501',
  null,
  'MEMBER cannot assign roles (lacks role.assign)'
);

select * from finish();

rollback;
