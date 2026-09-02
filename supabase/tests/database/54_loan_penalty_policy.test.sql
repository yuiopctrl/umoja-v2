-- Prompt 09D: loan penalty POLICY configuration and snapshot behavior
-- (section 40, items 1-7).
begin;

select plan(10);

insert into auth.users (id, email) values
  ('62000000-0000-0000-0000-000000000001', 'p09d-policy-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('62100000-0000-0000-0000-000000000001', 'P09D Policy Group', '62000000-0000-0000-0000-000000000001', 'PEND');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('62200000-0000-0000-0000-000000000001', '62100000-0000-0000-0000-000000000001', '62000000-0000-0000-0000-000000000001', 'PD Admin', 'ACTIVE', '2025-01-01', 'PEND-2026-0001'),
  ('62200000-0000-0000-0000-000000000005', '62100000-0000-0000-0000-000000000001', null, 'PD Borrower', 'ACTIVE', '2025-01-01', 'PEND-2026-0005');

insert into public.group_membership_roles (group_membership_id, role_id) select '62200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '62000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '62100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

-- ---------------------------------------------------------------------
-- 2/3/4: penalty config validation.
-- ---------------------------------------------------------------------

select throws_ok(
  $sql$ select public.rpc_create_loan_product(
    '62100000-0000-0000-0000-000000000001', 'BADFIX', 'Bad Fixed', 100000, 1, 12, 5.0, 'MONTHLY', 'FLAT',
    p_penalty_enabled => true, p_penalty_type => 'FIXED', p_penalty_frequency => 'ONCE', p_penalty_grace_days => 5
  ) $sql$,
  '22023',
  null,
  '2: FIXED policy without a fixed amount is rejected'
);

select throws_ok(
  $sql$ select public.rpc_create_loan_product(
    '62100000-0000-0000-0000-000000000001', 'BADPCT', 'Bad Percentage', 100000, 1, 12, 5.0, 'MONTHLY', 'FLAT',
    p_penalty_enabled => true, p_penalty_type => 'PERCENTAGE', p_penalty_frequency => 'ONCE', p_penalty_grace_days => 5
  ) $sql$,
  '22023',
  null,
  '3: PERCENTAGE policy without a rate is rejected'
);

select throws_ok(
  $sql$ select public.rpc_create_loan_product(
    '62100000-0000-0000-0000-000000000001', 'BADGRACE', 'Bad Grace', 100000, 1, 12, 5.0, 'MONTHLY', 'FLAT',
    p_penalty_enabled => true, p_penalty_type => 'FIXED', p_penalty_frequency => 'ONCE',
    p_penalty_grace_days => -1, p_penalty_fixed_amount => 20000
  ) $sql$,
  '22023',
  null,
  '4: negative grace_days is rejected'
);

-- ---------------------------------------------------------------------
-- 5: invalid config rejected — enabled with no frequency.
-- ---------------------------------------------------------------------

select throws_ok(
  $sql$ select public.rpc_create_loan_product(
    '62100000-0000-0000-0000-000000000001', 'BADFREQ', 'Bad Frequency', 100000, 1, 12, 5.0, 'MONTHLY', 'FLAT',
    p_penalty_enabled => true, p_penalty_type => 'FIXED', p_penalty_grace_days => 5, p_penalty_fixed_amount => 20000
  ) $sql$,
  '22023',
  null,
  '5: enabled policy with no frequency is rejected'
);

-- ---------------------------------------------------------------------
-- 1/6/7: a valid FIXED/ONCE product, a loan snapshotting it, then a
-- product edit to PERCENTAGE that must NOT retroactively alter the
-- existing loan's frozen snapshot, and a NEW loan that DOES pick up
-- the updated policy.
-- ---------------------------------------------------------------------

create temporary table t_product as
select public.rpc_create_loan_product(
  '62100000-0000-0000-0000-000000000001', 'PENFX', 'Penalty Product', 100000, 1, 12, 5.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'FIXED', p_penalty_frequency => 'ONCE',
  p_penalty_grace_days => 5, p_penalty_fixed_amount => 20000
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

create temporary table t_loan_a as
select public.rpc_create_draft_loan_account(
  '62100000-0000-0000-0000-000000000001', '62200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 300000, 3, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_a_id from t_loan_a \gset

select is(
  (select penalty_type::text from public.loan_accounts where id = :'loan_a_id'::uuid),
  'FIXED',
  '6a (pre-edit): loan A snapshots FIXED'
);
select is(
  (select penalty_fixed_amount from public.loan_accounts where id = :'loan_a_id'::uuid),
  20000.00::numeric,
  '6b (pre-edit): loan A snapshots the 20,000 fixed amount'
);

-- Disburse loan A and confirm assessment is a genuine no-op while
-- penalty_enabled is later flipped off at the LOAN level via a second,
-- disabled-policy loan (item 1) — but first, edit the PRODUCT.
select public.rpc_update_loan_product(
  '62100000-0000-0000-0000-000000000001', :'product_id'::uuid,
  p_penalty_type => 'PERCENTAGE', p_penalty_rate => 7.5, p_penalty_fixed_amount => null
);

select is(
  (select penalty_type::text from public.loan_accounts where id = :'loan_a_id'::uuid),
  'FIXED',
  '6c: editing the product does NOT retroactively change loan A''s already-frozen snapshot'
);

create temporary table t_loan_b as
select public.rpc_create_draft_loan_account(
  '62100000-0000-0000-0000-000000000001', '62200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 300000, 3, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_b_id from t_loan_b \gset

select is(
  (select penalty_type::text from public.loan_accounts where id = :'loan_b_id'::uuid),
  'PERCENTAGE',
  '7: a NEW loan created after the product edit picks up the updated PERCENTAGE policy'
);
select is(
  (select penalty_rate from public.loan_accounts where id = :'loan_b_id'::uuid),
  7.5000::numeric,
  '7b: loan B snapshots the updated 7.5% rate'
);

-- ---------------------------------------------------------------------
-- 1: a penalty-disabled product's loan never gets assessed, even when
-- clearly overdue.
-- ---------------------------------------------------------------------

create temporary table t_product_disabled as
select public.rpc_create_loan_product(
  '62100000-0000-0000-0000-000000000001', 'NOPEN', 'No Penalty Product', 100000, 1, 12, 5.0, 'MONTHLY', 'FLAT'
) as result;
select (result->>'id')::uuid as product_disabled_id from t_product_disabled \gset

create temporary table t_loan_disabled as
select public.rpc_create_draft_loan_account(
  '62100000-0000-0000-0000-000000000001', '62200000-0000-0000-0000-000000000005'::uuid,
  :'product_disabled_id'::uuid, 300000, 3, (current_date - interval '3 months')::date
) as result;
select (result->>'id')::uuid as loan_disabled_id from t_loan_disabled \gset
select public.rpc_submit_loan_account('62100000-0000-0000-0000-000000000001', :'loan_disabled_id'::uuid);
select public.rpc_approve_loan_account('62100000-0000-0000-0000-000000000001', :'loan_disabled_id'::uuid);
select public.rpc_disburse_loan_account('62100000-0000-0000-0000-000000000001', :'loan_disabled_id'::uuid, :'account_id'::uuid, current_date);

create temporary table t_assess_disabled as
select public.rpc_assess_loan_penalties(
  '62100000-0000-0000-0000-000000000001', current_date, :'loan_disabled_id'::uuid
) as result;

select is(
  (select (result->>'assessed_count')::integer from t_assess_disabled),
  0,
  '1: a penalty-disabled loan is never assessed, however overdue'
);

select * from finish();
rollback;
