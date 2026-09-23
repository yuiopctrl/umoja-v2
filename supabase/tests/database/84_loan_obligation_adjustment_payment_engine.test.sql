-- Prompt 09F-A: Payment Engine + Financial Position integration
-- (sections 19/21, test matrix items 25, 26, 27, 45, 46, 47). Mirrors
-- the prompt's own worked example exactly: penalty assessment 100,000,
-- waiver 30,000, payment 50,000 -> remaining outstanding 20,000 (never
-- another 50,000 against the original 100,000).
begin;

select plan(8);

insert into auth.users (id, email) values
  ('84000000-0000-0000-0000-000000000001', 'p09fa-engine-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('84100000-0000-0000-0000-000000000001', 'Engine Group', '84000000-0000-0000-0000-000000000001', 'ENGN');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('84200000-0000-0000-0000-000000000001', '84100000-0000-0000-0000-000000000001', '84000000-0000-0000-0000-000000000001', 'Engine Admin', 'ACTIVE', '2025-01-01', 'ENGN-2026-0001'),
  ('84200000-0000-0000-0000-000000000011', '84100000-0000-0000-0000-000000000001', null, 'Penalty Borrower', 'ACTIVE', '2025-01-01', 'ENGN-2026-0011'),
  ('84200000-0000-0000-0000-000000000012', '84100000-0000-0000-0000-000000000001', null, 'Interest Borrower', 'ACTIVE', '2025-01-01', 'ENGN-2026-0012');

insert into public.group_membership_roles (group_membership_id, role_id) select '84200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '84000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '84100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '84100000-0000-0000-0000-000000000001', 'ENGP', 'Engine Penalty Product', 100000, 1, 12, 5.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'FIXED', p_penalty_frequency => 'ONCE',
  p_penalty_grace_days => 0, p_penalty_fixed_amount => 100000
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

create temporary table t_loan as
select public.rpc_create_draft_loan_account(
  '84100000-0000-0000-0000-000000000001', '84200000-0000-0000-0000-000000000011'::uuid,
  :'product_id'::uuid, 500000, 1, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_id from t_loan \gset
select public.rpc_submit_loan_account('84100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_approve_loan_account('84100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_disburse_loan_account('84100000-0000-0000-0000-000000000001', :'loan_id'::uuid, :'account_id'::uuid, current_date);
select id as installment_id from public.loan_installments where loan_account_id = :'loan_id'::uuid \gset

select public.rpc_assess_loan_penalties('84100000-0000-0000-0000-000000000001', current_date, :'loan_id'::uuid);
select id as charge_id from public.loan_penalty_charges where loan_installment_id = :'installment_id'::uuid \gset

-- Waiver: 100,000 -> 70,000 effective outstanding.
select public.rpc_post_loan_obligation_waiver(
  '84100000-0000-0000-0000-000000000001', :'loan_id'::uuid, 'LOAN_PENALTY', :'charge_id'::uuid, 30000, 'HARDSHIP'
);

-- Payment of 50,000 (less than the 70,000 effective outstanding, well
-- below the original 100,000 assessment).
select public.rpc_post_payment(
  '84100000-0000-0000-0000-000000000001', '84200000-0000-0000-0000-000000000011'::uuid, :'account_id'::uuid,
  50000, current_date, 'CASH'
);

reset role;
select outstanding as penalty_outstanding_after from public.loan_penalty_charge_states(:'installment_id'::uuid) where charge_id = :'charge_id'::uuid \gset
set local role authenticated;
set local request.jwt.claim.sub to '84000000-0000-0000-0000-000000000001';

-- Item 25: the payment engine used the WAIVER-adjusted outstanding
-- (70,000), never the original 100,000 — remaining is exactly 20,000.
select is(
  :'penalty_outstanding_after'::numeric,
  20000.00::numeric,
  '25: payment after waiver respects adjusted outstanding (100,000 - 30,000 waiver - 50,000 payment = 20,000)'
);

-- Item 26: recognized penalty income reflects the ACTUAL 50,000 paid —
-- never the 70,000 effective figure and never the original 100,000.
select is(
  (public.rpc_get_financial_position('84100000-0000-0000-0000-000000000001')->>'recognized_loan_penalty_income')::numeric,
  50000.00::numeric,
  '26: penalty payment income reflects the actual 50,000 cash allocation only'
);

-- Item 45: financial position''s loan_penalties_outstanding matches the
-- same 20,000 effective figure, group-wide.
select is(
  (public.rpc_get_financial_position('84100000-0000-0000-0000-000000000001')->>'loan_penalties_outstanding')::numeric,
  20000.00::numeric,
  '45: financial position loan_penalties_outstanding is adjustment-aware (20,000)'
);

-- Item 47: principal receivable is completely unaffected by the penalty
-- waiver/payment above (principal is not adjustable in 09F-A).
select is(
  (public.rpc_get_financial_position('84100000-0000-0000-0000-000000000001')->>'funded_loan_principal_receivable')::numeric,
  500000.00::numeric,
  '47: funded_loan_principal_receivable is unaffected by the penalty waiver/payment'
);

-- =======================================================================
-- Interest scenario for items 27/46.
-- =======================================================================

create temporary table t_product_interest as
select public.rpc_create_loan_product(
  '84100000-0000-0000-0000-000000000001', 'ENGI', 'Engine Interest Product', 100000, 1, 12, 6.0, 'MONTHLY', 'FLAT'
) as result;
select (result->>'id')::uuid as product_interest_id from t_product_interest \gset

create temporary table t_loan_interest as
select public.rpc_create_draft_loan_account(
  '84100000-0000-0000-0000-000000000001', '84200000-0000-0000-0000-000000000012'::uuid,
  :'product_interest_id'::uuid, 400000, 1, (current_date - interval '1 month')::date
) as result;
select (result->>'id')::uuid as loan_interest_id from t_loan_interest \gset
select public.rpc_submit_loan_account('84100000-0000-0000-0000-000000000001', :'loan_interest_id'::uuid);
select public.rpc_approve_loan_account('84100000-0000-0000-0000-000000000001', :'loan_interest_id'::uuid);
select public.rpc_disburse_loan_account('84100000-0000-0000-0000-000000000001', :'loan_interest_id'::uuid, :'account_id'::uuid, current_date);
select id as due_installment_id, interest_due as due_interest, principal_due as due_principal from public.loan_installments
  where loan_account_id = :'loan_interest_id'::uuid \gset

select (public.rpc_get_financial_position('84100000-0000-0000-0000-000000000001')->>'scheduled_unearned_interest')::numeric as unearned_before \gset

-- Waive half the interest, then pay the other half.
select public.rpc_post_loan_obligation_waiver(
  '84100000-0000-0000-0000-000000000001', :'loan_interest_id'::uuid, 'LOAN_INTEREST', :'due_installment_id'::uuid,
  round(:due_interest / 2, 2), 'HARDSHIP'
);
select public.rpc_post_payment(
  '84100000-0000-0000-0000-000000000001', '84200000-0000-0000-0000-000000000012'::uuid, :'account_id'::uuid,
  round(:due_interest / 2, 2), current_date, 'CASH'
);

-- Item 27: recognized interest income reflects only the actual amount
-- paid (half), never the waived half.
select is(
  (public.rpc_get_financial_position('84100000-0000-0000-0000-000000000001')->>'recognized_loan_interest_income')::numeric,
  round(:due_interest / 2, 2),
  '27: interest payment income reflects the actual cash allocation only, excluding the waived half'
);

-- Item 46: scheduled_unearned_interest drops by exactly the waived
-- amount — the waived interest is neither still "unearned" (it will
-- never be collected) nor counted as recognized income.
select is(
  (public.rpc_get_financial_position('84100000-0000-0000-0000-000000000001')->>'scheduled_unearned_interest')::numeric,
  :'unearned_before'::numeric - round(:due_interest / 2, 2) - round(:due_interest / 2, 2),
  '46: scheduled_unearned_interest correctly excludes both the waived and the now-recognized portions'
);

reset role;
select outstanding as interest_outstanding_final from public.loan_installment_component_states(:'due_installment_id'::uuid) where component_type = 'INTEREST' \gset
set local role authenticated;
set local request.jwt.claim.sub to '84000000-0000-0000-0000-000000000001';

select is(
  :'interest_outstanding_final'::numeric,
  0.00::numeric,
  'setup sanity: interest is fully settled (half waived, half paid)'
);

-- Item 31 (NEW loan support): both scenarios above ran against ordinary
-- NEW loans.
select is(
  (select loan_origin from public.loan_accounts where id = :'loan_id'::uuid),
  'NEW',
  '31: NEW loans support waivers/corrections through the same RPCs as any other loan'
);

select * from finish();
rollback;
