-- Prompt 09F-B section D: Financial Position reconciliation across
-- write-off + recovery (test matrix item 23).
--
-- Uses a single-installment, fully-past-due loan (first_repayment_date
-- two months ago) so principal/interest/penalty are all fully
-- earned/outstanding at write-off time — this isolates the write-off
-- amount from any future/unearned-interest complication and makes the
-- before/after deltas exact.
begin;

select plan(14);

insert into auth.users (id, email) values
  ('97000000-0000-0000-0000-000000000001', 'p09fb-finpos-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('97100000-0000-0000-0000-000000000001', 'Financial Position Group', '97000000-0000-0000-0000-000000000001', 'FPOS');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('97200000-0000-0000-0000-000000000001', '97100000-0000-0000-0000-000000000001', '97000000-0000-0000-0000-000000000001', 'Finpos Admin', 'ACTIVE', '2025-01-01', 'FPOS-2026-0001'),
  ('97200000-0000-0000-0000-000000000011', '97100000-0000-0000-0000-000000000001', null, 'Finpos Borrower', 'ACTIVE', '2025-01-01', 'FPOS-2026-0011');

insert into public.group_membership_roles (group_membership_id, role_id) select '97200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '97000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '97100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '97100000-0000-0000-0000-000000000001', 'FPOSP', 'Finpos Product', 100000, 1, 12, 10.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'FIXED', p_penalty_frequency => 'ONCE',
  p_penalty_grace_days => 0, p_penalty_fixed_amount => 15000
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

create temporary table t_loan as
select public.rpc_create_draft_loan_account(
  '97100000-0000-0000-0000-000000000001', '97200000-0000-0000-0000-000000000011'::uuid,
  :'product_id'::uuid, 200000, 1, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_id from t_loan \gset
select public.rpc_submit_loan_account('97100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_approve_loan_account('97100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_disburse_loan_account('97100000-0000-0000-0000-000000000001', :'loan_id'::uuid, :'account_id'::uuid, (current_date - interval '2 months')::date);
select public.rpc_assess_loan_penalties('97100000-0000-0000-0000-000000000001', current_date, :'loan_id'::uuid);

create temporary table t_before as
select public.rpc_get_financial_position('97100000-0000-0000-0000-000000000001') as result;
select (result->>'funded_loan_principal_receivable')::numeric as receivable_before from t_before \gset
select (result->>'scheduled_unearned_interest')::numeric as unearned_interest_before from t_before \gset
select (result->>'loan_penalties_outstanding')::numeric as penalties_outstanding_before from t_before \gset
select (result->>'group_income')::numeric as group_income_before from t_before \gset
select (result->>'written_off_total')::numeric as written_off_total_before from t_before \gset

-- Sanity: this isolated single-loan group starts with the loan's full
-- principal/interest/penalty as its only contribution.
select is(:'receivable_before'::numeric, 200000.00::numeric, 'sanity: pre-write-off receivable equals the full disbursed principal (no repayment yet)');
select ok(:'unearned_interest_before'::numeric > 0, 'sanity: pre-write-off scheduled interest is positive');
select is(:'penalties_outstanding_before'::numeric, 15000.00::numeric, 'sanity: pre-write-off outstanding penalty equals the fixed penalty amount');

create temporary table t_write_off as
select public.rpc_post_loan_write_off(
  '97100000-0000-0000-0000-000000000001', :'loan_id'::uuid, 'PROLONGED_DEFAULT', null, current_date
) as result;
select (result->>'principal_amount')::numeric as wo_principal from t_write_off \gset
select (result->>'interest_amount')::numeric as wo_interest from t_write_off \gset
select (result->>'penalty_amount')::numeric as wo_penalty from t_write_off \gset
select (result->>'total_amount')::numeric as wo_total from t_write_off \gset

create temporary table t_after_wo as
select public.rpc_get_financial_position('97100000-0000-0000-0000-000000000001') as result;
select (result->>'funded_loan_principal_receivable')::numeric as receivable_after_wo from t_after_wo \gset
select (result->>'loan_penalties_outstanding')::numeric as penalties_outstanding_after_wo from t_after_wo \gset
select (result->>'written_off_total')::numeric as written_off_total_after_wo from t_after_wo \gset
select (result->>'written_off_principal')::numeric as written_off_principal_after_wo from t_after_wo \gset
select (result->>'remaining_recoverable_total')::numeric as remaining_recoverable_after_wo from t_after_wo \gset
select (result->>'group_income')::numeric as group_income_after_wo from t_after_wo \gset

-- Written-off principal is removed from the active receivable in full
-- (the whole loan drops out of the ACTIVE/DISBURSED/CLOSED aggregate).
select is(:'receivable_after_wo'::numeric, 0.00::numeric, 'write-off removes the loan''s principal from the active funded receivable entirely');
select is(:'penalties_outstanding_after_wo'::numeric, 0.00::numeric, 'write-off removes the loan''s penalty from active loan_penalties_outstanding');
select is(:'written_off_principal_after_wo'::numeric, :'wo_principal'::numeric, 'written_off_principal in Financial Position exactly matches the write-off event''s frozen principal');
select is(:'written_off_total_after_wo'::numeric, :'wo_total'::numeric, 'written_off_total in Financial Position exactly matches the write-off event''s total');
select is(:'remaining_recoverable_after_wo'::numeric, :'wo_total'::numeric, 'remaining_recoverable_total equals the full write-off amount before any recovery');

-- Write-off itself never touches recognized income (no cash event).
select is(:'group_income_after_wo'::numeric, :'group_income_before'::numeric, 'write-off does not change recognized group_income (zero income/loss recognition)');

-- Recover the interest + penalty components (never principal) and
-- confirm income recognition is scoped to interest/penalty only.
create temporary table t_recovery as
select public.rpc_post_loan_recovery(
  '97100000-0000-0000-0000-000000000001', :'loan_id'::uuid, :'wo_interest'::numeric + :'wo_penalty'::numeric,
  :'account_id'::uuid, 'CASH', current_date
) as result;

create temporary table t_after_recovery as
select public.rpc_get_financial_position('97100000-0000-0000-0000-000000000001') as result;
select (result->>'recovered_interest')::numeric as recovered_interest from t_after_recovery \gset
select (result->>'recovered_penalty')::numeric as recovered_penalty from t_after_recovery \gset
select (result->>'recovered_principal')::numeric as recovered_principal from t_after_recovery \gset
select (result->>'recognized_loan_recovery_interest_income')::numeric as recognized_recovery_interest from t_after_recovery \gset
select (result->>'recognized_loan_recovery_penalty_income')::numeric as recognized_recovery_penalty from t_after_recovery \gset
select (result->>'group_income')::numeric as group_income_after_recovery from t_after_recovery \gset
select (result->>'remaining_recoverable_total')::numeric as remaining_recoverable_after_recovery from t_after_recovery \gset

select is(:'recovered_principal'::numeric, 0.00::numeric, 'no principal was recovered yet (interest+penalty-only recovery)');
select is(
  :'group_income_after_recovery'::numeric,
  :'group_income_before'::numeric + :'recognized_recovery_interest'::numeric + :'recognized_recovery_penalty'::numeric,
  'group_income after recovery reconciles exactly to pre-write-off income plus the newly recognized recovery interest/penalty income'
);
select is(
  :'remaining_recoverable_after_recovery'::numeric,
  :'wo_principal'::numeric,
  'remaining_recoverable_total after interest+penalty recovery equals exactly the still-unrecovered principal'
);

-- Recover the remaining principal — confirm it is NEVER treated as
-- income (ordinary principal repayment / recovery is never income).
select public.rpc_post_loan_recovery(
  '97100000-0000-0000-0000-000000000001', :'loan_id'::uuid, :'wo_principal'::numeric,
  :'account_id'::uuid, 'CASH', current_date
);

create temporary table t_after_full_recovery as
select public.rpc_get_financial_position('97100000-0000-0000-0000-000000000001') as result;
select (result->>'group_income')::numeric as group_income_after_full_recovery from t_after_full_recovery \gset
select (result->>'remaining_recoverable_total')::numeric as remaining_recoverable_after_full from t_after_full_recovery \gset

select is(
  :'group_income_after_full_recovery'::numeric, :'group_income_after_recovery'::numeric,
  'recovering the remaining principal does not change group_income (principal recovery is never income, matching ordinary repayment)'
);
select is(:'remaining_recoverable_after_full'::numeric, 0.00::numeric, 'remaining_recoverable_total is fully zero once principal+interest+penalty are all recovered');

select * from finish();
rollback;
