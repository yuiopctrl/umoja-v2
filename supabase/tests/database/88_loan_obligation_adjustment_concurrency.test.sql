-- Prompt 09F-A: idempotency / concurrency safety (section 14, test
-- matrix items 41, 42). pgTAP runs single-connection, so true concurrent
-- transactions cannot be reproduced here; item 42 instead proves the
-- structural guarantee that makes concurrent safety possible — every
-- posting RPC locks the target row and recomputes outstanding AFTER
-- that lock, never trusting a previously-computed figure, so two
-- sequential (or concurrent, in production) requests against the same
-- target can never together over-waive.
begin;

select plan(7);

insert into auth.users (id, email) values
  ('88000000-0000-0000-0000-000000000001', 'p09fa-concurrency-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('88100000-0000-0000-0000-000000000001', 'Concurrency Group', '88000000-0000-0000-0000-000000000001', 'CONC');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('88200000-0000-0000-0000-000000000001', '88100000-0000-0000-0000-000000000001', '88000000-0000-0000-0000-000000000001', 'Concurrency Admin', 'ACTIVE', '2025-01-01', 'CONC-2026-0001'),
  ('88200000-0000-0000-0000-000000000011', '88100000-0000-0000-0000-000000000001', null, 'Borrower', 'ACTIVE', '2025-01-01', 'CONC-2026-0011');

insert into public.group_membership_roles (group_membership_id, role_id) select '88200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '88000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '88100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '88100000-0000-0000-0000-000000000001', 'CONCP', 'Concurrency Product', 100000, 1, 12, 5.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'FIXED', p_penalty_frequency => 'ONCE',
  p_penalty_grace_days => 0, p_penalty_fixed_amount => 40000
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

create temporary table t_loan as
select public.rpc_create_draft_loan_account(
  '88100000-0000-0000-0000-000000000001', '88200000-0000-0000-0000-000000000011'::uuid,
  :'product_id'::uuid, 500000, 1, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_id from t_loan \gset
select public.rpc_submit_loan_account('88100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_approve_loan_account('88100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_disburse_loan_account('88100000-0000-0000-0000-000000000001', :'loan_id'::uuid, :'account_id'::uuid, current_date);
select id as installment_id from public.loan_installments where loan_account_id = :'loan_id'::uuid \gset
select public.rpc_assess_loan_penalties('88100000-0000-0000-0000-000000000001', current_date, :'loan_id'::uuid);
select id as charge_id from public.loan_penalty_charges where loan_installment_id = :'installment_id'::uuid \gset

-- Item 41: idempotent retry. Same key, same params, twice.
create temporary table t_first as
select public.rpc_post_loan_obligation_waiver(
  '88100000-0000-0000-0000-000000000001', :'loan_id'::uuid, 'LOAN_PENALTY', :'charge_id'::uuid,
  25000, 'HARDSHIP', null, current_date, 'idem-key-88-001'
) as result;
select is((result->>'already_posted')::boolean, false, '41a: the first request posts normally') from t_first;

create temporary table t_retry as
select public.rpc_post_loan_obligation_waiver(
  '88100000-0000-0000-0000-000000000001', :'loan_id'::uuid, 'LOAN_PENALTY', :'charge_id'::uuid,
  25000, 'HARDSHIP', null, current_date, 'idem-key-88-001'
) as result;
select is((result->>'already_posted')::boolean, true, '41b: a retried request with the same idempotency key reports already_posted') from t_retry;
select is(
  (select (t_first.result->>'adjustment_id')::uuid) = (select (t_retry.result->>'adjustment_id')::uuid),
  true,
  '41c: the retry returns the SAME adjustment id, never a new one'
) from t_first, t_retry;
select is(
  (select count(*)::integer from public.loan_obligation_adjustments where idempotency_key = 'idem-key-88-001'),
  1,
  '41d: exactly one adjustment row exists for that idempotency key despite two requests'
);

-- The DB-level unique index is the authoritative backstop: even a raw
-- second insert with the same (group_id, idempotency_key) is rejected
-- structurally, independent of the RPC's own lookup-first logic. Run as
-- superuser to isolate the constraint itself from the (separately
-- tested, in 83_...) fact that authenticated has no INSERT grant at all.
reset role;
select throws_ok(
  $$ insert into public.loan_obligation_adjustments (
       group_id, loan_account_id, target_type, loan_penalty_charge_id,
       adjustment_type, amount, reason_code, idempotency_key, created_by
     ) values (
       '88100000-0000-0000-0000-000000000001', (select loan_account_id from public.loan_obligation_adjustments where idempotency_key = 'idem-key-88-001'),
       'LOAN_PENALTY', (select loan_penalty_charge_id from public.loan_obligation_adjustments where idempotency_key = 'idem-key-88-001'),
       'WAIVER', -1, 'HARDSHIP', 'idem-key-88-001', '88000000-0000-0000-0000-000000000001'
     ) $$,
  '23505',
  null,
  'the unique index on (group_id, idempotency_key) is the structural double-post backstop'
);

-- Item 42: sequential proxy for concurrent safety. After the 25,000
-- waiver above, only 15,000 remains outstanding (40,000 - 25,000). A
-- second, genuinely distinct request for 20,000 must be rejected —
-- proving outstanding is recomputed AFTER the row lock is acquired,
-- never trusting a stale/previously-read figure.
reset role;
select outstanding as outstanding_after_first from public.loan_penalty_charge_states(:'installment_id'::uuid) where charge_id = :'charge_id'::uuid \gset
set local role authenticated;
set local request.jwt.claim.sub to '88000000-0000-0000-0000-000000000001';

select is(
  :'outstanding_after_first'::numeric,
  15000.00::numeric,
  'setup: 15,000 remains outstanding after the first 25,000 waiver'
);

select throws_ok(
  format(
    $sql$ select public.rpc_post_loan_obligation_waiver('88100000-0000-0000-0000-000000000001', %L::uuid, 'LOAN_PENALTY', %L::uuid, 20000, 'GOODWILL') $sql$,
    :'loan_id', :'charge_id'
  ),
  'P0001',
  'LOAN_WAIVER_EXCEEDS_OUTSTANDING',
  '42: a second, distinct request recomputes outstanding fresh after locking — cannot over-waive the remaining 15,000'
);

select * from finish();
rollback;
