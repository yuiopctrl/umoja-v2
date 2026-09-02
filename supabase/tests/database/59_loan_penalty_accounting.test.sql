-- Prompt 09D: penalty ACCOUNTING (section 46, items 45-52). Loan:
-- 200,000 principal / 1 installment, 10% MONTHLY FLAT -> interest_due
-- = 20,000. FIXED penalty (grace=0, amount=15,000).
begin;

select plan(11);

insert into auth.users (id, email) values
  ('67000000-0000-0000-0000-000000000001', 'p09d-acct-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('67100000-0000-0000-0000-000000000001', 'P09D Accounting Group', '67000000-0000-0000-0000-000000000001', 'PENAC');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('67200000-0000-0000-0000-000000000001', '67100000-0000-0000-0000-000000000001', '67000000-0000-0000-0000-000000000001', 'PAC Admin', 'ACTIVE', '2025-01-01', 'PENAC-2026-0001'),
  ('67200000-0000-0000-0000-000000000005', '67100000-0000-0000-0000-000000000001', null, 'PAC Borrower', 'ACTIVE', '2025-01-01', 'PENAC-2026-0005'),
  ('67200000-0000-0000-0000-000000000006', '67100000-0000-0000-0000-000000000001', null, 'PAC Borrower Wallet', 'ACTIVE', '2025-01-01', 'PENAC-2026-0006');

insert into public.group_membership_roles (group_membership_id, role_id) select '67200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '67000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '67100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '67100000-0000-0000-0000-000000000001', 'PACCT', 'Accounting Product', 100000, 1, 12, 10.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'FIXED', p_penalty_frequency => 'ONCE',
  p_penalty_grace_days => 0, p_penalty_fixed_amount => 15000
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

create temporary table t_loan as
select public.rpc_create_draft_loan_account(
  '67100000-0000-0000-0000-000000000001', '67200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 200000, 1, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_id from t_loan \gset
select public.rpc_submit_loan_account('67100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_approve_loan_account('67100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_disburse_loan_account('67100000-0000-0000-0000-000000000001', :'loan_id'::uuid, :'account_id'::uuid, current_date);
select id as installment_id from public.loan_installments where loan_account_id = :'loan_id'::uuid \gset

select (public.rpc_get_financial_position('67100000-0000-0000-0000-000000000001')->>'group_income')::numeric as income_before_assess \gset
reset role;
select public.financial_account_balance(:'account_id'::uuid) as cash_before_assess \gset
set local role authenticated;
set local request.jwt.claim.sub to '67000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- 45/46/52: assessing a penalty is a pure obligation increase — zero
-- cashbook movement, zero income, and it is excluded from group_income
-- entirely while unpaid.
-- ---------------------------------------------------------------------

select public.rpc_assess_loan_penalties('67100000-0000-0000-0000-000000000001', current_date, :'loan_id'::uuid);

reset role;
select is(
  (public.financial_account_balance(:'account_id'::uuid)),
  :'cash_before_assess'::numeric,
  '45: assessing a penalty creates ZERO cashbook movement'
);
set local role authenticated;
set local request.jwt.claim.sub to '67000000-0000-0000-0000-000000000001';
select is(
  (public.rpc_get_financial_position('67100000-0000-0000-0000-000000000001')->>'group_income')::numeric,
  :'income_before_assess'::numeric,
  '46: assessing a penalty creates ZERO group income'
);
select is(
  (public.rpc_get_financial_position('67100000-0000-0000-0000-000000000001')->>'loan_penalties_outstanding')::numeric,
  15000.00::numeric,
  'setup: loan_penalties_outstanding reflects the assessed (unpaid) 15,000 penalty'
);
select is(
  (public.rpc_get_financial_position('67100000-0000-0000-0000-000000000001')->>'recognized_loan_penalty_income')::numeric,
  0.00::numeric,
  '52: an unpaid penalty is NEVER included in recognized_loan_penalty_income (or group_income)'
);

-- ---------------------------------------------------------------------
-- 47/48/49/51: a 20,000 external payment (fully settles the 15,000
-- penalty, then 5,000 of the 20,000 interest).
-- ---------------------------------------------------------------------

select count(*) as entries_before from public.financial_account_entries
  where financial_account_id = :'account_id'::uuid \gset

create temporary table t_post as
select public.rpc_post_payment(
  '67100000-0000-0000-0000-000000000001', '67200000-0000-0000-0000-000000000005'::uuid, :'account_id'::uuid,
  20000, current_date, 'CASH'
) as result;

select is(
  (select count(*) from public.financial_account_entries where financial_account_id = :'account_id'::uuid),
  (:'entries_before'::bigint + 1),
  '49: the penalty-inclusive payment still creates exactly ONE new cashbook INFLOW entry'
);
select is(
  (public.rpc_get_financial_position('67100000-0000-0000-0000-000000000001')->>'recognized_loan_penalty_income')::numeric,
  15000.00::numeric,
  '47: paying the penalty recognizes exactly 15,000 of penalty income'
);
select is(
  (public.rpc_get_financial_position('67100000-0000-0000-0000-000000000001')->>'loan_penalties_outstanding')::numeric,
  0.00::numeric,
  '47b: loan_penalties_outstanding drops to zero once fully paid'
);
select is(
  (public.rpc_get_financial_position('67100000-0000-0000-0000-000000000001')->>'funded_loan_principal_receivable')::numeric,
  200000.00::numeric,
  '48: paying the penalty (and partial interest) never reduces funded_loan_principal_receivable — no principal was allocated'
);
select is(
  (public.rpc_get_financial_position('67100000-0000-0000-0000-000000000001')->>'group_income')::numeric,
  (:'income_before_assess'::numeric + 15000.00 + 5000.00),
  '51: group_income increases by exactly the recognized penalty (15,000) plus the recognized interest (5,000) — counted once each'
);

-- ---------------------------------------------------------------------
-- 50: wallet settlement of a penalty creates ZERO cash movement.
-- ---------------------------------------------------------------------

create temporary table t_loan_wallet as
select public.rpc_create_draft_loan_account(
  '67100000-0000-0000-0000-000000000001', '67200000-0000-0000-0000-000000000006'::uuid,
  :'product_id'::uuid, 100000, 1, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_wallet_id from t_loan_wallet \gset
select public.rpc_submit_loan_account('67100000-0000-0000-0000-000000000001', :'loan_wallet_id'::uuid);
select public.rpc_approve_loan_account('67100000-0000-0000-0000-000000000001', :'loan_wallet_id'::uuid);
select public.rpc_disburse_loan_account('67100000-0000-0000-0000-000000000001', :'loan_wallet_id'::uuid, :'account_id'::uuid, current_date);
select public.rpc_assess_loan_penalties('67100000-0000-0000-0000-000000000001', current_date, :'loan_wallet_id'::uuid);

-- Overpay to generate wallet credit, then allocate purely from wallet.
select public.rpc_post_payment(
  '67100000-0000-0000-0000-000000000001', '67200000-0000-0000-0000-000000000006'::uuid, :'account_id'::uuid,
  200000, current_date, 'CASH'
);

select (public.rpc_get_financial_position('67100000-0000-0000-0000-000000000001')->>'group_income')::numeric as income_before_wallet \gset

-- The overpayment above already fully settled loan_wallet's penalty,
-- so create a SECOND penalty-bearing installment to allocate the
-- wallet credit against.
create temporary table t_loan_wallet2 as
select public.rpc_create_draft_loan_account(
  '67100000-0000-0000-0000-000000000001', '67200000-0000-0000-0000-000000000006'::uuid,
  :'product_id'::uuid, 100000, 1, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_wallet2_id from t_loan_wallet2 \gset
select public.rpc_submit_loan_account('67100000-0000-0000-0000-000000000001', :'loan_wallet2_id'::uuid);
select public.rpc_approve_loan_account('67100000-0000-0000-0000-000000000001', :'loan_wallet2_id'::uuid);
select public.rpc_disburse_loan_account('67100000-0000-0000-0000-000000000001', :'loan_wallet2_id'::uuid, :'account_id'::uuid, current_date);
select public.rpc_assess_loan_penalties('67100000-0000-0000-0000-000000000001', current_date, :'loan_wallet2_id'::uuid);

reset role;
select public.financial_account_balance(:'account_id'::uuid) as cash_before_wallet2 \gset
set local role authenticated;
set local request.jwt.claim.sub to '67000000-0000-0000-0000-000000000001';
select public.rpc_allocate_member_wallet('67100000-0000-0000-0000-000000000001', '67200000-0000-0000-0000-000000000006'::uuid, 15000);

reset role;
select is(
  (public.financial_account_balance(:'account_id'::uuid)),
  :'cash_before_wallet2'::numeric,
  '50: wallet-to-penalty settlement creates ZERO cash movement'
);
set local role authenticated;
set local request.jwt.claim.sub to '67000000-0000-0000-0000-000000000001';
select is(
  (public.rpc_get_financial_position('67100000-0000-0000-0000-000000000001')->>'group_income')::numeric,
  (:'income_before_wallet'::numeric + 15000.00),
  '50b: the wallet-settled penalty still recognizes 15,000 of income (income recognition and cash movement are independent)'
);

select * from finish();
rollback;
