-- Prompt 09D-UAT-BLOCKER-03: SIMPLE Import + server-authoritative
-- PREVIEW (sections AA/AB, items 1-27). Real scenario from section B:
-- original principal 20,000,000; contracted interest 2,000,000;
-- monthly installment 1,834,000; 5 historical unpaid installments;
-- total historical arrears (old records) 9,494,606 -> contractual
-- 9,170,000 + legacy penalty 324,606; 7 future installments; next due
-- 27 Sep 2026; original loan date 29 Mar 2026; opening as-of 31 Aug
-- 2026; 3% RECURRING_MONTHLY penalty policy.
begin;

select plan(28);

insert into auth.users (id, email) values
  ('7b000000-0000-0000-0000-000000000001', 'p09d-blocker3-simple-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('7b100000-0000-0000-0000-000000000001', 'Simple Import Group', '7b000000-0000-0000-0000-000000000001', 'SIMP');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('7b200000-0000-0000-0000-000000000001', '7b100000-0000-0000-0000-000000000001', '7b000000-0000-0000-0000-000000000001', 'SI Admin', 'ACTIVE', '2025-01-01', 'SIMP-2026-0001'),
  ('7b200000-0000-0000-0000-000000000005', '7b100000-0000-0000-0000-000000000001', null, 'SI Borrower A (real scenario)', 'ACTIVE', '2025-01-01', 'SIMP-2026-0005'),
  ('7b200000-0000-0000-0000-000000000006', '7b100000-0000-0000-0000-000000000001', null, 'SI Borrower B (zero arrears)', 'ACTIVE', '2025-01-01', 'SIMP-2026-0006'),
  ('7b200000-0000-0000-0000-000000000007', '7b100000-0000-0000-0000-000000000001', null, 'SI Borrower C (idempotency)', 'ACTIVE', '2025-01-01', 'SIMP-2026-0007');

insert into public.group_membership_roles (group_membership_id, role_id) select '7b200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

insert into public.groups (id, name, created_by, code) values
  ('7b100000-0000-0000-0000-000000000002', 'Simple Import Other Group', '7b000000-0000-0000-0000-000000000001', 'SIMPB');
insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('7b200000-0000-0000-0000-000000000008', '7b100000-0000-0000-0000-000000000002', null, 'Other Group Borrower', 'ACTIVE', '2025-01-01', 'SIMPB-2026-0008');

set local role authenticated;
set local request.jwt.claim.sub to '7b000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '7b100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '7b100000-0000-0000-0000-000000000001', 'SIMPPROD', 'Simple Import Product', 100000, 1, 24, 5.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'PERCENTAGE', p_penalty_frequency => 'RECURRING_MONTHLY',
  p_penalty_grace_days => 0, p_penalty_rate => 3.0
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

-- ---------------------------------------------------------------------
-- 15: total arrears below the derived contractual arrears is rejected
-- BEFORE we post the real scenario (proves the guard fires first).
-- ---------------------------------------------------------------------

select throws_ok(
  format($sql$ select public.rpc_create_migrated_loan(
    '7b100000-0000-0000-0000-000000000001'::uuid, %L::uuid, %L::uuid,
    20000000, '2026-03-29'::date, '2026-08-31'::date,
    0,
    p_remaining_installment_count => 7, p_next_due_date => '2026-09-27'::date,
    p_mode => 'SIMPLE', p_contracted_interest_amount => 2000000,
    p_monthly_installment_amount => 1834000, p_historical_unpaid_count => 5,
    p_total_historical_arrears => 9000000, p_original_term => 12
  ) $sql$, '7b200000-0000-0000-0000-000000000005', :'product_id'),
  '22023',
  null,
  '15: total_historical_arrears (9,000,000) below the derived contractual arrears (9,170,000) is rejected'
);

-- ---------------------------------------------------------------------
-- 2-14: post the real scenario via SIMPLE mode.
-- ---------------------------------------------------------------------

reset role;
select public.financial_account_balance(:'account_id'::uuid) as cash_before \gset
set local role authenticated;
set local request.jwt.claim.sub to '7b000000-0000-0000-0000-000000000001';
select (public.rpc_get_financial_position('7b100000-0000-0000-0000-000000000001')->>'funded_loan_principal_receivable')::numeric as receivable_before \gset
select public.rpc_get_financial_position('7b100000-0000-0000-0000-000000000001') as fp_before \gset

create temporary table t_migrated_a as
select public.rpc_create_migrated_loan(
  '7b100000-0000-0000-0000-000000000001', '7b200000-0000-0000-0000-000000000005'::uuid, :'product_id'::uuid,
  20000000, '2026-03-29'::date, '2026-08-31'::date,
  0,
  p_remaining_installment_count => 7, p_next_due_date => '2026-09-27'::date,
  p_mode => 'SIMPLE', p_contracted_interest_amount => 2000000,
  p_monthly_installment_amount => 1834000, p_historical_unpaid_count => 5,
  p_total_historical_arrears => 9494606, p_original_term => 12
) as result;
select (result->>'id')::uuid as loan_a_id from t_migrated_a \gset

select is(
  (select count(*) from public.loan_installments where loan_account_id = :'loan_a_id'::uuid and installment_number <= 5),
  5::bigint,
  '2: Simple Import with 5 historical unpaid installments creates exactly 5 historical rows'
);
select is(
  (select opening_principal_arrears + opening_interest_arrears from public.loan_opening_positions where loan_account_id = :'loan_a_id'::uuid),
  9170000.00::numeric,
  '3: contractual historical arrears derives exactly 9,170,000 (5 x 1,834,000)'
);
select is(
  (select opening_penalty_arrears from public.loan_opening_positions where loan_account_id = :'loan_a_id'::uuid),
  324606.00::numeric,
  '4: total historical arrears 9,494,606 derives legacy penalty exactly 324,606'
);
select is(
  (select coalesce(sum(penalty_amount), 0) from public.loan_penalty_charges
   where loan_account_id = :'loan_a_id'::uuid and origin = 'OPENING'),
  324606.00::numeric,
  '5: the opening penalty distribution across the 5 installments sums exactly to 324,606'
);
select is(
  (select count(*) from public.loan_penalty_charges where loan_account_id = :'loan_a_id'::uuid and origin <> 'OPENING'),
  0::bigint,
  '6: every penalty charge generated by Simple Import carries origin = OPENING, never ASSESSED'
);
select is(
  (select array_agg(due_date order by installment_number) from public.loan_installments where loan_account_id = :'loan_a_id'::uuid and installment_number <= 5),
  array['2026-04-27', '2026-05-27', '2026-06-27', '2026-07-27', '2026-08-27']::date[],
  '7: the five historical installments retain their real, individually-anchored due dates'
);
select is(
  (select count(*) from public.loan_installments where loan_account_id = :'loan_a_id'::uuid and installment_number > 5),
  7::bigint,
  '8: seven future installments are generated'
);
select is(
  (select due_date from public.loan_installments where loan_account_id = :'loan_a_id'::uuid and installment_number = 6),
  '2026-09-27'::date,
  '10: the next future installment is due exactly 27 Sep 2026'
);

reset role;
select is(
  (public.financial_account_balance(:'account_id'::uuid)),
  :'cash_before'::numeric,
  '11: Simple Import migration creates ZERO cashbook movement'
);
set local role authenticated;
set local request.jwt.claim.sub to '7b000000-0000-0000-0000-000000000001';
select is(
  (public.rpc_get_financial_position('7b100000-0000-0000-0000-000000000001')->>'group_income')::numeric,
  (:'fp_before'::jsonb->>'group_income')::numeric,
  '12: Simple Import migration creates ZERO income'
);
select is(
  (public.rpc_get_financial_position('7b100000-0000-0000-0000-000000000001')->>'expenses')::numeric,
  (:'fp_before'::jsonb->>'expenses')::numeric,
  '13: Simple Import migration creates ZERO expense'
);
select is(
  (public.rpc_get_financial_position('7b100000-0000-0000-0000-000000000001')->>'funded_loan_principal_receivable')::numeric,
  (:'receivable_before'::numeric + 20000000.00),
  '14: funded principal receivable increases by exactly the original principal (20,000,000) — nothing has ever been repaid'
);

-- ---------------------------------------------------------------------
-- 9: the "future contractual total" (informational, 7 x 1,834,000 =
-- 12,838,000) is exposed via the preview — distinct from, and never
-- confused with, the exact accounting future_scheduled_principal/
-- interest split that actually gets persisted.
-- ---------------------------------------------------------------------

create temporary table t_preview_a as
select public.rpc_preview_migrated_loan(
  '7b100000-0000-0000-0000-000000000001', '7b200000-0000-0000-0000-000000000005'::uuid, :'product_id'::uuid,
  20000000, '2026-08-31'::date,
  p_remaining_installment_count => 7, p_next_due_date => '2026-09-27'::date,
  p_mode => 'SIMPLE', p_contracted_interest_amount => 2000000,
  p_monthly_installment_amount => 1834000, p_historical_unpaid_count => 5,
  p_total_historical_arrears => 9494606, p_original_term => 12
) as result;

select is(
  (select (result->>'future_contractual_total')::numeric from t_preview_a),
  12838000.00::numeric,
  '9: the future contractual total (7 x 1,834,000) previews as exactly 12,838,000'
);

-- ---------------------------------------------------------------------
-- 18-25: the preview above touched ZERO tables.
-- ---------------------------------------------------------------------

select is(
  (select count(*) from public.loan_accounts where membership_id = '7b200000-0000-0000-0000-000000000005'::uuid),
  1::bigint,
  '18: the preview created no SECOND persistent loan (still only the one posted in test 2)'
);
select is(
  (select count(*) from public.loan_opening_positions where loan_account_id <> :'loan_a_id'::uuid and group_id = '7b100000-0000-0000-0000-000000000001'::uuid),
  0::bigint,
  '19: the preview created no opening position row'
);
select is(
  (select count(*) from public.loan_installments where loan_account_id <> :'loan_a_id'::uuid and group_id = '7b100000-0000-0000-0000-000000000001'::uuid),
  0::bigint,
  '20: the preview created no installment rows'
);
select is(
  (select count(*) from public.loan_penalty_charges where loan_account_id <> :'loan_a_id'::uuid and group_id = '7b100000-0000-0000-0000-000000000001'::uuid),
  0::bigint,
  '21: the preview created no penalty charge rows'
);
reset role;
select is(
  (public.financial_account_balance(:'account_id'::uuid)),
  :'cash_before'::numeric,
  '22: the preview created no cashbook entries'
);
set local role authenticated;
set local request.jwt.claim.sub to '7b000000-0000-0000-0000-000000000001';
select is(
  (select jsonb_array_length(result->'historical_installments') from t_preview_a),
  5,
  '23: the preview returns the full 5-installment historical schedule'
);
select is(
  (select jsonb_array_length(result->'future_installments') from t_preview_a),
  7,
  '24: the preview returns the full 7-installment future schedule'
);
select is(
  (select jsonb_build_array(
     result->'accounting_impact'->>'cashbook_impact',
     result->'accounting_impact'->>'income_recognized_now',
     result->'accounting_impact'->>'expense_recognized_now'
   ) from t_preview_a),
  '["0", "0", "0"]'::jsonb,
  '25: the preview accounting impact is zero cashbook/income/expense'
);

-- ---------------------------------------------------------------------
-- 26: create recomputes authoritative values — posting a DIFFERENT
-- total_historical_arrears than the earlier preview used produces a
-- loan reflecting the NEW figures, never the stale preview's.
-- ---------------------------------------------------------------------

create temporary table t_migrated_c as
select public.rpc_create_migrated_loan(
  '7b100000-0000-0000-0000-000000000001', '7b200000-0000-0000-0000-000000000007'::uuid, :'product_id'::uuid,
  20000000, '2026-03-29'::date, '2026-08-31'::date,
  0,
  p_remaining_installment_count => 7, p_next_due_date => '2026-09-27'::date,
  p_mode => 'SIMPLE', p_contracted_interest_amount => 2000000,
  p_monthly_installment_amount => 1834000, p_historical_unpaid_count => 5,
  p_total_historical_arrears => 9300000, p_original_term => 12
) as result;
select (result->>'id')::uuid as loan_c_id from t_migrated_c \gset

select is(
  (select opening_penalty_arrears from public.loan_opening_positions where loan_account_id = :'loan_c_id'::uuid),
  130000.00::numeric,
  '26: posting with a DIFFERENT total_historical_arrears (9,300,000) than the earlier preview (9,494,606) recomputes its own legacy penalty (130,000), never reusing the stale preview'
);

-- ---------------------------------------------------------------------
-- 27: a garbage/stale p_opening_principal_outstanding passed alongside
-- SIMPLE-mode inputs is ignored — the server always overrides it with
-- the authoritative original_principal.
-- ---------------------------------------------------------------------

select is(
  (select opening_principal_outstanding from public.loan_opening_positions where loan_account_id = :'loan_c_id'::uuid),
  20000000.00::numeric,
  '27: the server-recomputed opening_principal_outstanding (20,000,000) is used — the caller-supplied placeholder value (0) passed for that parameter is never trusted in SIMPLE mode'
);

-- ---------------------------------------------------------------------
-- 1: zero-arrears Simple Import remains valid (all-future).
-- ---------------------------------------------------------------------

create temporary table t_migrated_b as
select public.rpc_create_migrated_loan(
  '7b100000-0000-0000-0000-000000000001', '7b200000-0000-0000-0000-000000000006'::uuid, :'product_id'::uuid,
  20000000, '2026-03-29'::date, '2026-08-31'::date,
  0,
  p_remaining_installment_count => 12, p_next_due_date => '2026-09-27'::date,
  p_mode => 'SIMPLE', p_contracted_interest_amount => 2000000,
  p_monthly_installment_amount => 1834000, p_historical_unpaid_count => 0,
  p_total_historical_arrears => 0, p_original_term => 12
) as result;
select (result->>'id')::uuid as loan_b_id from t_migrated_b \gset

select is(
  (select count(*) from public.loan_installments where loan_account_id = :'loan_b_id'::uuid),
  12::bigint,
  '1: a zero-historical-arrears Simple Import loan is accepted, with all 12 installments future'
);
select is(
  (select count(*) from public.loan_penalty_charges where loan_account_id = :'loan_b_id'::uuid),
  0::bigint,
  '1b: a zero-historical-arrears Simple Import creates zero opening penalty charges'
);

-- ---------------------------------------------------------------------
-- 16: idempotency — retrying with the same key creates exactly one loan.
-- ---------------------------------------------------------------------

create temporary table t_migrated_idem_1 as
select public.rpc_create_migrated_loan(
  '7b100000-0000-0000-0000-000000000001', '7b200000-0000-0000-0000-000000000006'::uuid, :'product_id'::uuid,
  1000000, '2026-03-29'::date, '2026-08-31'::date,
  0,
  p_remaining_installment_count => 2, p_next_due_date => '2026-09-27'::date,
  p_original_loan_number => null, p_notes => null, p_idempotency_key => 'simple-idem-001',
  p_mode => 'SIMPLE', p_contracted_interest_amount => 100000,
  p_monthly_installment_amount => 100000, p_historical_unpaid_count => 1,
  p_total_historical_arrears => 100000, p_original_term => 3
) as result;
select (result->>'id')::uuid as loan_idem_id from t_migrated_idem_1 \gset

create temporary table t_migrated_idem_2 as
select public.rpc_create_migrated_loan(
  '7b100000-0000-0000-0000-000000000001', '7b200000-0000-0000-0000-000000000006'::uuid, :'product_id'::uuid,
  1000000, '2026-03-29'::date, '2026-08-31'::date,
  0,
  p_remaining_installment_count => 2, p_next_due_date => '2026-09-27'::date,
  p_original_loan_number => null, p_notes => null, p_idempotency_key => 'simple-idem-001',
  p_mode => 'SIMPLE', p_contracted_interest_amount => 100000,
  p_monthly_installment_amount => 100000, p_historical_unpaid_count => 1,
  p_total_historical_arrears => 100000, p_original_term => 3
) as result;

select is(
  (select (result->>'id')::uuid from t_migrated_idem_2),
  :'loan_idem_id'::uuid,
  '16: retrying a Simple Import with the same idempotency key returns the already-created loan, never a second one'
);

-- ---------------------------------------------------------------------
-- 17: group isolation — a cross-group membership is rejected under
-- Simple mode exactly like Detailed mode (same early validation path).
-- ---------------------------------------------------------------------

select throws_ok(
  format($sql$ select public.rpc_create_migrated_loan(
    '7b100000-0000-0000-0000-000000000001'::uuid, %L::uuid, %L::uuid,
    1000000, '2026-03-29'::date, '2026-08-31'::date,
    0,
    p_remaining_installment_count => 2, p_next_due_date => '2026-09-27'::date,
    p_mode => 'SIMPLE', p_contracted_interest_amount => 100000,
    p_monthly_installment_amount => 100000, p_historical_unpaid_count => 1,
    p_total_historical_arrears => 100000, p_original_term => 3
  ) $sql$, '7b200000-0000-0000-0000-000000000008', :'product_id'),
  '22023',
  null,
  '17: a membership belonging to a DIFFERENT group is rejected under Simple mode too'
);

select * from finish();
rollback;
