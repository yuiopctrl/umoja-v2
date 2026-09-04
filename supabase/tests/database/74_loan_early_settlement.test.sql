-- Prompt 09E: Early Settlement Quote + Full Early Settlement.
-- Loan A (no arrears): 600,000 principal / 6 months / 2% MONTHLY FLAT,
-- first installment due a month from now -> every installment is
-- future at settlement time. Total interest = 600,000*0.02*6 = 72,000
-- (12,000/installment), principal 100,000/installment. Early
-- settlement must charge principal only (600,000) — zero interest,
-- since none is due yet.
-- Loan B (overdue penalty + earned interest): 300,000 principal / 3
-- months / 2% MONTHLY FLAT, all 3 installments already overdue. Total
-- interest = 18,000 (6,000/installment). FIXED penalty 5,000 ONCE per
-- installment -> 3 x 5,000 = 15,000 total. Early settlement =
-- 15,000 + 18,000 + 300,000 = 333,000.
begin;

select plan(23);

insert into auth.users (id, email) values
  ('74000000-0000-0000-0000-000000000001', 'p09e-settle-admin@example.com'),
  ('74000000-0000-0000-0000-000000000002', 'p09e-settle-member@example.com');

insert into public.groups (id, name, created_by, code) values
  ('74100000-0000-0000-0000-000000000001', 'Early Settlement Group', '74000000-0000-0000-0000-000000000001', 'ESET'),
  ('74100000-0000-0000-0000-000000000002', 'Early Settlement Other Group', '74000000-0000-0000-0000-000000000001', 'ESETB');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('74200000-0000-0000-0000-000000000001', '74100000-0000-0000-0000-000000000001', '74000000-0000-0000-0000-000000000001', 'ES Admin', 'ACTIVE', '2025-01-01', 'ESET-2026-0001'),
  ('74200000-0000-0000-0000-000000000002', '74100000-0000-0000-0000-000000000001', '74000000-0000-0000-0000-000000000002', 'ES Member', 'ACTIVE', '2025-01-01', 'ESET-2026-0002'),
  ('74200000-0000-0000-0000-000000000005', '74100000-0000-0000-0000-000000000001', null, 'ES Borrower A', 'ACTIVE', '2025-01-01', 'ESET-2026-0005'),
  ('74200000-0000-0000-0000-000000000006', '74100000-0000-0000-0000-000000000001', null, 'ES Borrower B', 'ACTIVE', '2025-01-01', 'ESET-2026-0006'),
  ('74200000-0000-0000-0000-000000000007', '74100000-0000-0000-0000-000000000001', null, 'ES Borrower Migrated', 'ACTIVE', '2025-01-01', 'ESET-2026-0007'),
  ('74200000-0000-0000-0000-000000000009', '74100000-0000-0000-0000-000000000002', null, 'ES Other Group Borrower', 'ACTIVE', '2025-01-01', 'ESETB-2026-0009'),
  ('74200000-0000-0000-0000-000000000010', '74100000-0000-0000-0000-000000000002', '74000000-0000-0000-0000-000000000001', 'ES Admin in Other Group', 'ACTIVE', '2025-01-01', 'ESETB-2026-0010');

insert into public.group_membership_roles (group_membership_id, role_id) select '74200000-0000-0000-0000-000000000010', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select '74200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select '74200000-0000-0000-0000-000000000002', id from public.roles where code = 'MEMBER';

set local role authenticated;
set local request.jwt.claim.sub to '74000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '74100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product_a as
select public.rpc_create_loan_product(
  '74100000-0000-0000-0000-000000000001', 'ESPA', 'Early Settlement Product A', 100000, 1, 12, 2.0, 'MONTHLY', 'FLAT'
) as result;
select (result->>'id')::uuid as product_a_id from t_product_a \gset

create temporary table t_product_b as
select public.rpc_create_loan_product(
  '74100000-0000-0000-0000-000000000001', 'ESPB', 'Early Settlement Product B', 100000, 1, 12, 2.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'FIXED', p_penalty_frequency => 'ONCE',
  p_penalty_grace_days => 0, p_penalty_fixed_amount => 5000
) as result;
select (result->>'id')::uuid as product_b_id from t_product_b \gset

-- ---------------------------------------------------------------------
-- Loan A: no arrears — every installment is future.
-- ---------------------------------------------------------------------

