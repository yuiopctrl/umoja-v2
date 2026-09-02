-- Prompt 09D-UAT-BLOCKER-01: 09D PENALTY ENGINE integration with
-- migrated loans (section 53, items 34-40). Uses the exact worked
-- example from section 34: principal arrears 400,000 + interest
-- arrears 80,000 + opening penalty 20,000, 5% new penalty policy ->
-- basis 480,000, new penalty 24,000 (never 25,000 of 500,000).
begin;

select plan(9);

insert into auth.users (id, email) values
  ('76000000-0000-0000-0000-000000000001', 'p09d-blocker-penalty-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('76100000-0000-0000-0000-000000000001', 'Migrated Penalty Group', '76000000-0000-0000-0000-000000000001', 'MIGN');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('76200000-0000-0000-0000-000000000001', '76100000-0000-0000-0000-000000000001', '76000000-0000-0000-0000-000000000001', 'MN Admin', 'ACTIVE', '2025-01-01', 'MIGN-2026-0001'),
  ('76200000-0000-0000-0000-000000000005', '76100000-0000-0000-0000-000000000001', null, 'MN Borrower', 'ACTIVE', '2025-01-01', 'MIGN-2026-0005');

insert into public.group_membership_roles (group_membership_id, role_id) select '76200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '76000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '76100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '76100000-0000-0000-0000-000000000001', 'MIGPEN', 'Migration Penalty Product', 100000, 1, 24, 5.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'PERCENTAGE', p_penalty_frequency => 'ONCE',
  p_penalty_grace_days => 5, p_penalty_rate => 5.0
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

-- Arrears due 2026-08-01, grace 5 days -> threshold 2026-08-06;
-- opening_as_of 2026-08-31 (well past threshold, matching section 33's
-- own worked example of a 02 Sep assessment).
create temporary table t_migrated as
select public.rpc_create_migrated_loan(
  '76100000-0000-0000-0000-000000000001', '76200000-0000-0000-0000-000000000005'::uuid, :'product_id'::uuid,
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
select id as future_installment_1_id from public.loan_installments
  where loan_account_id = :'loan_id'::uuid and installment_number = 2 \gset

-- ---------------------------------------------------------------------
-- 35: still inside grace (assessing on the threshold day itself) ->
-- nothing assessed yet.
-- ---------------------------------------------------------------------

create temporary table t_assess_in_grace as
select public.rpc_assess_loan_penalties('76100000-0000-0000-0000-000000000001', '2026-08-06'::date, :'loan_id'::uuid) as result;
select is(
  (select (result->>'assessed_count')::integer from t_assess_in_grace),
  0,
  '35: assessing on due_date + grace_days (still inside grace) creates nothing'
);

-- ---------------------------------------------------------------------
-- 34/37/38: the migrated overdue arrears installment IS eligible for a
-- fresh 09D assessment once grace expires — the OPENING penalty
-- (20,000) never blocks it (ONCE would otherwise see "already
-- assessed"), and the basis correctly EXCLUDES the opening penalty:
-- 400,000 + 80,000 = 480,000 -> 5% = 24,000, never 25,000 of 500,000.
-- ---------------------------------------------------------------------

create temporary table t_assess as
select public.rpc_assess_loan_penalties('76100000-0000-0000-0000-000000000001', '2026-09-02'::date, :'loan_id'::uuid) as result;

select is(
  (select (result->>'assessed_count')::integer from t_assess),
  1,
  '34: the migrated overdue obligation IS assessed once grace expires — the OPENING penalty never blocks ONCE'
);
select is(
  (select penalty_amount from public.loan_penalty_charges
   where loan_installment_id = :'arrears_installment_id'::uuid and origin = 'ASSESSED'),
  24000.00::numeric,
  '37/38: the new penalty is exactly 24,000 (5% of 480,000) — the existing 20,000 OPENING penalty is excluded from the basis, never inflating it to 500,000/25,000'
);
select is(
  (select basis_amount from public.loan_penalty_charges
   where loan_installment_id = :'arrears_installment_id'::uuid and origin = 'ASSESSED'),
  480000.00::numeric,
  '37b: the stored basis_amount itself is 480,000, never 500,000'
);
select is(
  (select sequence_number from public.loan_penalty_charges
   where loan_installment_id = :'arrears_installment_id'::uuid and origin = 'ASSESSED'),
  1,
  '39: the ASSESSED occurrence is correctly numbered starting at 1 (the OPENING charge''s reserved sequence 0 never collides with or shifts ASSESSED numbering)'
);
select is(
  (select count(*) from public.loan_penalty_charges where loan_installment_id = :'arrears_installment_id'::uuid),
  2::bigint,
  'setup: the installment now carries exactly two charges — one OPENING (20,000) and one ASSESSED (24,000)'
);

-- Re-running the SAME assessment date creates no duplicate (ONCE).
select public.rpc_assess_loan_penalties('76100000-0000-0000-0000-000000000001', '2026-09-02'::date, :'loan_id'::uuid);
select is(
  (select count(*) from public.loan_penalty_charges
   where loan_installment_id = :'arrears_installment_id'::uuid and origin = 'ASSESSED'),
  1::bigint,
  '39b: retrying the assessment creates no duplicate ASSESSED occurrence (ONCE uniqueness preserved)'
);

-- ---------------------------------------------------------------------
-- 36: the future (UPCOMING) installment is never penalized, however
-- late the assessment date.
-- ---------------------------------------------------------------------

select is(
  (select count(*) from public.loan_penalty_charges where loan_installment_id = :'future_installment_1_id'::uuid),
  0::bigint,
  '36: the future migrated installment is never penalized'
);

-- ---------------------------------------------------------------------
-- 40: RECURRING_MONTHLY still behaves correctly on a migrated
-- installment — a second, later assessment produces occurrence 2.
-- ---------------------------------------------------------------------

select public.rpc_update_loan_product(
  '76100000-0000-0000-0000-000000000001', :'product_id'::uuid,
  p_penalty_frequency => 'RECURRING_MONTHLY'
);

create temporary table t_migrated_recurring as
select public.rpc_create_migrated_loan(
  '76100000-0000-0000-0000-000000000001', '76200000-0000-0000-0000-000000000005'::uuid, :'product_id'::uuid,
  1000000, '2025-11-10'::date, '2026-08-31'::date,
  400000,
  jsonb_build_array(jsonb_build_object(
    'due_date', '2026-08-01', 'principal_outstanding', 400000,
    'interest_outstanding', 80000, 'opening_penalty_outstanding', 0
  )),
  0, 0
) as result;
select (result->>'id')::uuid as recurring_loan_id from t_migrated_recurring \gset
select id as recurring_installment_id from public.loan_installments
  where loan_account_id = :'recurring_loan_id'::uuid and installment_number = 1 \gset

select public.rpc_assess_loan_penalties('76100000-0000-0000-0000-000000000001', '2026-09-02'::date, :'recurring_loan_id'::uuid);
select public.rpc_assess_loan_penalties('76100000-0000-0000-0000-000000000001', '2026-09-10'::date, :'recurring_loan_id'::uuid);

select is(
  (select count(*) from public.loan_penalty_charges
   where loan_installment_id = :'recurring_installment_id'::uuid and origin = 'ASSESSED'),
  2::bigint,
  '40: RECURRING_MONTHLY correctly produces a second occurrence on a migrated installment over time'
);

select * from finish();
rollback;
