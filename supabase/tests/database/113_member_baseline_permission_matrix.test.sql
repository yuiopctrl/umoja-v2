-- Prompt 09G-B5-B.1 (permission-matrix correction).
--
-- MEMBER is an identity / self-service baseline. It keeps group.view and the
-- self-service permissions, but NOT member.view. Officer and admin roles keep
-- member.view according to their own existing grants. Removing MEMBER ->
-- member.view must not remove it from any other role.
begin;

select plan(20);

-- =====================================================================
-- Catalog matrix (run as the owning role)
-- =====================================================================

-- A. MEMBER does not carry member.view.
select is(
  (select count(*)::int from public.role_permissions rp
   join public.roles r on r.id = rp.role_id
   join public.permissions p on p.id = rp.permission_id
   where r.code = 'MEMBER' and p.code = 'member.view'),
  0,
  'A: MEMBER does not hold member.view'
);

-- C/D/E. MEMBER keeps group.view and the self-service permissions.
select ok(
  exists (select 1 from public.role_permissions rp join public.roles r on r.id = rp.role_id join public.permissions p on p.id = rp.permission_id where r.code = 'MEMBER' and p.code = 'group.view')
  and exists (select 1 from public.role_permissions rp join public.roles r on r.id = rp.role_id join public.permissions p on p.id = rp.permission_id where r.code = 'MEMBER' and p.code = 'contribution.self_view')
  and exists (select 1 from public.role_permissions rp join public.roles r on r.id = rp.role_id join public.permissions p on p.id = rp.permission_id where r.code = 'MEMBER' and p.code = 'loan.self_view')
  and exists (select 1 from public.role_permissions rp join public.roles r on r.id = rp.role_id join public.permissions p on p.id = rp.permission_id where r.code = 'MEMBER' and p.code = 'financial_report.self_view'),
  'C/D/E: MEMBER keeps group.view, contribution.self_view, loan.self_view and financial_report.self_view'
);

-- H. Removing the MEMBER mapping leaves member.view on the roles that
-- legitimately hold it.
select ok(
  exists (select 1 from public.role_permissions rp join public.roles r on r.id = rp.role_id join public.permissions p on p.id = rp.permission_id where r.code = 'ADMIN' and p.code = 'member.view')
  and exists (select 1 from public.role_permissions rp join public.roles r on r.id = rp.role_id join public.permissions p on p.id = rp.permission_id where r.code = 'TREASURER' and p.code = 'member.view')
  and exists (select 1 from public.role_permissions rp join public.roles r on r.id = rp.role_id join public.permissions p on p.id = rp.permission_id where r.code = 'SECRETARY' and p.code = 'member.view')
  and exists (select 1 from public.role_permissions rp join public.roles r on r.id = rp.role_id join public.permissions p on p.id = rp.permission_id where r.code = 'CHAIRPERSON' and p.code = 'member.view'),
  'H: ADMIN, TREASURER, SECRETARY and CHAIRPERSON keep their own member.view grants'
);

select is(
  (select array_agg(r.code order by r.code)
   from public.role_permissions rp join public.roles r on r.id = rp.role_id join public.permissions p on p.id = rp.permission_id
   where p.code = 'member.view'),
  array['ADMIN', 'CHAIRPERSON', 'SECRETARY', 'TREASURER'],
  'member.view is held by exactly the officer/admin roles that grant it'
);

-- =====================================================================
-- Fixtures
-- =====================================================================

insert into auth.users (id, email) values
  ('13000000-0000-0000-0000-000000000301', 'p09gb5b1m-ordinary@example.com'),
  ('13000000-0000-0000-0000-000000000302', 'p09gb5b1m-treasurer@example.com'),
  ('13000000-0000-0000-0000-000000000303', 'p09gb5b1m-admin@example.com');

insert into public.groups (id, name, created_by, code, status) values
  ('13000000-0000-0000-0000-000000000001', 'B5B1 Matrix Group', '13000000-0000-0000-0000-000000000303', 'B5B1M', 'ACTIVE');

-- Linked memberships get the MEMBER baseline from the trigger.
insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number, phone) values
  ('13000000-0000-0000-0000-000000000401', '13000000-0000-0000-0000-000000000001', '13000000-0000-0000-0000-000000000301', 'Ordinary Member', 'ACTIVE', '2025-01-01', 'B5B1M-0001', null),
  ('13000000-0000-0000-0000-000000000402', '13000000-0000-0000-0000-000000000001', '13000000-0000-0000-0000-000000000302', 'Treasurer', 'ACTIVE', '2025-01-02', 'B5B1M-0002', null),
  ('13000000-0000-0000-0000-000000000403', '13000000-0000-0000-0000-000000000001', '13000000-0000-0000-0000-000000000303', 'Administrator', 'ACTIVE', '2025-01-03', 'B5B1M-0003', null),
  ('13000000-0000-0000-0000-000000000404', '13000000-0000-0000-0000-000000000001', null, 'Roster Only', 'ACTIVE', '2025-01-04', 'B5B1M-0004', null);

insert into public.group_membership_roles (group_membership_id, role_id) select '13000000-0000-0000-0000-000000000402', id from public.roles where code = 'TREASURER';
insert into public.group_membership_roles (group_membership_id, role_id) select '13000000-0000-0000-0000-000000000403', id from public.roles where code = 'ADMIN';

