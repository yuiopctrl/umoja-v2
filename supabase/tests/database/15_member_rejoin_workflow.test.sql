-- Prompt 05B: rpc_rejoin_group_member — the explicit, separate rejoin
-- workflow for EXITED members. rpc_change_group_member_status's own
-- EXITED-is-terminal rule (test 10) is untouched by this file.
begin;

select plan(10);

insert into auth.users (id, email) values
  ('93000000-0000-0000-0000-000000000001', 'rejoin-admin@example.com'),
  ('93000000-0000-0000-0000-000000000002', 'rejoin-treasurer@example.com'),
  ('93000000-0000-0000-0000-000000000003', 'rejoin-linked-member@example.com');

insert into public.groups (id, name, created_by, code) values
  ('94000000-0000-0000-0000-000000000001', 'Group Rejoin A', '93000000-0000-0000-0000-000000000001', 'REJA'),
  ('94000000-0000-0000-0000-000000000002', 'Group Rejoin B', '93000000-0000-0000-0000-000000000001', 'REJB');

insert into public.group_memberships (id, group_id, user_id, display_name, status, member_number) values
  ('95000000-0000-0000-0000-000000000001', '94000000-0000-0000-0000-000000000001', '93000000-0000-0000-0000-000000000001', 'Rejoin Admin', 'ACTIVE', 'REJA-2026-0001'),
  ('95000000-0000-0000-0000-000000000002', '94000000-0000-0000-0000-000000000001', '93000000-0000-0000-0000-000000000002', 'Rejoin Treasurer', 'ACTIVE', 'REJA-2026-0002');

insert into public.group_membership_roles (group_membership_id, role_id)
select '95000000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id)
select '95000000-0000-0000-0000-000000000002', id from public.roles where code = 'TREASURER';

-- An EXITED membership linked to a real auth user, plus a second
-- ACTIVE membership for that same user in the same group — rejoining
-- the first must be rejected (would create two ACTIVE memberships for
-- one user in one group).
insert into public.group_memberships (id, group_id, user_id, display_name, status, exited_at, member_number) values
  ('95000000-0000-0000-0000-000000000003', '94000000-0000-0000-0000-000000000001', '93000000-0000-0000-0000-000000000003', 'Linked Exited Member', 'EXITED', current_date, 'REJA-2026-0003'),
  ('95000000-0000-0000-0000-000000000004', '94000000-0000-0000-0000-000000000001', '93000000-0000-0000-0000-000000000003', 'Linked Member Second Row', 'ACTIVE', null, 'REJA-2026-0004');

-- A membership in a different group, EXITED, to exercise the
-- cross-group isolation check.
insert into public.group_memberships (id, group_id, display_name, status, exited_at, member_number) values
  ('95000000-0000-0000-0000-000000000005', '94000000-0000-0000-0000-000000000002', 'Other Group Member', 'EXITED', current_date, 'REJB-2026-0001');

set local role authenticated;
set local request.jwt.claim.sub to '93000000-0000-0000-0000-000000000001';

-- An ordinary EXITED member (no linked auth user) to rejoin.
create temporary table t_member as
select public.rpc_create_group_member('94000000-0000-0000-0000-000000000001', 'Exited Member') as result;

select public.rpc_change_group_member_status(
  '94000000-0000-0000-0000-000000000001',
  (select result ->> 'membership_id' from t_member)::uuid,
  'EXITED'
);

-- ---------------------------------------------------------------------
-- 1-4. A genuinely EXITED member can be rejoined by an authorized
-- caller (member.change_status), and history is preserved.
-- ---------------------------------------------------------------------
select lives_ok(
  format(
    $sql$ select public.rpc_rejoin_group_member('94000000-0000-0000-0000-000000000001', %L) $sql$,
    (select result ->> 'membership_id' from t_member)
  ),
  'an authorized caller can rejoin a genuinely EXITED member'
);

select is(
  (select status::text from public.group_memberships
     where id = (select (result ->> 'membership_id')::uuid from t_member)),
  'ACTIVE',
  'the rejoined member is ACTIVE again'
);

select is(
  (select exited_at from public.group_memberships
     where id = (select (result ->> 'membership_id')::uuid from t_member)),
  null,
  'exited_at is cleared on rejoin'
);

-- group_membership_status_history has no grants at all to authenticated
-- (see migration comment) — reset to the unrestricted test role to
-- inspect it, then resume as the authenticated caller below.
reset role;

select is(
  (select count(*)::int from public.group_membership_status_history
     where group_membership_id = (select (result ->> 'membership_id')::uuid from t_member)
       and from_status = 'EXITED' and to_status = 'ACTIVE' and action = 'REJOIN'),
  1,
  'a single immutable history row records the EXITED -> ACTIVE rejoin'
);

set local role authenticated;
set local request.jwt.claim.sub to '93000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- 5. Rejoining a non-EXITED membership is rejected.
-- ---------------------------------------------------------------------
select throws_ok(
  $$ select public.rpc_rejoin_group_member('94000000-0000-0000-0000-000000000001', '95000000-0000-0000-0000-000000000001') $$,
  'P0001',
  'MEMBERSHIP_NOT_EXITED',
  'rejoining a non-EXITED membership is rejected'
);

-- ---------------------------------------------------------------------
-- 6. A caller without member.change_status cannot rejoin.
-- ---------------------------------------------------------------------
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to '93000000-0000-0000-0000-000000000002';

select throws_ok(
  $$ select public.rpc_rejoin_group_member('94000000-0000-0000-0000-000000000001', '95000000-0000-0000-0000-000000000003') $$,
  '42501',
  null,
  'a caller without member.change_status cannot rejoin a member'
);

reset request.jwt.claim.sub;
set local request.jwt.claim.sub to '93000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- 7. Cross-group isolation: a membership from another group cannot be
-- rejoined by passing this group's id.
-- ---------------------------------------------------------------------
select throws_ok(
  $$ select public.rpc_rejoin_group_member('94000000-0000-0000-0000-000000000001', '95000000-0000-0000-0000-000000000005') $$,
  '22023',
  null,
  'a membership from a different group cannot be rejoined'
);

-- ---------------------------------------------------------------------
-- 8. Rejoining must not create a second ACTIVE membership for a
-- linked user who already holds one ACTIVE membership in this group.
-- ---------------------------------------------------------------------
select throws_ok(
  $$ select public.rpc_rejoin_group_member('94000000-0000-0000-0000-000000000001', '95000000-0000-0000-0000-000000000003') $$,
  'P0001',
  'USER_ALREADY_HAS_ACTIVE_MEMBERSHIP',
  'rejoin is rejected when it would give the linked user two ACTIVE memberships in one group'
);

-- ---------------------------------------------------------------------
-- 9. anon cannot execute the function at all.
-- ---------------------------------------------------------------------
select is(
  has_function_privilege('anon', 'public.rpc_rejoin_group_member(uuid, uuid, date)', 'execute'),
  false,
  'anon has no execute privilege on rpc_rejoin_group_member'
);

-- ---------------------------------------------------------------------
-- 10. The history table is never directly readable/writable by
-- authenticated clients (no grants at all — backend-only for now).
-- ---------------------------------------------------------------------
select throws_ok(
  $$ select 1 from public.group_membership_status_history limit 1 $$,
  '42501',
  null,
  'authenticated clients cannot directly read group_membership_status_history'
);

select * from finish();

rollback;
