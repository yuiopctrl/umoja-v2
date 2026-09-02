-- Prompt 09D-UAT-BLOCKER-02: 09D PENALTY ENGINE per-historical-
-- installment behavior (section 35, items 18-25) and MIGRATED loan
-- ACCOUNTING with multiple historical arrears (section 36, items
-- 26-34), including the REAL onboarding scenario from section 37:
-- original principal 20,000,000; historical overdue debt 9,494,606
-- across 3 installments; 7 future installments totaling 12,838,000 at
-- 1,834,000/month; 3% penalty policy.
begin;

select plan(30);

insert into auth.users (id, email) values
  ('79000000-0000-0000-0000-000000000001', 'p09d-blocker2-penalty-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('79100000-0000-0000-0000-000000000001', 'Migrated Multi Penalty Group', '79000000-0000-0000-0000-000000000001', 'MIGP2');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('79200000-0000-0000-0000-000000000001', '79100000-0000-0000-0000-000000000001', '79000000-0000-0000-0000-000000000001', 'MP2 Admin', 'ACTIVE', '2025-01-01', 'MIGP2-2026-0001'),
  ('79200000-0000-0000-0000-000000000005', '79100000-0000-0000-0000-000000000001', null, 'MP2 Borrower E (ONCE)', 'ACTIVE', '2025-01-01', 'MIGP2-2026-0005'),
  ('79200000-0000-0000-0000-000000000006', '79100000-0000-0000-0000-000000000001', null, 'MP2 Borrower G (RECURRING)', 'ACTIVE', '2025-01-01', 'MIGP2-2026-0006'),
  ('79200000-0000-0000-0000-000000000007', '79100000-0000-0000-0000-000000000001', null, 'MP2 Borrower F (real scenario)', 'ACTIVE', '2025-01-01', 'MIGP2-2026-0007');

insert into public.group_membership_roles (group_membership_id, role_id) select '79200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '79000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '79100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product_once as
select public.rpc_create_loan_product(
  '79100000-0000-0000-0000-000000000001', 'MIGP2ONCE', 'Migration Penalty ONCE Product', 100000, 1, 24, 5.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'PERCENTAGE', p_penalty_frequency => 'ONCE',
  p_penalty_grace_days => 0, p_penalty_rate => 3.0
) as result;
select (result->>'id')::uuid as product_once_id from t_product_once \gset

create temporary table t_product_recurring as
select public.rpc_create_loan_product(
  '79100000-0000-0000-0000-000000000001', 'MIGP2REC', 'Migration Penalty Recurring Product', 100000, 1, 24, 5.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'PERCENTAGE', p_penalty_frequency => 'RECURRING_MONTHLY',
  p_penalty_grace_days => 0, p_penalty_rate => 3.0
) as result;
select (result->>'id')::uuid as product_recurring_id from t_product_recurring \gset

-- =======================================================================
-- Loan E (ONCE): three historical overdue installments, each
-- independently eligible for exactly one ASSESSED occurrence. June
-- also carries an OPENING penalty (100,000) which must be EXCLUDED from
-- June's basis and must NOT block June's ASSESSED occurrence.
-- =======================================================================

create temporary table t_loan_e as
select public.rpc_create_migrated_loan(
  '79100000-0000-0000-0000-000000000001', '79200000-0000-0000-0000-000000000005'::uuid, :'product_once_id'::uuid,
  5000000, '2025-06-10'::date, '2026-08-31'::date,
  3000000,
  jsonb_build_array(
    jsonb_build_object('due_date', '2026-06-27', 'principal_outstanding', 1000000, 'interest_outstanding', 200000, 'opening_penalty_outstanding', 100000),
    jsonb_build_object('due_date', '2026-07-27', 'principal_outstanding', 1000000, 'interest_outstanding', 100000, 'opening_penalty_outstanding', 0),
    jsonb_build_object('due_date', '2026-08-27', 'principal_outstanding', 1000000, 'interest_outstanding', 50000, 'opening_penalty_outstanding', 0)
  ),
  0, 0
) as result;
select (result->>'id')::uuid as loan_e_id from t_loan_e \gset
select id as e_inst1_id from public.loan_installments where loan_account_id = :'loan_e_id'::uuid and installment_number = 1 \gset
select id as e_inst2_id from public.loan_installments where loan_account_id = :'loan_e_id'::uuid and installment_number = 2 \gset
select id as e_inst3_id from public.loan_installments where loan_account_id = :'loan_e_id'::uuid and installment_number = 3 \gset

create temporary table t_assess_e as
select public.rpc_assess_loan_penalties('79100000-0000-0000-0000-000000000001', '2026-09-02'::date, :'loan_e_id'::uuid) as result;

select is(
  (select (result->>'assessed_count')::integer from t_assess_e),
  3,
  '18: each of the three historical overdue installments is independently assessed in one call (ONCE each)'
);
select is(
  (select basis_amount from public.loan_penalty_charges where loan_installment_id = :'e_inst1_id'::uuid and origin = 'ASSESSED'),
  1200000.00::numeric,
  '19: June''s ASSESSED basis is 1,200,000 (1,000,000 principal + 200,000 interest) — the 100,000 OPENING penalty is excluded'
);
select is(
  (select penalty_amount from public.loan_penalty_charges where loan_installment_id = :'e_inst1_id'::uuid and origin = 'ASSESSED'),
  36000.00::numeric,
  '19b: June''s new penalty is exactly 36,000 (3% of 1,200,000), never inflated by the existing opening penalty'
);
select is(
  (select count(*) from public.loan_penalty_charges where loan_installment_id = :'e_inst1_id'::uuid and origin = 'ASSESSED'),
  1::bigint,
  '22: June still receives its ONE ASSESSED occurrence — the OPENING penalty never blocks ONCE'
);
select is(
  (select count(*) from public.loan_penalty_charges where loan_installment_id = :'e_inst2_id'::uuid and origin = 'ASSESSED'),
  1::bigint,
  '21: July independently receives its own ONE ASSESSED occurrence'
);
select is(
  (select count(*) from public.loan_penalty_charges where loan_installment_id = :'e_inst3_id'::uuid and origin = 'ASSESSED'),
  1::bigint,
  '21b: August independently receives its own ONE ASSESSED occurrence'
);

-- =======================================================================
-- Loan G (RECURRING_MONTHLY): each historical installment keeps its OWN
-- occurrence sequence anchored to ITS OWN due date — a single
-- assessment run on 2026-09-02 naturally produces June occurrence 3,
-- July occurrence 2, August occurrence 1 (section 16's exact example).
-- A future installment is also included and must never be assessed.
-- =======================================================================

create temporary table t_loan_g as
select public.rpc_create_migrated_loan(
  '79100000-0000-0000-0000-000000000001', '79200000-0000-0000-0000-000000000006'::uuid, :'product_recurring_id'::uuid,
  3400000, '2025-06-10'::date, '2026-08-31'::date,
  3200000,
  jsonb_build_array(
    jsonb_build_object('due_date', '2026-06-27', 'principal_outstanding', 1000000, 'interest_outstanding', 100000, 'opening_penalty_outstanding', 0),
    jsonb_build_object('due_date', '2026-07-27', 'principal_outstanding', 1000000, 'interest_outstanding', 100000, 'opening_penalty_outstanding', 0),
    jsonb_build_object('due_date', '2026-08-27', 'principal_outstanding', 1000000, 'interest_outstanding', 100000, 'opening_penalty_outstanding', 0)
  ),
  20000, 1,
  p_next_due_date => '2026-09-27'::date
) as result;
select (result->>'id')::uuid as loan_g_id from t_loan_g \gset
select id as g_inst1_id from public.loan_installments where loan_account_id = :'loan_g_id'::uuid and installment_number = 1 \gset
select id as g_inst2_id from public.loan_installments where loan_account_id = :'loan_g_id'::uuid and installment_number = 2 \gset
select id as g_inst3_id from public.loan_installments where loan_account_id = :'loan_g_id'::uuid and installment_number = 3 \gset
select id as g_inst4_id from public.loan_installments where loan_account_id = :'loan_g_id'::uuid and installment_number = 4 \gset

select public.rpc_assess_loan_penalties('79100000-0000-0000-0000-000000000001', '2026-09-02'::date, :'loan_g_id'::uuid);

select is(
  (select count(*) from public.loan_penalty_charges where loan_installment_id = :'g_inst1_id'::uuid and origin = 'ASSESSED'),
  3::bigint,
  '23: June (due furthest in the past) has independently reached occurrence 3'
);
select is(
  (select count(*) from public.loan_penalty_charges where loan_installment_id = :'g_inst2_id'::uuid and origin = 'ASSESSED'),
  2::bigint,
  '23b: July has independently reached only occurrence 2'
);
select is(
  (select count(*) from public.loan_penalty_charges where loan_installment_id = :'g_inst3_id'::uuid and origin = 'ASSESSED'),
  1::bigint,
  '23c: August has independently reached only occurrence 1 — no shared loan-wide sequence'
);
select is(
  (select assessment_date from public.loan_penalty_charges where loan_installment_id = :'g_inst1_id'::uuid and sequence_number = 3),
  '2026-08-27'::date,
  '24: June''s 3rd occurrence is anchored to a real CALENDAR month step (27 Jun + 2 months = 27 Aug), never a fixed 30-day drift'
);
select is(
  (select coalesce(sum(basis_amount), null) from public.loan_penalty_charges where loan_installment_id = :'g_inst1_id'::uuid and origin = 'ASSESSED' and basis_amount <> 1100000.00),
  null,
  '20: every one of June''s 3 occurrences shares the SAME 1,100,000 basis — a prior occurrence''s own penalty never inflates or shrinks the next basis'
);
select is(
  (select count(*) from public.loan_penalty_charges where loan_installment_id = :'g_inst4_id'::uuid),
  0::bigint,
  '25: the future (UPCOMING) installment is never assessed, however overdue its siblings are'
);

-- =======================================================================
-- Borrower F: the REAL onboarding scenario (section 37). Original
-- principal 20,000,000; 3 historical overdue installments summing to
-- exactly 9,494,606; 7 future installments totaling exactly
-- 12,838,000 at 1,834,000/month; 3% penalty policy.
-- =======================================================================

reset role;
select public.financial_account_balance(:'account_id'::uuid) as cash_before \gset
set local role authenticated;
set local request.jwt.claim.sub to '79000000-0000-0000-0000-000000000001';
select public.rpc_get_financial_position('79100000-0000-0000-0000-000000000001') as fp_before \gset
select (public.rpc_get_financial_position('79100000-0000-0000-0000-000000000001')->>'funded_loan_principal_receivable')::numeric as receivable_before \gset

create temporary table t_loan_f as
select public.rpc_create_migrated_loan(
  '79100000-0000-0000-0000-000000000001', '79200000-0000-0000-0000-000000000007'::uuid, :'product_once_id'::uuid,
  20000000, '2024-06-27'::date, '2026-08-31'::date,
  19300000,
  jsonb_build_array(
    jsonb_build_object('due_date', '2026-06-27', 'principal_outstanding', 2700000, 'interest_outstanding', 350000, 'opening_penalty_outstanding', 144606),
    jsonb_build_object('due_date', '2026-07-27', 'principal_outstanding', 2700000, 'interest_outstanding', 350000, 'opening_penalty_outstanding', 100000),
    jsonb_build_object('due_date', '2026-08-27', 'principal_outstanding', 2700000, 'interest_outstanding', 350000, 'opening_penalty_outstanding', 100000)
  ),
  1638000, 7,
  p_next_due_date => '2026-09-27'::date
) as result;
select (result->>'id')::uuid as loan_f_id from t_loan_f \gset
select id as f_inst1_id from public.loan_installments where loan_account_id = :'loan_f_id'::uuid and installment_number = 1 \gset

select is(
  (select opening_principal_arrears + opening_interest_arrears + opening_penalty_arrears
   from public.loan_opening_positions where loan_account_id = :'loan_f_id'::uuid),
  9494606.00::numeric,
  '37: the real scenario''s historical arrears total is exactly 9,494,606 across 3 separate installments'
);
select is(
  (select future_scheduled_principal + future_scheduled_interest
   from public.loan_opening_positions where loan_account_id = :'loan_f_id'::uuid),
  12838000.00::numeric,
  '37b: the future schedule totals exactly 12,838,000 across the 7 remaining installments (1,834,000/month)'
);
select is(
  (select count(*) from public.loan_installments where loan_account_id = :'loan_f_id'::uuid and installment_number > 3),
  7::bigint,
  '37c: exactly 7 future installments are created, separately from the 3 historical ones'
);
select is(
  (select coalesce(sum(principal_due), 0) from public.loan_installments where loan_account_id = :'loan_f_id'::uuid and installment_number > 3),
  11200000.00::numeric,
  '29: funded principal receivable reconciles — future principal (11,200,000) + historical principal (8,100,000) = opening_principal_outstanding (19,300,000)'
);

reset role;
select is(
  (public.financial_account_balance(:'account_id'::uuid)),
  :'cash_before'::numeric,
  '26: the real-scenario migration creates ZERO cashbook movement'
);
set local role authenticated;
set local request.jwt.claim.sub to '79000000-0000-0000-0000-000000000001';
select is(
  (public.rpc_get_financial_position('79100000-0000-0000-0000-000000000001')->>'group_income')::numeric,
  (:'fp_before'::jsonb->>'group_income')::numeric,
  '27: the real-scenario migration creates ZERO income'
);
select is(
  (public.rpc_get_financial_position('79100000-0000-0000-0000-000000000001')->>'expenses')::numeric,
  (:'fp_before'::jsonb->>'expenses')::numeric,
  '28: the real-scenario migration creates ZERO expense'
);
select is(
  (public.rpc_get_financial_position('79100000-0000-0000-0000-000000000001')->>'funded_loan_principal_receivable')::numeric,
  (:'receivable_before'::numeric + 19300000.00),
  '29b: funded principal receivable increases by exactly the opening_principal_outstanding (19,300,000)'
);

-- 30/31/32/33/34: paying June in full (2,700,000 + 350,000 + 144,606 =
-- 3,194,606) reduces the receivable by principal only, recognizes
-- interest and opening-penalty income, and the loan remains ACTIVE
-- (July/August/future still outstanding) until reversed.
create temporary table t_post_f as
select public.rpc_post_payment(
  '79100000-0000-0000-0000-000000000001', '79200000-0000-0000-0000-000000000007'::uuid, :'account_id'::uuid,
  3194606, '2026-09-02'::date, 'CASH'
) as result;
select (result->>'payment_id')::uuid as payment_f_id from t_post_f \gset

select is(
  (public.rpc_get_financial_position('79100000-0000-0000-0000-000000000001')->>'funded_loan_principal_receivable')::numeric,
  (:'receivable_before'::numeric + 19300000.00 - 2700000.00),
  '30: paying June in full reduces Funded Loan Principal Receivable by exactly its 2,700,000 principal, never more'
);
select is(
  (public.rpc_get_financial_position('79100000-0000-0000-0000-000000000001')->>'recognized_loan_interest_income')::numeric,
  350000.00::numeric,
  '31: June''s historical interest arrears is recognized as income only now that it is actually paid (350,000)'
);
select is(
  (public.rpc_get_financial_position('79100000-0000-0000-0000-000000000001')->>'recognized_loan_penalty_income')::numeric,
  144606.00::numeric,
  '32: June''s OPENING penalty is recognized as income only now that it is actually paid (144,606)'
);
select is(
  (select status::text from public.loan_accounts where id = :'loan_f_id'::uuid),
  'ACTIVE',
  '34: the loan remains ACTIVE — July, August, and the future schedule are all still outstanding'
);

select public.rpc_reverse_payment('79100000-0000-0000-0000-000000000001', :'payment_f_id'::uuid, 'Blocker-02 reversal test');

reset role;
select is(
  (select outstanding from public.loan_installment_component_states(:'f_inst1_id'::uuid) where component_type = 'PRINCIPAL'),
  2700000.00::numeric,
  '33: reversal restores June''s principal outstanding to exactly 2,700,000'
);
select is(
  (select outstanding from public.loan_installment_component_states(:'f_inst1_id'::uuid) where component_type = 'INTEREST'),
  350000.00::numeric,
  '33b: reversal restores June''s interest outstanding to exactly 350,000'
);
select is(
  (select outstanding from public.loan_installment_component_states(:'f_inst1_id'::uuid) where component_type = 'PENALTY'),
  144606.00::numeric,
  '33c: reversal restores June''s OPENING penalty outstanding to exactly 144,606'
);
set local role authenticated;
set local request.jwt.claim.sub to '79000000-0000-0000-0000-000000000001';
select is(
  (public.rpc_get_financial_position('79100000-0000-0000-0000-000000000001')->>'funded_loan_principal_receivable')::numeric,
  (:'receivable_before'::numeric + 19300000.00),
  '33d: reversal restores Funded Loan Principal Receivable exactly'
);

-- 3%-basis exclusion on the real scenario''s June installment (run
-- AFTER the payment/reversal proof above so it never perturbs it).
create temporary table t_assess_f as
select public.rpc_assess_loan_penalties('79100000-0000-0000-0000-000000000001', '2026-09-02'::date, :'loan_f_id'::uuid) as result;
select is(
  (select basis_amount from public.loan_penalty_charges where loan_installment_id = :'f_inst1_id'::uuid and origin = 'ASSESSED'),
  3050000.00::numeric,
  '37d: June''s 3% assessment basis is 3,050,000 (2,700,000 principal + 350,000 interest) — the 144,606 OPENING penalty is excluded'
);
select is(
  (select penalty_amount from public.loan_penalty_charges where loan_installment_id = :'f_inst1_id'::uuid and origin = 'ASSESSED'),
  91500.00::numeric,
  '37e: June''s new penalty is exactly 91,500 (3% of 3,050,000), never inflated by the 144,606 opening penalty'
);

select * from finish();
rollback;
