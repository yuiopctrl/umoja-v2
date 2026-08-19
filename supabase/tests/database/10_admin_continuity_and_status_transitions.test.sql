-- Prompt 02B: a group's sole ACTIVE ADMIN must not be left without an
-- active administrator via rpc_change_group_member_status(), matching
-- the protection rpc_remove_group_role() already had (Prompt 02A). Also
-- covers the tightened status-transition rules (EXITED is terminal;
-- same-status calls are a safe no-op).
begin;

select plan(22);

insert into auth.users (id, email) values
  ('90000000-0000-0000-0000-000000000001', 'admin1@example.com'),
  ('90000000-0000-0000-0000-000000000002', 'admin2@example.com');

insert into public.groups (id, name, created_by) values
  ('91000000-0000-0000-0000-000000000001', 'Group P', '90000000-0000-0000-0000-000000000001');

insert into public.group_memberships (id, group_id, user_id, display_name, status) values
  ('92000000-0000-0000-0000-000000000001', '91000000-0000-0000-0000-000000000001', '90000000-0000-0000-0000-000000000001', 'Admin1', 'ACTIVE'),
  ('92000000-0000-0000-0000-000000000002', '91000000-0000-0000-0000-000000000001', '90000000-0000-0000-0000-000000000002', 'Admin2', 'ACTIVE');

insert into public.group_membership_roles (group_membership_id, role_id)
select '92000000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id)
select '92000000-0000-0000-0000-000000000002', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-0000-0000-000000000001';

-- Create a non-admin member to exercise ordinary status changes.
create temporary table t_member as
select public.rpc_create_group_member('91000000-0000-0000-0000-000000000001', 'Ordinary Member') as result;

-- ---------------------------------------------------------------------
-- 3. ADMIN can be SUSPENDED if another ACTIVE ADMIN exists.
-- ---------------------------------------------------------------------
select lives_ok(
  $$ select public.rpc_change_group_member_status('91000000-0000-0000-0000-000000000001', '92000000-0000-0000-0000-000000000002', 'SUSPENDED') $$,
  'Admin2 can be suspended while Admin1 remains an ACTIVE ADMIN'
);

select is(
  (select status::text from public.group_memberships where id = '92000000-0000-0000-0000-000000000002'),
  'SUSPENDED',
  'Admin2 is now SUSPENDED'
);

-- ---------------------------------------------------------------------
-- 7. SUSPENDED member can return to ACTIVE.
-- ---------------------------------------------------------------------
select lives_ok(
  $$ select public.rpc_change_group_member_status('91000000-0000-0000-0000-000000000001', '92000000-0000-0000-0000-000000000002', 'ACTIVE') $$,
  'Admin2 can return from SUSPENDED to ACTIVE'
);

select is(
  (select status::text from public.group_memberships where id = '92000000-0000-0000-0000-000000000002'),
  'ACTIVE',
  'Admin2 is ACTIVE again'
);

-- ---------------------------------------------------------------------
-- 4. ADMIN can be EXITED if another ACTIVE ADMIN exists.
-- ---------------------------------------------------------------------
select lives_ok(
  $$ select public.rpc_change_group_member_status('91000000-0000-0000-0000-000000000001', '92000000-0000-0000-0000-000000000002', 'EXITED') $$,
  'Admin2 can be exited while Admin1 remains an ACTIVE ADMIN'
);

select ok(
  (select status = 'EXITED' and exited_at is not null
     from public.group_memberships where id = '92000000-0000-0000-0000-000000000002'),
  'Admin2 is EXITED with exited_at set'
);

-- ---------------------------------------------------------------------
-- Admin1 is now the group's sole ACTIVE ADMIN (Admin2's ADMIN role row
-- still exists, but their membership is EXITED, so it must not count).
-- ---------------------------------------------------------------------

-- 1. Sole ACTIVE ADMIN cannot be SUSPENDED.
select throws_ok(
  $$ select public.rpc_change_group_member_status('91000000-0000-0000-0000-000000000001', '92000000-0000-0000-0000-000000000001', 'SUSPENDED') $$,
  'P0001',
  'LAST_ADMIN_REQUIRED',
  'the sole ACTIVE ADMIN cannot be suspended'
);

-- 2. Sole ACTIVE ADMIN cannot be EXITED.
select throws_ok(
  $$ select public.rpc_change_group_member_status('91000000-0000-0000-0000-000000000001', '92000000-0000-0000-0000-000000000001', 'EXITED') $$,
  'P0001',
  'LAST_ADMIN_REQUIRED',
  'the sole ACTIVE ADMIN cannot be exited'
);

select is(
  (select status::text from public.group_memberships where id = '92000000-0000-0000-0000-000000000001'),
  'ACTIVE',
  'Admin1 remains ACTIVE after both rejected attempts'
);

