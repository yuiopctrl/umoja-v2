-- Prompt 09D-UAT-BLOCKER-01: MIGRATED loan PAYMENT integration
-- (section 52, items 23-33). The exact worked example from section 30:
-- a 500,000 payment against opening penalty 20,000 + opening interest
-- 80,000 + opening principal arrears 400,000 (summing to exactly
-- 500,000, so nothing spills into the future schedule).
begin;

select plan(14);

insert into auth.users (id, email) values
  ('75000000-0000-0000-0000-000000000001', 'p09d-blocker-payment-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('75100000-0000-0000-0000-000000000001', 'Migrated Payment Group', '75000000-0000-0000-0000-000000000001', 'MIGP');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('75200000-0000-0000-0000-000000000001', '75100000-0000-0000-0000-000000000001', '75000000-0000-0000-0000-000000000001', 'MP Admin', 'ACTIVE', '2025-01-01', 'MIGP-2026-0001'),
  ('75200000-0000-0000-0000-000000000005', '75100000-0000-0000-0000-000000000001', null, 'MP Borrower', 'ACTIVE', '2025-01-01', 'MIGP-2026-0005'),
  ('75200000-0000-0000-0000-000000000006', '75100000-0000-0000-0000-000000000001', null, 'MP Borrower Wallet', 'ACTIVE', '2025-01-01', 'MIGP-2026-0006');

insert into public.group_membership_roles (group_membership_id, role_id) select '75200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '75000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '75100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '75100000-0000-0000-0000-000000000001', 'MIGPROD', 'Migration Product', 100000, 1, 24, 5.0, 'MONTHLY', 'FLAT'
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

create temporary table t_migrated as
select public.rpc_create_migrated_loan(
  '75100000-0000-0000-0000-000000000001', '75200000-0000-0000-0000-000000000005'::uuid, :'product_id'::uuid,
  10000000, '2025-11-10'::date, '2026-08-31'::date,
  4000000,
  jsonb_build_array(jsonb_build_object(
    'due_date', '2026-08-01', 'principal_outstanding', 400000,
    'interest_outstanding', 80000, 'opening_penalty_outstanding', 20000
  )),
  600000, 4,
  p_next_due_date => '2026-09-01'::date
) as result;
select (result->>'id')::uuid as loan_id from t_migrated \gset
select id as arrears_installment_id from public.loan_installments
  where loan_account_id = :'loan_id'::uuid and installment_number = 1 \gset

-- ---------------------------------------------------------------------
-- 23/24/25: a small preview at the arrears due date shows the opening
-- penalty/interest/principal in the locked priority order.
-- ---------------------------------------------------------------------

create temporary table t_preview as
select public.rpc_preview_payment_allocation(
  '75100000-0000-0000-0000-000000000001', '75200000-0000-0000-0000-000000000005'::uuid,
  :'account_id'::uuid, 500000, '2026-08-01'::date
) as result;

select is(
  (select result->'allocations'->0->>'obligation_kind' from t_preview),
  'LOAN_PENALTY',
  '23/25: the opening penalty (highest priority) is allocatable and settles first'
);
select is(
  (select jsonb_agg(a->>'obligation_kind') from t_preview, jsonb_array_elements(result->'allocations') a),
  '["LOAN_PENALTY", "LOAN_INTEREST", "LOAN_PRINCIPAL"]'::jsonb,
  '23/24/25: opening penalty/interest/principal arrears are ALL allocatable, in the exact locked priority order'
);
select is(
  (select (result->>'total_allocated')::numeric from t_preview),
  500000.00::numeric,
  'setup: the full 500,000 is allocated (exactly consuming all three arrears, nothing spills to the future schedule)'
);

-- ---------------------------------------------------------------------
-- 26/27/28/29/30/31: post the payment.
-- ---------------------------------------------------------------------

select (public.rpc_get_financial_position('75100000-0000-0000-0000-000000000001')->>'funded_loan_principal_receivable')::numeric as receivable_before \gset
select count(*) as entries_before from public.financial_account_entries where financial_account_id = :'account_id'::uuid \gset

create temporary table t_post as
select public.rpc_post_payment(
  '75100000-0000-0000-0000-000000000001', '75200000-0000-0000-0000-000000000005'::uuid, :'account_id'::uuid,
  500000, '2026-09-02'::date, 'CASH'
) as result;
select (result->>'payment_id')::uuid as payment_id from t_post \gset

select is(
  (public.rpc_get_financial_position('75100000-0000-0000-0000-000000000001')->>'funded_loan_principal_receivable')::numeric,
  (:'receivable_before'::numeric - 400000.00),
  '26: the principal payment reduces Funded Loan Principal Receivable by exactly 400,000'
);
select is(
  (public.rpc_get_financial_position('75100000-0000-0000-0000-000000000001')->>'recognized_loan_interest_income')::numeric,
  80000.00::numeric,
  '28: the interest arrears payment recognizes exactly 80,000 of interest income'
);
select is(
  (public.rpc_get_financial_position('75100000-0000-0000-0000-000000000001')->>'recognized_loan_penalty_income')::numeric,
  20000.00::numeric,
  '29: the opening penalty payment recognizes exactly 20,000 of penalty income'
);
select is(
  (select count(*) from public.financial_account_entries where financial_account_id = :'account_id'::uuid),
  (:'entries_before'::bigint + 1),
  '30: exactly one new cashbook INFLOW entry is created for the entire 500,000 payment'
);
select is(
  (select count(*) from public.payments where id = :'payment_id'::uuid),
  1::bigint,
  '31: exactly one payment (and therefore exactly one receipt) represents this settlement'
);

reset role;
select is(
  (select coalesce(sum(outstanding), 0) from public.loan_installment_component_states(:'arrears_installment_id'::uuid)),
  0.00::numeric,
  '27: the arrears installment (principal+interest+penalty) is now fully settled — principal repayment recognized zero income of its own'
);
set local role authenticated;
set local request.jwt.claim.sub to '75000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- 32: wallet settles a SEPARATE migrated loan's arrears with zero
-- cashbook movement.
-- ---------------------------------------------------------------------

create temporary table t_migrated_wallet as
select public.rpc_create_migrated_loan(
  '75100000-0000-0000-0000-000000000001', '75200000-0000-0000-0000-000000000006'::uuid, :'product_id'::uuid,
  1000000, '2025-11-10'::date, '2026-08-31'::date,
  100000,
  jsonb_build_array(jsonb_build_object(
    'due_date', '2026-08-01', 'principal_outstanding', 100000,
    'interest_outstanding', 10000, 'opening_penalty_outstanding', 5000
  )),
  0, 0
) as result;
select (result->>'id')::uuid as loan_wallet_id from t_migrated_wallet \gset

select public.rpc_post_payment(
  '75100000-0000-0000-0000-000000000001', '75200000-0000-0000-0000-000000000006'::uuid, :'account_id'::uuid,
  300000, '2026-09-02'::date, 'CASH'
);

reset role;
select public.financial_account_balance(:'account_id'::uuid) as cash_before_wallet \gset
set local role authenticated;
set local request.jwt.claim.sub to '75000000-0000-0000-0000-000000000001';

create temporary table t_migrated_wallet2 as
select public.rpc_create_migrated_loan(
  '75100000-0000-0000-0000-000000000001', '75200000-0000-0000-0000-000000000006'::uuid, :'product_id'::uuid,
  1000000, '2025-11-10'::date, '2026-08-31'::date,
  100000,
  jsonb_build_array(jsonb_build_object(
    'due_date', '2026-08-01', 'principal_outstanding', 100000,
    'interest_outstanding', 10000, 'opening_penalty_outstanding', 5000
  )),
  0, 0
) as result;
select (result->>'id')::uuid as loan_wallet2_id from t_migrated_wallet2 \gset

select public.rpc_allocate_member_wallet('75100000-0000-0000-0000-000000000001', '75200000-0000-0000-0000-000000000006'::uuid, 115000);

reset role;
select is(
  (public.financial_account_balance(:'account_id'::uuid)),
  :'cash_before_wallet'::numeric,
  '32: wallet settlement of a migrated loan''s opening arrears creates ZERO cashbook movement'
);
set local role authenticated;
set local request.jwt.claim.sub to '75000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- 33: reversal restores all opening obligations/economics exactly.
-- ---------------------------------------------------------------------

select public.rpc_reverse_payment('75100000-0000-0000-0000-000000000001', :'payment_id'::uuid, 'Blocker reversal test');

reset role;
select is(
  (select outstanding from public.loan_installment_component_states(:'arrears_installment_id'::uuid) where component_type = 'PENALTY'),
  20000.00::numeric,
  '33a: reversal restores opening penalty outstanding to exactly 20,000'
);
select is(
  (select outstanding from public.loan_installment_component_states(:'arrears_installment_id'::uuid) where component_type = 'INTEREST'),
  80000.00::numeric,
  '33b: reversal restores opening interest arrears outstanding to exactly 80,000'
);
select is(
  (select outstanding from public.loan_installment_component_states(:'arrears_installment_id'::uuid) where component_type = 'PRINCIPAL'),
  400000.00::numeric,
  '33c: reversal restores opening principal arrears outstanding to exactly 400,000'
);
set local role authenticated;
set local request.jwt.claim.sub to '75000000-0000-0000-0000-000000000001';

select is(
  (public.rpc_get_financial_position('75100000-0000-0000-0000-000000000001')->>'funded_loan_principal_receivable')::numeric,
  :'receivable_before'::numeric,
  '33d: reversal restores Funded Loan Principal Receivable exactly'
);

select * from finish();
rollback;
