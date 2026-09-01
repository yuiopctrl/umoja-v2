-- Prompt 09C: loan repayment reversal (section 33, items 28-34).
-- Item 35 ("wallet loan allocation reversal") is intentionally absent
-- here — Prompt 07 never built a wallet-allocation reversal mechanism
-- at all (payment_allocations' own header comment: "a wallet-sourced
-- row is always active — wallet allocations are not reversible in this
-- phase"), so there is nothing to extend; inventing one would be new
-- accounting scope beyond 09C. See the 09C closeout report.
begin;

select plan(9);

insert into auth.users (id, email) values
  ('4c000000-0000-0000-0000-000000000001', 'p09c-rev-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('4c100000-0000-0000-0000-000000000001', 'P09C Reversal Group', '4c000000-0000-0000-0000-000000000001', 'LREV');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('4c200000-0000-0000-0000-000000000001', '4c100000-0000-0000-0000-000000000001', '4c000000-0000-0000-0000-000000000001', 'LR Admin', 'ACTIVE', '2025-01-01', 'LREV-2026-0001'),
  ('4c200000-0000-0000-0000-000000000005', '4c100000-0000-0000-0000-000000000001', null, 'LR Borrower', 'ACTIVE', '2025-01-01', 'LREV-2026-0005');

insert into public.group_membership_roles (group_membership_id, role_id) select '4c200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '4c000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '4c100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '4c100000-0000-0000-0000-000000000001', 'NORMAL', 'Mkopo wa Kawaida',
  100000, 1, 12, 5.0000, 'MONTHLY', 'FLAT', 10000000
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

create temporary table t_loan as
select public.rpc_create_draft_loan_account(
  '4c100000-0000-0000-0000-000000000001', '4c200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 1000000, 4, current_date
) as result;
select (result->>'id')::uuid as loan_id from t_loan \gset
select public.rpc_submit_loan_account('4c100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_approve_loan_account('4c100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_disburse_loan_account('4c100000-0000-0000-0000-000000000001', :'loan_id'::uuid, :'account_id'::uuid, current_date);

select id as installment1_id from public.loan_installments
where loan_account_id = :'loan_id'::uuid and installment_number = 1 \gset

-- ---------------------------------------------------------------------
-- 28-33: a single loan-only payment, fully settling installment 1,
-- then reversed.
-- ---------------------------------------------------------------------

create temporary table t_pay as
select public.rpc_post_payment(
  '4c100000-0000-0000-0000-000000000001', '4c200000-0000-0000-0000-000000000005'::uuid, :'account_id'::uuid,
  300000, current_date, 'CASH'
) as result;
select (result->>'payment_id')::uuid as payment_id from t_pay \gset

select public.rpc_reverse_payment('4c100000-0000-0000-0000-000000000001', :'payment_id'::uuid, 'entered in error');

reset role;

-- 28. principal outstanding restored.
select is(
  (select outstanding from public.loan_installment_component_states(:'installment1_id'::uuid) where component_type = 'PRINCIPAL'),
  250000.00::numeric,
  '28: reversal restores installment 1''s principal outstanding'
);

-- 31. interest outstanding restored.
select is(
  (select outstanding from public.loan_installment_component_states(:'installment1_id'::uuid) where component_type = 'INTEREST'),
  50000.00::numeric,
  '31: reversal restores installment 1''s interest outstanding'
);

set local role authenticated;
set local request.jwt.claim.sub to '4c000000-0000-0000-0000-000000000001';

-- 29. principal receivable restored.
select is(
  (public.rpc_get_financial_position('4c100000-0000-0000-0000-000000000001')->>'funded_loan_principal_receivable')::numeric,
  1000000.00::numeric,
  '29: reversal restores funded_loan_principal_receivable to the full disbursed principal'
);

-- 30. recognized interest effect removed.
select is(
  (public.rpc_get_financial_position('4c100000-0000-0000-0000-000000000001')->>'recognized_loan_interest_income')::numeric,
  0.00::numeric,
  '30: reversal removes the recognized interest income effect'
);

-- 32. original allocation rows are never edited/deleted — both rows
-- from the reversed payment remain, at their original amounts.
select is(
  (select count(*) from public.payment_allocations where payment_id = :'payment_id'::uuid),
  2::bigint,
  '32: the original allocation rows (principal + interest) are never deleted'
);
select is(
  (select sum(amount) from public.payment_allocations where payment_id = :'payment_id'::uuid),
  300000.00::numeric,
  '32b: the original allocation amounts are never edited'
);

-- 33. cashbook reversal occurs exactly once.
select is(
  (select count(*) from public.financial_account_entries
   where source_type = 'PAYMENT_REVERSAL' and source_id = :'payment_id'::uuid),
  1::bigint,
  '33: the cashbook reversal occurs exactly once'
);

-- ---------------------------------------------------------------------
-- 34. A mixed contribution + loan payment reverses correctly — both
-- kinds of obligation restore together, atomically, from one reversal.
-- ---------------------------------------------------------------------

create temporary table t_ctype as
select public.rpc_create_contribution_type(
  '4c100000-0000-0000-0000-000000000001', 'ADA', 'GENERAL', 'GROUP_INCOME'
) as result;
select (result->>'id')::uuid as ctype_id from t_ctype \gset

create temporary table t_setup as
select public.rpc_create_contribution_setup(
  '4c100000-0000-0000-0000-000000000001', :'ctype_id'::uuid, 'ADA Setup', 'MONTHLY', 'FIXED',
  p_fixed_amount => 20000
) as result;
select (result->>'id')::uuid as setup_id from t_setup \gset

create temporary table t_period as
select public.rpc_create_contribution_period(
  '4c100000-0000-0000-0000-000000000001', :'setup_id'::uuid, 'Mixed Period', current_date, current_date,
  p_due_date => current_date
) as result;
select (result->>'id')::uuid as period_id from t_period \gset
select public.rpc_open_contribution_period('4c100000-0000-0000-0000-000000000001', :'period_id'::uuid);

select id as charge_id from public.member_contribution_charges
where membership_id = '4c200000-0000-0000-0000-000000000005'::uuid and period_id = :'period_id'::uuid \gset

-- 20,000 contribution + the full 300,000 re-settlement of installment 1.
create temporary table t_pay_mixed as
select public.rpc_post_payment(
  '4c100000-0000-0000-0000-000000000001', '4c200000-0000-0000-0000-000000000005'::uuid, :'account_id'::uuid,
  320000, current_date, 'CASH'
) as result;
select (result->>'payment_id')::uuid as payment_mixed_id from t_pay_mixed \gset

select public.rpc_reverse_payment('4c100000-0000-0000-0000-000000000001', :'payment_mixed_id'::uuid, 'entered in error');

select is(
  (public.rpc_get_contribution_charge_detail('4c100000-0000-0000-0000-000000000001', :'charge_id'::uuid)->>'total_outstanding')::numeric,
  20000.00::numeric,
  '34a: reversing a mixed payment restores the contribution obligation'
);
reset role;
select is(
  (select outstanding from public.loan_installment_component_states(:'installment1_id'::uuid) where component_type = 'PRINCIPAL'),
  250000.00::numeric,
  '34b: reversing a mixed payment restores the loan principal obligation in the SAME atomic reversal'
);

select * from finish();
rollback;
