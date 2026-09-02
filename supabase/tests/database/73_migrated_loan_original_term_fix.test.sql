-- Prompt 09D-UAT-BLOCKER-04: fixes the physical-UAT bug where Simple
-- Import had no concept of the ORIGINAL LOAN TERM and therefore
-- redistributed the ENTIRE original principal/contracted interest
-- across only the remaining future installments whenever some
-- installments had already been settled before Umoja (section AA/T,
-- items 1-26). No-arrears worked case from section E/V: original
-- principal 20,000,000; contracted interest 2,008,000; original term
-- 12; contractual installment 1,834,000; 0 historical unpaid; 7
-- remaining future -> 5 paid-before-Umoja, every future installment
-- exactly 1,834,000, future total exactly 12,838,000.
begin;

select plan(28);

insert into auth.users (id, email) values
  ('7d000000-0000-0000-0000-000000000001', 'p09d-blocker4-term-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('7d100000-0000-0000-0000-000000000001', 'Original Term Fix Group', '7d000000-0000-0000-0000-000000000001', 'TERMF');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('7d200000-0000-0000-0000-000000000001', '7d100000-0000-0000-0000-000000000001', '7d000000-0000-0000-0000-000000000001', 'TF Admin', 'ACTIVE', '2025-01-01', 'TERMF-2026-0001'),
  ('7d200000-0000-0000-0000-000000000005', '7d100000-0000-0000-0000-000000000001', null, 'TF Borrower A (no-arrears)', 'ACTIVE', '2025-01-01', 'TERMF-2026-0005'),
  ('7d200000-0000-0000-0000-000000000006', '7d100000-0000-0000-0000-000000000001', null, 'TF Borrower B (5-arrears regression)', 'ACTIVE', '2025-01-01', 'TERMF-2026-0006'),
  ('7d200000-0000-0000-0000-000000000007', '7d100000-0000-0000-0000-000000000001', null, 'TF Borrower C (mixed)', 'ACTIVE', '2025-01-01', 'TERMF-2026-0007'),
  ('7d200000-0000-0000-0000-000000000008', '7d100000-0000-0000-0000-000000000001', null, 'TF Borrower D (final-adjustment)', 'ACTIVE', '2025-01-01', 'TERMF-2026-0008');

insert into public.group_membership_roles (group_membership_id, role_id) select '7d200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

insert into public.groups (id, name, created_by, code) values
  ('7d100000-0000-0000-0000-000000000002', 'Original Term Fix Other Group', '7d000000-0000-0000-0000-000000000001', 'TERMFB');
insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('7d200000-0000-0000-0000-000000000009', '7d100000-0000-0000-0000-000000000002', null, 'Other Group Borrower', 'ACTIVE', '2025-01-01', 'TERMFB-2026-0009');

set local role authenticated;
set local request.jwt.claim.sub to '7d000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '7d100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '7d100000-0000-0000-0000-000000000001', 'TERMPROD', 'Original Term Fix Product', 100000, 1, 24, 5.0, 'MONTHLY', 'FLAT'
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

-- ---------------------------------------------------------------------
-- 1: original_term is required in Simple mode.
-- ---------------------------------------------------------------------

select throws_ok(
  format($sql$ select public.rpc_create_migrated_loan(
    '7d100000-0000-0000-0000-000000000001'::uuid, %L::uuid, %L::uuid,
    20000000, '2026-03-29'::date, '2026-08-31'::date,
    0,
    p_remaining_installment_count => 7, p_next_due_date => '2026-09-27'::date,
    p_mode => 'SIMPLE', p_contracted_interest_amount => 2008000,
    p_monthly_installment_amount => 1834000, p_historical_unpaid_count => 0,
    p_total_historical_arrears => 0
  ) $sql$, '7d200000-0000-0000-0000-000000000005', :'product_id'),
  '22023',
  null,
  '1: original_term is required — omitting it is rejected'
);

-- ---------------------------------------------------------------------
-- 20/21: derived paid-before-Umoja count going negative (counts
-- exceeding the original term) is rejected.
-- ---------------------------------------------------------------------

select throws_ok(
  format($sql$ select public.rpc_create_migrated_loan(
    '7d100000-0000-0000-0000-000000000001'::uuid, %L::uuid, %L::uuid,
    20000000, '2026-03-29'::date, '2026-08-31'::date,
    0,
    p_remaining_installment_count => 7, p_next_due_date => '2026-09-27'::date,
    p_mode => 'SIMPLE', p_contracted_interest_amount => 2008000,
    p_monthly_installment_amount => 1834000, p_historical_unpaid_count => 5,
    p_total_historical_arrears => 9170000, p_original_term => 5
  ) $sql$, '7d200000-0000-0000-0000-000000000005', :'product_id'),
  '22023',
  null,
  '20/21: historical_unpaid_count (5) + remaining_future_count (7) exceeding original_term (5) is rejected — never a negative paid-before-Umoja count'
);

-- ---------------------------------------------------------------------
-- 3/4/5/6/7/25: the no-arrears worked case — preview first (writes
-- zero tables), then post.
-- ---------------------------------------------------------------------

select count(*) as loan_count_before from public.loan_accounts where group_id = '7d100000-0000-0000-0000-000000000001'::uuid \gset

create temporary table t_preview_a as
select public.rpc_preview_migrated_loan(
  '7d100000-0000-0000-0000-000000000001', '7d200000-0000-0000-0000-000000000005'::uuid, :'product_id'::uuid,
  20000000, '2026-08-31'::date,
  p_remaining_installment_count => 7, p_next_due_date => '2026-09-27'::date,
  p_mode => 'SIMPLE', p_contracted_interest_amount => 2008000,
  p_monthly_installment_amount => 1834000, p_historical_unpaid_count => 0,
  p_total_historical_arrears => 0, p_original_term => 12
) as result;

select is(
  (select (result->>'paid_before_umoja_count')::integer from t_preview_a),
  5,
  '3: 0 historical + 7 future out of a 12-installment original term derives exactly 5 paid-before-Umoja'
);
select is(
  (select jsonb_array_length(result->'future_installments') from t_preview_a),
  7,
  '4: the no-arrears preview returns exactly 7 future installments'
);
select is(
  (select count(*) from t_preview_a, jsonb_array_elements(result->'future_installments') a
   where (a->>'total_contractual_amount')::numeric <> 1834000.00),
  0::bigint,
  '5: every future installment is exactly 1,834,000 (2,008,000 interest reconciles exactly with 12 x 1,834,000 = 22,008,000)'
);
select is(
  (select (result->>'future_contractual_total')::numeric from t_preview_a),
  12838000.00::numeric,
  '6: future total previews as exactly 12,838,000 (7 x 1,834,000)'
);
select is(
  (select (result->>'opening_principal_outstanding')::numeric from t_preview_a),
  (select coalesce(sum((a->>'principal_outstanding')::numeric), 0) from t_preview_a, jsonb_array_elements(result->'future_installments') a),
  '7: opening funded principal receivable equals ONLY the future installments'' principal — never the full original principal'
);
select isnt(
  (select (result->>'opening_principal_outstanding')::numeric from t_preview_a),
  20000000.00::numeric,
  '7b: opening funded principal receivable is NOT 20,000,000 — the BLOCKER-03 bug is fixed'
);
select is(
  (select count(*) from public.loan_accounts where group_id = '7d100000-0000-0000-0000-000000000001'::uuid),
  :'loan_count_before'::bigint,
  '25: the preview created no persistent loan account'
);

reset role;
select public.financial_account_balance(:'account_id'::uuid) as cash_before \gset
set local role authenticated;
set local request.jwt.claim.sub to '7d000000-0000-0000-0000-000000000001';
select public.rpc_get_financial_position('7d100000-0000-0000-0000-000000000001') as fp_before \gset
select (public.rpc_get_financial_position('7d100000-0000-0000-0000-000000000001')->>'funded_loan_principal_receivable')::numeric as receivable_before \gset

create temporary table t_migrated_a as
select public.rpc_create_migrated_loan(
  '7d100000-0000-0000-0000-000000000001', '7d200000-0000-0000-0000-000000000005'::uuid, :'product_id'::uuid,
  20000000, '2026-03-29'::date, '2026-08-31'::date,
  0,
  p_remaining_installment_count => 7, p_next_due_date => '2026-09-27'::date,
  p_mode => 'SIMPLE', p_contracted_interest_amount => 2008000,
  p_monthly_installment_amount => 1834000, p_historical_unpaid_count => 0,
  p_total_historical_arrears => 0, p_original_term => 12
) as result;
select (result->>'id')::uuid as loan_a_id from t_migrated_a \gset

select is(
  (select count(*) from public.loan_installments where loan_account_id = :'loan_a_id'::uuid),
  7::bigint,
  '13/14: exactly 7 operational installment rows exist — no phantom rows for the 5 paid-before-Umoja installments, so none of them can ever become payable'
);
select is(
  (select opening_principal_outstanding from public.loan_opening_positions where loan_account_id = :'loan_a_id'::uuid),
  (select opening_principal_arrears + future_scheduled_principal from public.loan_opening_positions where loan_account_id = :'loan_a_id'::uuid),
  '7c: the persisted opening_principal_outstanding reconciles exactly (0 historical arrears + future principal only)'
);
select isnt(
  (select opening_principal_outstanding from public.loan_opening_positions where loan_account_id = :'loan_a_id'::uuid),
  20000000.00::numeric,
  '7d: the PERSISTED opening principal outstanding is also NOT 20,000,000'
);

-- ---------------------------------------------------------------------
-- 8/9/10/11/12: zero cashbook/income/expense/payment/receipt.
-- ---------------------------------------------------------------------

reset role;
select is(
  (public.financial_account_balance(:'account_id'::uuid)),
  :'cash_before'::numeric,
  '8: the no-arrears migration creates ZERO cashbook movement'
);
set local role authenticated;
set local request.jwt.claim.sub to '7d000000-0000-0000-0000-000000000001';
select is(
  (public.rpc_get_financial_position('7d100000-0000-0000-0000-000000000001')->>'group_income')::numeric,
  (:'fp_before'::jsonb->>'group_income')::numeric,
  '9: the no-arrears migration creates ZERO income'
);
select is(
  (public.rpc_get_financial_position('7d100000-0000-0000-0000-000000000001')->>'expenses')::numeric,
  (:'fp_before'::jsonb->>'expenses')::numeric,
  '10: the no-arrears migration creates ZERO expense'
);
select is(
  (select count(*) from public.payments where membership_id = '7d200000-0000-0000-0000-000000000005'::uuid),
  0::bigint,
  '11: no fake payment row is created'
);
select is(
  (select count(*) from public.financial_account_entries where source_type = 'PAYMENT'),
  0::bigint,
  '12: no fake receipt-generating cashbook entry is created'
);
select is(
  (select count(*) from public.payment_allocations where loan_account_id = :'loan_a_id'::uuid),
  0::bigint,
  '13b: no allocation exists for this freshly-migrated loan (nothing was ever paid, so certainly nothing for the paid-before-Umoja installments)'
);

-- ---------------------------------------------------------------------
-- 23: future installments remain excluded from ordinary allocation.
-- ---------------------------------------------------------------------

create temporary table t_preview_large as
select public.rpc_preview_payment_allocation(
  '7d100000-0000-0000-0000-000000000001', '7d200000-0000-0000-0000-000000000005'::uuid,
  :'account_id'::uuid, 5000000, '2026-09-01'::date
) as result;
select is(
  (select (result->>'total_allocated')::numeric from t_preview_large),
  0.00::numeric,
  '23: with zero historical arrears, nothing is allocatable yet — the future schedule remains excluded from ordinary auto-allocation regardless of payment size'
);

-- ---------------------------------------------------------------------
-- 15/16/17: the earlier 5-overdue + 7-future scenario still derives 0
-- paid-before-Umoja and still produces exactly 9,170,000 contractual
-- arrears / 324,606 legacy penalty.
-- ---------------------------------------------------------------------

create temporary table t_migrated_b as
select public.rpc_create_migrated_loan(
  '7d100000-0000-0000-0000-000000000001', '7d200000-0000-0000-0000-000000000006'::uuid, :'product_id'::uuid,
  20000000, '2026-03-29'::date, '2026-08-31'::date,
  0,
  p_remaining_installment_count => 7, p_next_due_date => '2026-09-27'::date,
  p_mode => 'SIMPLE', p_contracted_interest_amount => 2008000,
  p_monthly_installment_amount => 1834000, p_historical_unpaid_count => 5,
  p_total_historical_arrears => 9494606, p_original_term => 12
) as result;
select (result->>'id')::uuid as loan_b_id from t_migrated_b \gset

select is(
  (select count(*) from public.loan_installments where loan_account_id = :'loan_b_id'::uuid),
  12::bigint,
  '15: 5 overdue + 7 future out of a 12-installment term derives 0 paid-before-Umoja — all 12 installments are operational'
);
select is(
  (select opening_principal_arrears + opening_interest_arrears from public.loan_opening_positions where loan_account_id = :'loan_b_id'::uuid),
  9170000.00::numeric,
  '16: the earlier 9,170,000 contractual arrears case still passes'
);
select is(
  (select opening_penalty_arrears from public.loan_opening_positions where loan_account_id = :'loan_b_id'::uuid),
  324606.00::numeric,
  '17: the earlier 324,606 legacy penalty case still passes'
);

-- ---------------------------------------------------------------------
-- 18/19: mixed case — 3 paid-before-Umoja + 2 overdue + 7 future.
-- ---------------------------------------------------------------------

create temporary table t_migrated_c as
select public.rpc_create_migrated_loan(
  '7d100000-0000-0000-0000-000000000001', '7d200000-0000-0000-0000-000000000007'::uuid, :'product_id'::uuid,
  20000000, '2026-03-29'::date, '2026-08-31'::date,
  0,
  p_remaining_installment_count => 7, p_next_due_date => '2026-09-27'::date,
  p_mode => 'SIMPLE', p_contracted_interest_amount => 2008000,
  p_monthly_installment_amount => 1834000, p_historical_unpaid_count => 2,
  p_total_historical_arrears => 3668000, p_original_term => 12
) as result;
select (result->>'id')::uuid as loan_c_id from t_migrated_c \gset

select is(
  (select count(*) from public.loan_installments where loan_account_id = :'loan_c_id'::uuid),
  9::bigint,
  '18: 2 overdue + 7 future out of a 12-installment term derives 3 paid-before-Umoja — only 9 operational rows exist (2+7), never 12'
);
select is(
  (select array_agg(due_date order by installment_number) from public.loan_installments
   where loan_account_id = :'loan_c_id'::uuid and installment_number <= 2),
  array['2026-07-27', '2026-08-27']::date[],
  '19: the mixed case classifies oldest-first correctly — the 2 overdue installments are the ones immediately preceding the future schedule (27 Jul, 27 Aug), not months 1-2 of the original contract'
);

-- ---------------------------------------------------------------------
-- 22: final-installment adjustment — 20,000,000 principal + 2,000,000
-- interest over a 12-installment term at 1,834,000/installment does
-- NOT divide evenly (12 x 1,834,000 = 22,008,000 vs 22,000,000 contract
-- total): the first 11 installments stay exactly 1,834,000, and only
-- the 12th absorbs the exact 8,000 difference (1,826,000) — never a
-- repeated value like 1,832,857.xx.
-- ---------------------------------------------------------------------

create temporary table t_migrated_d as
select public.rpc_create_migrated_loan(
  '7d100000-0000-0000-0000-000000000001', '7d200000-0000-0000-0000-000000000008'::uuid, :'product_id'::uuid,
  20000000, '2026-03-29'::date, '2026-08-31'::date,
  0,
  p_remaining_installment_count => 12, p_next_due_date => '2026-09-27'::date,
  p_mode => 'SIMPLE', p_contracted_interest_amount => 2000000,
  p_monthly_installment_amount => 1834000, p_historical_unpaid_count => 0,
  p_total_historical_arrears => 0, p_original_term => 12
) as result;
select (result->>'id')::uuid as loan_d_id from t_migrated_d \gset

select is(
  (select count(*) from public.loan_installments
   where loan_account_id = :'loan_d_id'::uuid and installment_number <= 11
     and (principal_due + interest_due) <> 1834000.00),
  0::bigint,
  '22: the first 11 installments are each exactly 1,834,000'
);
select is(
  (select principal_due + interest_due from public.loan_installments
   where loan_account_id = :'loan_d_id'::uuid and installment_number = 12),
  1826000.00::numeric,
  '22b: the 12th (final) installment absorbs the exact 8,000 reconciliation difference (1,826,000), never a repeated 1,832,857.xx-style value'
);

-- ---------------------------------------------------------------------
-- 24: group isolation preserved under the new p_original_term param.
-- ---------------------------------------------------------------------

select throws_ok(
  format($sql$ select public.rpc_create_migrated_loan(
    '7d100000-0000-0000-0000-000000000001'::uuid, %L::uuid, %L::uuid,
    20000000, '2026-03-29'::date, '2026-08-31'::date,
    0,
    p_remaining_installment_count => 7, p_next_due_date => '2026-09-27'::date,
    p_mode => 'SIMPLE', p_contracted_interest_amount => 2008000,
    p_monthly_installment_amount => 1834000, p_historical_unpaid_count => 0,
    p_total_historical_arrears => 0, p_original_term => 12
  ) $sql$, '7d200000-0000-0000-0000-000000000009', :'product_id'),
  '22023',
  null,
  '24: a membership belonging to a DIFFERENT group is rejected under the fixed Simple mode too'
);

-- ---------------------------------------------------------------------
-- 26: create recomputes server-authoritatively — posting with
-- DIFFERENT counts than an earlier preview never reuses the stale
-- preview's paid_before_umoja_count/opening_principal_outstanding.
-- ---------------------------------------------------------------------

create temporary table t_preview_e as
select public.rpc_preview_migrated_loan(
  '7d100000-0000-0000-0000-000000000001', '7d200000-0000-0000-0000-000000000005'::uuid, :'product_id'::uuid,
  20000000, '2026-08-31'::date,
  p_remaining_installment_count => 5, p_next_due_date => '2026-09-27'::date,
  p_mode => 'SIMPLE', p_contracted_interest_amount => 2008000,
  p_monthly_installment_amount => 1834000, p_historical_unpaid_count => 0,
  p_total_historical_arrears => 0, p_original_term => 12
) as result;

select is(
  (select (result->>'paid_before_umoja_count')::integer from t_preview_e),
  7,
  '26: a preview with a DIFFERENT remaining-future count (5 instead of 7) derives its own paid-before-Umoja count (7), never a cached value from an earlier preview/create call'
);

select * from finish();
rollback;
