-- rpc_create_group() must atomically create the group, the caller's
-- membership, and their ADMIN role assignment in one call.
begin;

select plan(5);

insert into auth.users (id, email, raw_user_meta_data) values (
  '55555555-5555-5555-5555-555555555555',
  'creator@example.com',
  '{"full_name":"Creator Person"}'::jsonb
);

set local role authenticated;
set local request.jwt.claim.sub to '55555555-5555-5555-5555-555555555555';

create temporary table t_ctx as
select public.rpc_create_group('New Group', 'A test group') as ctx;

select is(
  jsonb_array_length((select ctx from t_ctx) -> 'memberships'),
  1,
  'rpc_create_group results in exactly one membership for the creator'
);

select is(
  ((select ctx from t_ctx) -> 'memberships' -> 0 ->> 'group_name'),
  'New Group',
  'the created group name is reflected in the returned context'
);

select ok(
  ((select ctx from t_ctx) -> 'memberships' -> 0 -> 'roles') @> '["ADMIN"]'::jsonb,
  'the creator is assigned the ADMIN role'
);

select is(
  (select count(*) from public.groups
    where name = 'New Group' and created_by = '55555555-5555-5555-5555-555555555555'),
  1::bigint,
  'exactly one group row was created'
);

select is(
  (select count(*)
    from public.group_memberships gm
    join public.groups g on g.id = gm.group_id
    where g.name = 'New Group' and gm.user_id = '55555555-5555-5555-5555-555555555555'),
  1::bigint,
  'exactly one membership row links the creator to the new group'
);

select * from finish();

rollback;
