-- Prompt 09D-UAT-BLOCKER-03: PAYMENT/PENALTY regression for a loan
-- imported via SIMPLE mode (section AC, items 28-36) — proves the
-- existing Payment Engine and 09D Penalty Engine behave IDENTICALLY
-- regardless of which import mode created the underlying
-- loan_installments/loan_penalty_charges rows, since both modes
-- produce the exact same generic row shapes.
begin;

select plan(9);

insert into auth.users (id, email) values
  ('7c000000-0000-0000-0000-000000000001', 'p09d-blocker3-simple-payment-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('7c100000-0000-0000-0000-000000000001', 'Simple Import Payment Group', '7c000000-0000-0000-0000-000000000001', 'SIMPP');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('7c200000-0000-0000-0000-000000000001', '7c100000-0000-0000-0000-000000000001', '7c000000-0000-0000-0000-000000000001', 'SP Admin', 'ACTIVE', '2025-01-01', 'SIMPP-2026-0001'),
  ('7c200000-0000-0000-0000-000000000005', '7c100000-0000-0000-0000-000000000001', null, 'SP Borrower', 'ACTIVE', '2025-01-01', 'SIMPP-2026-0005');

insert into public.group_membership_roles (group_membership_id, role_id) select '7c200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '7c000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '7c100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '7c100000-0000-0000-0000-000000000001', 'SIMPPPROD', 'Simple Import Payment Product', 100000, 1, 24, 5.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'PERCENTAGE', p_penalty_frequency => 'RECURRING_MONTHLY',
  p_penalty_grace_days => 0, p_penalty_rate => 3.0
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

create temporary table t_migrated as
select public.rpc_create_migrated_loan(
  '7c100000-0000-0000-0000-000000000001', '7c200000-0000-0000-0000-000000000005'::uuid, :'product_id'::uuid,
  20000000, '2026-03-29'::date, '2026-08-31'::date,
  0,
  p_remaining_installment_count => 7, p_next_due_date => '2026-09-27'::date,
  p_mode => 'SIMPLE', p_contracted_interest_amount => 2000000,
  p_monthly_installment_amount => 1834000, p_historical_unpaid_count => 5,
  p_total_historical_arrears => 9494606, p_original_term => 12
) as result;
select (result->>'id')::uuid as loan_id from t_migrated \gset
select id as inst1_id from public.loan_installments where loan_account_id = :'loan_id'::uuid and installment_number = 1 \gset
select id as inst2_id from public.loan_installments where loan_account_id = :'loan_id'::uuid and installment_number = 2 \gset
select id as inst5_id from public.loan_installments where loan_account_id = :'loan_id'::uuid and installment_number = 5 \gset
select id as future_inst_id from public.loan_installments where loan_account_id = :'loan_id'::uuid and installment_number = 6 \gset
select principal_due as inst1_principal, interest_due as inst1_interest from public.loan_installments where id = :'inst1_id'::uuid \gset

-- ---------------------------------------------------------------------
-- 28/29/30: oldest historical installment first, PENALTY -> INTEREST ->
-- PRINCIPAL, future excluded.
-- ---------------------------------------------------------------------

create temporary table t_preview as
select public.rpc_preview_payment_allocation(
  '7c100000-0000-0000-0000-000000000001', '7c200000-0000-0000-0000-000000000005'::uuid,
  :'account_id'::uuid, 1898921.20, '2026-09-01'::date
) as result;

select is(
  (select result->'allocations'->0->>'loan_installment_id' from t_preview),
  :'inst1_id'::text,
  '28: the oldest historical installment (installment 1) is allocated first'
);
select is(
  (select jsonb_build_array(
     result->'allocations'->0->>'obligation_kind',
     result->'allocations'->1->>'obligation_kind',
     result->'allocations'->2->>'obligation_kind'
   ) from t_preview),
  '["LOAN_PENALTY", "LOAN_INTEREST", "LOAN_PRINCIPAL"]'::jsonb,
  '29: PENALTY -> INTEREST -> PRINCIPAL is preserved within the installment'
);

create temporary table t_preview_large as
select public.rpc_preview_payment_allocation(
  '7c100000-0000-0000-0000-000000000001', '7c200000-0000-0000-0000-000000000005'::uuid,
  :'account_id'::uuid, 20000000, '2026-09-01'::date
) as result;
select is(
  (select count(*) from t_preview_large, jsonb_array_elements(result->'allocations') a
   where a->>'loan_installment_id' = :'future_inst_id'::text),
  0::bigint,
  '30: the future installment remains excluded from ordinary auto-allocation, however large the payment'
);

-- ---------------------------------------------------------------------
-- 31/32/33: pay installment 1 in full.
-- ---------------------------------------------------------------------

select (public.rpc_get_financial_position('7c100000-0000-0000-0000-000000000001')->>'funded_loan_principal_receivable')::numeric as receivable_before \gset

create temporary table t_post as
select public.rpc_post_payment(
  '7c100000-0000-0000-0000-000000000001', '7c200000-0000-0000-0000-000000000005'::uuid, :'account_id'::uuid,
  1898921.20, '2026-09-01'::date, 'CASH'
) as result;
select (result->>'payment_id')::uuid as payment_id from t_post \gset

select is(
  (public.rpc_get_financial_position('7c100000-0000-0000-0000-000000000001')->>'funded_loan_principal_receivable')::numeric,
  (:'receivable_before'::numeric - :'inst1_principal'::numeric),
  '32: the principal payment reduces Funded Loan Principal Receivable exactly — never counted as income'
);
select is(
  (public.rpc_get_financial_position('7c100000-0000-0000-0000-000000000001')->>'recognized_loan_interest_income')::numeric,
  :'inst1_interest'::numeric,
  '33: the interest payment recognizes exactly its own interest as income, only now that it is actually paid'
);
select is(
  (public.rpc_get_financial_position('7c100000-0000-0000-0000-000000000001')->>'recognized_loan_penalty_income')::numeric,
  64921.20::numeric,
  '31: the opening (legacy) penalty payment recognizes exactly 64,921.20 of penalty income'
);

-- ---------------------------------------------------------------------
-- 34: reversal restores exact balances.
-- ---------------------------------------------------------------------

select public.rpc_reverse_payment('7c100000-0000-0000-0000-000000000001', :'payment_id'::uuid, 'Blocker-03 reversal test');

reset role;
select is(
  (select jsonb_build_array(
     (select outstanding from public.loan_installment_component_states(:'inst1_id'::uuid) where component_type = 'PRINCIPAL'),
     (select outstanding from public.loan_installment_component_states(:'inst1_id'::uuid) where component_type = 'INTEREST'),
     (select outstanding from public.loan_installment_component_states(:'inst1_id'::uuid) where component_type = 'PENALTY')
   )),
  jsonb_build_array(:'inst1_principal'::numeric, :'inst1_interest'::numeric, 64921.20::numeric),
  '34: reversal restores installment 1''s principal/interest/opening-penalty outstanding exactly'
);
set local role authenticated;
set local request.jwt.claim.sub to '7c000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- 35/36: 09D assessment excludes the opening penalty from its basis,
-- and RECURRING_MONTHLY remains independent per historical installment
-- (installment 1, due 27 Apr, has been overdue far longer than
-- installment 5, due 27 Aug, so a single assessment run on 2 Sep 2026
-- must give installment 1 strictly MORE occurrences).
-- ---------------------------------------------------------------------

select public.rpc_assess_loan_penalties('7c100000-0000-0000-0000-000000000001', '2026-09-02'::date, :'loan_id'::uuid);

select is(
  (select basis_amount from public.loan_penalty_charges
   where loan_installment_id = :'inst1_id'::uuid and origin = 'ASSESSED' and sequence_number = 1),
  (:'inst1_principal'::numeric + :'inst1_interest'::numeric),
  '35: the new 3% assessment''s basis is principal+interest outstanding ONLY — the 64,921.20 opening penalty is excluded'
);
select ok(
  (select count(*) from public.loan_penalty_charges where loan_installment_id = :'inst1_id'::uuid and origin = 'ASSESSED')
  >
  (select count(*) from public.loan_penalty_charges where loan_installment_id = :'inst5_id'::uuid and origin = 'ASSESSED'),
  '36: RECURRING_MONTHLY remains independent per historical installment — installment 1 (overdue longest) has strictly more ASSESSED occurrences than installment 5'
);

select * from finish();
rollback;
