-- Prompt 09D-UAT-BLOCKER-01: MIGRATED loan SECURITY (section 54, items
-- 41-46).
begin;

select plan(7);

insert into auth.users (id, email) values
  ('77000000-0000-0000-0000-000000000001', 'p09d-blocker-sec-admin@example.com'),
  ('77000000-0000-0000-0000-000000000002', 'p09d-blocker-sec-member@example.com');

insert into public.groups (id, name, created_by, code) values
  ('77100000-0000-0000-0000-000000000001', 'Migrated Security Group A', '77000000-0000-0000-0000-000000000001', 'MIGA1'),
  ('77100000-0000-0000-0000-000000000002', 'Migrated Security Group B', '77000000-0000-0000-0000-000000000001', 'MIGB1');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('77200000-0000-0000-0000-000000000001', '77100000-0000-0000-0000-000000000001', '77000000-0000-0000-0000-000000000001', 'SA Admin', 'ACTIVE', '2025-01-01', 'MIGA1-2026-0001'),
  ('77200000-0000-0000-0000-000000000002', '77100000-0000-0000-0000-000000000001', '77000000-0000-0000-0000-000000000002', 'SA Member', 'ACTIVE', '2025-01-01', 'MIGA1-2026-0002'),
  ('77200000-0000-0000-0000-000000000005', '77100000-0000-0000-0000-000000000001', null, 'SA Borrower', 'ACTIVE', '2025-01-01', 'MIGA1-2026-0005'),
  ('77200000-0000-0000-0000-000000000006', '77100000-0000-0000-0000-000000000002', null, 'SB Borrower (other group)', 'ACTIVE', '2025-01-01', 'MIGB1-2026-0006'),
  ('77200000-0000-0000-0000-000000000007', '77100000-0000-0000-0000-000000000002', '77000000-0000-0000-0000-000000000001', 'SB Admin (same user, other group)', 'ACTIVE', '2025-01-01', 'MIGB1-2026-0007');

insert into public.group_membership_roles (group_membership_id, role_id) select '77200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select '77200000-0000-0000-0000-000000000007', id from public.roles where code = 'ADMIN';
-- SA Member has ordinary loan.view/loan.create only — NOT loan_opening.create.
insert into public.group_membership_roles (group_membership_id, role_id) select '77200000-0000-0000-0000-000000000002', id from public.roles where code = 'CHAIRPERSON';

set local role authenticated;
set local request.jwt.claim.sub to '77000000-0000-0000-0000-000000000001';

create temporary table t_product_a as
select public.rpc_create_loan_product(
  '77100000-0000-0000-0000-000000000001', 'MIGSEC', 'Migration Security Product', 100000, 1, 24, 5.0, 'MONTHLY', 'FLAT'
) as result;
select (result->>'id')::uuid as product_a_id from t_product_a \gset

create temporary table t_product_b as
select public.rpc_create_loan_product(
  '77100000-0000-0000-0000-000000000002', 'MIGSECB', 'Other Group Product', 100000, 1, 24, 5.0, 'MONTHLY', 'FLAT'
) as result;
select (result->>'id')::uuid as product_b_id from t_product_b \gset

-- ---------------------------------------------------------------------
-- 42/43: cross-group member/product rejected.
-- ---------------------------------------------------------------------

select throws_ok(
  format($sql$ select public.rpc_create_migrated_loan(
    '77100000-0000-0000-0000-000000000001'::uuid, %L::uuid, %L::uuid,
    1000000, '2025-11-10'::date, '2026-08-31'::date,
    400000,
    jsonb_build_array(jsonb_build_object(
      'due_date', '2026-08-01', 'principal_outstanding', 400000,
      'interest_outstanding', 0, 'opening_penalty_outstanding', 0
    )),
    0, 0
  ) $sql$, '77200000-0000-0000-0000-000000000006', :'product_a_id'),
  '22023',
  null,
  '42: a membership belonging to a DIFFERENT group is rejected'
);
select throws_ok(
  format($sql$ select public.rpc_create_migrated_loan(
    '77100000-0000-0000-0000-000000000001'::uuid, %L::uuid, %L::uuid,
    1000000, '2025-11-10'::date, '2026-08-31'::date,
    400000,
    jsonb_build_array(jsonb_build_object(
      'due_date', '2026-08-01', 'principal_outstanding', 400000,
      'interest_outstanding', 0, 'opening_penalty_outstanding', 0
    )),
    0, 0
  ) $sql$, '77200000-0000-0000-0000-000000000005', :'product_b_id'),
  '22023',
  null,
  '43: a loan product belonging to a DIFFERENT group is rejected'
);