create temporary table t_loan_a as
select public.rpc_create_draft_loan_account(
  '74100000-0000-0000-0000-000000000001', '74200000-0000-0000-0000-000000000005'::uuid,
  :'product_a_id'::uuid, 600000, 6, (current_date + interval '1 month')::date
) as result;
select (result->>'id')::uuid as loan_a_id from t_loan_a \gset
select public.rpc_submit_loan_account('74100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid);
select public.rpc_approve_loan_account('74100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid);
select public.rpc_disburse_loan_account('74100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid, :'account_id'::uuid, current_date);

create temporary table t_quote_a as
select public.rpc_preview_loan_early_settlement('74100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid) as result;

select is(
  (select (result->>'overdue_penalty_outstanding')::numeric from t_quote_a),
  0.00::numeric,
  '1: no-arrears quote has zero overdue penalty'
);
select is(
  (select (result->>'total_settlement_amount')::numeric from t_quote_a),
  600000.00::numeric,
  '2: no-arrears quote charges principal only (no interest is yet due)'
);
select is(
  (select (result->>'future_unearned_interest')::numeric from t_quote_a),
  72000.00::numeric,
  '3: no-arrears quote separately reports future unearned interest (informational, not charged)'
);

select count(*) as payments_before_a from public.payments where membership_id = '74200000-0000-0000-0000-000000000005'::uuid \gset
select is(:payments_before_a::integer, 0, '4: preview creates zero payments (no writes)');

create temporary table t_settle_a as
select public.rpc_settle_loan_early(
  '74100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid, :'account_id'::uuid, 'CASH'
) as result;
select (result->>'payment_id')::uuid as settle_a_payment_id from t_settle_a \gset
select (result->>'amount')::numeric as settle_a_amount from t_settle_a \gset
select (result->>'receipt_number')::text as settle_a_receipt from t_settle_a \gset

select is(:settle_a_amount::numeric, 600000.00::numeric, '5: full settlement amount matches the quote exactly');
select ok(:'settle_a_receipt' is not null and :'settle_a_receipt' <> '', '6: full settlement creates a receipt');
select is(
  (select count(*)::integer from public.financial_account_entries where source_type = 'PAYMENT' and source_id = :'settle_a_payment_id'::uuid),
  1,
  '7: full settlement creates exactly one cashbook inflow'
);
select is(
  (select status from public.loan_accounts where id = :'loan_a_id'::uuid),
  'CLOSED',
  '8: loan A closes once fully settled'
);
select is(
  (public.rpc_get_loan_account('74100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid)->>'principal_outstanding')::numeric,
  0.00::numeric,
  '9: principal outstanding is exactly zero after full settlement'
);
select is(
  (select count(*)::integer from public.loan_installments where loan_account_id = :'loan_a_id'::uuid and cancelled_at is not null),
  6,
  '10: every not-yet-due installment (all 6 — none were due yet) is cancelled, never deleted'
);
select is(
  (select coalesce(sum(li.interest_due), 0) from public.loan_installments li
    where li.loan_account_id = :'loan_a_id'::uuid and li.cancelled_at is null),
  0.00::numeric,
  '11: no future interest remains recognized/scheduled after settlement'
);

-- ---------------------------------------------------------------------
-- Loan B: overdue penalty + earned interest.
-- ---------------------------------------------------------------------

create temporary table t_loan_b as
select public.rpc_create_draft_loan_account(
  '74100000-0000-0000-0000-000000000001', '74200000-0000-0000-0000-000000000006'::uuid,
  :'product_b_id'::uuid, 300000, 3, (current_date - interval '3 months')::date
) as result;
select (result->>'id')::uuid as loan_b_id from t_loan_b \gset
select public.rpc_submit_loan_account('74100000-0000-0000-0000-000000000001', :'loan_b_id'::uuid);
select public.rpc_approve_loan_account('74100000-0000-0000-0000-000000000001', :'loan_b_id'::uuid);
select public.rpc_disburse_loan_account('74100000-0000-0000-0000-000000000001', :'loan_b_id'::uuid, :'account_id'::uuid, (current_date - interval '3 months')::date);
select public.rpc_assess_loan_penalties('74100000-0000-0000-0000-000000000001', current_date, :'loan_b_id'::uuid);

create temporary table t_quote_b as
select public.rpc_preview_loan_early_settlement('74100000-0000-0000-0000-000000000001', :'loan_b_id'::uuid) as result;

select is(
  (select (result->>'overdue_penalty_outstanding')::numeric from t_quote_b),
  15000.00::numeric,
  '12: outstanding penalty across 3 overdue installments is exactly 15,000'
);
select is(
  (select (result->>'overdue_interest_outstanding')::numeric from t_quote_b),
  18000.00::numeric,
  '13: outstanding earned interest across 3 overdue installments is exactly 18,000'
);
select is(
  (select (result->>'total_settlement_amount')::numeric from t_quote_b),
  333000.00::numeric,
  '14: total settlement is penalty + interest + principal = 333,000'
);

create temporary table t_settle_b as
select public.rpc_settle_loan_early(
  '74100000-0000-0000-0000-000000000001', :'loan_b_id'::uuid, :'account_id'::uuid, 'CASH'
) as result;
select is(
  (select (result->>'amount')::numeric from t_settle_b),
  333000.00::numeric,
  '15: settlement B posts exactly the quoted amount'
);
select is(
  (select status from public.loan_accounts where id = :'loan_b_id'::uuid),
  'CLOSED',
  '16: loan B closes once fully settled'
);

-- ---------------------------------------------------------------------
-- Migrated loan settlement (section 8).
-- ---------------------------------------------------------------------

create temporary table t_migrated as
select public.rpc_create_migrated_loan(
  '74100000-0000-0000-0000-000000000001', '74200000-0000-0000-0000-000000000007'::uuid, :'product_a_id'::uuid,
  500000, (current_date - interval '2 months')::date, current_date,
  500000,
  '[]'::jsonb,
  10000, 1,
  p_next_due_date => (current_date + interval '1 month')::date
) as result;
select (result->>'id')::uuid as migrated_loan_id from t_migrated \gset

create temporary table t_quote_m as
select public.rpc_preview_loan_early_settlement('74100000-0000-0000-0000-000000000001', :'migrated_loan_id'::uuid) as result;
select is(
  (select (result->>'total_settlement_amount')::numeric from t_quote_m),
  500000.00::numeric,
  '17: migrated loan early settlement quote excludes its own future interest'
);

select public.rpc_settle_loan_early(
  '74100000-0000-0000-0000-000000000001', :'migrated_loan_id'::uuid, :'account_id'::uuid, 'CASH'
);
select is(
  (select status from public.loan_accounts where id = :'migrated_loan_id'::uuid),
  'CLOSED',
  '18: migrated loan closes correctly after early settlement'
);

-- ---------------------------------------------------------------------
-- Reversal (section 9): must restore principal/interest, reopen the
-- loan, and un-cancel the voided future installments.
-- ---------------------------------------------------------------------

select public.rpc_reverse_payment(
  '74100000-0000-0000-0000-000000000001', :'settle_a_payment_id'::uuid, 'Reversing early settlement for test'
);
select is(
  (select status from public.loan_accounts where id = :'loan_a_id'::uuid),
  'ACTIVE',
  '19: reversal reopens the CLOSED loan'
);
select is(
  (select count(*)::integer from public.loan_installments where loan_account_id = :'loan_a_id'::uuid and cancelled_at is not null),
  0,
  '20: reversal un-cancels every installment this payment had cancelled'
);
select is(
  (public.rpc_get_loan_account('74100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid)->>'principal_outstanding')::numeric,
  600000.00::numeric,
  '21: reversal restores the full principal outstanding'
);

-- ---------------------------------------------------------------------
-- Security: permission + tenant isolation.
-- ---------------------------------------------------------------------

set local request.jwt.claim.sub to '74000000-0000-0000-0000-000000000002';
select throws_ok(
  format($sql$ select public.rpc_settle_loan_early(%L::uuid, %L::uuid, %L::uuid, 'CASH') $sql$,
    '74100000-0000-0000-0000-000000000001', :'loan_b_id', :'account_id'),
  '42501',
  null,
  '22: a MEMBER without loan.settle_early is rejected'
);

set local request.jwt.claim.sub to '74000000-0000-0000-0000-000000000001';
select throws_ok(
  format($sql$ select public.rpc_settle_loan_early(%L::uuid, %L::uuid, %L::uuid, 'CASH') $sql$,
    '74100000-0000-0000-0000-000000000002', :'loan_b_id', :'account_id'),
  '22023',
  'Loan account not found in group',
  '23: settling a loan under the wrong group_id is rejected (tenant isolation)'
);

select * from finish();
rollback;
