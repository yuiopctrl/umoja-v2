-- Prompt 09F-A-09 (UAT Blocker-02, Defect C): future/unearned interest
-- must never be CORRECTION_DECREASE-able — enforced independently in
-- BOTH preview and post. Uses an explicit p_effective_date anchor
-- throughout (never wall-clock `current_date`) so past/due-today/future
-- installments are deterministic regardless of when this suite runs.
begin;

select plan(20);

insert into auth.users (id, email) values
  ('92000000-0000-0000-0000-000000000001', 'p09fa09-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('92100000-0000-0000-0000-000000000001', 'Blocker02 Group', '92000000-0000-0000-0000-000000000001', 'BLK2');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('92200000-0000-0000-0000-000000000001', '92100000-0000-0000-0000-000000000001', '92000000-0000-0000-0000-000000000001', 'Blocker02 Admin', 'ACTIVE', '2025-01-01', 'BLK2-2026-0001'),
  ('92200000-0000-0000-0000-000000000011', '92100000-0000-0000-0000-000000000001', null, 'Interest Borrower', 'ACTIVE', '2025-01-01', 'BLK2-2026-0011'),
  ('92200000-0000-0000-0000-000000000012', '92100000-0000-0000-0000-000000000001', null, 'Penalty Borrower', 'ACTIVE', '2025-01-01', 'BLK2-2026-0012'),
  ('92200000-0000-0000-0000-000000000013', '92100000-0000-0000-0000-000000000001', null, 'Waiver Borrower', 'ACTIVE', '2025-01-01', 'BLK2-2026-0013');

insert into public.group_membership_roles (group_membership_id, role_id) select '92200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '92000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '92100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, '2026-06-15'::date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

-- =======================================================================
-- Section 1 (items 1-8): LOAN_INTEREST correction/waiver gate, anchored
-- at effective date 2026-06-15. first_repayment_date 2026-05-15 gives:
--   installment 1 due 2026-05-15 -> PAST (earned)
--   installment 2 due 2026-06-15 -> DUE-TODAY (earned, due_date == effective_date)
--   installment 3 due 2026-07-15 -> FUTURE (unearned)
-- =======================================================================

create temporary table t_product_interest as
select public.rpc_create_loan_product(
  '92100000-0000-0000-0000-000000000001', 'BLK2INT', 'Blocker02 Interest Product', 100000, 1, 12, 6.0, 'MONTHLY', 'FLAT'
) as result;
select (result->>'id')::uuid as product_interest_id from t_product_interest \gset

create temporary table t_loan_interest as
select public.rpc_create_draft_loan_account(
  '92100000-0000-0000-0000-000000000001', '92200000-0000-0000-0000-000000000011'::uuid,
  :'product_interest_id'::uuid, 300000, 3, '2026-05-15'::date
) as result;
select (result->>'id')::uuid as loan_interest_id from t_loan_interest \gset
select public.rpc_submit_loan_account('92100000-0000-0000-0000-000000000001', :'loan_interest_id'::uuid);
select public.rpc_approve_loan_account('92100000-0000-0000-0000-000000000001', :'loan_interest_id'::uuid);
select public.rpc_disburse_loan_account('92100000-0000-0000-0000-000000000001', :'loan_interest_id'::uuid, :'account_id'::uuid, '2026-05-15'::date);

select id as past_installment_id from public.loan_installments
  where loan_account_id = :'loan_interest_id'::uuid and due_date = '2026-05-15' \gset
select id as due_today_installment_id from public.loan_installments
  where loan_account_id = :'loan_interest_id'::uuid and due_date = '2026-06-15' \gset
select id as future_installment_id from public.loan_installments
  where loan_account_id = :'loan_interest_id'::uuid and due_date = '2026-07-15' \gset

select count(*)::integer as adjustments_before from public.loan_obligation_adjustments \gset
select count(*)::integer as payments_before from public.payments \gset
select count(*)::integer as wallet_entries_before from public.member_wallet_entries \gset
select count(*)::integer as fa_entries_before from public.financial_account_entries \gset
reset role;
select (public.rpc_get_financial_position('92100000-0000-0000-0000-000000000001')->>'recognized_loan_interest_income')::numeric as interest_income_before \gset
set local role authenticated;
set local request.jwt.claim.sub to '92000000-0000-0000-0000-000000000001';

-- Item 1: future LOAN_INTEREST CORRECTION_DECREASE preview rejected.
select throws_ok(
  format(
    $sql$ select public.rpc_preview_loan_obligation_correction('92100000-0000-0000-0000-000000000001', %L::uuid, 'LOAN_INTEREST', %L::uuid, 'CORRECTION_DECREASE', 100, 'ASSESSMENT_ERROR', null, '2026-06-15'::date) $sql$,
    :'loan_interest_id', :'future_installment_id'
  ),
  'P0001',
  'LOAN_FUTURE_INTEREST_NOT_CORRECTABLE',
  '1: future LOAN_INTEREST CORRECTION_DECREASE preview is rejected'
);

-- Item 2: future LOAN_INTEREST CORRECTION_DECREASE direct post rejected
-- (post enforces the gate independently — not merely protected by preview).
select throws_ok(
  format(
    $sql$ select public.rpc_post_loan_obligation_correction('92100000-0000-0000-0000-000000000001', %L::uuid, 'LOAN_INTEREST', %L::uuid, 'CORRECTION_DECREASE', 100, 'ASSESSMENT_ERROR', null, '2026-06-15'::date) $sql$,
    :'loan_interest_id', :'future_installment_id'
  ),
  'P0001',
  'LOAN_FUTURE_INTEREST_NOT_CORRECTABLE',
  '2: future LOAN_INTEREST CORRECTION_DECREASE direct post is rejected'
);

-- Item 12/13: the rejected future-interest correction created nothing.
select is(
  (select count(*)::integer from public.loan_obligation_adjustments),
  :adjustments_before,
  '12: the rejected future-interest correction created zero adjustment rows'
);
select is(
  (select count(*)::integer from public.payments),
  :payments_before,
  '13a: zero payment rows created by the rejected future-interest correction'
);
select is(
  (select count(*)::integer from public.member_wallet_entries),
  :wallet_entries_before,
  '13b: zero wallet movement created by the rejected future-interest correction'
);
select is(
  (select count(*)::integer from public.financial_account_entries),
  :fa_entries_before,
  '13c: zero cashbook movement created by the rejected future-interest correction'
);
reset role;
select is(
  (public.rpc_get_financial_position('92100000-0000-0000-0000-000000000001')->>'recognized_loan_interest_income')::numeric,
  :'interest_income_before'::numeric,
  '13d: zero income recognized by the rejected future-interest correction'
);
set local role authenticated;
set local request.jwt.claim.sub to '92000000-0000-0000-0000-000000000001';

-- Item 3: due-today LOAN_INTEREST CORRECTION_DECREASE preview allowed.
select ok(
  (public.rpc_preview_loan_obligation_correction(
    '92100000-0000-0000-0000-000000000001', :'loan_interest_id'::uuid, 'LOAN_INTEREST', :'due_today_installment_id'::uuid,
    'CORRECTION_DECREASE', 100, 'ASSESSMENT_ERROR', null, '2026-06-15'::date
  ) ->> 'adjustment_type') = 'CORRECTION_DECREASE',
  '3: due-today (due_date == effective_date) LOAN_INTEREST CORRECTION_DECREASE preview is allowed'
);

-- Item 4: due-today LOAN_INTEREST CORRECTION_DECREASE post succeeds.
create temporary table t_due_today_correction as
select public.rpc_post_loan_obligation_correction(
  '92100000-0000-0000-0000-000000000001', :'loan_interest_id'::uuid, 'LOAN_INTEREST', :'due_today_installment_id'::uuid,
  'CORRECTION_DECREASE', 100, 'ASSESSMENT_ERROR', null, '2026-06-15'::date
) as result;
select is(
  (result->>'adjustment_type')::text, 'CORRECTION_DECREASE',
  '4: due-today LOAN_INTEREST CORRECTION_DECREASE post succeeds'
) from t_due_today_correction;

-- Item 5: past-due earned/payable interest correction decrease succeeds.
create temporary table t_past_correction as
select public.rpc_post_loan_obligation_correction(
  '92100000-0000-0000-0000-000000000001', :'loan_interest_id'::uuid, 'LOAN_INTEREST', :'past_installment_id'::uuid,
  'CORRECTION_DECREASE', 100, 'ASSESSMENT_ERROR', null, '2026-06-15'::date
) as result;
select is(
  (result->>'adjustment_type')::text, 'CORRECTION_DECREASE',
  '5: past-due earned/payable interest correction decrease succeeds'
) from t_past_correction;

-- Item 6: future interest WAIVER remains rejected (unaffected by this fix).
select throws_ok(
  format(
    $sql$ select public.rpc_preview_loan_obligation_waiver('92100000-0000-0000-0000-000000000001', %L::uuid, 'LOAN_INTEREST', %L::uuid, 100, 'HARDSHIP', null, '2026-06-15'::date) $sql$,
    :'loan_interest_id', :'future_installment_id'
  ),
  'P0001',
  'LOAN_FUTURE_INTEREST_NOT_WAIVABLE',
  '6: future interest waiver remains rejected'
);

-- Item 7: due/past interest waiver remains eligible.
select ok(
  (public.rpc_preview_loan_obligation_waiver(
    '92100000-0000-0000-0000-000000000001', :'loan_interest_id'::uuid, 'LOAN_INTEREST', :'due_today_installment_id'::uuid,
    100, 'HARDSHIP', null, '2026-06-15'::date
  ) ->> 'target_type') = 'LOAN_INTEREST',
  '7: due-today interest waiver remains eligible'
);

-- Item 8: interest CORRECTION_INCREASE remains prohibited outright.
select throws_ok(
  format(
    $sql$ select public.rpc_preview_loan_obligation_correction('92100000-0000-0000-0000-000000000001', %L::uuid, 'LOAN_INTEREST', %L::uuid, 'CORRECTION_INCREASE', 100, 'ASSESSMENT_ERROR', null, '2026-06-15'::date) $sql$,
    :'loan_interest_id', :'past_installment_id'
  ),
  'P0001',
  'LOAN_CORRECTION_INCREASE_NOT_ALLOWED',
  '8: interest CORRECTION_INCREASE remains prohibited outright'
);

-- =======================================================================
-- Section 2 (items 9-11): LOAN_PENALTY regression — Blocker-01 bound
-- and MIGRATED/OPENING behavior unaffected by this migration.
-- =======================================================================

create temporary table t_product_penalty as
select public.rpc_create_loan_product(
  '92100000-0000-0000-0000-000000000001', 'BLK2PEN', 'Blocker02 Penalty Product', 100000, 1, 12, 5.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'FIXED', p_penalty_frequency => 'ONCE',
  p_penalty_grace_days => 0, p_penalty_fixed_amount => 50000
) as result;
select (result->>'id')::uuid as product_penalty_id from t_product_penalty \gset

create temporary table t_loan_penalty as
select public.rpc_create_draft_loan_account(
  '92100000-0000-0000-0000-000000000001', '92200000-0000-0000-0000-000000000012'::uuid,
  :'product_penalty_id'::uuid, 500000, 1, '2026-05-15'::date
) as result;
select (result->>'id')::uuid as loan_penalty_id from t_loan_penalty \gset
select public.rpc_submit_loan_account('92100000-0000-0000-0000-000000000001', :'loan_penalty_id'::uuid);
select public.rpc_approve_loan_account('92100000-0000-0000-0000-000000000001', :'loan_penalty_id'::uuid);
select public.rpc_disburse_loan_account('92100000-0000-0000-0000-000000000001', :'loan_penalty_id'::uuid, :'account_id'::uuid, '2026-05-15'::date);
select id as penalty_installment_id from public.loan_installments where loan_account_id = :'loan_penalty_id'::uuid \gset

select public.rpc_assess_loan_penalties('92100000-0000-0000-0000-000000000001', '2026-06-15'::date, :'loan_penalty_id'::uuid);
select id as penalty_charge_id from public.loan_penalty_charges where loan_installment_id = :'penalty_installment_id'::uuid \gset

-- Item 9: penalty correction decrease unaffected.
create temporary table t_penalty_decrease as
select public.rpc_post_loan_obligation_correction(
  '92100000-0000-0000-0000-000000000001', :'loan_penalty_id'::uuid, 'LOAN_PENALTY', :'penalty_charge_id'::uuid,
  'CORRECTION_DECREASE', 10000, 'ASSESSMENT_ERROR', null, '2026-06-15'::date
) as result;
select is(
  (result->>'new_effective_amount')::numeric, 40000.00::numeric,
  '9: penalty correction decrease is unaffected (50,000 - 10,000 = 40,000)'
) from t_penalty_decrease;

-- Item 10: penalty correction increase frozen-policy bound unaffected
-- (Blocker-01: headroom is exactly 10,000 after the decrease above; an
-- increase beyond it is rejected, one within it succeeds).
select throws_ok(
  format(
    $sql$ select public.rpc_post_loan_obligation_correction('92100000-0000-0000-0000-000000000001', %L::uuid, 'LOAN_PENALTY', %L::uuid, 'CORRECTION_INCREASE', 10001, 'ASSESSMENT_ERROR', null, '2026-06-15'::date) $sql$,
    :'loan_penalty_id', :'penalty_charge_id'
  ),
  'P0001',
  'LOAN_CORRECTION_INCREASE_EXCEEDS_BOUND',
  '10a: penalty correction increase Blocker-01 bound still rejects beyond headroom'
);
create temporary table t_penalty_increase as
select public.rpc_post_loan_obligation_correction(
  '92100000-0000-0000-0000-000000000001', :'loan_penalty_id'::uuid, 'LOAN_PENALTY', :'penalty_charge_id'::uuid,
  'CORRECTION_INCREASE', 10000, 'ASSESSMENT_ERROR', null, '2026-06-15'::date
) as result;
select is(
  (result->>'new_effective_amount')::numeric, 50000.00::numeric,
  '10b: penalty correction increase within the Blocker-01 headroom still succeeds'
) from t_penalty_increase;

-- Item 11: MIGRATED/OPENING policy-unavailable behavior unaffected.
create temporary table t_migrated as
select public.rpc_create_migrated_loan(
  '92100000-0000-0000-0000-000000000001', '92200000-0000-0000-0000-000000000012'::uuid, :'product_penalty_id'::uuid,
  10000000, '2025-11-10'::date, '2026-05-31'::date,
  4000000,
  jsonb_build_array(jsonb_build_object(
    'due_date', '2026-05-01', 'principal_outstanding', 400000,
    'interest_outstanding', 80000, 'opening_penalty_outstanding', 20000
  )),
  600000, 4,
  p_next_due_date => '2026-06-01'::date
) as result;
select (result->>'id')::uuid as migrated_loan_id from t_migrated \gset
select id as migrated_installment_id from public.loan_installments
  where loan_account_id = :'migrated_loan_id'::uuid and installment_number = 1 \gset
select id as migrated_charge_id from public.loan_penalty_charges
  where loan_installment_id = :'migrated_installment_id'::uuid and origin = 'OPENING' \gset

select throws_ok(
  format(
    $sql$ select public.rpc_post_loan_obligation_correction('92100000-0000-0000-0000-000000000001', %L::uuid, 'LOAN_PENALTY', %L::uuid, 'CORRECTION_INCREASE', 1, 'ASSESSMENT_ERROR', null, '2026-06-15'::date) $sql$,
    :'migrated_loan_id', :'migrated_charge_id'
  ),
  'P0001',
  'LOAN_CORRECTION_INCREASE_POLICY_UNAVAILABLE',
  '11: MIGRATED/OPENING policy-unavailable behavior remains unaffected'
);

-- =======================================================================
-- Section 3 (items 14-15): entry_no generation and reversal/idempotency
-- regression remain intact after this migration.
-- =======================================================================

create temporary table t_loan_waiver as
select public.rpc_create_draft_loan_account(
  '92100000-0000-0000-0000-000000000001', '92200000-0000-0000-0000-000000000013'::uuid,
  :'product_penalty_id'::uuid, 500000, 1, '2026-05-15'::date
) as result;
select (result->>'id')::uuid as loan_waiver_id from t_loan_waiver \gset
select public.rpc_submit_loan_account('92100000-0000-0000-0000-000000000001', :'loan_waiver_id'::uuid);
select public.rpc_approve_loan_account('92100000-0000-0000-0000-000000000001', :'loan_waiver_id'::uuid);
select public.rpc_disburse_loan_account('92100000-0000-0000-0000-000000000001', :'loan_waiver_id'::uuid, :'account_id'::uuid, '2026-05-15'::date);
select id as waiver_installment_id from public.loan_installments where loan_account_id = :'loan_waiver_id'::uuid \gset

select public.rpc_assess_loan_penalties('92100000-0000-0000-0000-000000000001', '2026-06-15'::date, :'loan_waiver_id'::uuid);
select id as waiver_charge_id from public.loan_penalty_charges where loan_installment_id = :'waiver_installment_id'::uuid \gset

create temporary table t_waiver_1 as
select public.rpc_post_loan_obligation_waiver(
  '92100000-0000-0000-0000-000000000001', :'loan_waiver_id'::uuid, 'LOAN_PENALTY', :'waiver_charge_id'::uuid,
  10000, 'HARDSHIP', null, '2026-06-15'::date
) as result;
select (result->>'adjustment_id')::uuid as waiver_1_id from t_waiver_1 \gset

create temporary table t_waiver_2 as
select public.rpc_post_loan_obligation_waiver(
  '92100000-0000-0000-0000-000000000001', :'loan_waiver_id'::uuid, 'LOAN_PENALTY', :'waiver_charge_id'::uuid,
  10000, 'GOODWILL', null, '2026-06-15'::date
) as result;
select (result->>'adjustment_id')::uuid as waiver_2_id from t_waiver_2 \gset

reset role;
select entry_no as entry_no_1 from public.loan_obligation_adjustments where id = :'waiver_1_id'::uuid \gset
select entry_no as entry_no_2 from public.loan_obligation_adjustments where id = :'waiver_2_id'::uuid \gset
set local role authenticated;
set local request.jwt.claim.sub to '92000000-0000-0000-0000-000000000001';

select ok(
  :entry_no_1 is not null and :entry_no_2 is not null and :entry_no_2 > :entry_no_1,
  '14: authorized adjustment posting still generates a normal, monotonic entry_no after sequence hardening'
);

-- Item 15: reversal/idempotency regression.
select public.rpc_reverse_loan_obligation_adjustment('92100000-0000-0000-0000-000000000001', :'waiver_2_id'::uuid, 'no dependent activity');
select ok(
  (select count(*)::integer from public.loan_obligation_adjustments where reverses_adjustment_id = :'waiver_2_id'::uuid) = 1,
  '15a: reversal regression remains passing after this migration'
);

create temporary table t_idem_1 as
select public.rpc_post_loan_obligation_waiver(
  '92100000-0000-0000-0000-000000000001', :'loan_waiver_id'::uuid, 'LOAN_PENALTY', :'waiver_charge_id'::uuid,
  5000, 'HARDSHIP', null, '2026-06-15'::date, 'blocker02-idem-key-01'
) as result;
create temporary table t_idem_2 as
select public.rpc_post_loan_obligation_waiver(
  '92100000-0000-0000-0000-000000000001', :'loan_waiver_id'::uuid, 'LOAN_PENALTY', :'waiver_charge_id'::uuid,
  5000, 'HARDSHIP', null, '2026-06-15'::date, 'blocker02-idem-key-01'
) as result;
select is(
  (select (t_idem_1.result->>'adjustment_id')::uuid) = (select (t_idem_2.result->>'adjustment_id')::uuid),
  true,
  '15b: idempotency regression remains passing after this migration'
) from t_idem_1, t_idem_2;

select * from finish();
rollback;
