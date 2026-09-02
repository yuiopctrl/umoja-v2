-- Prompt 09D: penalty interaction with loan CLOSURE/REOPENING (section
-- 48, items 59-64). Loan: 200,000 principal / 1 installment, 10%
-- MONTHLY FLAT -> interest_due 20,000. FIXED penalty (grace=0, amount
-- 15,000).
begin;

select plan(8);

insert into auth.users (id, email) values
  ('69000000-0000-0000-0000-000000000001', 'p09d-closure-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('69100000-0000-0000-0000-000000000001', 'P09D Closure Group', '69000000-0000-0000-0000-000000000001', 'PENCL');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('69200000-0000-0000-0000-000000000001', '69100000-0000-0000-0000-000000000001', '69000000-0000-0000-0000-000000000001', 'PCL Admin', 'ACTIVE', '2025-01-01', 'PENCL-2026-0001'),
  ('69200000-0000-0000-0000-000000000005', '69100000-0000-0000-0000-000000000001', null, 'PCL Borrower', 'ACTIVE', '2025-01-01', 'PENCL-2026-0005');

insert into public.group_membership_roles (group_membership_id, role_id) select '69200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '69000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '69100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '69100000-0000-0000-0000-000000000001', 'PCLOSE', 'Closure Product', 100000, 1, 12, 10.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'FIXED', p_penalty_frequency => 'ONCE',
  p_penalty_grace_days => 0, p_penalty_fixed_amount => 15000
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

create temporary table t_loan as
select public.rpc_create_draft_loan_account(
  '69100000-0000-0000-0000-000000000001', '69200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 200000, 1, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_id from t_loan \gset
select public.rpc_submit_loan_account('69100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_approve_loan_account('69100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_disburse_loan_account('69100000-0000-0000-0000-000000000001', :'loan_id'::uuid, :'account_id'::uuid, current_date);
select id as installment_id from public.loan_installments where loan_account_id = :'loan_id'::uuid \gset

select public.rpc_assess_loan_penalties('69100000-0000-0000-0000-000000000001', current_date, :'loan_id'::uuid);

-- ---------------------------------------------------------------------
-- 59: principal+interest zero but penalty outstanding -> loan stays
-- ACTIVE. Structurally unreachable via ordinary allocation under the
-- locked PENALTY-first priority, so proven directly against the
-- closure predicate via a raw (contrived) fixture insert — the exact
-- isolation technique already used for the analogous 09C case (see
-- 50_loan_repayment_closure.test.sql item 37).
-- ---------------------------------------------------------------------

reset role;
insert into public.payments (
  id, group_id, membership_id, financial_account_id, amount, effective_at, payment_method, receipt_number, created_by
) values (
  '69900000-0000-0000-0000-000000000001', '69100000-0000-0000-0000-000000000001'::uuid,
  '69200000-0000-0000-0000-000000000005'::uuid, :'account_id'::uuid, 220000, current_date, 'CASH',
  'MANUAL-TEST-0001', '69000000-0000-0000-0000-000000000001'
);
insert into public.payment_allocations (
  group_id, payment_id, membership_id, amount, allocation_target_type, line_number, loan_account_id, loan_installment_id, created_by
) values (
  '69100000-0000-0000-0000-000000000001'::uuid, '69900000-0000-0000-0000-000000000001', '69200000-0000-0000-0000-000000000005'::uuid,
  200000, 'LOAN_PRINCIPAL', 1, :'loan_id'::uuid, :'installment_id'::uuid, '69000000-0000-0000-0000-000000000001'
),
(
  '69100000-0000-0000-0000-000000000001'::uuid, '69900000-0000-0000-0000-000000000001', '69200000-0000-0000-0000-000000000005'::uuid,
  20000, 'LOAN_INTEREST', 2, :'loan_id'::uuid, :'installment_id'::uuid, '69000000-0000-0000-0000-000000000001'
);
select public.loan_account_recheck_closure(
  '69100000-0000-0000-0000-000000000001'::uuid, :'loan_id'::uuid, '69000000-0000-0000-0000-000000000001'::uuid
);
select is(
  (select status::text from public.loan_accounts where id = :'loan_id'::uuid),
  'ACTIVE',
  '59: principal+interest fully settled but a 15,000 penalty remains outstanding (contrived) — the loan stays ACTIVE, never closes early'
);

-- Undo the contrived state before the real closure test below.
delete from public.payment_allocations where payment_id = '69900000-0000-0000-0000-000000000001';
delete from public.payments where id = '69900000-0000-0000-0000-000000000001';
set local role authenticated;
set local request.jwt.claim.sub to '69000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- 60/61: paying off ALL three (penalty + interest + principal) closes
-- the loan, with exactly one CLOSED event.
-- ---------------------------------------------------------------------

create temporary table t_post as
select public.rpc_post_payment(
  '69100000-0000-0000-0000-000000000001', '69200000-0000-0000-0000-000000000005'::uuid, :'account_id'::uuid,
  235000, current_date, 'CASH'
) as result;
select (result->>'payment_id')::uuid as payment_id from t_post \gset

select is(
  (select status::text from public.loan_accounts where id = :'loan_id'::uuid),
  'CLOSED',
  '60: once principal+interest+penalty are ALL zero, the loan closes'
);
select is(
  (select count(*) from public.loan_account_events where loan_account_id = :'loan_id'::uuid and event_type = 'CLOSED'),
  1::bigint,
  '61: exactly one CLOSED event is recorded'
);

-- ---------------------------------------------------------------------
-- 62/63/64: reversing the final payment restores the outstanding
-- balance and reopens the loan, with exactly one REOPENED event and
-- correct restored totals.
-- ---------------------------------------------------------------------

select public.rpc_reverse_payment('69100000-0000-0000-0000-000000000001', :'payment_id'::uuid, 'Reopen test');

select is(
  (select status::text from public.loan_accounts where id = :'loan_id'::uuid),
  'ACTIVE',
  '62: reversing the final payment (which restores penalty+interest+principal outstanding) reopens the loan to ACTIVE'
);
select is(
  (select count(*) from public.loan_account_events where loan_account_id = :'loan_id'::uuid and event_type = 'REOPENED'),
  1::bigint,
  '63: exactly one REOPENED event is recorded'
);

reset role;
select is(
  (select outstanding from public.loan_installment_component_states(:'installment_id'::uuid) where component_type = 'PENALTY'),
  15000.00::numeric,
  '64a: reopened penalty outstanding is exactly 15,000'
);
select is(
  (select outstanding from public.loan_installment_component_states(:'installment_id'::uuid) where component_type = 'INTEREST'),
  20000.00::numeric,
  '64b: reopened interest outstanding is exactly 20,000'
);
select is(
  (select outstanding from public.loan_installment_component_states(:'installment_id'::uuid) where component_type = 'PRINCIPAL'),
  200000.00::numeric,
  '64c: reopened principal outstanding is exactly 200,000'
);
set local role authenticated;
set local request.jwt.claim.sub to '69000000-0000-0000-0000-000000000001';

select * from finish();
rollback;
