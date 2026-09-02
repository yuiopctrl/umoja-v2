-- Prompt 09D: Financial Position worked example (section 49). Mirrors
-- the prompt's own figures: disbursed principal 1,000,000, scheduled
-- interest 200,000, assessed penalties 20,000, payments allocated
-- principal 250,000 / interest 50,000 / penalty 5,000.
--
-- Financial Position is a GROUP-WIDE aggregate, so two separate loans
-- (different borrowers) are used to isolate each story cleanly under
-- the locked PENALTY-before-INTEREST-before-PRINCIPAL priority (which
-- would otherwise force any later payment on the SAME loan to drain a
-- still-outstanding EARLIER penalty first): Loan A carries the
-- interest/principal story (no penalty policy, so nothing competes
-- with its interest/principal); Loan B carries the penalty story
-- (0% interest, so it never pollutes scheduled/recognized interest).
-- Every assertion below is checked as a DELTA across a single, isolated
-- action, so the results are exact regardless of loan B's own
-- (separately, correctly accounted) contribution to the totals.
begin;

select plan(12);

insert into auth.users (id, email) values
  ('6a000000-0000-0000-0000-000000000001', 'p09d-fp-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('6a100000-0000-0000-0000-000000000001', 'P09D Financial Position Group', '6a000000-0000-0000-0000-000000000001', 'PENFP');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('6a200000-0000-0000-0000-000000000001', '6a100000-0000-0000-0000-000000000001', '6a000000-0000-0000-0000-000000000001', 'PFP Admin', 'ACTIVE', '2025-01-01', 'PENFP-2026-0001'),
  ('6a200000-0000-0000-0000-000000000005', '6a100000-0000-0000-0000-000000000001', null, 'PFP Borrower A', 'ACTIVE', '2025-01-01', 'PENFP-2026-0005'),
  ('6a200000-0000-0000-0000-000000000006', '6a100000-0000-0000-0000-000000000001', null, 'PFP Borrower B', 'ACTIVE', '2025-01-01', 'PENFP-2026-0006');

insert into public.group_membership_roles (group_membership_id, role_id) select '6a200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '6a000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '6a100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 10000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

-- ---------------------------------------------------------------------
-- Loan B: penalty story. 100,000 principal / 1 installment / 0%
-- interest, FIXED/ONCE penalty (grace=0, amount=20,000).
-- ---------------------------------------------------------------------

create temporary table t_product_b as
select public.rpc_create_loan_product(
  '6a100000-0000-0000-0000-000000000001', 'FPPEN', 'FP Penalty Product', 100000, 1, 12, 0.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'FIXED', p_penalty_frequency => 'ONCE',
  p_penalty_grace_days => 0, p_penalty_fixed_amount => 20000
) as result;
select (result->>'id')::uuid as product_b_id from t_product_b \gset

create temporary table t_loan_b as
select public.rpc_create_draft_loan_account(
  '6a100000-0000-0000-0000-000000000001', '6a200000-0000-0000-0000-000000000006'::uuid,
  :'product_b_id'::uuid, 100000, 1, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_b_id from t_loan_b \gset
select public.rpc_submit_loan_account('6a100000-0000-0000-0000-000000000001', :'loan_b_id'::uuid);
select public.rpc_approve_loan_account('6a100000-0000-0000-0000-000000000001', :'loan_b_id'::uuid);
select public.rpc_disburse_loan_account('6a100000-0000-0000-0000-000000000001', :'loan_b_id'::uuid, :'account_id'::uuid, current_date);
select public.rpc_assess_loan_penalties('6a100000-0000-0000-0000-000000000001', current_date, :'loan_b_id'::uuid);

select is(
  (public.rpc_get_financial_position('6a100000-0000-0000-0000-000000000001')->>'loan_penalties_outstanding')::numeric,
  20000.00::numeric,
  'setup: 20,000 assessed penalty is fully outstanding before any payment'
);

select public.rpc_post_payment(
  '6a100000-0000-0000-0000-000000000001', '6a200000-0000-0000-0000-000000000006'::uuid, :'account_id'::uuid,
  5000, current_date, 'CASH'
);

select is(
  (public.rpc_get_financial_position('6a100000-0000-0000-0000-000000000001')->>'loan_penalties_outstanding')::numeric,
  15000.00::numeric,
  'Loan Penalties Outstanding: 20,000 - 5,000 paid = 15,000'
);
select is(
  (public.rpc_get_financial_position('6a100000-0000-0000-0000-000000000001')->>'recognized_loan_penalty_income')::numeric,
  5000.00::numeric,
  'Recognized Loan Penalty Income: exactly the 5,000 actually allocated'
);

select (public.rpc_get_financial_position('6a100000-0000-0000-0000-000000000001')->>'group_income')::numeric as income_after_penalty \gset

-- ---------------------------------------------------------------------
-- Loan A: interest/principal story. 1,000,000 principal / 4
-- installments / 5% MONTHLY FLAT -> total scheduled interest = 200,000
-- (50,000 per installment), no penalty policy.
-- ---------------------------------------------------------------------

create temporary table t_product_a as
select public.rpc_create_loan_product(
  '6a100000-0000-0000-0000-000000000001', 'FPINT', 'FP Interest Product', 100000, 1, 12, 5.0, 'MONTHLY', 'FLAT'
) as result;
select (result->>'id')::uuid as product_a_id from t_product_a \gset

create temporary table t_loan_a as
select public.rpc_create_draft_loan_account(
  '6a100000-0000-0000-0000-000000000001', '6a200000-0000-0000-0000-000000000005'::uuid,
  :'product_a_id'::uuid, 1000000, 4, current_date
) as result;
select (result->>'id')::uuid as loan_a_id from t_loan_a \gset
select public.rpc_submit_loan_account('6a100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid);
select public.rpc_approve_loan_account('6a100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid);
select public.rpc_disburse_loan_account('6a100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid, :'account_id'::uuid, current_date);
select id as installment_1_id from public.loan_installments where loan_account_id = :'loan_a_id'::uuid and installment_number = 1 \gset

select (select coalesce(sum(interest_due), 0) from public.loan_installments where loan_account_id = :'loan_a_id'::uuid) as loan_a_scheduled_interest \gset
select is(
  :'loan_a_scheduled_interest'::numeric,
  200000.00::numeric,
  'setup: Loan A''s total scheduled interest matches the worked example (200,000)'
);

select (public.rpc_get_financial_position('6a100000-0000-0000-0000-000000000001')->>'funded_loan_principal_receivable')::numeric as receivable_before \gset
select (public.rpc_get_financial_position('6a100000-0000-0000-0000-000000000001')->>'scheduled_unearned_interest')::numeric as unearned_before \gset

create temporary table t_post_a as
select public.rpc_post_payment(
  '6a100000-0000-0000-0000-000000000001', '6a200000-0000-0000-0000-000000000005'::uuid, :'account_id'::uuid,
  300000, current_date, 'CASH'
) as result;
select (result->>'payment_id')::uuid as payment_a_id from t_post_a \gset

select is(
  (public.rpc_get_financial_position('6a100000-0000-0000-0000-000000000001')->>'funded_loan_principal_receivable')::numeric,
  (:'receivable_before'::numeric - 250000.00),
  'Funded Principal Receivable decreases by exactly the 250,000 principal allocated'
);
select is(
  (public.rpc_get_financial_position('6a100000-0000-0000-0000-000000000001')->>'scheduled_unearned_interest')::numeric,
  (:'unearned_before'::numeric - 50000.00),
  'Scheduled/Unearned Interest decreases by exactly the 50,000 interest recognized'
);
select is(
  (public.rpc_get_financial_position('6a100000-0000-0000-0000-000000000001')->>'recognized_loan_interest_income')::numeric,
  50000.00::numeric,
  'Recognized Loan Interest: exactly 50,000'
);
select is(
  (public.rpc_get_financial_position('6a100000-0000-0000-0000-000000000001')->>'group_income')::numeric,
  (:'income_after_penalty'::numeric + 50000.00),
  'Group Income includes the 50,000 interest on top of the earlier 5,000 penalty — each counted exactly once'
);
select is(
  (public.rpc_get_financial_position('6a100000-0000-0000-0000-000000000001')->>'loan_penalties_outstanding')::numeric,
  15000.00::numeric,
  'Loan Penalties Outstanding is unaffected by Loan A''s (penalty-free) payment — remains 15,000'
);

-- ---------------------------------------------------------------------
-- Reversal: everything above restores exactly.
-- ---------------------------------------------------------------------

select public.rpc_reverse_payment('6a100000-0000-0000-0000-000000000001', :'payment_a_id'::uuid, 'FP reversal test');

select is(
  (public.rpc_get_financial_position('6a100000-0000-0000-0000-000000000001')->>'funded_loan_principal_receivable')::numeric,
  :'receivable_before'::numeric,
  'reversal: Funded Principal Receivable is restored exactly'
);
select is(
  (public.rpc_get_financial_position('6a100000-0000-0000-0000-000000000001')->>'scheduled_unearned_interest')::numeric,
  :'unearned_before'::numeric,
  'reversal: Scheduled/Unearned Interest is restored exactly'
);
select is(
  (public.rpc_get_financial_position('6a100000-0000-0000-0000-000000000001')->>'group_income')::numeric,
  :'income_after_penalty'::numeric,
  'reversal: Group Income drops back to just the penalty''s 5,000 (interest''s 50,000 reversed, cash reflects the external payment exactly once throughout)'
);

select * from finish();
rollback;
