-- Prompt 02A, issue 2: member.edit vs member.change_status must be
-- distinctly enforced, via rpc_update_group_member() and
-- rpc_change_group_member_status(). Direct authenticated INSERT/UPDATE
-- on group_memberships is revoked entirely (tested here too).
begin;

select plan(10);

insert into auth.users (id, email) values
  ('40000000-0000-0000-0000-000000000001', 'admin@example.com'),
  ('40000000-0000-0000-0000-000000000002', 'secretary@example.com'),
  ('40000000-0000-0000-0000-000000000003', 'treasurer@example.com');

insert into public.groups (id, name, created_by, code) values
  ('50000000-0000-0000-0000-000000000001', 'Group M', '40000000-0000-0000-0000-000000000001', 'STAM'),
  ('50000000-0000-0000-0000-000000000002', 'Group N', '40000000-0000-0000-0000-000000000001', 'STAN');

insert into public.group_memberships (id, group_id, user_id, display_name, status, member_number) values
  ('60000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', 'Admin', 'ACTIVE', 'STAM-2026-0001'),
  ('60000000-0000-0000-0000-000000000002', '50000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000002', 'Secretary', 'ACTIVE', 'STAM-2026-0002'),
  ('60000000-0000-0000-0000-000000000003', '50000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000003', 'Treasurer', 'ACTIVE', 'STAM-2026-0003');

insert into public.group_membership_roles (group_membership_id, role_id)
select '60000000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id)
select '60000000-0000-0000-0000-000000000002', id from public.roles where code = 'SECRETARY';
insert into public.group_membership_roles (group_membership_id, role_id)
select '60000000-0000-0000-0000-000000000003', id from public.roles where code = 'TREASURER';

-- Create the target member as ADMIN (has member.create).
set local role authenticated;
set local request.jwt.claim.sub to '40000000-0000-0000-0000-000000000001';

create temporary table t_target as
select public.rpc_create_group_member('50000000-0000-0000-0000-000000000001', 'Target Member') as result;

-- ---------------------------------------------------------------------
-- As SECRETARY (member.edit, but not member.change_status).
-- ---------------------------------------------------------------------
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to '40000000-0000-0000-0000-000000000002';

-- 10. SECRETARY/member.edit can edit display_name.
select lives_ok(
  format(
    $sql$ select public.rpc_update_group_member('50000000-0000-0000-0000-000000000001', %L, 'Renamed by Secretary') $sql$,
    (select result ->> 'membership_id' from t_target)
  ),
  'SECRETARY (member.edit) can edit display_name'
);

select is(
  (select display_name from public.group_memberships
    where id = (select (result ->> 'membership_id')::uuid from t_target)),
  'Renamed by Secretary',
  'display_name was actually updated'
);

-- 11. SECRETARY cannot change status without member.change_status.
select throws_ok(
  format(
    $sql$ select public.rpc_change_group_member_status('50000000-0000-0000-0000-000000000001', %L, 'SUSPENDED') $sql$,
    (select result ->> 'membership_id' from t_target)
  ),
  '42501',
  null,
  'SECRETARY cannot change member status (lacks member.change_status)'
);

-- ---------------------------------------------------------------------
-- As TREASURER (neither member.edit nor member.change_status).
-- ---------------------------------------------------------------------
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to '40000000-0000-0000-0000-000000000003';

-- 14. Unauthorized user cannot edit member metadata.
select throws_ok(
  format(
    $sql$ select public.rpc_update_group_member('50000000-0000-0000-0000-000000000001', %L, 'Hacked Name') $sql$,
    (select result ->> 'membership_id' from t_target)
  ),
  '42501',
  null,
  'TREASURER cannot edit member metadata (lacks member.edit)'
);

-- ---------------------------------------------------------------------
-- As ADMIN (has member.change_status).
-- ---------------------------------------------------------------------
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to '40000000-0000-0000-0000-000000000001';

-- 12. Authorized member.change_status holder can suspend member.
select lives_ok(
  format(
    $sql$ select public.rpc_change_group_member_status('50000000-0000-0000-0000-000000000001', %L, 'SUSPENDED') $sql$,
    (select result ->> 'membership_id' from t_target)
  ),
  'ADMIN (member.change_status) can suspend a member'
);

select is(
  (select status::text from public.group_memberships
    where id = (select (result ->> 'membership_id')::uuid from t_target)),
  'SUSPENDED',
  'member status is now SUSPENDED'
);

-- 13. Authorized member.change_status holder can restore SUSPENDED -> ACTIVE.
select lives_ok(
  format(
    $sql$ select public.rpc_change_group_member_status('50000000-0000-0000-0000-000000000001', %L, 'ACTIVE') $sql$,
    (select result ->> 'membership_id' from t_target)
  ),
  'ADMIN can restore a SUSPENDED member to ACTIVE'
);

select is(
  (select status::text from public.group_memberships
    where id = (select (result ->> 'membership_id')::uuid from t_target)),
  'ACTIVE',
  'member status is restored to ACTIVE, preserving the row/history'
);

-- 15. user_id cannot be changed through direct access (RPC never
-- exposes it as a parameter, and the direct grant is revoked).
select throws_ok(
  format(
    $sql$ update public.group_memberships set user_id = '40000000-0000-0000-0000-000000000003' where id = %L $sql$,
    (select result ->> 'membership_id' from t_target)
  ),
  '42501',
  null,
  'user_id cannot be changed via direct UPDATE, even by an ADMIN'
);

-- 16. group_id cannot be moved between memberships.
select throws_ok(
  format(
    $sql$ update public.group_memberships set group_id = '50000000-0000-0000-0000-000000000002' where id = %L $sql$,
    (select result ->> 'membership_id' from t_target)
  ),
  '42501',
  null,
  'group_id cannot be changed via direct UPDATE, even by an ADMIN'
);

select * from finish();

rollback;
