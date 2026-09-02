-- Prompt 09D: penalty REVERSAL (section 47, items 53-58). Loan:
-- 200,000 principal / 1 installment, 10% MONTHLY FLAT -> interest_due
-- 20,000. FIXED penalty (grace=0, amount=15,000). A single payment of
-- 235,000 fully settles penalty + interest + principal; reversing it
-- must restore all three exactly, reverse the recognized penalty
-- income, and touch cash exactly once — all without mutating the
-- original charge or allocation rows.
begin;

select plan(12);

insert into auth.users (id, email) values
  ('68000000-0000-0000-0000-000000000001', 'p09d-rev-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('68100000-0000-0000-0000-000000000001', 'P09D Reversal Group', '68000000-0000-0000-0000-000000000001', 'PENR');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('68200000-0000-0000-0000-000000000001', '68100000-0000-0000-0000-000000000001', '68000000-0000-0000-0000-000000000001', 'PR Admin', 'ACTIVE', '2025-01-01', 'PENR-2026-0001'),
  ('68200000-0000-0000-0000-000000000005', '68100000-0000-0000-0000-000000000001', null, 'PR Borrower', 'ACTIVE', '2025-01-01', 'PENR-2026-0005');

insert into public.group_membership_roles (group_membership_id, role_id) select '68200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '68000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '68100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '68100000-0000-0000-0000-000000000001', 'PREV', 'Reversal Product', 100000, 1, 12, 10.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'FIXED', p_penalty_frequency => 'ONCE',
  p_penalty_grace_days => 0, p_penalty_fixed_amount => 15000
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

create temporary table t_loan as
select public.rpc_create_draft_loan_account(
  '68100000-0000-0000-0000-000000000001', '68200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 200000, 1, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_id from t_loan \gset
select public.rpc_submit_loan_account('68100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_approve_loan_account('68100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_disburse_loan_account('68100000-0000-0000-0000-000000000001', :'loan_id'::uuid, :'account_id'::uuid, current_date);
select id as installment_id from public.loan_installments where loan_account_id = :'loan_id'::uuid \gset

select public.rpc_assess_loan_penalties('68100000-0000-0000-0000-000000000001', current_date, :'loan_id'::uuid);
select id as charge_id, penalty_amount as charge_penalty_amount, assessment_date as charge_assessment_date
  from public.loan_penalty_charges where loan_installment_id = :'installment_id'::uuid \gset

reset role;
select public.financial_account_balance(:'account_id'::uuid) as cash_before_payment \gset
set local role authenticated;
set local request.jwt.claim.sub to '68000000-0000-0000-0000-000000000001';

create temporary table t_post as
select public.rpc_post_payment(
  '68100000-0000-0000-0000-000000000001', '68200000-0000-0000-0000-000000000005'::uuid, :'account_id'::uuid,
  235000, current_date, 'CASH'
) as result;
select (result->>'payment_id')::uuid as payment_id from t_post \gset

select id as penalty_allocation_id, amount as penalty_allocation_amount
  from public.payment_allocations
  where payment_id = :'payment_id'::uuid and allocation_target_type = 'LOAN_PENALTY' \gset

reset role;
select is(
  (select coalesce(sum(outstanding), 0) from public.loan_installment_component_states(:'installment_id'::uuid)),
  0.00::numeric,
  'setup: penalty+interest+principal are all fully settled by the 235,000 payment'
);
set local role authenticated;
set local request.jwt.claim.sub to '68000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- Reverse the payment.
-- ---------------------------------------------------------------------

select public.rpc_reverse_payment('68100000-0000-0000-0000-000000000001', :'payment_id'::uuid, 'Test reversal');

reset role;
select is(
  (select outstanding from public.loan_installment_component_states(:'installment_id'::uuid) where component_type = 'PENALTY'),
  15000.00::numeric,
  '53: reversal restores penalty outstanding to exactly 15,000'
);
select is(
  (select outstanding from public.loan_installment_component_states(:'installment_id'::uuid) where component_type = 'INTEREST'),
  20000.00::numeric,
  '58a: reversal restores interest outstanding to exactly 20,000'
);
select is(
  (select outstanding from public.loan_installment_component_states(:'installment_id'::uuid) where component_type = 'PRINCIPAL'),
  200000.00::numeric,
  '58b: reversal restores principal outstanding to exactly 200,000 — mixed penalty+interest+principal reconciles exactly'
);
set local role authenticated;
set local request.jwt.claim.sub to '68000000-0000-0000-0000-000000000001';

select is(
  (public.rpc_get_financial_position('68100000-0000-0000-0000-000000000001')->>'recognized_loan_penalty_income')::numeric,
  0.00::numeric,
  '54: recognized penalty income reverses back to zero'
);
select is(
  (public.rpc_get_financial_position('68100000-0000-0000-0000-000000000001')->>'loan_penalties_outstanding')::numeric,
  15000.00::numeric,
  '54b: loan_penalties_outstanding is restored to 15,000'
);

reset role;
select is(
  (public.financial_account_balance(:'account_id'::uuid)),
  :'cash_before_payment'::numeric,
  '55: cash is restored to exactly its pre-payment balance — the reversal touches cash exactly once (one INFLOW, one offsetting OUTFLOW)'
);
select is(
  (select count(*) from public.financial_account_entries
   where financial_account_id = :'account_id'::uuid and source_type = 'PAYMENT_REVERSAL' and source_id = :'payment_id'::uuid),
  1::bigint,
  '55b: exactly one reversal cashbook entry exists for this payment'
);
set local role authenticated;
set local request.jwt.claim.sub to '68000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- 56/57: the original charge and allocation rows are never mutated —
-- only payments.status flips.
-- ---------------------------------------------------------------------

select is(
  (select penalty_amount from public.loan_penalty_charges where id = :'charge_id'::uuid),
  :'charge_penalty_amount'::numeric,
  '56: the original loan_penalty_charges row is completely unchanged (immutable) after reversal'
);
select is(
  (select assessment_date from public.loan_penalty_charges where id = :'charge_id'::uuid),
  :'charge_assessment_date'::date,
  '56b: the charge''s assessment_date is unchanged'
);
select is(
  (select amount from public.payment_allocations where id = :'penalty_allocation_id'::uuid),
  :'penalty_allocation_amount'::numeric,
  '57: the original LOAN_PENALTY payment_allocations row is never edited or deleted — only payments.status flips to REVERSED'
);
select is(
  (select status::text from public.payments where id = :'payment_id'::uuid),
  'REVERSED',
  '57b: the payment itself is marked REVERSED (the sole mechanism that deactivates its allocations)'
);

select * from finish();
rollback;
