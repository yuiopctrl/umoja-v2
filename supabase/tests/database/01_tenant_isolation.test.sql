-- Tenant isolation: a user with no membership in a group cannot see that
-- group's data, an active member can see their own group, and
-- member_number uniqueness is scoped per-group.
begin;

select plan(5);

-- Fixtures (inserted as postgres, which bypasses RLS).
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'user-a@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'user-b@example.com');

insert into public.groups (id, name, created_by) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Group A', '11111111-1111-1111-1111-111111111111'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Group B', '22222222-2222-2222-2222-222222222222');

insert into public.group_memberships (id, group_id, user_id, display_name, status) values
  ('c1111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'User A', 'ACTIVE'),
  ('c2222222-2222-2222-2222-222222222222', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '22222222-2222-2222-2222-222222222222', 'User B', 'ACTIVE');

insert into public.group_membership_roles (group_membership_id, role_id)
select 'c1111111-1111-1111-1111-111111111111', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id)
select 'c2222222-2222-2222-2222-222222222222', id from public.roles where code = 'MEMBER';

insert into public.group_memberships (group_id, user_id, display_name, status, member_number)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', null, 'Member X', 'ACTIVE', 'M-001');

select lives_ok(
  $$ insert into public.group_memberships (group_id, user_id, display_name, status, member_number)
     values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', null, 'Member Y', 'ACTIVE', 'M-001') $$,
  'the same member_number can exist in different groups'
);

select throws_ok(
  $$ insert into public.group_memberships (group_id, user_id, display_name, status, member_number)
     values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', null, 'Member Z', 'ACTIVE', 'M-001') $$,
  '23505',
  null,
  'member_number uniqueness is scoped to a single group'
);

-- Simulate an authenticated request from User A.
set local role authenticated;
set local request.jwt.claim.sub to '11111111-1111-1111-1111-111111111111';

select is(
  (select count(*) from public.groups where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  0::bigint,
  'User A cannot read Group B when not a member of it'
);

select is(
  (select count(*) from public.groups where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  1::bigint,
  'an active membership lets the user see their own group'
);

select is(
  public.is_group_member('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  false,
  'is_group_member is false for a group the caller does not belong to'
);

select * from finish();

rollback;
