-- Prompt 09D-UAT-BLOCKER-02: MULTIPLE HISTORICAL ARREARS INSTALLMENTS —
-- data model, reconciliation, and allocation ordering (sections 33/34,
-- items 1-17). Core proof: a migrated loan's historical overdue debt is
-- preserved as N SEPARATE loan_installments rows (never one synthetic
-- combined arrears row), each with its own due date, and the existing
-- Payment Engine settles them oldest-due-first, PENALTY -> INTEREST ->
-- PRINCIPAL within each, with the future schedule structurally excluded
-- throughout — reproducing section 13's exact worked example (June
-- 1,300,000 fully settled + July penalty 90,000 + partial interest
-- 110,000 = 1,500,000, nothing to August or beyond).
begin;

select plan(26);

insert into auth.users (id, email) values
  ('78000000-0000-0000-0000-000000000001', 'p09d-blocker2-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('78100000-0000-0000-0000-000000000001', 'Migrated Multi Arrears Group', '78000000-0000-0000-0000-000000000001', 'MIGM');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('78200000-0000-0000-0000-000000000001', '78100000-0000-0000-0000-000000000001', '78000000-0000-0000-0000-000000000001', 'MM Admin', 'ACTIVE', '2025-01-01', 'MIGM-2026-0001'),
  ('78200000-0000-0000-0000-000000000005', '78100000-0000-0000-0000-000000000001', null, 'MM Borrower A (cash)', 'ACTIVE', '2025-01-01', 'MIGM-2026-0005'),
  ('78200000-0000-0000-0000-000000000006', '78100000-0000-0000-0000-000000000001', null, 'MM Borrower B (wallet)', 'ACTIVE', '2025-01-01', 'MIGM-2026-0006'),
  ('78200000-0000-0000-0000-000000000007', '78100000-0000-0000-0000-000000000001', null, 'MM Borrower C (single row)', 'ACTIVE', '2025-01-01', 'MIGM-2026-0007'),
  ('78200000-0000-0000-0000-000000000008', '78100000-0000-0000-0000-000000000001', null, 'MM Borrower D (future only)', 'ACTIVE', '2025-01-01', 'MIGM-2026-0008');

insert into public.group_membership_roles (group_membership_id, role_id) select '78200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '78000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '78100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '78100000-0000-0000-0000-000000000001', 'MIGMPROD', 'Migration Multi Product', 100000, 1, 24, 5.0, 'MONTHLY', 'FLAT'
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

-- ---------------------------------------------------------------------
-- 1: zero historical arrears is valid — all-future migrated loan.
-- ---------------------------------------------------------------------

create temporary table t_loan_d as
select public.rpc_create_migrated_loan(
  '78100000-0000-0000-0000-000000000001', '78200000-0000-0000-0000-000000000008'::uuid, :'product_id'::uuid,
  2000000, '2026-03-10'::date, '2026-08-31'::date,
  2000000, '[]'::jsonb, 100000, 2,
  p_next_due_date => '2026-09-27'::date
) as result;
select (result->>'id')::uuid as loan_d_id from t_loan_d \gset

select is(
  (select count(*) from public.loan_installments where loan_account_id = :'loan_d_id'::uuid and due_date <= '2026-08-31'::date),
  0::bigint,
  '1: a migrated loan with zero historical arrears (all installments future) is accepted'
);
select is(
  (select count(*) from public.loan_installments where loan_account_id = :'loan_d_id'::uuid),
  2::bigint,
  '1b: the future-only schedule still creates exactly its 2 remaining installments'
);

-- ---------------------------------------------------------------------
-- 2: exactly one historical arrears installment is valid (regression).
-- ---------------------------------------------------------------------

create temporary table t_loan_c as
select public.rpc_create_migrated_loan(
  '78100000-0000-0000-0000-000000000001', '78200000-0000-0000-0000-000000000007'::uuid, :'product_id'::uuid,
  500000, '2025-06-10'::date, '2026-08-31'::date,
  100000,
  jsonb_build_array(jsonb_build_object(
    'due_date', '2026-08-01', 'principal_outstanding', 100000,
    'interest_outstanding', 5000, 'opening_penalty_outstanding', 0
  )),
  0, 0
) as result;
select (result->>'id')::uuid as loan_c_id from t_loan_c \gset

select is(
  (select count(*) from public.loan_installments where loan_account_id = :'loan_c_id'::uuid),
  1::bigint,
  '2: a migrated loan with exactly one historical arrears installment is accepted'
);

-- ---------------------------------------------------------------------
-- 3-8/10: THREE separate historical overdue installments + a future
-- one, never collapsed. June 27 / July 27 / August 27 arrears, each
-- with its own principal/interest/penalty; a 4th future installment
-- due 27 Sep.
-- ---------------------------------------------------------------------

create temporary table t_loan_a as
select public.rpc_create_migrated_loan(
  '78100000-0000-0000-0000-000000000001', '78200000-0000-0000-0000-000000000005'::uuid, :'product_id'::uuid,
  5000000, '2025-06-10'::date, '2026-08-31'::date,
  3500000,
  jsonb_build_array(
    jsonb_build_object('due_date', '2026-06-27', 'principal_outstanding', 1000000, 'interest_outstanding', 200000, 'opening_penalty_outstanding', 100000),
    jsonb_build_object('due_date', '2026-07-27', 'principal_outstanding', 1000000, 'interest_outstanding', 200000, 'opening_penalty_outstanding', 90000),
    jsonb_build_object('due_date', '2026-08-27', 'principal_outstanding', 1000000, 'interest_outstanding', 200000, 'opening_penalty_outstanding', 80000)
  ),
  50000, 1,
  p_next_due_date => '2026-09-27'::date
) as result;
select (result->>'id')::uuid as loan_a_id from t_loan_a \gset

select id as inst1_id from public.loan_installments where loan_account_id = :'loan_a_id'::uuid and installment_number = 1 \gset
select id as inst2_id from public.loan_installments where loan_account_id = :'loan_a_id'::uuid and installment_number = 2 \gset
select id as inst3_id from public.loan_installments where loan_account_id = :'loan_a_id'::uuid and installment_number = 3 \gset
select id as inst4_id from public.loan_installments where loan_account_id = :'loan_a_id'::uuid and installment_number = 4 \gset

select is(
  (select count(*) from public.loan_installments where loan_account_id = :'loan_a_id'::uuid and installment_number <= 3),
  3::bigint,
  '3: three historical overdue installments are each preserved as their own row'
);
select is(
  (select array_agg(due_date order by installment_number) from public.loan_installments where loan_account_id = :'loan_a_id'::uuid and installment_number <= 3),
  array['2026-06-27', '2026-07-27', '2026-08-27']::date[],
  '4: each historical installment keeps its own real due date, in order'
);
select is(
  (select opening_principal_arrears from public.loan_opening_positions where loan_account_id = :'loan_a_id'::uuid),
  3000000.00::numeric,
  '5: opening_principal_arrears is derived as the sum of the 3 historical rows'' principal (1,000,000 x 3)'
);
select is(
  (select opening_interest_arrears from public.loan_opening_positions where loan_account_id = :'loan_a_id'::uuid),
  600000.00::numeric,
  '6: opening_interest_arrears is derived as the sum of the 3 historical rows'' interest (200,000 x 3)'
);
select is(
  (select opening_penalty_arrears from public.loan_opening_positions where loan_account_id = :'loan_a_id'::uuid),
  270000.00::numeric,
  '7: opening_penalty_arrears is derived as the sum of the 3 historical rows'' opening penalty (100,000+90,000+80,000)'
);
select is(
  (select opening_principal_arrears + opening_interest_arrears + opening_penalty_arrears
   from public.loan_opening_positions where loan_account_id = :'loan_a_id'::uuid),
  3870000.00::numeric,
  '8: total historical arrears (principal+interest+penalty) is exactly 3,870,000'
);
select is(
  (select due_date from public.loan_installments where id = :'inst4_id'::uuid),
  '2026-09-27'::date,
  '10: the future installment keeps its own due date, strictly after every historical due date'
);
select is(
  (select principal_due from public.loan_installments where id = :'inst4_id'::uuid),
  500000.00::numeric,
  '10b: the future installment carries exactly the derived future_scheduled_principal (3,500,000 - 3,000,000), never mixed with historical arrears'
);

-- ---------------------------------------------------------------------
-- 9: two historical rows sharing the same due date are rejected.
-- ---------------------------------------------------------------------

select throws_ok(
  format($sql$ select public.rpc_create_migrated_loan(
    '78100000-0000-0000-0000-000000000001'::uuid, %L::uuid, %L::uuid,
    1000000, '2025-06-10'::date, '2026-08-31'::date,
    200000,
    jsonb_build_array(
      jsonb_build_object('due_date', '2026-06-27', 'principal_outstanding', 100000, 'interest_outstanding', 10000, 'opening_penalty_outstanding', 0),
      jsonb_build_object('due_date', '2026-06-27', 'principal_outstanding', 100000, 'interest_outstanding', 10000, 'opening_penalty_outstanding', 0)
    ),
    0, 0
  ) $sql$, '78200000-0000-0000-0000-000000000005', :'product_id'),
  '22023',
  null,
  '9: two historical rows sharing the same due date are rejected'
);

-- ---------------------------------------------------------------------
-- 11/12: a 1,500,000 preview settles June (penalty/interest/principal)
-- first, in the locked priority order.
-- ---------------------------------------------------------------------

create temporary table t_preview_a as
select public.rpc_preview_payment_allocation(
  '78100000-0000-0000-0000-000000000001', '78200000-0000-0000-0000-000000000005'::uuid,
  :'account_id'::uuid, 1500000, '2026-09-01'::date
) as result;

select is(
  (select result->'allocations'->0->>'loan_installment_id' from t_preview_a),
  :'inst1_id'::text,
  '11: the oldest historical installment (June) is allocated first'
);
select is(
  (select jsonb_build_array(
     result->'allocations'->0->>'obligation_kind',
     result->'allocations'->1->>'obligation_kind',
     result->'allocations'->2->>'obligation_kind'
   ) from t_preview_a),
  '["LOAN_PENALTY", "LOAN_INTEREST", "LOAN_PRINCIPAL"]'::jsonb,
  '12: within June, allocation still follows PENALTY -> INTEREST -> PRINCIPAL'
);

-- ---------------------------------------------------------------------
-- 13/14: July receives only the 200,000 remainder (penalty 90,000 +
-- PARTIAL interest 110,000 of its 200,000 due) — August is completely
-- untouched.
-- ---------------------------------------------------------------------

select is(
  (select result->'allocations'->3->>'loan_installment_id' from t_preview_a),
  :'inst2_id'::text,
  '13: after June is exhausted, allocation moves to July (the second historical installment)'
);
select is(
  (select (result->'allocations'->4->>'allocate_amount')::numeric from t_preview_a),
  110000.00::numeric,
  '13b: July receives only a PARTIAL interest allocation (110,000 of 200,000 due) — exactly the remainder of the 1,500,000 payment'
);
select is(
  (select jsonb_array_length(result->'allocations') from t_preview_a),
  5,
  'setup: exactly 5 allocation lines are produced (June x3 + July x2)'
);
select is(
  (select count(*) from t_preview_a, jsonb_array_elements(result->'allocations') a
   where a->>'loan_installment_id' = :'inst3_id'::text),
  0::bigint,
  '14: August (the third historical installment) is completely untouched until June and July are settled'
);

-- ---------------------------------------------------------------------
-- 15: the future installment is structurally excluded from ordinary
-- auto-allocation, however large the payment.
-- ---------------------------------------------------------------------

create temporary table t_preview_large as
select public.rpc_preview_payment_allocation(
  '78100000-0000-0000-0000-000000000001', '78200000-0000-0000-0000-000000000005'::uuid,
  :'account_id'::uuid, 10000000, '2026-09-01'::date
) as result;

select is(
  (select count(*) from t_preview_large, jsonb_array_elements(result->'allocations') a
   where a->>'loan_installment_id' = :'inst4_id'::text),
  0::bigint,
  '15: even with ample funds (10,000,000), the future installment is never touched by ordinary auto-allocation'
);
select is(
  (select (result->>'total_allocated')::numeric from t_preview_large),
  3870000.00::numeric,
  '15b: total_allocated caps at exactly the 3 historical installments'' total (3,870,000) — the rest becomes wallet credit, never a future prepayment'
);

-- ---------------------------------------------------------------------
-- 17: posting the payment preserves per-installment identity in the
-- receipt/payment-detail read model.
-- ---------------------------------------------------------------------

create temporary table t_post_a as
select public.rpc_post_payment(
  '78100000-0000-0000-0000-000000000001', '78200000-0000-0000-0000-000000000005'::uuid, :'account_id'::uuid,
  1500000, '2026-09-01'::date, 'CASH'
) as result;
select (result->>'payment_id')::uuid as payment_a_id from t_post_a \gset

create temporary table t_detail_a as
select public.rpc_get_payment_detail('78100000-0000-0000-0000-000000000001', :'payment_a_id'::uuid) as result;

select is(
  (select jsonb_build_array(
     result->'allocations'->0->>'installment_number',
     result->'allocations'->0->>'due_date'
   ) from t_detail_a),
  jsonb_build_array('1', '2026-06-27'),
  '17: the first allocation line still identifies its exact installment (number 1, due 27 Jun) — never a generic loan line'
);
select is(
  (select jsonb_build_array(
     result->'allocations'->3->>'installment_number',
     result->'allocations'->3->>'due_date'
   ) from t_detail_a),
  jsonb_build_array('2', '2026-07-27'),
  '17b: the July allocation lines identify installment 2 (due 27 Jul), distinct from June'
);

-- ---------------------------------------------------------------------
-- 16: wallet settlement follows the SAME oldest-first, PENALTY ->
-- INTEREST -> PRINCIPAL ordering. Borrower B seeds a 50,000 wallet
-- credit BEFORE loan B's arrears even exist (a small unrelated loan is
-- overpaid by 50,000), then loan B is created and the wallet applied —
-- it settles July's penalty (20,000) + interest (30,000) exactly,
-- leaving July principal and all of August untouched.
-- ---------------------------------------------------------------------

