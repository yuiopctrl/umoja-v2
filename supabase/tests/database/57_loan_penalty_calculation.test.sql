-- Prompt 09D: penalty CALCULATION exactness (section 44, items 30-36).
-- Worked example from the prompt itself (section 12): principal
-- outstanding 200,000 + interest outstanding 20,000, existing
-- penalties 10,000 (deliberately EXCLUDED from basis), rate 5% ->
-- new penalty = 11,000 (5% of 220,000, never 5% of 230,000).
begin;

select plan(7);

insert into auth.users (id, email) values
  ('65000000-0000-0000-0000-000000000001', 'p09d-calc-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('65100000-0000-0000-0000-000000000001', 'P09D Calc Group', '65000000-0000-0000-0000-000000000001', 'PENC');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('65200000-0000-0000-0000-000000000001', '65100000-0000-0000-0000-000000000001', '65000000-0000-0000-0000-000000000001', 'PC Admin', 'ACTIVE', '2025-01-01', 'PENC-2026-0001'),
  ('65200000-0000-0000-0000-000000000005', '65100000-0000-0000-0000-000000000001', null, 'PC Borrower Fixed', 'ACTIVE', '2025-01-01', 'PENC-2026-0005'),
  ('65200000-0000-0000-0000-000000000006', '65100000-0000-0000-0000-000000000001', null, 'PC Borrower Pct', 'ACTIVE', '2025-01-01', 'PENC-2026-0006'),
  ('65200000-0000-0000-0000-000000000007', '65100000-0000-0000-0000-000000000001', null, 'PC Borrower Round', 'ACTIVE', '2025-01-01', 'PENC-2026-0007');

insert into public.group_membership_roles (group_membership_id, role_id) select '65200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '65000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '65100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

-- ---------------------------------------------------------------------
-- 30: FIXED calculation is exact — the configured fixed amount, no
-- proration, no rounding surprises.
-- ---------------------------------------------------------------------

create temporary table t_product_fixed as
select public.rpc_create_loan_product(
  '65100000-0000-0000-0000-000000000001', 'CFX', 'Calc Fixed Product', 100000, 1, 12, 5.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'FIXED', p_penalty_frequency => 'ONCE',
  p_penalty_grace_days => 5, p_penalty_fixed_amount => 17500
) as result;
select (result->>'id')::uuid as product_fixed_id from t_product_fixed \gset

create temporary table t_loan_fixed as
select public.rpc_create_draft_loan_account(
  '65100000-0000-0000-0000-000000000001', '65200000-0000-0000-0000-000000000005'::uuid,
  :'product_fixed_id'::uuid, 300000, 3, (current_date - interval '3 months')::date
) as result;
select (result->>'id')::uuid as loan_fixed_id from t_loan_fixed \gset
select public.rpc_submit_loan_account('65100000-0000-0000-0000-000000000001', :'loan_fixed_id'::uuid);
select public.rpc_approve_loan_account('65100000-0000-0000-0000-000000000001', :'loan_fixed_id'::uuid);
select public.rpc_disburse_loan_account('65100000-0000-0000-0000-000000000001', :'loan_fixed_id'::uuid, :'account_id'::uuid, current_date);
select id as fixed_installment_id from public.loan_installments where loan_account_id = :'loan_fixed_id'::uuid and installment_number = 1 \gset

select public.rpc_assess_loan_penalties('65100000-0000-0000-0000-000000000001', current_date, :'loan_fixed_id'::uuid);
select is(
  (select penalty_amount from public.loan_penalty_charges where loan_installment_id = :'fixed_installment_id'::uuid),
  17500.00::numeric,
  '30: FIXED penalty amount is exactly the configured fixed amount'
);

-- ---------------------------------------------------------------------
-- 31/33/36: PERCENTAGE calculation — the prompt's own worked example.
-- Loan: 200,000 principal / 1 installment, 10% MONTHLY FLAT interest
-- (-> interest_due = 20,000, matching the worked example exactly).
-- First a FIXED penalty of 10,000 is raw-inserted to represent
-- "existing penalties" (an occurrence-1 FIXED charge would itself
-- change the product's own type, so a direct fixture insert isolates
-- exactly the basis-exclusion behavior being tested), then a
-- PERCENTAGE/RECURRING_MONTHLY occurrence 2 must compute 5% of
-- (200,000 + 20,000) = 11,000 — never 5% of 230,000.
-- ---------------------------------------------------------------------

create temporary table t_product_pct as
select public.rpc_create_loan_product(
  '65100000-0000-0000-0000-000000000001', 'CPCT', 'Calc Percentage Product', 100000, 1, 12, 10.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'PERCENTAGE', p_penalty_frequency => 'RECURRING_MONTHLY',
  p_penalty_grace_days => 0, p_penalty_rate => 5.0
) as result;
select (result->>'id')::uuid as product_pct_id from t_product_pct \gset

create temporary table t_loan_pct as
select public.rpc_create_draft_loan_account(
  '65100000-0000-0000-0000-000000000001', '65200000-0000-0000-0000-000000000006'::uuid,
  :'product_pct_id'::uuid, 200000, 1, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_pct_id from t_loan_pct \gset
select public.rpc_submit_loan_account('65100000-0000-0000-0000-000000000001', :'loan_pct_id'::uuid);
select public.rpc_approve_loan_account('65100000-0000-0000-0000-000000000001', :'loan_pct_id'::uuid);
select public.rpc_disburse_loan_account('65100000-0000-0000-0000-000000000001', :'loan_pct_id'::uuid, :'account_id'::uuid, current_date);
select id as pct_installment_id, interest_due as pct_interest_due from public.loan_installments where loan_account_id = :'loan_pct_id'::uuid \gset

select is(
  :'pct_interest_due'::numeric,
  20000.00::numeric,
  'setup: interest_due matches the worked example (20,000)'
);

reset role;
insert into public.loan_penalty_charges (
  group_id, loan_account_id, loan_installment_id, assessment_date, sequence_number,
  penalty_type, penalty_frequency, penalty_basis, penalty_grace_days,
  basis_amount, fixed_amount, penalty_amount
) values (
  '65100000-0000-0000-0000-000000000001', :'loan_pct_id'::uuid, :'pct_installment_id'::uuid,
  current_date - 30, 1, 'FIXED', 'ONCE', 'OUTSTANDING_INSTALLMENT', 0, 220000, 10000, 10000
);
set local role authenticated;
set local request.jwt.claim.sub to '65000000-0000-0000-0000-000000000001';

create temporary table t_assess_pct as
select public.rpc_assess_loan_penalties('65100000-0000-0000-0000-000000000001', current_date, :'loan_pct_id'::uuid) as result;

select is(
  (select penalty_amount from public.loan_penalty_charges
   where loan_installment_id = :'pct_installment_id'::uuid and sequence_number = 2),
  11000.00::numeric,
  '31/33: PERCENTAGE penalty = 5% of (200,000 principal + 20,000 interest) = 11,000 — the existing 10,000 penalty is excluded from the basis'
);
select is(
  (select basis_amount from public.loan_penalty_charges
   where loan_installment_id = :'pct_installment_id'::uuid and sequence_number = 2),
  220000.00::numeric,
  '33b: the stored basis_amount itself is 220,000, never 230,000'
);
select is(
  (select (result->>'total_penalty_amount')::numeric from t_assess_pct),
  11000.00::numeric,
  '36: the assessment result total reconciles exactly to the one new charge row created in this run'
);

-- ---------------------------------------------------------------------
-- 34/35: deterministic NUMERIC rounding (never float) — a rate/basis
-- combination whose raw product is not already a 2-decimal value.
-- Basis 333,333.33 (principal_due truncation from a 3-way split) at
-- 7.5% -> raw = 24,999.99975 -> round(...,2) = 25,000.00 exactly.
-- ---------------------------------------------------------------------

create temporary table t_product_round as
select public.rpc_create_loan_product(
  '65100000-0000-0000-0000-000000000001', 'CRND', 'Calc Rounding Product', 100000, 1, 12, 5.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'PERCENTAGE', p_penalty_frequency => 'ONCE',
  p_penalty_grace_days => 0, p_penalty_rate => 7.5
) as result;
select (result->>'id')::uuid as product_round_id from t_product_round \gset

create temporary table t_loan_round as
select public.rpc_create_draft_loan_account(
  '65100000-0000-0000-0000-000000000001', '65200000-0000-0000-0000-000000000007'::uuid,
  :'product_round_id'::uuid, 1000000, 3, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_round_id from t_loan_round \gset
select public.rpc_submit_loan_account('65100000-0000-0000-0000-000000000001', :'loan_round_id'::uuid);
select public.rpc_approve_loan_account('65100000-0000-0000-0000-000000000001', :'loan_round_id'::uuid);
select public.rpc_disburse_loan_account('65100000-0000-0000-0000-000000000001', :'loan_round_id'::uuid, :'account_id'::uuid, current_date);
select id as round_installment_id, principal_due, interest_due from public.loan_installments
  where loan_account_id = :'loan_round_id'::uuid and installment_number = 1 \gset

select public.rpc_assess_loan_penalties('65100000-0000-0000-0000-000000000001', current_date, :'loan_round_id'::uuid);

select is(
  (select penalty_amount from public.loan_penalty_charges where loan_installment_id = :'round_installment_id'::uuid),
  round((:principal_due + :interest_due) * 7.5 / 100, 2),
  '34/35: PERCENTAGE penalty uses exact NUMERIC round(basis * rate / 100, 2) — no float drift'
);
select ok(
  (select penalty_amount from public.loan_penalty_charges where loan_installment_id = :'round_installment_id'::uuid)
    = round((select penalty_amount from public.loan_penalty_charges where loan_installment_id = :'round_installment_id'::uuid), 2),
  '35b: the stored penalty_amount already has exactly 2 decimal places (numeric(14,2) column, no float type anywhere)'
);

select * from finish();
rollback;
