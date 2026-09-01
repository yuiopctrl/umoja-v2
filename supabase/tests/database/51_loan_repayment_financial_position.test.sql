-- Prompt 09C: Financial Position worked example (section 35). Loan:
-- principal 1,000,000, term 4, 5% MONTHLY FLAT -> scheduled interest
-- 200,000 total (50,000/installment). A single 300,000 payment
-- allocates Interest 50,000 + Principal 250,000 (installment 1, exact).
begin;

select plan(8);

insert into auth.users (id, email) values
  ('4e000000-0000-0000-0000-000000000001', 'p09c-fp-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('4e100000-0000-0000-0000-000000000001', 'P09C FP Group', '4e000000-0000-0000-0000-000000000001', 'LFPC');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('4e200000-0000-0000-0000-000000000001', '4e100000-0000-0000-0000-000000000001', '4e000000-0000-0000-0000-000000000001', 'LF Admin', 'ACTIVE', '2025-01-01', 'LFPC-2026-0001'),
  ('4e200000-0000-0000-0000-000000000005', '4e100000-0000-0000-0000-000000000001', null, 'LF Borrower', 'ACTIVE', '2025-01-01', 'LFPC-2026-0005');

insert into public.group_membership_roles (group_membership_id, role_id) select '4e200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '4e000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '4e100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '4e100000-0000-0000-0000-000000000001', 'NORMAL', 'Mkopo wa Kawaida',
  100000, 1, 12, 5.0000, 'MONTHLY', 'FLAT', 10000000
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

create temporary table t_loan as
select public.rpc_create_draft_loan_account(
  '4e100000-0000-0000-0000-000000000001', '4e200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 1000000, 4, current_date
) as result;
select (result->>'id')::uuid as loan_id from t_loan \gset
select public.rpc_submit_loan_account('4e100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_approve_loan_account('4e100000-0000-0000-0000-000000000001', :'loan_id'::uuid);

select public.rpc_disburse_loan_account('4e100000-0000-0000-0000-000000000001', :'loan_id'::uuid, :'account_id'::uuid, current_date);

create temporary table t_cash_before as
select coalesce(sum(case when entry_type in ('INFLOW', 'TRANSFER_IN') then amount else -amount end), 0) as cash
from public.financial_account_entries where financial_account_id = :'account_id'::uuid;

-- Baseline right after disbursement, before any repayment.
select is(
  (public.rpc_get_financial_position('4e100000-0000-0000-0000-000000000001')->>'funded_loan_principal_receivable')::numeric,
  1000000.00::numeric,
  'baseline: funded_loan_principal_receivable is the full disbursed principal before any repayment'
);
select is(
  (public.rpc_get_financial_position('4e100000-0000-0000-0000-000000000001')->>'scheduled_unearned_interest')::numeric,
  200000.00::numeric,
  'baseline: scheduled_unearned_interest is the full contractual interest before any repayment'
);

create temporary table t_pay as
select public.rpc_post_payment(
  '4e100000-0000-0000-0000-000000000001', '4e200000-0000-0000-0000-000000000005'::uuid, :'account_id'::uuid,
  300000, current_date, 'CASH'
) as result;
select (result->>'payment_id')::uuid as payment_id from t_pay \gset

-- Cash increases by exactly 300,000, once.
select is(
  (select coalesce(sum(case when entry_type in ('INFLOW', 'TRANSFER_IN') then amount else -amount end), 0)
   from public.financial_account_entries where financial_account_id = :'account_id'::uuid)
  - (select cash from t_cash_before),
  300000.00::numeric,
  'cash increases by exactly 300,000 from the repayment (measured after disbursement, before repayment)'
);

select is(
  (public.rpc_get_financial_position('4e100000-0000-0000-0000-000000000001')->>'funded_loan_principal_receivable')::numeric,
  750000.00::numeric,
  'funded_loan_principal_receivable: 1,000,000 - 250,000 = 750,000'
);
select is(
  (public.rpc_get_financial_position('4e100000-0000-0000-0000-000000000001')->>'recognized_loan_interest_income')::numeric,
  50000.00::numeric,
  'recognized_loan_interest_income: exactly the 50,000 interest allocated'
);
select is(
  (public.rpc_get_financial_position('4e100000-0000-0000-0000-000000000001')->>'scheduled_unearned_interest')::numeric,
  150000.00::numeric,
  'scheduled_unearned_interest: 200,000 - 50,000 recognized = 150,000'
);

-- Reversal restores all three figures exactly.
select public.rpc_reverse_payment('4e100000-0000-0000-0000-000000000001', :'payment_id'::uuid, 'entered in error');

select is(
  (public.rpc_get_financial_position('4e100000-0000-0000-0000-000000000001')->>'funded_loan_principal_receivable')::numeric,
  1000000.00::numeric,
  'reversal restores funded_loan_principal_receivable to 1,000,000'
);
select is(
  jsonb_build_object(
    'recognized_loan_interest_income',
    (public.rpc_get_financial_position('4e100000-0000-0000-0000-000000000001')->>'recognized_loan_interest_income')::numeric,
    'scheduled_unearned_interest',
    (public.rpc_get_financial_position('4e100000-0000-0000-0000-000000000001')->>'scheduled_unearned_interest')::numeric
  ),
  jsonb_build_object(
    'recognized_loan_interest_income', 0.00::numeric,
    'scheduled_unearned_interest', 200000.00::numeric
  ),
  'reversal restores recognized_loan_interest_income to 0 and scheduled_unearned_interest to 200,000'
);

select * from finish();
rollback;
