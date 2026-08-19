-- A member.create/member.edit permission holder must not be able to
-- attach an arbitrary auth user_id to a membership (directly or via
-- update) — linking an existing membership to an auth user is a
-- controlled future workflow, not a side effect of ordinary member
-- management permissions. See docs/product/member-identity-model.md.
--
-- Updated for Prompt 02A: direct authenticated INSERT/UPDATE on
-- group_memberships is now revoked entirely (see
-- 20260819083321_create_group_member_management_rpcs.sql) — member
-- creation goes exclusively through rpc_create_group_member(), even
-- with a null user_id.
begin;

select plan(4);

insert into auth.users (id, email) values
  ('66666666-6666-6666-6666-666666666666', 'admin-f@example.com'),
  ('77777777-7777-7777-7777-777777777777', 'bystander@example.com');

insert into public.groups (id, name, created_by) values
  ('ffffffff-ffff-ffff-ffff-ffffffffffff', 'Group F', '66666666-6666-6666-6666-666666666666');

insert into public.group_memberships (id, group_id, user_id, display_name, status) values
  ('a9999999-9999-9999-9999-999999999999', 'ffffffff-ffff-ffff-ffff-ffffffffffff', '66666666-6666-6666-6666-666666666666', 'Admin F', 'ACTIVE');

insert into public.group_membership_roles (group_membership_id, role_id)
select 'a9999999-9999-9999-9999-999999999999', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '66666666-6666-6666-6666-666666666666';

select throws_ok(
  $$ insert into public.group_memberships (group_id, user_id, display_name, status)
     values ('ffffffff-ffff-ffff-ffff-ffffffffffff', '77777777-7777-7777-7777-777777777777', 'Bystander', 'ACTIVE') $$,
  '42501',
  null,
  'a member.create holder cannot insert a membership pre-linked to an arbitrary user_id'
);

select throws_ok(
  $$ insert into public.group_memberships (group_id, user_id, display_name, status)
     values ('ffffffff-ffff-ffff-ffff-ffffffffffff', null, 'Unlinked Member', 'ACTIVE') $$,
  '42501',
  null,
  'direct INSERT on group_memberships is blocked even with a null user_id; only rpc_create_group_member may create members'
);

create temporary table t_member as
select public.rpc_create_group_member('ffffffff-ffff-ffff-ffff-ffffffffffff', 'Unlinked Member') as result;

select is(
  ((select result from t_member) ->> 'group_id'),
  'ffffffff-ffff-ffff-ffff-ffffffffffff',
  'rpc_create_group_member still works after direct INSERT was revoked'
);

select throws_ok(
  format(
    $sql$ update public.group_memberships set user_id = '77777777-7777-7777-7777-777777777777' where id = %L $sql$,
    (select result ->> 'membership_id' from t_member)
  ),
  '42501',
  null,
  'user_id cannot be changed by update, even by an ADMIN'
);

select * from finish();

rollback;