-- =====================================================================
-- B. Ordinary MEMBER cannot use the Members directory backend.
-- =====================================================================
set local role authenticated;
set local request.jwt.claim.sub to '13000000-0000-0000-0000-000000000301';

select throws_ok(
  $$ select public.rpc_list_group_members('13000000-0000-0000-0000-000000000001') $$,
  '42501', null,
  'B1: ordinary MEMBER cannot list the Members directory'
);
select throws_ok(
  $$ select public.rpc_get_group_member('13000000-0000-0000-0000-000000000001', '13000000-0000-0000-0000-000000000402') $$,
  '42501', null,
  'B2: ordinary MEMBER cannot read another member detail through the directory'
);

-- The ordinary member sees only their own membership row directly (RLS).
select is(
  (select count(*)::int from public.group_memberships where group_id = '13000000-0000-0000-0000-000000000001'),
  1,
  'B3: ordinary MEMBER sees only their own membership row, never the roster'
);

-- C. group.view retained.
select ok(
  public.has_group_permission('13000000-0000-0000-0000-000000000001'::uuid, 'group.view'),
  'C: ordinary MEMBER retains group.view'
);

-- D. contribution self-view retained.
select ok(
  public.has_group_permission('13000000-0000-0000-0000-000000000001'::uuid, 'contribution.self_view'),
  'D: ordinary MEMBER retains contribution self-view'
);

-- E. loan self-view retained.
select ok(
  public.has_group_permission('13000000-0000-0000-0000-000000000001'::uuid, 'loan.self_view'),
  'E: ordinary MEMBER retains loan.self_view'
);

-- A (effective). Ordinary member has no member.view.
select ok(
  not public.has_group_permission('13000000-0000-0000-0000-000000000001'::uuid, 'member.view'),
  'A: ordinary MEMBER has no effective member.view'
);
reset role;

-- =====================================================================
-- F. TREASURER + MEMBER keeps member.view only through TREASURER.
-- G. ADMIN + MEMBER keeps member.view through ADMIN.
-- =====================================================================
set local role authenticated;
set local request.jwt.claim.sub to '13000000-0000-0000-0000-000000000302';
select ok(
  public.has_group_permission('13000000-0000-0000-0000-000000000001'::uuid, 'member.view'),
  'F: TREASURER + MEMBER has member.view through the TREASURER grant'
);
select lives_ok(
  $$ select public.rpc_list_group_members('13000000-0000-0000-0000-000000000001') $$,
  'F2: treasurer can use the Members directory through TREASURER'
);
reset role;

set local role authenticated;
set local request.jwt.claim.sub to '13000000-0000-0000-0000-000000000303';
select ok(
  public.has_group_permission('13000000-0000-0000-0000-000000000001'::uuid, 'member.view'),
  'G: ADMIN + MEMBER has member.view through ADMIN'
);
reset role;

-- =====================================================================
-- I. Baseline trigger stays idempotent: repeated MEMBER assignment on a linked
-- membership never duplicates it.
-- =====================================================================
insert into public.group_membership_roles (group_membership_id, role_id, assigned_by)
select '13000000-0000-0000-0000-000000000401', id, null from public.roles where code = 'MEMBER'
on conflict (group_membership_id, role_id) do nothing;
insert into public.group_membership_roles (group_membership_id, role_id, assigned_by)
select '13000000-0000-0000-0000-000000000401', id, null from public.roles where code = 'MEMBER'
on conflict (group_membership_id, role_id) do nothing;

select is(
  (select count(*)::int from public.group_membership_roles gmr join public.roles r on r.id = gmr.role_id
   where gmr.group_membership_id = '13000000-0000-0000-0000-000000000401' and r.code = 'MEMBER'),
  1,
  'I1: repeated MEMBER assignment on a linked membership is idempotent'
);

select is(
  (select count(*)::int from public.group_membership_roles gmr join public.roles r on r.id = gmr.role_id
   where gmr.group_membership_id = '13000000-0000-0000-0000-000000000404' and r.code = 'MEMBER'),
  0,
  'I2: roster-only membership still holds no MEMBER'
);

-- H (role-level). Removing the mapping from MEMBER does not touch the rest of
-- the matrix: an ADMIN-held member.view is still effective for an admin.
set local role authenticated;
set local request.jwt.claim.sub to '13000000-0000-0000-0000-000000000303';
select lives_ok(
  $$ select public.rpc_list_group_members('13000000-0000-0000-0000-000000000001') $$,
  'H: admin still reaches the Members directory after the MEMBER correction'
);
reset role;

-- =====================================================================
-- Self-service regression through MEMBER (no bypass added).
-- =====================================================================
set local role authenticated;
set local request.jwt.claim.sub to '13000000-0000-0000-0000-000000000301';
select lives_ok(
  $$ select public.rpc_get_my_loans('13000000-0000-0000-0000-000000000001', 20, 0) $$,
  'J1: ordinary MEMBER still lists own loans through loan.self_view'
);
select lives_ok(
  $$ select public.rpc_get_my_contributions('13000000-0000-0000-0000-000000000001') $$,
  'J2: ordinary MEMBER still reads own contributions through contribution.self_view'
);
reset role;

-- No self-service directory bypass: no RPC body gates on the directory permission
-- other than the officer directory RPCs.
select is(
  (select array_agg(p.proname::text order by p.proname::text)
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.prosrc like '%member.view%'),
  array['rpc_get_group_member', 'rpc_list_group_members'],
  'J3: only the officer directory RPCs gate on member.view'
);

select * from finish();
rollback;
