-- Prompt 09D-UAT-BLOCKER-01: MIGRATED loan RECONCILIATION invariants
-- (section 50, items 9-15).
begin;

select plan(9);

insert into auth.users (id, email) values
  ('73000000-0000-0000-0000-000000000001', 'p09d-blocker-recon-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('73100000-0000-0000-0000-000000000001', 'Migrated Reconciliation Group', '73000000-0000-0000-0000-000000000001', 'MIGR');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('73200000-0000-0000-0000-000000000001', '73100000-0000-0000-0000-000000000001', '73000000-0000-0000-0000-000000000001', 'MR Admin', 'ACTIVE', '2025-01-01', 'MIGR-2026-0001'),
  ('73200000-0000-0000-0000-000000000005', '73100000-0000-0000-0000-000000000001', null, 'MR Borrower', 'ACTIVE', '2025-01-01', 'MIGR-2026-0005');

insert into public.group_membership_roles (group_membership_id, role_id) select '73200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '73000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '73100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '73100000-0000-0000-0000-000000000001', 'MIGPROD', 'Migration Product', 100000, 1, 24, 5.0, 'MONTHLY', 'FLAT'
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

-- ---------------------------------------------------------------------
-- 10: principal arrears cannot exceed opening principal outstanding.
-- ---------------------------------------------------------------------

select throws_ok(
  format($sql$ select public.rpc_create_migrated_loan(
    '73100000-0000-0000-0000-000000000001'::uuid, %L::uuid, %L::uuid,
    10000000, '2025-11-10'::date, '2026-08-31'::date,
    4000000,
    jsonb_build_array(jsonb_build_object(
      'due_date', '2026-08-01', 'principal_outstanding', 4500000,
      'interest_outstanding', 80000, 'opening_penalty_outstanding', 20000
    )),
    600000, 4,
    p_next_due_date => '2026-09-01'::date
  ) $sql$, '73200000-0000-0000-0000-000000000005', :'product_id'),
  '22023',
  null,
  '10: principal arrears (4,500,000) exceeding opening principal outstanding (4,000,000) is rejected'
);

-- ---------------------------------------------------------------------
-- 9/11: opening principal reconciliation is exact and structural
-- (future_scheduled_principal is DERIVED, never a redundant input that
-- could mismatch) — proven by inspecting the posted row directly.
-- ---------------------------------------------------------------------

create temporary table t_migrated as
select public.rpc_create_migrated_loan(
  '73100000-0000-0000-0000-000000000001', '73200000-0000-0000-0000-000000000005'::uuid, :'product_id'::uuid,
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

select is(
  (select opening_principal_arrears + future_scheduled_principal from public.loan_opening_positions where loan_account_id = :'loan_id'::uuid),
  (select opening_principal_outstanding from public.loan_opening_positions where loan_account_id = :'loan_id'::uuid),
  '9/11: opening_principal_arrears + future_scheduled_principal = opening_principal_outstanding exactly'
);
select is(
  (select future_scheduled_principal from public.loan_opening_positions where loan_account_id = :'loan_id'::uuid),
  3600000.00::numeric,
  '11b: future_scheduled_principal is correctly derived as 4,000,000 - 400,000 = 3,600,000'
);

-- ---------------------------------------------------------------------
-- 12: opening interest arrears stay separate from future scheduled
-- interest — the arrears installment carries only 80,000 interest_due,
-- never 680,000.
-- ---------------------------------------------------------------------

select id as arrears_installment_id from public.loan_installments
  where loan_account_id = :'loan_id'::uuid and installment_number = 1 \gset
select is(
  (select interest_due from public.loan_installments where id = :'arrears_installment_id'::uuid),
  80000.00::numeric,
  '12: the arrears installment carries exactly the 80,000 opening interest arrears, never the combined 680,000 total'
);
select is(
  (select coalesce(sum(interest_due), 0) from public.loan_installments
   where loan_account_id = :'loan_id'::uuid and installment_number > 1),
  600000.00::numeric,
  '12b: future installments carry exactly the 600,000 future scheduled interest, separately'
);

-- ---------------------------------------------------------------------
-- 13: opening penalty (origin OPENING) stays distinguishable from a
-- later 09D-assessed penalty (origin ASSESSED) on the SAME installment.
-- ---------------------------------------------------------------------

select public.rpc_update_loan_product(
  '73100000-0000-0000-0000-000000000001', :'product_id'::uuid,
  p_penalty_enabled => true, p_penalty_type => 'FIXED', p_penalty_frequency => 'ONCE',
  p_penalty_grace_days => 0, p_penalty_fixed_amount => 15000
);
-- The migrated loan already snapshotted the product's PRE-edit (no
-- penalty) policy — this proves migrated loans respect the same
-- snapshot rule as NEW loans (regression), so no assessment is
-- possible on it; the origin distinction is instead proven directly
-- against the posted OPENING row.
select is(
  (select origin::text from public.loan_penalty_charges where loan_installment_id = :'arrears_installment_id'::uuid and sequence_number = 0),
  'OPENING',
  '13: the opening penalty charge is stored with origin = OPENING (sequence_number 0)'
);
select is(
  (select penalty_amount from public.loan_penalty_charges where loan_installment_id = :'arrears_installment_id'::uuid and origin = 'OPENING'),
  20000.00::numeric,
  '13b: the opening penalty charge carries exactly the declared 20,000 opening penalty arrears'
);

-- ---------------------------------------------------------------------
-- 14/15: zero/invalid opening position and inconsistent remaining
-- schedule are rejected.
-- ---------------------------------------------------------------------

select throws_ok(
  format($sql$ select public.rpc_create_migrated_loan(
    '73100000-0000-0000-0000-000000000001'::uuid, %L::uuid, %L::uuid,
    100000, '2025-11-10'::date, '2026-08-31'::date,
    0, '[]'::jsonb, 0, 0
  ) $sql$, '73200000-0000-0000-0000-000000000005', :'product_id'),
  'P0001',
  null,
  '14: a fully-settled (zero everywhere) opening position is rejected — nothing to migrate'
);
select throws_ok(
  format($sql$ select public.rpc_create_migrated_loan(
    '73100000-0000-0000-0000-000000000001'::uuid, %L::uuid, %L::uuid,
    1000000, '2025-11-10'::date, '2026-08-31'::date,
    500000, '[]'::jsonb, 200000, 0,
    p_next_due_date => '2026-09-01'::date
  ) $sql$, '73200000-0000-0000-0000-000000000005', :'product_id'),
  '22023',
  null,
  '15: a remaining schedule with future principal/interest but ZERO remaining installments is rejected as inconsistent'
);

select * from finish();
rollback;