-- 13. Role removal still protects the final ACTIVE ADMIN, and a
-- SUSPENDED/EXITED membership's ADMIN role row does not count as an
-- active administrator (Admin2's EXITED ADMIN role is ignored here).
select throws_ok(
  $$ select public.rpc_remove_group_role('91000000-0000-0000-0000-000000000001', '92000000-0000-0000-0000-000000000001', 'ADMIN') $$,
  'P0001',
  'LAST_ADMIN_REQUIRED',
  'removing ADMIN from the group''s sole active admin is still rejected'
);

-- ---------------------------------------------------------------------
-- Ordinary (non-admin) member status changes.
-- ---------------------------------------------------------------------

-- 5. Non-ADMIN member can be suspended by an authorized caller.
select lives_ok(
  format(
    $sql$ select public.rpc_change_group_member_status('91000000-0000-0000-0000-000000000001', %L, 'SUSPENDED') $sql$,
    (select result ->> 'membership_id' from t_member)
  ),
  'a non-ADMIN member can be suspended'
);

-- 11. SUSPENDED -> SUSPENDED is a safe no-op.
select lives_ok(
  format(
    $sql$ select public.rpc_change_group_member_status('91000000-0000-0000-0000-000000000001', %L, 'SUSPENDED') $sql$,
    (select result ->> 'membership_id' from t_member)
  ),
  'SUSPENDED -> SUSPENDED is idempotent'
);

select ok(
  (select status = 'SUSPENDED' and exited_at is null
     from public.group_memberships
     where id = (select (result ->> 'membership_id')::uuid from t_member)),
  'the idempotent no-op left status/exited_at unchanged'
);

-- 6. Non-ADMIN member can be exited by an authorized caller.
select lives_ok(
  format(
    $sql$ select public.rpc_change_group_member_status('91000000-0000-0000-0000-000000000001', %L, 'EXITED') $sql$,
    (select result ->> 'membership_id' from t_member)
  ),
  'a non-ADMIN member can be exited'
);

select ok(
  (select status = 'EXITED' and exited_at is not null
     from public.group_memberships
     where id = (select (result ->> 'membership_id')::uuid from t_member)),
  'the member is now EXITED with exited_at set'
);

-- 8. EXITED -> ACTIVE is rejected.
select throws_ok(
  format(
    $sql$ select public.rpc_change_group_member_status('91000000-0000-0000-0000-000000000001', %L, 'ACTIVE') $sql$,
    (select result ->> 'membership_id' from t_member)
  ),
  'P0001',
  'EXITED_MEMBERSHIP_IS_TERMINAL',
  'EXITED -> ACTIVE is rejected; rejoining is a future, explicit workflow'
);

-- 9. EXITED -> SUSPENDED is rejected.
select throws_ok(
  format(
    $sql$ select public.rpc_change_group_member_status('91000000-0000-0000-0000-000000000001', %L, 'SUSPENDED') $sql$,
    (select result ->> 'membership_id' from t_member)
  ),
  'P0001',
  'EXITED_MEMBERSHIP_IS_TERMINAL',
  'EXITED -> SUSPENDED is rejected'
);

-- EXITED -> EXITED remains a safe no-op and does not disturb exited_at.
select lives_ok(
  format(
    $sql$ select public.rpc_change_group_member_status('91000000-0000-0000-0000-000000000001', %L, 'EXITED') $sql$,
    (select result ->> 'membership_id' from t_member)
  ),
  'EXITED -> EXITED is idempotent'
);

-- 10. ACTIVE -> ACTIVE is safe/idempotent.
select lives_ok(
  $$ select public.rpc_change_group_member_status('91000000-0000-0000-0000-000000000001', '92000000-0000-0000-0000-000000000001', 'ACTIVE') $$,
  'ACTIVE -> ACTIVE is idempotent (and does not trip the last-admin check)'
);

select is(
  (select status::text from public.group_memberships where id = '92000000-0000-0000-0000-000000000001'),
  'ACTIVE',
  'Admin1 is still ACTIVE after the idempotent call'
);

-- 12. Concurrency protection is represented as far as pgTAP's
-- single-session model allows: sequential calls above already prove
-- the invariant holds across separate statements/transactions, and we
-- additionally assert the shared guard uses row locking (FOR UPDATE),
-- which is what makes two genuinely concurrent transactions serialize
-- instead of racing. True concurrent-transaction testing is not
-- practical within a single pgTAP session.
select ok(
  pg_get_functiondef('public.assert_last_active_admin_remains(uuid, uuid)'::regprocedure) ~* 'for update',
  'the shared last-admin guard locks ACTIVE ADMIN rows (FOR UPDATE) for concurrency safety'
);

-- The shared guard is an internal-only helper, not part of the public API.
select throws_ok(
  $$ select public.assert_last_active_admin_remains('91000000-0000-0000-0000-000000000001', '92000000-0000-0000-0000-000000000001') $$,
  '42501',
  null,
  'assert_last_active_admin_remains is not directly callable by authenticated clients'
);

select * from finish();

rollback;