create temporary table t_loan_b_seed as
select public.rpc_create_migrated_loan(
  '78100000-0000-0000-0000-000000000001', '78200000-0000-0000-0000-000000000006'::uuid, :'product_id'::uuid,
  100000, '2025-06-10'::date, '2026-08-31'::date,
  100000,
  jsonb_build_array(jsonb_build_object(
    'due_date', '2026-08-01', 'principal_outstanding', 100000,
    'interest_outstanding', 0, 'opening_penalty_outstanding', 0
  )),
  0, 0
) as result;

select public.rpc_post_payment(
  '78100000-0000-0000-0000-000000000001', '78200000-0000-0000-0000-000000000006'::uuid, :'account_id'::uuid,
  150000, '2026-09-01'::date, 'CASH'
);

create temporary table t_loan_b as
select public.rpc_create_migrated_loan(
  '78100000-0000-0000-0000-000000000001', '78200000-0000-0000-0000-000000000006'::uuid, :'product_id'::uuid,
  1000000, '2025-06-10'::date, '2026-08-31'::date,
  300000,
  jsonb_build_array(
    jsonb_build_object('due_date', '2026-07-27', 'principal_outstanding', 150000, 'interest_outstanding', 30000, 'opening_penalty_outstanding', 20000),
    jsonb_build_object('due_date', '2026-08-27', 'principal_outstanding', 150000, 'interest_outstanding', 30000, 'opening_penalty_outstanding', 20000)
  ),
  0, 0
) as result;
select (result->>'id')::uuid as loan_b_id from t_loan_b \gset
select id as b_inst1_id from public.loan_installments where loan_account_id = :'loan_b_id'::uuid and installment_number = 1 \gset
select id as b_inst2_id from public.loan_installments where loan_account_id = :'loan_b_id'::uuid and installment_number = 2 \gset

select public.rpc_allocate_member_wallet('78100000-0000-0000-0000-000000000001', '78200000-0000-0000-0000-000000000006'::uuid, 50000);

reset role;
select is(
  (select outstanding from public.loan_installment_component_states(:'b_inst1_id'::uuid) where component_type = 'PENALTY'),
  0.00::numeric,
  '16: wallet settlement clears July''s penalty first (oldest installment, highest priority)'
);
select is(
  (select outstanding from public.loan_installment_component_states(:'b_inst1_id'::uuid) where component_type = 'INTEREST'),
  0.00::numeric,
  '16b: wallet settlement then clears July''s interest (30,000), exactly exhausting the 50,000 wallet credit'
);
select is(
  (select outstanding from public.loan_installment_component_states(:'b_inst1_id'::uuid) where component_type = 'PRINCIPAL'),
  150000.00::numeric,
  '16c: July''s principal (150,000) is untouched — the wallet credit ran out before reaching it'
);
select is(
  (select coalesce(sum(outstanding), 0) from public.loan_installment_component_states(:'b_inst2_id'::uuid)),
  200000.00::numeric,
  '16d: August (the second historical installment) is completely untouched by the wallet settlement'
);

select * from finish();
rollback;
