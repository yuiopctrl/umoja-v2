-- Prompt 05E: the private user_pin_credentials table + its narrowly
-- scoped SECURITY DEFINER helpers (record_pin_login_failure,
-- reset_pin_login_failures, rpc_has_pin_credential). These back the
-- setup-pin/pin-login Edge Functions — see supabase/functions/setup-pin/,
-- supabase/functions/pin-login/, whose own request/response behavior is
-- covered by Deno tests, not pgTAP. Nothing here ever touches a PIN
-- value or a derived password — those never reach the database at all.
begin;

select plan(15);

insert into auth.users (id, email) values
  ('e1000000-0000-0000-0000-000000000001', 'pin-user-a@example.com'),
  ('e1000000-0000-0000-0000-000000000002', 'pin-user-b@example.com');

-- ---------------------------------------------------------------------
-- 1-2. No direct client access at all — RLS is enabled with zero
-- policies on user_pin_credentials, which is default-deny for every
-- RLS-subject role.
-- ---------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claim.sub to 'e1000000-0000-0000-0000-000000000001';

select throws_ok(
  $$ select * from public.user_pin_credentials $$,
  '42501',
  null,
  'authenticated cannot directly read user_pin_credentials'
);

select throws_ok(
  format(
    $sql$ insert into public.user_pin_credentials (user_id, phone_e164, pin_set_at)
          values (%L, '+255712345678', now()) $sql$,
    'e1000000-0000-0000-0000-000000000001'
  ),
  '42501',
  null,
  'authenticated cannot directly insert into user_pin_credentials'
);

reset role;

-- ---------------------------------------------------------------------
-- 3-4. record_pin_login_failure / reset_pin_login_failures are
-- internal only — no direct client execute privilege. Only trusted
-- Edge Function code (service-role) ever calls these.
-- ---------------------------------------------------------------------
select is(
  has_function_privilege(
    'authenticated',
    'public.record_pin_login_failure(uuid, integer, integer, integer)',
    'execute'
  ),
  false,
  'authenticated has no direct execute privilege on record_pin_login_failure'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.reset_pin_login_failures(uuid)',
    'execute'
  ),
  false,
  'authenticated has no direct execute privilege on reset_pin_login_failures'
);

-- ---------------------------------------------------------------------
-- Fixture: a credential row for user A, inserted the way a trusted
-- service-role Edge Function client would (reset role bypasses the
-- RLS/grant restriction proven above, standing in for that context).
-- ---------------------------------------------------------------------
insert into public.user_pin_credentials (user_id, phone_e164, pin_set_at) values
  ('e1000000-0000-0000-0000-000000000001', '+255712345678', now());

-- ---------------------------------------------------------------------
-- 5. phone_e164 format is enforced at the database level.
-- ---------------------------------------------------------------------
select throws_ok(
  $$ insert into public.user_pin_credentials (user_id, phone_e164, pin_set_at)
     values ('e1000000-0000-0000-0000-000000000002', '0712345678', now()) $$,
  '23514',
  null,
  'a non-E.164 phone is rejected by the format check'
);

-- ---------------------------------------------------------------------
-- 6. phone_e164 is unique across users.
-- ---------------------------------------------------------------------
select throws_ok(
  $$ insert into public.user_pin_credentials (user_id, phone_e164, pin_set_at)
     values ('e1000000-0000-0000-0000-000000000002', '+255712345678', now()) $$,
  '23505',
  null,
  'the same phone number cannot be claimed by a second user'
);

-- ---------------------------------------------------------------------
-- 7-10. record_pin_login_failure: attempts 1-4 never lock; the 5th
-- crosses the threshold and locks for the base ~5 minute duration.
-- ---------------------------------------------------------------------
select public.record_pin_login_failure('e1000000-0000-0000-0000-000000000001')
from generate_series(1, 4);

select is(
  (select failed_attempts from public.user_pin_credentials
     where user_id = 'e1000000-0000-0000-0000-000000000001'),
  4,
  'four failed attempts do not lock the account'
);

select is(
  (select locked_until from public.user_pin_credentials
     where user_id = 'e1000000-0000-0000-0000-000000000001'),
  null,
  'no lock is set before the threshold is crossed'
);

select public.record_pin_login_failure('e1000000-0000-0000-0000-000000000001');

select is(
  (select failed_attempts from public.user_pin_credentials
     where user_id = 'e1000000-0000-0000-0000-000000000001'),
  5,
  'the fifth failed attempt is recorded'
);

select ok(
  (select locked_until from public.user_pin_credentials
     where user_id = 'e1000000-0000-0000-0000-000000000001')
    between now() + interval '4 minutes' and now() + interval '6 minutes',
  'the fifth failed attempt locks the account for the base ~5 minute duration'
);

-- ---------------------------------------------------------------------
-- 11. Escalating lockout: a second full cycle of failures (10 total,
-- continuing from the 5 already recorded above — no reset in between)
-- locks for longer than the first cycle's ~5 minutes. The SQL function
-- itself does not refuse to increment while already locked — that
-- check belongs to the caller (pin-login checks locked_until before
-- ever calling this), so calling it straight through to 10 is the
-- correct way to exercise both cycles in one pgTAP transaction.
-- ---------------------------------------------------------------------
select public.record_pin_login_failure('e1000000-0000-0000-0000-000000000001')
from generate_series(1, 5);

select ok(
  (select locked_until from public.user_pin_credentials
     where user_id = 'e1000000-0000-0000-0000-000000000001')
    between now() + interval '9 minutes' and now() + interval '11 minutes',
  'a second lock cycle (10 total failures) locks for a longer ~10 minute duration'
);

-- ---------------------------------------------------------------------
-- 12. reset_pin_login_failures clears both failed_attempts and
-- locked_until (called on a successful login, and on a fresh PIN
-- set/reset via setup-pin) — even after an escalated lock.
-- ---------------------------------------------------------------------
select public.reset_pin_login_failures('e1000000-0000-0000-0000-000000000001');

select results_eq(
  $$ select failed_attempts, locked_until from public.user_pin_credentials
     where user_id = 'e1000000-0000-0000-0000-000000000001' $$,
  $$ values (0, null::timestamptz) $$,
  'reset_pin_login_failures clears both the counter and any lock'
);

-- ---------------------------------------------------------------------
-- 13-15. rpc_has_pin_credential(): true only for the caller's own row,
-- false otherwise, and reveals nothing about a different user; no
-- anon access.
-- ---------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claim.sub to 'e1000000-0000-0000-0000-000000000001';

select is(
  public.rpc_has_pin_credential(),
  true,
  'rpc_has_pin_credential is true for a user with a credential row'
);

reset role;
set local role authenticated;
set local request.jwt.claim.sub to 'e1000000-0000-0000-0000-000000000002';

select is(
  public.rpc_has_pin_credential(),
  false,
  'rpc_has_pin_credential is false for a user with no credential row of their own'
);

select is(
  has_function_privilege('anon', 'public.rpc_has_pin_credential()', 'execute'),
  false,
  'anon has no execute privilege on rpc_has_pin_credential'
);

select * from finish();

rollback;
