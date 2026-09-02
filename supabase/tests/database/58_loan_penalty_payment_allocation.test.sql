-- Prompt 09D: penalty PAYMENT ALLOCATION integration (section 45,
-- items 37-44). Loan: 300,000 principal / 3 installments, 5% MONTHLY
-- FLAT -> each installment 100,000 principal + 15,000 interest.
-- Installment 1 due 1 month ago, FIXED/ONCE penalty (grace=0,
-- amount=20,000) so installment 1 carries penalty 20,000 + interest
-- 15,000 + principal 100,000 = 135,000 total outstanding, installment
-- 2 is due today, and installment 3 (due in 1 month) remains a
-- genuinely future (UPCOMING) obligation — never penalized, never
-- auto-allocated.
begin;

select plan(13);

insert into auth.users (id, email) values
  ('66000000-0000-0000-0000-000000000001', 'p09d-alloc-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('66100000-0000-0000-0000-000000000001', 'P09D Alloc Group', '66000000-0000-0000-0000-000000000001', 'PENA');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('66200000-0000-0000-0000-000000000001', '66100000-0000-0000-0000-000000000001', '66000000-0000-0000-0000-000000000001', 'PA Admin', 'ACTIVE', '2025-01-01', 'PENA-2026-0001'),
  ('66200000-0000-0000-0000-000000000005', '66100000-0000-0000-0000-000000000001', null, 'PA Borrower', 'ACTIVE', '2025-01-01', 'PENA-2026-0005'),
  ('66200000-0000-0000-0000-000000000006', '66100000-0000-0000-0000-000000000001', null, 'PA Borrower Wallet', 'ACTIVE', '2025-01-01', 'PENA-2026-0006');

insert into public.group_membership_roles (group_membership_id, role_id) select '66200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '66000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '66100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '66100000-0000-0000-0000-000000000001', 'PALLOC', 'Alloc Product', 100000, 1, 12, 5.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'FIXED', p_penalty_frequency => 'ONCE',
  p_penalty_grace_days => 0, p_penalty_fixed_amount => 20000
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

create temporary table t_loan as
select public.rpc_create_draft_loan_account(
  '66100000-0000-0000-0000-000000000001', '66200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 300000, 3, (current_date - interval '1 month')::date
) as result;
select (result->>'id')::uuid as loan_id from t_loan \gset
select public.rpc_submit_loan_account('66100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_approve_loan_account('66100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_disburse_loan_account('66100000-0000-0000-0000-000000000001', :'loan_id'::uuid, :'account_id'::uuid, current_date);

select id as i1_id from public.loan_installments where loan_account_id = :'loan_id'::uuid and installment_number = 1 \gset
select id as i3_id from public.loan_installments where loan_account_id = :'loan_id'::uuid and installment_number = 3 \gset

select public.rpc_assess_loan_penalties('66100000-0000-0000-0000-000000000001', current_date, :'loan_id'::uuid);

-- ---------------------------------------------------------------------
-- 37/39: a preview shows LOAN_PENALTY as an allocation target, and it
-- is prioritized BEFORE interest/principal within the same
-- installment.
-- ---------------------------------------------------------------------

create temporary table t_preview as
select public.rpc_preview_payment_allocation(
  '66100000-0000-0000-0000-000000000001', '66200000-0000-0000-0000-000000000005'::uuid,
  :'account_id'::uuid, 10000, current_date
) as result;

select is(
  (select a->>'obligation_kind' from jsonb_array_elements((select result->'allocations' from t_preview)) a limit 1),
  'LOAN_PENALTY',
  '37/39: a small payment settles LOAN_PENALTY first — it is the highest-priority obligation on the installment'
);

-- ---------------------------------------------------------------------
-- 38/42: a payment smaller than the penalty amount allocates AT MOST
-- the outstanding penalty, never more — and interest/principal remain
-- completely untouched (partial penalty payment).
-- ---------------------------------------------------------------------

select is(
  (select (a->>'allocate_amount')::numeric from jsonb_array_elements((select result->'allocations' from t_preview)) a limit 1),
  10000.00::numeric,
  '38: the allocation never exceeds the amount actually paid (10,000 of the 20,000 outstanding penalty)'
);
select is(
  (select (result->>'total_allocated')::numeric from t_preview),
  10000.00::numeric,
  '42: a partial penalty payment allocates only to the penalty — interest/principal remain untouched'
);

create temporary table t_post_partial as
select public.rpc_post_payment(
  '66100000-0000-0000-0000-000000000001', '66200000-0000-0000-0000-000000000005'::uuid, :'account_id'::uuid,
  10000, current_date, 'CASH'
) as result;

reset role;
select is(
  (select outstanding from public.loan_installment_component_states(:'i1_id'::uuid) where component_type = 'PENALTY'),
  10000.00::numeric,
  '42b: penalty outstanding drops from 20,000 to 10,000 after the partial payment'
);
select is(
  (select outstanding from public.loan_installment_component_states(:'i1_id'::uuid) where component_type = 'INTEREST'),
  15000.00::numeric,
  '42c: interest outstanding is completely untouched by the partial penalty payment'
);
set local role authenticated;
set local request.jwt.claim.sub to '66000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- 43: a large enough payment fully settles the remaining penalty and
-- spills into interest, then principal, in that exact order.
-- ---------------------------------------------------------------------

create temporary table t_post_full as
select public.rpc_post_payment(
  '66100000-0000-0000-0000-000000000001', '66200000-0000-0000-0000-000000000005'::uuid, :'account_id'::uuid,
  30000, current_date, 'CASH'
) as result;

reset role;
select is(
  (select outstanding from public.loan_installment_component_states(:'i1_id'::uuid) where component_type = 'PENALTY'),
  0.00::numeric,
  '43a: the remaining 10,000 penalty is now fully settled'
);
select is(
  (select outstanding from public.loan_installment_component_states(:'i1_id'::uuid) where component_type = 'INTEREST'),
  0.00::numeric,
  '43b: the full 15,000 interest is settled once the penalty is out of the way'
);
select is(
  (select outstanding from public.loan_installment_component_states(:'i1_id'::uuid) where component_type = 'PRINCIPAL'),
  95000.00::numeric,
  '43c: the remainder (30,000 - 10,000 penalty - 15,000 interest = 5,000) reduces principal from 100,000 to 95,000'
);

-- ---------------------------------------------------------------------
-- 41: installment 3 (a genuinely future/UPCOMING obligation) is never
-- touched, however much money is paid.
-- ---------------------------------------------------------------------

select is(
  (select coalesce(sum(outstanding), 0) from public.loan_installment_component_states(:'i3_id'::uuid)),
  115000.00::numeric,
  '41: the future installment 3 remains completely untouched (still fully outstanding, no penalty possible on it either)'
);
set local role authenticated;
set local request.jwt.claim.sub to '66000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- 40: on an exact due_date tie, a contribution charge still settles
-- before any loan obligation — the cross-domain tie rule (contribution
-- before loan) is completely unaffected by LOAN_PENALTY's new
-- intra-loan priority (which only reorders components WITHIN one loan
-- installment, never across domains). A FRESH borrower/loan is used so
-- no earlier (earlier-due-date) obligation is walked first.
-- ---------------------------------------------------------------------

reset role;
insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('66200000-0000-0000-0000-000000000007', '66100000-0000-0000-0000-000000000001', null, 'PA Borrower Tie', 'ACTIVE', '2025-01-01', 'PENA-2026-0007');
set local role authenticated;
set local request.jwt.claim.sub to '66000000-0000-0000-0000-000000000001';

create temporary table t_loan_tie as
select public.rpc_create_draft_loan_account(
  '66100000-0000-0000-0000-000000000001', '66200000-0000-0000-0000-000000000007'::uuid,
  :'product_id'::uuid, 100000, 1, (current_date + interval '10 days')::date
) as result;
select (result->>'id')::uuid as loan_tie_id from t_loan_tie \gset
select public.rpc_submit_loan_account('66100000-0000-0000-0000-000000000001', :'loan_tie_id'::uuid);
select public.rpc_approve_loan_account('66100000-0000-0000-0000-000000000001', :'loan_tie_id'::uuid);
select public.rpc_disburse_loan_account('66100000-0000-0000-0000-000000000001', :'loan_tie_id'::uuid, :'account_id'::uuid, current_date);
select due_date as tie_due_date from public.loan_installments where loan_account_id = :'loan_tie_id'::uuid \gset

create temporary table t_ctype as
select public.rpc_create_contribution_type(
  '66100000-0000-0000-0000-000000000001', 'ADA', 'GENERAL', 'GROUP_INCOME'
) as result;
select (result->>'id')::uuid as ctype_id from t_ctype \gset

create temporary table t_setup as
select public.rpc_create_contribution_setup(
  '66100000-0000-0000-0000-000000000001', :'ctype_id'::uuid, 'ADA Setup', 'MONTHLY', 'FIXED',
  p_fixed_amount => 20000
) as result;
select (result->>'id')::uuid as setup_id from t_setup \gset

create temporary table t_period as
select public.rpc_create_contribution_period(
  '66100000-0000-0000-0000-000000000001', :'setup_id'::uuid, 'Tie Period', :'tie_due_date'::date, :'tie_due_date'::date,
  p_due_date => :'tie_due_date'::date
) as result;
select (result->>'id')::uuid as period_id from t_period \gset
select public.rpc_open_contribution_period('66100000-0000-0000-0000-000000000001', :'period_id'::uuid);

create temporary table t_tie_preview as
select public.rpc_preview_payment_allocation(
  '66100000-0000-0000-0000-000000000001', '66200000-0000-0000-0000-000000000007'::uuid,
  :'account_id'::uuid, 20000, :'tie_due_date'::date
) as result;

select is(
  (select a->>'obligation_kind' from jsonb_array_elements((select result->'allocations' from t_tie_preview)) a limit 1),
  'CONTRIBUTION',
  '40: on an exact due_date tie, the contribution still settles before any loan obligation — priority rule unchanged'
);

-- ---------------------------------------------------------------------
-- 44: wallet settles a penalty with ZERO cashbook movement.
-- ---------------------------------------------------------------------

create temporary table t_product_wallet as
select public.rpc_create_loan_product(
  '66100000-0000-0000-0000-000000000001', 'PWAL', 'Wallet Alloc Product', 100000, 1, 12, 5.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'FIXED', p_penalty_frequency => 'ONCE',
  p_penalty_grace_days => 0, p_penalty_fixed_amount => 20000
) as result;
select (result->>'id')::uuid as product_wallet_id from t_product_wallet \gset

create temporary table t_loan_wallet as
select public.rpc_create_draft_loan_account(
  '66100000-0000-0000-0000-000000000001', '66200000-0000-0000-0000-000000000006'::uuid,
  :'product_wallet_id'::uuid, 100000, 1, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_wallet_id from t_loan_wallet \gset
select public.rpc_submit_loan_account('66100000-0000-0000-0000-000000000001', :'loan_wallet_id'::uuid);
select public.rpc_approve_loan_account('66100000-0000-0000-0000-000000000001', :'loan_wallet_id'::uuid);
select public.rpc_disburse_loan_account('66100000-0000-0000-0000-000000000001', :'loan_wallet_id'::uuid, :'account_id'::uuid, current_date);
select id as wallet_installment_id from public.loan_installments where loan_account_id = :'loan_wallet_id'::uuid \gset

select public.rpc_assess_loan_penalties('66100000-0000-0000-0000-000000000001', current_date, :'loan_wallet_id'::uuid);

-- An overpayment larger than everything owed becomes wallet credit
-- for the remainder.
reset role;
select coalesce(sum(outstanding), 0) as total_owed from public.loan_installment_component_states(:'wallet_installment_id'::uuid) \gset
set local role authenticated;
set local request.jwt.claim.sub to '66000000-0000-0000-0000-000000000001';

select public.rpc_post_payment(
  '66100000-0000-0000-0000-000000000001', '66200000-0000-0000-0000-000000000006'::uuid, :'account_id'::uuid,
  (:total_owed + 50000), current_date, 'CASH'
);

reset role;
select is(
  (select coalesce(sum(outstanding), 0) from public.loan_installment_component_states(:'wallet_installment_id'::uuid)),
  0.00::numeric,
  'setup: the wallet loan''s penalty+interest+principal are now fully settled by the overpayment, with 50,000 left over as wallet credit'
);
set local role authenticated;
set local request.jwt.claim.sub to '66000000-0000-0000-0000-000000000001';

-- A SECOND penalty-bearing installment on a fresh loan for the SAME
-- wallet borrower, settled purely from the existing wallet credit.
create temporary table t_loan_wallet2 as
select public.rpc_create_draft_loan_account(
  '66100000-0000-0000-0000-000000000001', '66200000-0000-0000-0000-000000000006'::uuid,
  :'product_wallet_id'::uuid, 100000, 1, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_wallet2_id from t_loan_wallet2 \gset
select public.rpc_submit_loan_account('66100000-0000-0000-0000-000000000001', :'loan_wallet2_id'::uuid);
select public.rpc_approve_loan_account('66100000-0000-0000-0000-000000000001', :'loan_wallet2_id'::uuid);
select public.rpc_disburse_loan_account('66100000-0000-0000-0000-000000000001', :'loan_wallet2_id'::uuid, :'account_id'::uuid, current_date);
select id as wallet2_installment_id from public.loan_installments where loan_account_id = :'loan_wallet2_id'::uuid \gset
select public.rpc_assess_loan_penalties('66100000-0000-0000-0000-000000000001', current_date, :'loan_wallet2_id'::uuid);

-- Captured AFTER the second loan's own disbursement (an unrelated
-- cash OUTFLOW), so this genuinely isolates the wallet allocation's
-- own cash effect below.
reset role;
select public.financial_account_balance(:'account_id'::uuid) as cash_before_wallet_test \gset
set local role authenticated;
set local request.jwt.claim.sub to '66000000-0000-0000-0000-000000000001';

select public.rpc_allocate_member_wallet('66100000-0000-0000-0000-000000000001', '66200000-0000-0000-0000-000000000006'::uuid, 20000);

reset role;
select is(
  (select outstanding from public.loan_installment_component_states(:'wallet2_installment_id'::uuid) where component_type = 'PENALTY'),
  0.00::numeric,
  '44a: the wallet allocation fully settles the second loan''s penalty'
);
select is(
  (public.financial_account_balance(:'account_id'::uuid)),
  :'cash_before_wallet_test'::numeric,
  '44b: the wallet-to-penalty allocation creates ZERO cashbook movement (cash balance unchanged)'
);

select * from finish();
rollback;
