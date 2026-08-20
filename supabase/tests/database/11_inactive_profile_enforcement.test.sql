-- Prompt 03: an inactive profile (is_active = false) must not retain
-- effective group mutation privileges through an existing session, and
-- rpc_get_my_context() must still represent an inactive profile safely
-- (never blocked) so Flutter can detect it and route accordingly.
begin;

select plan(12);

insert into auth.users (id, email) values
  ('a0000000-0000-0000-0000-000000000001', 'active-admin@example.com'),
  ('a0000000-0000-0000-0000-000000000002', 'inactive-admin@example.com');

insert into public.groups (id, name, created_by) values
  ('a1000000-0000-0000-0000-000000000001', 'Group Q', 'a0000000-0000-0000-0000-000000000001');

insert into public.group_memberships (id, group_id, user_id, display_name, status) values
  ('a2000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'ActiveAdmin', 'ACTIVE'),
  ('a2000000-0000-0000-0000-000000000002', 'a1000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000002', 'InactiveAdmin', 'ACTIVE');

insert into public.group_membership_roles (group_membership_id, role_id)
select 'a2000000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id)
select 'a2000000-0000-0000-0000-000000000002', id from public.roles where code = 'ADMIN';

-- Deactivate the second user's profile (as postgres, bypassing the
-- column-grant restriction that applies to ordinary clients).
update public.profiles set is_active = false where id = 'a0000000-0000-0000-0000-000000000002';

-- ---------------------------------------------------------------------
-- As the inactive user.
-- ---------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claim.sub to 'a0000000-0000-0000-0000-000000000002';

-- 1. is_active=false user cannot create a new group.
select throws_ok(
  $$ select public.rpc_create_group('Should Not Exist') $$,
  'P0001',
  'ACCOUNT_DISABLED',
  'an inactive profile cannot create a new group'
);

-- 2. is_active=false user cannot create/edit group members.
select throws_ok(
  $$ select public.rpc_create_group_member('a1000000-0000-0000-0000-000000000001', 'New Member') $$,
  'P0001',
  'ACCOUNT_DISABLED',
  'an inactive profile cannot create a group member'
);

select throws_ok(
  $$ select public.rpc_update_group_member('a1000000-0000-0000-0000-000000000001', 'a2000000-0000-0000-0000-000000000001', 'Renamed') $$,
  'P0001',
  'ACCOUNT_DISABLED',
  'an inactive profile cannot edit a group member'
);

-- 3. is_active=false user cannot assign/remove roles.
select throws_ok(
  $$ select public.rpc_assign_group_role('a1000000-0000-0000-0000-000000000001', 'a2000000-0000-0000-0000-000000000001', 'TREASURER') $$,
  'P0001',
  'ACCOUNT_DISABLED',
  'an inactive profile cannot assign a role'
);

select throws_ok(
  $$ select public.rpc_remove_group_role('a1000000-0000-0000-0000-000000000001', 'a2000000-0000-0000-0000-000000000001', 'ADMIN') $$,
  'P0001',
  'ACCOUNT_DISABLED',
  'an inactive profile cannot remove a role'
);

select throws_ok(
  $$ select public.rpc_change_group_member_status('a1000000-0000-0000-0000-000000000001', 'a2000000-0000-0000-0000-000000000001', 'SUSPENDED') $$,
  'P0001',
  'ACCOUNT_DISABLED',
  'an inactive profile cannot change a member''s status'
);

-- 4. is_active=false user does not retain effective group permission,
-- even though their ADMIN role assignment structurally still exists.
select is(
  public.has_group_permission('a1000000-0000-0000-0000-000000000001', 'group.view'),
  false,
  'has_group_permission is false for an inactive profile despite holding ADMIN'
);

select is(
  public.is_group_member('a1000000-0000-0000-0000-000000000001'),
  false,
  'is_group_member is false for an inactive profile'
);

-- 6. rpc_get_my_context represents the inactive profile safely (never
-- blocked/errors) so Flutter can detect it and route to
-- /access/account-disabled.
select lives_ok(
  $$ select public.rpc_get_my_context() $$,
  'rpc_get_my_context does not error for an inactive profile'
);

create temporary table t_inactive_ctx as
select public.rpc_get_my_context() as ctx;

select is(
  ((select ctx from t_inactive_ctx) -> 'profile' ->> 'is_active')::boolean,
  false,
  'rpc_get_my_context reports is_active = false for the inactive profile'
);

-- ---------------------------------------------------------------------
-- 5. An active user continues to function normally (same group,
-- different admin membership).
-- ---------------------------------------------------------------------
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to 'a0000000-0000-0000-0000-000000000001';

select lives_ok(
  $$ select public.rpc_create_group_member('a1000000-0000-0000-0000-000000000001', 'Legit Member') $$,
  'an active profile can still create a group member'
);

select is(
  public.has_group_permission('a1000000-0000-0000-0000-000000000001', 'group.view'),
  true,
  'has_group_permission remains true for an active profile'
);

select * from finish();

rollback;
