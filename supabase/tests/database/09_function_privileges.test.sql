-- Prompt 02A: focused function/RPC privilege review. anon must not be
-- able to invoke protected mutation RPCs; authenticated calls without a
-- resolved auth.uid() must fail safely; authorized authenticated calls
-- must still work.
begin;

select plan(5);

insert into auth.users (id, email) values
  ('80000000-0000-0000-0000-000000000001', 'authorized@example.com');

-- 21. anon cannot invoke protected mutation RPCs.
set local role anon;

select throws_ok(
  $$ select public.rpc_create_group('Anon Group') $$,
  '42501',
  null,
  'anon cannot invoke rpc_create_group'
);

select throws_ok(
  $$ select public.rpc_assign_group_role(gen_random_uuid(), gen_random_uuid(), 'MEMBER') $$,
  '42501',
  null,
  'anon cannot invoke rpc_assign_group_role'
);

select throws_ok(
  $$ select public.rpc_update_group_member(gen_random_uuid(), gen_random_uuid(), 'X') $$,
  '42501',
  null,
  'anon cannot invoke rpc_update_group_member'
);

-- 22. Unauthenticated calls (authenticated role, but no resolved
-- auth.uid()) fail safely rather than acting on a null identity.
reset role;
set local role authenticated;

select throws_ok(
  $$ select public.rpc_get_my_context() $$,
  '28000',
  null,
  'an authenticated-role call without a resolved auth.uid() fails safely'
);

-- 23. RPCs still work for an authorized, authenticated caller.
set local request.jwt.claim.sub to '80000000-0000-0000-0000-000000000001';

select lives_ok(
  $$ select public.rpc_get_my_context() $$,
  'rpc_get_my_context still works for an authorized authenticated caller'
);

select * from finish();

rollback;
