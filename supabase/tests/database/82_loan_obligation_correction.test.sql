-- Prompt 09F-A: Loan Corrections — core accounting behaviour (sections
-- 11/12/13, test matrix items 7-13, 24).
begin;

select plan(15);

insert into auth.users (id, email) values
  ('82000000-0000-0000-0000-000000000001', 'p09fa-correction-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('82100000-0000-0000-0000-000000000001', 'Correction Group', '82000000-0000-0000-0000-000000000001', 'CORR'),
  ('82100000-0000-0000-0000-000000000002', 'Correction Other Group', '82000000-0000-0000-0000-000000000001', 'CORB');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('82200000-0000-0000-0000-000000000001', '82100000-0000-0000-0000-000000000001', '82000000-0000-0000-0000-000000000001', 'Correction Admin', 'ACTIVE', '2025-01-01', 'CORR-2026-0001'),
  ('82200000-0000-0000-0000-000000000011', '82100000-0000-0000-0000-000000000001', null, 'Penalty Borrower', 'ACTIVE', '2025-01-01', 'CORR-2026-0011'),
  ('82200000-0000-0000-0000-000000000012', '82100000-0000-0000-0000-000000000001', null, 'Interest Borrower', 'ACTIVE', '2025-01-01', 'CORR-2026-0012');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('82200000-0000-0000-0000-000000000002', '82100000-0000-0000-0000-000000000002', '82000000-0000-0000-0000-000000000001', 'Correction Admin (group 2)', 'ACTIVE', '2025-01-01', 'CORB-2026-0001');

insert into public.group_membership_roles (group_membership_id, role_id) select '82200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select '82200000-0000-0000-0000-000000000002', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '82000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '82100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

-- =======================================================================
-- Penalty correction scenario: 50,000 FIXED assessment.
-- =======================================================================

create temporary table t_product_penalty as
select public.rpc_create_loan_product(
  '82100000-0000-0000-0000-000000000001', 'CPEN', 'Correction Penalty Product', 100000, 1, 12, 5.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'FIXED', p_penalty_frequency => 'ONCE',
  p_penalty_grace_days => 0, p_penalty_fixed_amount => 50000
) as result;
select (result->>'id')::uuid as product_penalty_id from t_product_penalty \gset

create temporary table t_loan_penalty as
select public.rpc_create_draft_loan_account(
  '82100000-0000-0000-0000-000000000001', '82200000-0000-0000-0000-000000000011'::uuid,
  :'product_penalty_id'::uuid, 500000, 1, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_penalty_id from t_loan_penalty \gset
select public.rpc_submit_loan_account('82100000-0000-0000-0000-000000000001', :'loan_penalty_id'::uuid);
select public.rpc_approve_loan_account('82100000-0000-0000-0000-000000000001', :'loan_penalty_id'::uuid);
select public.rpc_disburse_loan_account('82100000-0000-0000-0000-000000000001', :'loan_penalty_id'::uuid, :'account_id'::uuid, current_date);
select id as penalty_installment_id from public.loan_installments where loan_account_id = :'loan_penalty_id'::uuid \gset

select public.rpc_assess_loan_penalties('82100000-0000-0000-0000-000000000001', current_date, :'loan_penalty_id'::uuid);
select id as penalty_charge_id from public.loan_penalty_charges where loan_installment_id = :'penalty_installment_id'::uuid \gset

select count(*)::integer as payments_before from public.payments \gset
reset role;
select (public.rpc_get_financial_position('82100000-0000-0000-0000-000000000001')->>'recognized_loan_penalty_income')::numeric as penalty_income_before \gset
set local role authenticated;
set local request.jwt.claim.sub to '82000000-0000-0000-0000-000000000001';

-- Item 13: an unrelated/invalid target is rejected — the real loan/charge
-- combination does not belong to this OTHER group.
select throws_ok(
  format(
    $sql$ select public.rpc_preview_loan_obligation_correction('82100000-0000-0000-0000-000000000002', %L::uuid, 'LOAN_PENALTY', %L::uuid, 'CORRECTION_DECREASE', 1000, 'ASSESSMENT_ERROR') $sql$,
    :'loan_penalty_id', :'penalty_charge_id'
  ),
  '22023',
  'Loan account not found in group',
  '13: cross-group attack — a real loan/charge from group 1 cannot be targeted via group 2, even by an ADMIN of both'
);

-- Item 7 / 12: penalty correction decrease, source-linked to the exact
-- charge — reduces effective outstanding without touching the original
-- assessment.
create temporary table t_decrease as
select public.rpc_post_loan_obligation_correction(
  '82100000-0000-0000-0000-000000000001', :'loan_penalty_id'::uuid, 'LOAN_PENALTY', :'penalty_charge_id'::uuid,
  'CORRECTION_DECREASE', 10000, 'ASSESSMENT_ERROR'
) as result;

select is((result->>'loan_penalty_charge_id')::uuid, :'penalty_charge_id'::uuid, '12: the posted correction is source-linked to the exact charge') from t_decrease;
select is((result->>'source_original_amount')::numeric, 50000.00::numeric, '12b: source_original_amount matches the original assessment exactly') from t_decrease;

reset role;
select outstanding as after_decrease_outstanding from public.loan_penalty_charge_states(:'penalty_installment_id'::uuid) where charge_id = :'penalty_charge_id'::uuid \gset
set local role authenticated;
set local request.jwt.claim.sub to '82000000-0000-0000-0000-000000000001';

select is(
  :'after_decrease_outstanding'::numeric,
  40000.00::numeric,
  '7: penalty correction decrease reduces effective outstanding from 50,000 to 40,000'
);
select is(
  (select penalty_amount from public.loan_penalty_charges where id = :'penalty_charge_id'::uuid),
  50000.00::numeric,
  '7b: the original 50,000 assessment is untouched'
);

-- Item 9/11 (09F-A-BLOCKER-01 rule): the charge's frozen fixed_amount IS
-- its expected_policy_amount (50,000) — the prior -10,000 decrease left
-- corrected-gross at 40,000, so remaining increase headroom is exactly
-- 10,000. An increase beyond that headroom is rejected; a bounded
-- increase up to it is accepted. (See
-- 90_loan_obligation_correction_increase_bound.test.sql for the full
-- BLOCKER-01 matrix.)
select throws_ok(
  format(
    $sql$ select public.rpc_post_loan_obligation_correction('82100000-0000-0000-0000-000000000001', %L::uuid, 'LOAN_PENALTY', %L::uuid, 'CORRECTION_INCREASE', 10001, 'ASSESSMENT_ERROR') $sql$,
    :'loan_penalty_id', :'penalty_charge_id'
  ),
  'P0001',
  'LOAN_CORRECTION_INCREASE_EXCEEDS_BOUND',
  '11: an increase beyond the remaining frozen-policy headroom (10,000) is rejected'
);

create temporary table t_increase as
select public.rpc_post_loan_obligation_correction(
  '82100000-0000-0000-0000-000000000001', :'loan_penalty_id'::uuid, 'LOAN_PENALTY', :'penalty_charge_id'::uuid,
  'CORRECTION_INCREASE', 10000, 'ASSESSMENT_ERROR'
) as result;

select is((result->>'adjustment_type')::text, 'CORRECTION_INCREASE', '9: an increase within the remaining frozen-policy headroom is accepted') from t_increase;

reset role;
select outstanding as after_increase_outstanding from public.loan_penalty_charge_states(:'penalty_installment_id'::uuid) where charge_id = :'penalty_charge_id'::uuid \gset
set local role authenticated;
set local request.jwt.claim.sub to '82000000-0000-0000-0000-000000000001';

select is(
  :'after_increase_outstanding'::numeric,
  50000.00::numeric,
  '9b: effective outstanding after -10,000 then +10,000 on a 50,000 base/expected-policy-amount is back to exactly 50,000'
);
select is(
  (select penalty_amount from public.loan_penalty_charges where id = :'penalty_charge_id'::uuid),
  50000.00::numeric,
  '9c: the original assessment remains 50,000 — corrections are additive, never rewritten in place'
);

-- =======================================================================
-- Interest correction scenario.
-- =======================================================================

create temporary table t_product_interest as
select public.rpc_create_loan_product(
  '82100000-0000-0000-0000-000000000001', 'CINT', 'Correction Interest Product', 100000, 1, 12, 6.0, 'MONTHLY', 'FLAT'
) as result;
select (result->>'id')::uuid as product_interest_id from t_product_interest \gset

create temporary table t_loan_interest as
select public.rpc_create_draft_loan_account(
  '82100000-0000-0000-0000-000000000001', '82200000-0000-0000-0000-000000000012'::uuid,
  :'product_interest_id'::uuid, 400000, 1, (current_date - interval '1 month')::date
) as result;
select (result->>'id')::uuid as loan_interest_id from t_loan_interest \gset
select public.rpc_submit_loan_account('82100000-0000-0000-0000-000000000001', :'loan_interest_id'::uuid);
select public.rpc_approve_loan_account('82100000-0000-0000-0000-000000000001', :'loan_interest_id'::uuid);
select public.rpc_disburse_loan_account('82100000-0000-0000-0000-000000000001', :'loan_interest_id'::uuid, :'account_id'::uuid, current_date);
select id as due_installment_id, interest_due as due_interest from public.loan_installments
  where loan_account_id = :'loan_interest_id'::uuid \gset

-- Item 10: interest correction increase is always rejected, structurally.
select throws_ok(
  format(
    $sql$ select public.rpc_post_loan_obligation_correction('82100000-0000-0000-0000-000000000001', %L::uuid, 'LOAN_INTEREST', %L::uuid, 'CORRECTION_INCREASE', 1, 'ASSESSMENT_ERROR') $sql$,
    :'loan_interest_id', :'due_installment_id'
  ),
  'P0001',
  'LOAN_CORRECTION_INCREASE_NOT_ALLOWED',
  '10: interest correction increase is explicitly rejected'
);

-- Item 8: interest correction decrease succeeds and is bounded by
-- effective outstanding, same as a waiver.
create temporary table t_interest_decrease as
select public.rpc_post_loan_obligation_correction(
  '82100000-0000-0000-0000-000000000001', :'loan_interest_id'::uuid, 'LOAN_INTEREST', :'due_installment_id'::uuid,
  'CORRECTION_DECREASE', :due_interest, 'DATA_ENTRY_ERROR'
) as result;

reset role;
select outstanding as interest_after_decrease from public.loan_installment_component_states(:'due_installment_id'::uuid) where component_type = 'INTEREST' \gset
set local role authenticated;
set local request.jwt.claim.sub to '82000000-0000-0000-0000-000000000001';

select is(
  :'interest_after_decrease'::numeric,
  0.00::numeric,
  '8: interest correction decrease of the full amount brings effective outstanding to zero'
);
select is(
  (select interest_due from public.loan_installments where id = :'due_installment_id'::uuid),
  :'due_interest'::numeric,
  '8b: interest_due itself is never rewritten by the correction'
);

select throws_ok(
  format(
    $sql$ select public.rpc_post_loan_obligation_correction('82100000-0000-0000-0000-000000000001', %L::uuid, 'LOAN_INTEREST', %L::uuid, 'CORRECTION_DECREASE', 1, 'DATA_ENTRY_ERROR') $sql$,
    :'loan_interest_id', :'due_installment_id'
  ),
  'P0001',
  'LOAN_CORRECTION_DECREASE_EXCEEDS_OUTSTANDING',
  'a further decrease beyond the now-zero outstanding is rejected'
);

-- Item 24: no income/cash/payment was created by any correction above.
select is(
  (select count(*)::integer from public.payments),
  :payments_before::integer,
  '24: no payment row was created by any correction'
);
reset role;
select is(
  (public.rpc_get_financial_position('82100000-0000-0000-0000-000000000001')->>'recognized_loan_penalty_income')::numeric,
  :'penalty_income_before'::numeric,
  '24b: recognized penalty income is unchanged — a correction never recognizes income merely by being posted'
);

select * from finish();
rollback;
