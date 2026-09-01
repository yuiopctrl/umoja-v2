-- Prompt 09C: loan repayment accounting semantics (section 32, items
-- 18-27). Loan: principal 1,000,000, term 4, 5% MONTHLY FLAT -> each
-- installment is exactly 250,000 principal + 50,000 interest.
begin;

select plan(13);

insert into auth.users (id, email) values
  ('4b000000-0000-0000-0000-000000000001', 'p09c-acct-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('4b100000-0000-0000-0000-000000000001', 'P09C Accounting Group', '4b000000-0000-0000-0000-000000000001', 'LACC');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('4b200000-0000-0000-0000-000000000001', '4b100000-0000-0000-0000-000000000001', '4b000000-0000-0000-0000-000000000001', 'LB Admin', 'ACTIVE', '2025-01-01', 'LACC-2026-0001'),
  ('4b200000-0000-0000-0000-000000000005', '4b100000-0000-0000-0000-000000000001', null, 'LB Borrower', 'ACTIVE', '2025-01-01', 'LACC-2026-0005');

insert into public.group_membership_roles (group_membership_id, role_id) select '4b200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '4b000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '4b100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '4b100000-0000-0000-0000-000000000001', 'NORMAL', 'Mkopo wa Kawaida',
  100000, 1, 12, 5.0000, 'MONTHLY', 'FLAT', 10000000
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

create temporary table t_loan as
select public.rpc_create_draft_loan_account(
  '4b100000-0000-0000-0000-000000000001', '4b200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 1000000, 4, (current_date - interval '3 months')::date
) as result;
select (result->>'id')::uuid as loan_id from t_loan \gset
select public.rpc_submit_loan_account('4b100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_approve_loan_account('4b100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_disburse_loan_account('4b100000-0000-0000-0000-000000000001', :'loan_id'::uuid, :'account_id'::uuid, current_date);

select installment_number, id as installment_id from public.loan_installments
where loan_account_id = :'loan_id'::uuid and installment_number = 1 \gset i1_
select installment_number, id as installment_id from public.loan_installments
where loan_account_id = :'loan_id'::uuid and installment_number = 2 \gset i2_

-- 22. scheduled interest alone (right after disbursement, before any
-- repayment) creates zero income.
select is(
  (public.rpc_get_financial_position('4b100000-0000-0000-0000-000000000001')->>'recognized_loan_interest_income')::numeric,
  0.00::numeric,
  '22: scheduled interest alone creates zero recognized income'
);

create temporary table t_position_before as
select public.rpc_get_financial_position('4b100000-0000-0000-0000-000000000001') as result;

-- Installment 1, fully settled in one payment: 50,000 interest +
-- 250,000 principal = 300,000.
create temporary table t_pay1 as
select public.rpc_post_payment(
  '4b100000-0000-0000-0000-000000000001', '4b200000-0000-0000-0000-000000000005'::uuid, :'account_id'::uuid,
  300000, current_date, 'CASH'
) as result;
select (result->>'payment_id')::uuid as payment1_id from t_pay1 \gset

-- 18. exactly one cashbook INFLOW for this payment.
select is(
  (select count(*) from public.financial_account_entries
   where source_type = 'PAYMENT' and source_id = :'payment1_id'::uuid and entry_type = 'INFLOW'),
  1::bigint,
  '18: one payment creates exactly one cashbook INFLOW'
);

-- 19. principal allocation reduces the funded receivable by exactly
-- the principal component (1,000,000 -> 750,000).
select is(
  (public.rpc_get_financial_position('4b100000-0000-0000-0000-000000000001')->>'funded_loan_principal_receivable')::numeric,
  750000.00::numeric,
  '19: principal allocation reduces funded_loan_principal_receivable by exactly the principal settled'
);

-- 20. principal allocation does not increase income — the ONLY income
-- increase from this 300,000 payment is the 50,000 interest, never the
-- full 300,000.
select is(
  (public.rpc_get_financial_position('4b100000-0000-0000-0000-000000000001')->>'group_income')::numeric
    - (select (result->>'group_income')::numeric from t_position_before),
  50000.00::numeric,
  '20: group_income increases by exactly the interest allocated (50,000), never the full payment'
);

-- 21. interest allocation increases recognized income by exactly
-- 50,000.
select is(
  (public.rpc_get_financial_position('4b100000-0000-0000-0000-000000000001')->>'recognized_loan_interest_income')::numeric,
  50000.00::numeric,
  '21: interest allocation recognizes exactly the interest settled as income'
);

-- 23. partial interest recognition — pay HALF of installment 2's
-- interest (25,000) only.
select public.rpc_post_payment(
  '4b100000-0000-0000-0000-000000000001', '4b200000-0000-0000-0000-000000000005'::uuid, :'account_id'::uuid,
  25000, current_date, 'CASH'
);
select is(
  (public.rpc_get_financial_position('4b100000-0000-0000-0000-000000000001')->>'recognized_loan_interest_income')::numeric,
  75000.00::numeric,
  '23a: partial interest recognition is exact (50,000 + 25,000 = 75,000)'
);
select is(
  (public.rpc_get_financial_position('4b100000-0000-0000-0000-000000000001')->>'scheduled_unearned_interest')::numeric,
  125000.00::numeric,
  '23b: scheduled/unearned interest decreases by exactly the newly recognized amount (200,000 - 75,000 = 125,000)'
);

-- 27 setup: settle the remaining 875,000 across installments 2-4
-- (installment 2 has 25,000 interest + 250,000 principal remaining;
-- installments 3-4 are fully untouched at 300,000 each) with a clean
-- partial payment first, so the wallet stays at zero credit until the
-- deliberate overpayment below.
select public.rpc_post_payment(
  '4b100000-0000-0000-0000-000000000001', '4b200000-0000-0000-0000-000000000005'::uuid, :'account_id'::uuid,
  524000, current_date, 'CASH'
);

select is(
  (public.rpc_get_member_wallet('4b100000-0000-0000-0000-000000000001', '4b200000-0000-0000-0000-000000000005'::uuid)->>'wallet_balance')::numeric,
  0.00::numeric,
  'setup check: no wallet credit yet — every payment so far was fully absorbed by outstanding obligations'
);

-- Now 351,000 remains outstanding on the loan. Pay a clean, deliberate
-- overpayment far beyond that remainder to generate wallet credit for
-- the wallet-allocation tests (27 first, to establish the invariant,
-- then 24/25/26 reusing that same credit against a FRESH loan's
-- obligations).
create temporary table t_overpay as
select public.rpc_post_payment(
  '4b100000-0000-0000-0000-000000000001', '4b200000-0000-0000-0000-000000000005'::uuid, :'account_id'::uuid,
  900000, current_date, 'CASH'
) as result;

-- 27. overpayment remainder follows the wallet invariant:
-- sum(allocations) + wallet_credit = payment amount.
select is(
  (select (result->>'total_allocated')::numeric + (result->>'wallet_credit_amount')::numeric from t_overpay),
  (select (result->>'amount')::numeric from t_overpay),
  '27: sum(allocations) + wallet_credit exactly equals the payment amount'
);
select ok(
  (select (result->>'wallet_credit_amount')::numeric from t_overpay) > 0,
  '27b: the unapplied remainder (loan and contributions fully settled) becomes wallet credit, never a phantom loan prepayment ledger'
);

-- A second, fresh ACTIVE loan for the same borrower, to exercise
-- wallet-to-loan settlement (24/25/26) against known-outstanding
-- components using the wallet credit just created above.
create temporary table t_loan2 as
select public.rpc_create_draft_loan_account(
  '4b100000-0000-0000-0000-000000000001', '4b200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 400000, 1, current_date
) as result;
select (result->>'id')::uuid as loan2_id from t_loan2 \gset
select public.rpc_submit_loan_account('4b100000-0000-0000-0000-000000000001', :'loan2_id'::uuid);
select public.rpc_approve_loan_account('4b100000-0000-0000-0000-000000000001', :'loan2_id'::uuid);
select public.rpc_disburse_loan_account('4b100000-0000-0000-0000-000000000001', :'loan2_id'::uuid, :'account_id'::uuid, current_date);

select id as loan2_installment_id from public.loan_installments where loan_account_id = :'loan2_id'::uuid \gset

create temporary table t_cashbook_count_before as
select count(*) as n from public.financial_account_entries where financial_account_id = :'account_id'::uuid;

create temporary table t_position_before_wallet as
select public.rpc_get_financial_position('4b100000-0000-0000-0000-000000000001') as result;

-- loan2: principal 400,000, term 1, 5% flat -> 20,000 interest,
-- 420,000 total due in installment 1. Allocate the whole wallet
-- balance (>= 420,000, since the earlier overpayment far exceeded it)
-- against it.
select public.rpc_allocate_member_wallet(
  '4b100000-0000-0000-0000-000000000001', '4b200000-0000-0000-0000-000000000005'::uuid, 420000
);

-- 24. wallet loan allocation creates zero cashbook movement.
select is(
  (select count(*) from public.financial_account_entries where financial_account_id = :'account_id'::uuid),
  (select n from t_cashbook_count_before),
  '24: wallet-to-loan allocation creates zero new cashbook entries'
);

-- 25. wallet principal allocation reduces the funded receivable.
select is(
  (public.rpc_get_financial_position('4b100000-0000-0000-0000-000000000001')->>'funded_loan_principal_receivable')::numeric,
  (select (result->>'funded_loan_principal_receivable')::numeric from t_position_before_wallet) - 400000,
  '25: wallet principal allocation reduces funded_loan_principal_receivable exactly'
);

-- 26. wallet interest allocation recognizes income.
select is(
  (public.rpc_get_financial_position('4b100000-0000-0000-0000-000000000001')->>'recognized_loan_interest_income')::numeric,
  (select (result->>'recognized_loan_interest_income')::numeric from t_position_before_wallet) + 20000,
  '26: wallet interest allocation recognizes exactly the interest settled as income'
);

select * from finish();
rollback;
