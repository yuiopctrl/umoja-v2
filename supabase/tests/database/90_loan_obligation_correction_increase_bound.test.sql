-- Prompt 09F-A-BLOCKER-01: penalty CORRECTION_INCREASE bound — the
-- corrected GROSS obligation (original assessment + every prior
-- non-reversed CORRECTION_INCREASE - every prior non-reversed
-- CORRECTION_DECREASE) may never exceed the charge's own frozen-policy
-- expected_policy_amount. No multiplier, no tolerance, no override.
-- Payments and waivers never create or consume headroom — only
-- correction events do. Scenarios below use a raw fixture insert to
-- construct charges whose penalty_amount deliberately differs from
-- their frozen fixed_amount (simulating a genuine historical
-- under/over-assessment mistake) — the same isolation technique
-- already used by 57_loan_penalty_calculation.test.sql.
begin;

select plan(19);

insert into auth.users (id, email) values
  ('90000000-0000-0000-0000-000000000001', 'p09fa-blocker01-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('90100000-0000-0000-0000-000000000001', 'Blocker01 Group', '90000000-0000-0000-0000-000000000001', 'BLK1');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('90200000-0000-0000-0000-000000000001', '90100000-0000-0000-0000-000000000001', '90000000-0000-0000-0000-000000000001', 'Blocker01 Admin', 'ACTIVE', '2025-01-01', 'BLK1-2026-0001'),
  ('90200000-0000-0000-0000-000000000011', '90100000-0000-0000-0000-000000000001', null, 'Borrower A', 'ACTIVE', '2025-01-01', 'BLK1-2026-0011'),
  ('90200000-0000-0000-0000-000000000012', '90100000-0000-0000-0000-000000000001', null, 'Borrower B', 'ACTIVE', '2025-01-01', 'BLK1-2026-0012'),
  ('90200000-0000-0000-0000-000000000013', '90100000-0000-0000-0000-000000000001', null, 'Borrower C', 'ACTIVE', '2025-01-01', 'BLK1-2026-0013'),
  ('90200000-0000-0000-0000-000000000014', '90100000-0000-0000-0000-000000000001', null, 'Borrower D', 'ACTIVE', '2025-01-01', 'BLK1-2026-0014'),
  ('90200000-0000-0000-0000-000000000015', '90100000-0000-0000-0000-000000000001', null, 'Borrower E', 'ACTIVE', '2025-01-01', 'BLK1-2026-0015'),
  ('90200000-0000-0000-0000-000000000016', '90100000-0000-0000-0000-000000000001', null, 'Borrower F', 'ACTIVE', '2025-01-01', 'BLK1-2026-0016'),
  ('90200000-0000-0000-0000-000000000017', '90100000-0000-0000-0000-000000000001', null, 'Borrower G', 'ACTIVE', '2025-01-01', 'BLK1-2026-0017');

insert into public.group_membership_roles (group_membership_id, role_id) select '90200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '90100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '90100000-0000-0000-0000-000000000001', 'BLK1P', 'Blocker01 Product', 100000, 1, 12, 5.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'FIXED', p_penalty_frequency => 'ONCE',
  p_penalty_grace_days => 0, p_penalty_fixed_amount => 50000
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

-- ---------------------------------------------------------------------
-- Helper macro (repeated inline): create a disbursed loan + a raw-
-- inserted penalty charge whose frozen fixed_amount is 50,000 but whose
-- penalty_amount is deliberately set to simulate an original mistake.
-- ---------------------------------------------------------------------

-- =======================================================================
-- Scenarios 1/2: original 30,000, expected 50,000 -> max increase 20,000.
-- =======================================================================

create temporary table t_loan_1 as
select public.rpc_create_draft_loan_account(
  '90100000-0000-0000-0000-000000000001', '90200000-0000-0000-0000-000000000011'::uuid,
  :'product_id'::uuid, 500000, 1, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_1_id from t_loan_1 \gset
select public.rpc_submit_loan_account('90100000-0000-0000-0000-000000000001', :'loan_1_id'::uuid);
select public.rpc_approve_loan_account('90100000-0000-0000-0000-000000000001', :'loan_1_id'::uuid);
select public.rpc_disburse_loan_account('90100000-0000-0000-0000-000000000001', :'loan_1_id'::uuid, :'account_id'::uuid, current_date);
select id as installment_1_id from public.loan_installments where loan_account_id = :'loan_1_id'::uuid \gset

reset role;
insert into public.loan_penalty_charges (
  group_id, loan_account_id, loan_installment_id, assessment_date, sequence_number,
  penalty_type, penalty_frequency, penalty_basis, penalty_grace_days,
  basis_amount, fixed_amount, penalty_amount
) values (
  '90100000-0000-0000-0000-000000000001', :'loan_1_id'::uuid, :'installment_1_id'::uuid,
  current_date, 1, 'FIXED', 'ONCE', 'OUTSTANDING_INSTALLMENT', 0, 500000, 50000, 30000
);
select id as charge_1_id from public.loan_penalty_charges where loan_installment_id = :'installment_1_id'::uuid \gset
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-0000-0000-000000000001';

-- Scenario 2: +20,001 rejected FIRST (checked before the passing case so
-- the pass in scenario 1 doesn't consume headroom needed here).
select throws_ok(
  format(
    $sql$ select public.rpc_post_loan_obligation_correction('90100000-0000-0000-0000-000000000001', %L::uuid, 'LOAN_PENALTY', %L::uuid, 'CORRECTION_INCREASE', 20001, 'ASSESSMENT_ERROR') $sql$,
    :'loan_1_id', :'charge_1_id'
  ),
  'P0001',
  'LOAN_CORRECTION_INCREASE_EXCEEDS_BOUND',
  '2: original 30k, expected 50k, increase 20,001 -> REJECT'
);

-- Scenario 1: +20,000 passes exactly.
create temporary table t_scenario1 as
select public.rpc_post_loan_obligation_correction(
  '90100000-0000-0000-0000-000000000001', :'loan_1_id'::uuid, 'LOAN_PENALTY', :'charge_1_id'::uuid,
  'CORRECTION_INCREASE', 20000, 'ASSESSMENT_ERROR'
) as result;
select is((result->>'new_effective_amount')::numeric, 50000.00::numeric, '1: original 30k, expected 50k, increase 20,000 -> PASS, corrected gross 50,000') from t_scenario1;

-- =======================================================================
-- Scenario 3: original 50,000, expected 50,000, paid 30,000 (outstanding
-- 20,000) -> increase 1 REJECTED. Payments create no headroom.
-- =======================================================================

create temporary table t_loan_3 as
select public.rpc_create_draft_loan_account(
  '90100000-0000-0000-0000-000000000001', '90200000-0000-0000-0000-000000000012'::uuid,
  :'product_id'::uuid, 500000, 1, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_3_id from t_loan_3 \gset
select public.rpc_submit_loan_account('90100000-0000-0000-0000-000000000001', :'loan_3_id'::uuid);
select public.rpc_approve_loan_account('90100000-0000-0000-0000-000000000001', :'loan_3_id'::uuid);
select public.rpc_disburse_loan_account('90100000-0000-0000-0000-000000000001', :'loan_3_id'::uuid, :'account_id'::uuid, current_date);
select id as installment_3_id from public.loan_installments where loan_account_id = :'loan_3_id'::uuid \gset

select public.rpc_assess_loan_penalties('90100000-0000-0000-0000-000000000001', current_date, :'loan_3_id'::uuid);
select id as charge_3_id from public.loan_penalty_charges where loan_installment_id = :'installment_3_id'::uuid \gset

select public.rpc_post_payment(
  '90100000-0000-0000-0000-000000000001', '90200000-0000-0000-0000-000000000012'::uuid, :'account_id'::uuid,
  30000, current_date, 'CASH'
);
select id as payment_id from public.payments where membership_id = '90200000-0000-0000-0000-000000000012' \gset

select throws_ok(
  format(
    $sql$ select public.rpc_post_loan_obligation_correction('90100000-0000-0000-0000-000000000001', %L::uuid, 'LOAN_PENALTY', %L::uuid, 'CORRECTION_INCREASE', 1, 'ASSESSMENT_ERROR') $sql$,
    :'loan_3_id', :'charge_3_id'
  ),
  'P0001',
  'LOAN_CORRECTION_INCREASE_EXCEEDS_BOUND',
  '3: original 50k, expected 50k, paid 30k, increase 1 -> REJECT (payment creates no headroom)'
);

-- Scenario 11 continues on this same loan: reversing the payment must
-- not change the (still-zero) correction headroom either.
select public.rpc_reverse_payment('90100000-0000-0000-0000-000000000001', :'payment_id'::uuid, 'test reversal');

select throws_ok(
  format(
    $sql$ select public.rpc_post_loan_obligation_correction('90100000-0000-0000-0000-000000000001', %L::uuid, 'LOAN_PENALTY', %L::uuid, 'CORRECTION_INCREASE', 1, 'ASSESSMENT_ERROR') $sql$,
    :'loan_3_id', :'charge_3_id'
  ),
  'P0001',
  'LOAN_CORRECTION_INCREASE_EXCEEDS_BOUND',
  '11: after reversing the payment, correction headroom is unchanged (still zero)'
);

-- =======================================================================
-- Scenario 4: original 50,000, expected 50,000, waived 20,000 ->
-- increase 1 REJECTED. Waivers create no headroom.
-- =======================================================================

create temporary table t_loan_4 as
select public.rpc_create_draft_loan_account(
  '90100000-0000-0000-0000-000000000001', '90200000-0000-0000-0000-000000000013'::uuid,
  :'product_id'::uuid, 500000, 1, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_4_id from t_loan_4 \gset
select public.rpc_submit_loan_account('90100000-0000-0000-0000-000000000001', :'loan_4_id'::uuid);
select public.rpc_approve_loan_account('90100000-0000-0000-0000-000000000001', :'loan_4_id'::uuid);
select public.rpc_disburse_loan_account('90100000-0000-0000-0000-000000000001', :'loan_4_id'::uuid, :'account_id'::uuid, current_date);
select id as installment_4_id from public.loan_installments where loan_account_id = :'loan_4_id'::uuid \gset

select public.rpc_assess_loan_penalties('90100000-0000-0000-0000-000000000001', current_date, :'loan_4_id'::uuid);
select id as charge_4_id from public.loan_penalty_charges where loan_installment_id = :'installment_4_id'::uuid \gset

create temporary table t_waiver_4 as
select public.rpc_post_loan_obligation_waiver(
  '90100000-0000-0000-0000-000000000001', :'loan_4_id'::uuid, 'LOAN_PENALTY', :'charge_4_id'::uuid, 20000, 'HARDSHIP'
) as result;
select (result->>'adjustment_id')::uuid as waiver_4_id from t_waiver_4 \gset

select throws_ok(
  format(
    $sql$ select public.rpc_post_loan_obligation_correction('90100000-0000-0000-0000-000000000001', %L::uuid, 'LOAN_PENALTY', %L::uuid, 'CORRECTION_INCREASE', 1, 'ASSESSMENT_ERROR') $sql$,
    :'loan_4_id', :'charge_4_id'
  ),
  'P0001',
  'LOAN_CORRECTION_INCREASE_EXCEEDS_BOUND',
  '4: original 50k, expected 50k, waived 20k, increase 1 -> REJECT (waiver creates no headroom)'
);

-- Scenario 10 continues on this same loan: reversing the waiver must not
-- change the (still-zero) correction headroom either.
select public.rpc_reverse_loan_obligation_adjustment('90100000-0000-0000-0000-000000000001', :'waiver_4_id'::uuid, 'test reversal');

select throws_ok(
  format(
    $sql$ select public.rpc_post_loan_obligation_correction('90100000-0000-0000-0000-000000000001', %L::uuid, 'LOAN_PENALTY', %L::uuid, 'CORRECTION_INCREASE', 1, 'ASSESSMENT_ERROR') $sql$,
    :'loan_4_id', :'charge_4_id'
  ),
  'P0001',
  'LOAN_CORRECTION_INCREASE_EXCEEDS_BOUND',
  '10: after reversing the waiver, correction headroom is unchanged (still zero)'
);

-- =======================================================================
-- Scenarios 5/6: original 30,000, expected 50,000 -> two +10,000
-- increases both PASS (final corrected gross 50,000); a further +0.01
-- REJECTS.
-- =======================================================================

create temporary table t_loan_5 as
select public.rpc_create_draft_loan_account(
  '90100000-0000-0000-0000-000000000001', '90200000-0000-0000-0000-000000000014'::uuid,
  :'product_id'::uuid, 500000, 1, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_5_id from t_loan_5 \gset
select public.rpc_submit_loan_account('90100000-0000-0000-0000-000000000001', :'loan_5_id'::uuid);
select public.rpc_approve_loan_account('90100000-0000-0000-0000-000000000001', :'loan_5_id'::uuid);
select public.rpc_disburse_loan_account('90100000-0000-0000-0000-000000000001', :'loan_5_id'::uuid, :'account_id'::uuid, current_date);
select id as installment_5_id from public.loan_installments where loan_account_id = :'loan_5_id'::uuid \gset

reset role;
insert into public.loan_penalty_charges (
  group_id, loan_account_id, loan_installment_id, assessment_date, sequence_number,
  penalty_type, penalty_frequency, penalty_basis, penalty_grace_days,
  basis_amount, fixed_amount, penalty_amount
) values (
  '90100000-0000-0000-0000-000000000001', :'loan_5_id'::uuid, :'installment_5_id'::uuid,
  current_date, 1, 'FIXED', 'ONCE', 'OUTSTANDING_INSTALLMENT', 0, 500000, 50000, 30000
);
select id as charge_5_id from public.loan_penalty_charges where loan_installment_id = :'installment_5_id'::uuid \gset
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-0000-0000-000000000001';

create temporary table t_scenario5a as
select public.rpc_post_loan_obligation_correction(
  '90100000-0000-0000-0000-000000000001', :'loan_5_id'::uuid, 'LOAN_PENALTY', :'charge_5_id'::uuid,
  'CORRECTION_INCREASE', 10000, 'ASSESSMENT_ERROR'
) as result;
select is((result->>'new_effective_amount')::numeric, 40000.00::numeric, '5a: first +10,000 increase -> PASS, corrected gross 40,000') from t_scenario5a;

create temporary table t_scenario5b as
select public.rpc_post_loan_obligation_correction(
  '90100000-0000-0000-0000-000000000001', :'loan_5_id'::uuid, 'LOAN_PENALTY', :'charge_5_id'::uuid,
  'CORRECTION_INCREASE', 10000, 'ASSESSMENT_ERROR'
) as result;
select is((result->>'new_effective_amount')::numeric, 50000.00::numeric, '5b: second +10,000 increase -> PASS, final corrected gross exactly 50,000') from t_scenario5b;

select throws_ok(
  format(
    $sql$ select public.rpc_post_loan_obligation_correction('90100000-0000-0000-0000-000000000001', %L::uuid, 'LOAN_PENALTY', %L::uuid, 'CORRECTION_INCREASE', 0.01, 'ASSESSMENT_ERROR') $sql$,
    :'loan_5_id', :'charge_5_id'
  ),
  'P0001',
  'LOAN_CORRECTION_INCREASE_EXCEEDS_BOUND',
  '6: after scenario 5, an additional +0.01 increase -> REJECT'
);

-- =======================================================================
-- Scenario 9: a correction increase posted then safely (immediately)
-- reversed restores headroom exactly.
-- =======================================================================

create temporary table t_loan_9 as
select public.rpc_create_draft_loan_account(
  '90100000-0000-0000-0000-000000000001', '90200000-0000-0000-0000-000000000015'::uuid,
  :'product_id'::uuid, 500000, 1, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_9_id from t_loan_9 \gset
select public.rpc_submit_loan_account('90100000-0000-0000-0000-000000000001', :'loan_9_id'::uuid);
select public.rpc_approve_loan_account('90100000-0000-0000-0000-000000000001', :'loan_9_id'::uuid);
select public.rpc_disburse_loan_account('90100000-0000-0000-0000-000000000001', :'loan_9_id'::uuid, :'account_id'::uuid, current_date);
select id as installment_9_id from public.loan_installments where loan_account_id = :'loan_9_id'::uuid \gset

reset role;
insert into public.loan_penalty_charges (
  group_id, loan_account_id, loan_installment_id, assessment_date, sequence_number,
  penalty_type, penalty_frequency, penalty_basis, penalty_grace_days,
  basis_amount, fixed_amount, penalty_amount
) values (
  '90100000-0000-0000-0000-000000000001', :'loan_9_id'::uuid, :'installment_9_id'::uuid,
  current_date, 1, 'FIXED', 'ONCE', 'OUTSTANDING_INSTALLMENT', 0, 500000, 50000, 30000
);
select id as charge_9_id from public.loan_penalty_charges where loan_installment_id = :'installment_9_id'::uuid \gset
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-0000-0000-000000000001';

create temporary table t_scenario9_increase as
select public.rpc_post_loan_obligation_correction(
  '90100000-0000-0000-0000-000000000001', :'loan_9_id'::uuid, 'LOAN_PENALTY', :'charge_9_id'::uuid,
  'CORRECTION_INCREASE', 20000, 'ASSESSMENT_ERROR'
) as result;
select (result->>'adjustment_id')::uuid as increase_9_id from t_scenario9_increase \gset

select public.rpc_reverse_loan_obligation_adjustment('90100000-0000-0000-0000-000000000001', :'increase_9_id'::uuid, 'test reversal — no later activity');

select throws_ok(
  format(
    $sql$ select public.rpc_post_loan_obligation_correction('90100000-0000-0000-0000-000000000001', %L::uuid, 'LOAN_PENALTY', %L::uuid, 'CORRECTION_INCREASE', 20001, 'ASSESSMENT_ERROR') $sql$,
    :'loan_9_id', :'charge_9_id'
  ),
  'P0001',
  'LOAN_CORRECTION_INCREASE_EXCEEDS_BOUND',
  '9a: after reversal, +20,001 still exceeds the restored 20,000 headroom -> REJECT'
);

create temporary table t_scenario9_reincrease as
select public.rpc_post_loan_obligation_correction(
  '90100000-0000-0000-0000-000000000001', :'loan_9_id'::uuid, 'LOAN_PENALTY', :'charge_9_id'::uuid,
  'CORRECTION_INCREASE', 20000, 'ASSESSMENT_ERROR'
) as result;
select is(
  (result->>'new_effective_amount')::numeric,
  50000.00::numeric,
  '9b: reversal fully restored the 20,000 headroom — the same +20,000 increase now passes again'
) from t_scenario9_reincrease;

-- =======================================================================
-- Scenario 7: original 70,000, expected 50,000 -> any increase rejected.
-- =======================================================================

create temporary table t_loan_7 as
select public.rpc_create_draft_loan_account(
  '90100000-0000-0000-0000-000000000001', '90200000-0000-0000-0000-000000000016'::uuid,
  :'product_id'::uuid, 500000, 1, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_7_id from t_loan_7 \gset
select public.rpc_submit_loan_account('90100000-0000-0000-0000-000000000001', :'loan_7_id'::uuid);
select public.rpc_approve_loan_account('90100000-0000-0000-0000-000000000001', :'loan_7_id'::uuid);
select public.rpc_disburse_loan_account('90100000-0000-0000-0000-000000000001', :'loan_7_id'::uuid, :'account_id'::uuid, current_date);
select id as installment_7_id from public.loan_installments where loan_account_id = :'loan_7_id'::uuid \gset

reset role;
insert into public.loan_penalty_charges (
  group_id, loan_account_id, loan_installment_id, assessment_date, sequence_number,
  penalty_type, penalty_frequency, penalty_basis, penalty_grace_days,
  basis_amount, fixed_amount, penalty_amount
) values (
  '90100000-0000-0000-0000-000000000001', :'loan_7_id'::uuid, :'installment_7_id'::uuid,
  current_date, 1, 'FIXED', 'ONCE', 'OUTSTANDING_INSTALLMENT', 0, 500000, 50000, 70000
);
select id as charge_7_id from public.loan_penalty_charges where loan_installment_id = :'installment_7_id'::uuid \gset
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-0000-0000-000000000001';

select throws_ok(
  format(
    $sql$ select public.rpc_post_loan_obligation_correction('90100000-0000-0000-0000-000000000001', %L::uuid, 'LOAN_PENALTY', %L::uuid, 'CORRECTION_INCREASE', 1, 'ASSESSMENT_ERROR') $sql$,
    :'loan_7_id', :'charge_7_id'
  ),
  'P0001',
  'LOAN_CORRECTION_INCREASE_EXCEEDS_BOUND',
  '7: original 70k, expected 50k -> any increase is REJECTED (the original row is never silently normalized)'
);
select is(
  (select penalty_amount from public.loan_penalty_charges where id = :'charge_7_id'::uuid),
  70000.00::numeric,
  '7b: the over-assessed original row is left exactly as-is — never silently normalized'
);

-- =======================================================================
-- Scenario 8: original 70,000, expected 50,000, correction decrease
-- 20,000 -> corrected gross 50,000; a further +0.01 increase rejects.
-- =======================================================================

create temporary table t_scenario8_decrease as
select public.rpc_post_loan_obligation_correction(
  '90100000-0000-0000-0000-000000000001', :'loan_7_id'::uuid, 'LOAN_PENALTY', :'charge_7_id'::uuid,
  'CORRECTION_DECREASE', 20000, 'ASSESSMENT_ERROR'
) as result;
select is(
  (result->>'new_effective_amount')::numeric,
  50000.00::numeric,
  '8a: correction decrease of 20,000 on the 70,000 original brings corrected gross to exactly 50,000'
) from t_scenario8_decrease;

select throws_ok(
  format(
    $sql$ select public.rpc_post_loan_obligation_correction('90100000-0000-0000-0000-000000000001', %L::uuid, 'LOAN_PENALTY', %L::uuid, 'CORRECTION_INCREASE', 0.01, 'ASSESSMENT_ERROR') $sql$,
    :'loan_7_id', :'charge_7_id'
  ),
  'P0001',
  'LOAN_CORRECTION_INCREASE_EXCEEDS_BOUND',
  '8b: after the decrease, a further +0.01 increase -> REJECT'
);

-- =======================================================================
-- Scenario 12: a MIGRATED loan's OPENING-origin penalty charge has no
-- frozen policy to reconcile against -> CORRECTION_INCREASE is rejected
-- with a stable, distinct domain error; waiver/decrease remain
-- available.
-- =======================================================================

create temporary table t_migrated_12 as
select public.rpc_create_migrated_loan(
  '90100000-0000-0000-0000-000000000001', '90200000-0000-0000-0000-000000000017'::uuid, :'product_id'::uuid,
  10000000, '2025-11-10'::date, '2026-08-31'::date,
  4000000,
  jsonb_build_array(jsonb_build_object(
    'due_date', '2026-08-01', 'principal_outstanding', 400000,
    'interest_outstanding', 80000, 'opening_penalty_outstanding', 20000
  )),
  600000, 4,
  p_next_due_date => '2026-09-01'::date
) as result;
select (result->>'id')::uuid as loan_12_id from t_migrated_12 \gset
select id as installment_12_id from public.loan_installments
  where loan_account_id = :'loan_12_id'::uuid and installment_number = 1 \gset
select id as charge_12_id from public.loan_penalty_charges
  where loan_installment_id = :'installment_12_id'::uuid and origin = 'OPENING' \gset

select is(
  (select penalty_type from public.loan_penalty_charges where id = :'charge_12_id'::uuid),
  null::public.loan_penalty_type,
  'setup: the OPENING charge has no frozen penalty_type — no frozen policy exists to reconcile against'
);

select throws_ok(
  format(
    $sql$ select public.rpc_post_loan_obligation_correction('90100000-0000-0000-0000-000000000001', %L::uuid, 'LOAN_PENALTY', %L::uuid, 'CORRECTION_INCREASE', 1, 'ASSESSMENT_ERROR') $sql$,
    :'loan_12_id', :'charge_12_id'
  ),
  'P0001',
  'LOAN_CORRECTION_INCREASE_POLICY_UNAVAILABLE',
  '12: CORRECTION_INCREASE on an OPENING charge with no frozen policy is rejected with a distinct, stable domain error'
);

-- Waiver and CORRECTION_DECREASE remain fully available for the same
-- OPENING target.
select is(
  (public.rpc_post_loan_obligation_waiver(
    '90100000-0000-0000-0000-000000000001', :'loan_12_id'::uuid, 'LOAN_PENALTY', :'charge_12_id'::uuid, 5000, 'HARDSHIP'
  )->>'adjustment_type')::text,
  'WAIVER',
  '12b: waiver remains available for an OPENING charge with no frozen policy'
);
select is(
  (public.rpc_post_loan_obligation_correction(
    '90100000-0000-0000-0000-000000000001', :'loan_12_id'::uuid, 'LOAN_PENALTY', :'charge_12_id'::uuid,
    'CORRECTION_DECREASE', 5000, 'ASSESSMENT_ERROR'
  )->>'adjustment_type')::text,
  'CORRECTION_DECREASE',
  '12c: correction decrease remains available for an OPENING charge with no frozen policy'
);

select * from finish();
rollback;