-- ---------------------------------------------------------------------
-- 41: a caller without loan_opening.create (ordinary CHAIRPERSON, who
-- only has loan.view via existing policy) is rejected.
-- ---------------------------------------------------------------------

set local request.jwt.claim.sub to '77000000-0000-0000-0000-000000000002';
select throws_ok(
  format($sql$ select public.rpc_create_migrated_loan(
    '77100000-0000-0000-0000-000000000001'::uuid, %L::uuid, %L::uuid,
    1000000, '2025-11-10'::date, '2026-08-31'::date,
    400000,
    jsonb_build_array(jsonb_build_object(
      'due_date', '2026-08-01', 'principal_outstanding', 400000,
      'interest_outstanding', 0, 'opening_penalty_outstanding', 0
    )),
    0, 0
  ) $sql$, '77200000-0000-0000-0000-000000000005', :'product_a_id'),
  '42501',
  null,
  '41: a caller without loan_opening.create (e.g. plain CHAIRPERSON) is rejected'
);
set local request.jwt.claim.sub to '77000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- 44: direct client mutation of loan_opening_positions is impossible —
-- no INSERT/UPDATE/DELETE grant exists for authenticated at all.
-- ---------------------------------------------------------------------

select throws_ok(
  $sql$ insert into public.loan_opening_positions (
    group_id, loan_account_id, opening_as_of_date, original_disbursement_date,
    original_principal, opening_principal_outstanding, opening_principal_arrears,
    opening_interest_arrears, opening_penalty_arrears, future_scheduled_principal,
    future_scheduled_interest, remaining_installment_count
  ) values (
    '77100000-0000-0000-0000-000000000001', gen_random_uuid(), current_date, current_date,
    1000000, 400000, 400000, 0, 0, 0, 0, 0
  ) $sql$,
  '42501',
  null,
  '44: direct client INSERT into loan_opening_positions is rejected — no grant exists for authenticated'
);

-- ---------------------------------------------------------------------
-- 45/46: idempotency — a retried post with the same key creates
-- exactly one loan, never two, and the structural unique index is the
-- authoritative backstop (never merely Flutter button-disabling).
-- ---------------------------------------------------------------------

create temporary table t_migrated_1 as
select public.rpc_create_migrated_loan(
  '77100000-0000-0000-0000-000000000001', '77200000-0000-0000-0000-000000000005'::uuid, :'product_a_id'::uuid,
  1000000, '2025-11-10'::date, '2026-08-31'::date,
  400000,
  jsonb_build_array(jsonb_build_object(
    'due_date', '2026-08-01', 'principal_outstanding', 400000,
    'interest_outstanding', 0, 'opening_penalty_outstanding', 0
  )),
  0, 0,
  p_idempotency_key => 'idem-key-001'
) as result;
select (result->>'id')::uuid as loan_1_id from t_migrated_1 \gset

create temporary table t_migrated_1_retry as
select public.rpc_create_migrated_loan(
  '77100000-0000-0000-0000-000000000001', '77200000-0000-0000-0000-000000000005'::uuid, :'product_a_id'::uuid,
  1000000, '2025-11-10'::date, '2026-08-31'::date,
  400000,
  jsonb_build_array(jsonb_build_object(
    'due_date', '2026-08-01', 'principal_outstanding', 400000,
    'interest_outstanding', 0, 'opening_penalty_outstanding', 0
  )),
  0, 0,
  p_idempotency_key => 'idem-key-001'
) as result;

select is(
  (select (result->>'id')::uuid from t_migrated_1_retry),
  :'loan_1_id'::uuid,
  '45: retrying with the SAME idempotency key returns the already-created loan, never a second one'
);
select is(
  (select count(*) from public.loan_accounts where membership_id = '77200000-0000-0000-0000-000000000005'::uuid),
  1::bigint,
  '45b: exactly one loan account exists after the retry'
);
select is(
  (select count(*) from pg_indexes
   where schemaname = 'public' and tablename = 'loan_opening_positions'
     and indexdef ilike '%unique%' and indexdef ilike '%idempotency_key%'),
  1::bigint,
  '46: a structural unique index on (group_id, idempotency_key) exists — concurrency safety is never merely Flutter button-disabling'
);

select * from finish();
rollback;
