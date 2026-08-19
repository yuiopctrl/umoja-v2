-- rpc_get_my_context() cannot be pointed at an arbitrary user, and
-- ordinary authenticated users cannot mutate system role/permission
-- definitions.
begin;

select plan(3);

select is(
  pg_get_function_identity_arguments('public.rpc_get_my_context'::regproc),
  '',
  'rpc_get_my_context takes no parameters, so it cannot accept a caller-supplied user_id'
);

select throws_ok(
  $$ select public.rpc_get_my_context() $$,
  '28000',
  null,
  'rpc_get_my_context requires an authenticated caller (auth.uid() is not null)'
);

set local role authenticated;
set local request.jwt.claim.sub to '11111111-1111-1111-1111-111111111111';

select throws_ok(
  $$ insert into public.roles (code, name) values ('HACKER', 'Hacker') $$,
  '42501',
  null,
  'ordinary authenticated users cannot create new role definitions'
);

select * from finish();

rollback;
