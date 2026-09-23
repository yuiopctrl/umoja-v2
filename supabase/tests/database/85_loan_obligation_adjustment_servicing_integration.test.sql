-- Prompt 09F-A: 09E servicing integration + closure (section 18/20,
-- test matrix items 28, 29, 30, 43). Every check below relies on
-- rpc_settle_loan_early / loan_prepayment_eligibility / the restructure
-- gate already consuming the shared balance primitives unmodified —
-- proving they picked up adjustment-awareness for free.
begin;

select plan(6);

insert into auth.users (id, email) values
  ('85000000-0000-0000-0000-000000000001', 'p09fa-servicing-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('85100000-0000-0000-0000-000000000001', 'Servicing Group', '85000000-0000-0000-0000-000000000001', 'SERV');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('85200000-0000-0000-0000-000000000001', '85100000-0000-0000-0000-000000000001', '85000000-0000-0000-0000-000000000001', 'Servicing Admin', 'ACTIVE', '2025-01-01', 'SERV-2026-0001'),
  ('85200000-0000-0000-0000-000000000011', '85100000-0000-0000-0000-000000000001', null, 'Settlement Borrower', 'ACTIVE', '2025-01-01', 'SERV-2026-0011'),
  ('85200000-0000-0000-0000-000000000012', '85100000-0000-0000-0000-000000000001', null, 'Prepayment Borrower', 'ACTIVE', '2025-01-01', 'SERV-2026-0012'),
  ('85200000-0000-0000-0000-000000000013', '85100000-0000-0000-0000-000000000001', null, 'Restructure Borrower', 'ACTIVE', '2025-01-01', 'SERV-2026-0013'),
  ('85200000-0000-0000-0000-000000000014', '85100000-0000-0000-0000-000000000001', null, 'Closure Borrower', 'ACTIVE', '2025-01-01', 'SERV-2026-0014');

insert into public.group_membership_roles (group_membership_id, role_id) select '85200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '85000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '85100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '85100000-0000-0000-0000-000000000001', 'SERVP', 'Servicing Product', 100000, 1, 12, 5.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'FIXED', p_penalty_frequency => 'ONCE',
  p_penalty_grace_days => 0, p_penalty_fixed_amount => 40000
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

-- =======================================================================
-- Item 28: early settlement quote uses the WAIVER-adjusted penalty
-- outstanding (25,000), never the original 40,000 assessment.
-- =======================================================================

create temporary table t_loan_settle as
select public.rpc_create_draft_loan_account(
  '85100000-0000-0000-0000-000000000001', '85200000-0000-0000-0000-000000000011'::uuid,
  :'product_id'::uuid, 600000, 1, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_settle_id from t_loan_settle \gset
select public.rpc_submit_loan_account('85100000-0000-0000-0000-000000000001', :'loan_settle_id'::uuid);
select public.rpc_approve_loan_account('85100000-0000-0000-0000-000000000001', :'loan_settle_id'::uuid);
select public.rpc_disburse_loan_account('85100000-0000-0000-0000-000000000001', :'loan_settle_id'::uuid, :'account_id'::uuid, current_date);
select id as settle_installment_id from public.loan_installments where loan_account_id = :'loan_settle_id'::uuid \gset

select public.rpc_assess_loan_penalties('85100000-0000-0000-0000-000000000001', current_date, :'loan_settle_id'::uuid);
select id as settle_charge_id from public.loan_penalty_charges where loan_installment_id = :'settle_installment_id'::uuid \gset

select public.rpc_post_loan_obligation_waiver(
  '85100000-0000-0000-0000-000000000001', :'loan_settle_id'::uuid, 'LOAN_PENALTY', :'settle_charge_id'::uuid, 15000, 'HARDSHIP'
);

select is(
  (public.rpc_preview_loan_early_settlement('85100000-0000-0000-0000-000000000001', :'loan_settle_id'::uuid)->>'overdue_penalty_outstanding')::numeric,
  25000.00::numeric,
  '28: early settlement quote reflects the waiver-adjusted penalty outstanding (40,000 - 15,000 = 25,000)'
);

-- =======================================================================
-- Item 29: prepayment eligibility uses adjusted overdue penalty/interest
-- — a loan blocked by overdue penalty becomes eligible once fully
-- waived.
-- =======================================================================

create temporary table t_loan_prepay as
select public.rpc_create_draft_loan_account(
  '85100000-0000-0000-0000-000000000001', '85200000-0000-0000-0000-000000000012'::uuid,
  :'product_id'::uuid, 600000, 2, (current_date - interval '15 days')::date
) as result;
select (result->>'id')::uuid as loan_prepay_id from t_loan_prepay \gset
select public.rpc_submit_loan_account('85100000-0000-0000-0000-000000000001', :'loan_prepay_id'::uuid);
select public.rpc_approve_loan_account('85100000-0000-0000-0000-000000000001', :'loan_prepay_id'::uuid);
select public.rpc_disburse_loan_account('85100000-0000-0000-0000-000000000001', :'loan_prepay_id'::uuid, :'account_id'::uuid, current_date);
select id as prepay_installment_id, interest_due as prepay_interest from public.loan_installments
  where loan_account_id = :'loan_prepay_id'::uuid and installment_number = 1 \gset

select public.rpc_assess_loan_penalties('85100000-0000-0000-0000-000000000001', current_date, :'loan_prepay_id'::uuid);
select id as prepay_charge_id from public.loan_penalty_charges where loan_installment_id = :'prepay_installment_id'::uuid \gset

select throws_ok(
  format(
    $sql$ select public.rpc_preview_loan_prepayment('85100000-0000-0000-0000-000000000001', %L::uuid, 50000, 'REDUCE_TERM') $sql$,
    :'loan_prepay_id'
  ),
  'P0001',
  'LOAN_PREPAYMENT_BLOCKED_OVERDUE_PENALTY',
  'setup: prepayment is blocked while overdue penalty remains outstanding'
);

select public.rpc_post_loan_obligation_waiver(
  '85100000-0000-0000-0000-000000000001', :'loan_prepay_id'::uuid, 'LOAN_PENALTY', :'prepay_charge_id'::uuid, 40000, 'HARDSHIP'
);
select public.rpc_post_loan_obligation_waiver(
  '85100000-0000-0000-0000-000000000001', :'loan_prepay_id'::uuid, 'LOAN_INTEREST', :'prepay_installment_id'::uuid, :prepay_interest, 'HARDSHIP'
);

select is(
  (public.rpc_preview_loan_prepayment('85100000-0000-0000-0000-000000000001', :'loan_prepay_id'::uuid, 50000, 'REDUCE_TERM')->>'amount')::numeric,
  50000.00::numeric,
  '29: prepayment eligibility uses adjusted (fully-waived) overdue penalty/interest — no longer blocked'
);

-- =======================================================================
-- Item 30: restructure eligibility uses adjusted overdue balances.
-- =======================================================================

create temporary table t_loan_restructure as
select public.rpc_create_draft_loan_account(
  '85100000-0000-0000-0000-000000000001', '85200000-0000-0000-0000-000000000013'::uuid,
  :'product_id'::uuid, 600000, 2, (current_date - interval '15 days')::date
) as result;
select (result->>'id')::uuid as loan_restructure_id from t_loan_restructure \gset
select public.rpc_submit_loan_account('85100000-0000-0000-0000-000000000001', :'loan_restructure_id'::uuid);
select public.rpc_approve_loan_account('85100000-0000-0000-0000-000000000001', :'loan_restructure_id'::uuid);
select public.rpc_disburse_loan_account('85100000-0000-0000-0000-000000000001', :'loan_restructure_id'::uuid, :'account_id'::uuid, current_date);
select id as restructure_installment_id, interest_due as restructure_interest, principal_due as restructure_principal
  from public.loan_installments where loan_account_id = :'loan_restructure_id'::uuid and installment_number = 1 \gset

select public.rpc_assess_loan_penalties('85100000-0000-0000-0000-000000000001', current_date, :'loan_restructure_id'::uuid);
select id as restructure_charge_id from public.loan_penalty_charges where loan_installment_id = :'restructure_installment_id'::uuid \gset

select throws_ok(
  format(
    $sql$ select public.rpc_preview_loan_restructure('85100000-0000-0000-0000-000000000001', %L::uuid, 3, %L::date) $sql$,
    :'loan_restructure_id', (current_date + interval '2 months')::date
  ),
  'P0001',
  'LOAN_RESTRUCTURE_BLOCKED_OVERDUE_BALANCE',
  'setup: restructure is blocked while any overdue balance remains outstanding'
);

select public.rpc_post_loan_obligation_waiver(
  '85100000-0000-0000-0000-000000000001', :'loan_restructure_id'::uuid, 'LOAN_PENALTY', :'restructure_charge_id'::uuid, 40000, 'HARDSHIP'
);
select public.rpc_post_loan_obligation_waiver(
  '85100000-0000-0000-0000-000000000001', :'loan_restructure_id'::uuid, 'LOAN_INTEREST', :'restructure_installment_id'::uuid, :restructure_interest, 'HARDSHIP'
);
select public.rpc_post_payment(
  '85100000-0000-0000-0000-000000000001', '85200000-0000-0000-0000-000000000013'::uuid, :'account_id'::uuid,
  :restructure_principal, current_date, 'CASH'
);

select isnt(
  (public.rpc_preview_loan_restructure('85100000-0000-0000-0000-000000000001', :'loan_restructure_id'::uuid, 3, (current_date + interval '2 months')::date)->>'new_term')::integer,
  null,
  '30: restructure eligibility uses adjusted overdue balances — no longer blocked once penalty/interest are waived and principal is paid'
);

-- =======================================================================
-- Item 43: a full waiver of the last remaining component (penalty),
-- combined with an ordinary payment settling interest+principal in
-- full, closes the loan — with no fake payment/receipt for the waived
-- portion.
-- =======================================================================

create temporary table t_loan_closure as
select public.rpc_create_draft_loan_account(
  '85100000-0000-0000-0000-000000000001', '85200000-0000-0000-0000-000000000014'::uuid,
  :'product_id'::uuid, 600000, 1, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_closure_id from t_loan_closure \gset
select public.rpc_submit_loan_account('85100000-0000-0000-0000-000000000001', :'loan_closure_id'::uuid);
select public.rpc_approve_loan_account('85100000-0000-0000-0000-000000000001', :'loan_closure_id'::uuid);
select public.rpc_disburse_loan_account('85100000-0000-0000-0000-000000000001', :'loan_closure_id'::uuid, :'account_id'::uuid, current_date);
select id as closure_installment_id, interest_due as closure_interest, principal_due as closure_principal
  from public.loan_installments where loan_account_id = :'loan_closure_id'::uuid \gset

select public.rpc_assess_loan_penalties('85100000-0000-0000-0000-000000000001', current_date, :'loan_closure_id'::uuid);
select id as closure_charge_id from public.loan_penalty_charges where loan_installment_id = :'closure_installment_id'::uuid \gset

-- Waive the penalty fully, then pay interest+principal exactly in full.
select public.rpc_post_loan_obligation_waiver(
  '85100000-0000-0000-0000-000000000001', :'loan_closure_id'::uuid, 'LOAN_PENALTY', :'closure_charge_id'::uuid, 40000, 'HARDSHIP'
);
select public.rpc_post_payment(
  '85100000-0000-0000-0000-000000000001', '85200000-0000-0000-0000-000000000014'::uuid, :'account_id'::uuid,
  :closure_interest + :closure_principal, current_date, 'CASH'
);

select is(
  (select status from public.loan_accounts where id = :'loan_closure_id'::uuid),
  'CLOSED',
  '43: the loan closes once penalty (waived) + interest/principal (paid) all reach zero — no fake payment for the waived portion'
);

select * from finish();
rollback;
