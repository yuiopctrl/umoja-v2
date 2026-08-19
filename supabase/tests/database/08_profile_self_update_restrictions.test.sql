-- Prompt 02A, issue 3: profiles unsafe self-update columns. Row access
-- stays owner-only (RLS); column access is now restricted to
-- full_name/phone/avatar_url via column-level GRANTs.
begin;

select plan(8);

insert into auth.users (id, email, raw_user_meta_data) values
  ('70000000-0000-0000-0000-000000000001', 'usera@example.com', '{"full_name":"User A"}'::jsonb),
  ('70000000-0000-0000-0000-000000000002', 'userb@example.com', '{"full_name":"User B"}'::jsonb);

set local role authenticated;
set local request.jwt.claim.sub to '70000000-0000-0000-0000-000000000001';

-- 17. User can edit own full_name.
select lives_ok(
  $$ update public.profiles set full_name = 'User A Updated' where id = '70000000-0000-0000-0000-000000000001' $$,
  'a user can update their own full_name'
);

select is(
  (select full_name from public.profiles where id = '70000000-0000-0000-0000-000000000001'),
  'User A Updated',
  'full_name was actually updated'
);

-- User can update own other safe profile fields (phone).
select lives_ok(
  $$ update public.profiles set phone = '+255700000001' where id = '70000000-0000-0000-0000-000000000001' $$,
  'a user can update their own safe profile fields (phone)'
);

select is(
  (select phone from public.profiles where id = '70000000-0000-0000-0000-000000000001'),
  '+255700000001',
  'phone was actually updated'
);

-- 18. User cannot edit another profile (RLS row-level: the UPDATE
-- matches zero rows rather than erroring). A data-modifying WITH must
-- be the top-level statement, so run it into a temp table first.
create temporary table t_cross_user_update as
with updated as (
  update public.profiles set full_name = 'Hacked'
  where id = '70000000-0000-0000-0000-000000000002'
  returning id
)
select count(*) as n from updated;

select is(
  (select n from t_cross_user_update),
  0::bigint,
  'a user cannot update another user''s profile row'
);

-- 19. User cannot reactivate/change their own is_active flag.
select throws_ok(
  $$ update public.profiles set is_active = false where id = '70000000-0000-0000-0000-000000000001' $$,
  '42501',
  null,
  'a user cannot change their own is_active flag'
);

-- 20. Protected profile identity/audit fields remain protected.
select throws_ok(
  $$ update public.profiles set email = 'attacker@example.com' where id = '70000000-0000-0000-0000-000000000001' $$,
  '42501',
  null,
  'a user cannot change their own email via public.profiles'
);

select throws_ok(
  $$ update public.profiles set created_at = now() - interval '1 year' where id = '70000000-0000-0000-0000-000000000001' $$,
  '42501',
  null,
  'a user cannot change their own created_at'
);

select * from finish();

rollback;
