-- Authorization: permission-gated member creation and role assignment,
-- and that the tenant helper functions cannot be used to escalate
-- privileges into a group the caller does not belong to.
begin;

select plan(6);

insert into auth.users (id, email) values
  ('33333333-3333-3333-3333-333333333333', 'admin@example.com'),
  ('44444444-4444-4444-4444-444444444444', 'member@example.com');

insert into public.groups (id, name, created_by) values
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'Group D', '33333333-3333-3333-3333-333333333333'),
  ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'Group E', '33333333-3333-3333-3333-333333333333');

insert into public.group_memberships (id, group_id, user_id, display_name, status) values
  ('f1111111-1111-1111-1111-111111111111', 'dddddddd-dddd-dddd-dddd-dddddddddddd', '33333333-3333-3333-3333-333333333333', 'Admin D', 'ACTIVE'),
  ('f2222222-2222-2222-2222-222222222222', 'dddddddd-dddd-dddd-dddd-dddddddddddd', '44444444-4444-4444-4444-444444444444', 'Member D', 'ACTIVE');

insert into public.group_membership_roles (group_membership_id, role_id)
select 'f1111111-1111-1111-1111-111111111111', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id)
select 'f2222222-2222-2222-2222-222222222222', id from public.roles where code = 'MEMBER';

-- Simulate a plain MEMBER (no member.create, no role.assign).
set local role authenticated;
set local request.jwt.claim.sub to '44444444-4444-4444-4444-444444444444';

select throws_ok(
  $$ select public.rpc_create_group_member('dddddddd-dddd-dddd-dddd-dddddddddddd', 'New Member') $$,
  '42501',
  null,
  'a MEMBER cannot create another member via rpc_create_group_member'
);

select throws_ok(
  $$ insert into public.group_membership_roles (group_membership_id, role_id)
     select 'f2222222-2222-2222-2222-222222222222', id from public.roles where code = 'ADMIN' $$,
  '42501',
  null,
  'assigning a role requires role.assign permission'
);

select is(
  public.has_group_permission('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'member.view'),
  false,
  'the tenant helper function cannot grant permission in a group the caller does not belong to'
);

-- Switch to the ADMIN of Group D.
reset request.jwt.claim.sub;
set local request.jwt.claim.sub to '33333333-3333-3333-3333-333333333333';

select isnt(
  (select public.rpc_create_group_member('dddddddd-dddd-dddd-dddd-dddddddddddd', 'New Member')),
  null,
  'an ADMIN can create another member via rpc_create_group_member'
);

select is(
  (select count(*) from public.group_memberships
    where group_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd' and display_name = 'New Member'),
  1::bigint,
  'the created member row exists in the group'
);

select is(
  (select user_id from public.group_memberships
    where group_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd' and display_name = 'New Member'),
  null,
  'a member created via rpc_create_group_member has no auth user_id'
);

select * from finish();

rollback;
