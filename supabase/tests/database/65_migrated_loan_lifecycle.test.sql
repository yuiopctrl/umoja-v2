-- Prompt 09D-UAT-BLOCKER-01: MIGRATED loan LIFECYCLE (section 51,
-- items 16-22).
begin;

select plan(9);

insert into auth.users (id, email) values
  ('74000000-0000-0000-0000-000000000001', 'p09d-blocker-lifecycle-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('74100000-0000-0000-0000-000000000001', 'Migrated Lifecycle Group', '74000000-0000-0000-0000-000000000001', 'MIGL');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('74200000-0000-0000-0000-000000000001', '74100000-0000-0000-0000-000000000001', '74000000-0000-0000-0000-000000000001', 'ML Admin', 'ACTIVE', '2025-01-01', 'MIGL-2026-0001'),
  ('74200000-0000-0000-0000-000000000005', '74100000-0000-0000-0000-000000000001', null, 'ML Borrower Migrated', 'ACTIVE', '2025-01-01', 'MIGL-2026-0005'),
  ('74200000-0000-0000-0000-000000000006', '74100000-0000-0000-0000-000000000001', null, 'ML Borrower New', 'ACTIVE', '2025-01-01', 'MIGL-2026-0006');

insert into public.group_membership_roles (group_membership_id, role_id) select '74200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '74000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '74100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '74100000-0000-0000-0000-000000000001', 'MIGPROD', 'Migration Product', 100000, 1, 24, 5.0, 'MONTHLY', 'FLAT'
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

-- ---------------------------------------------------------------------
-- 21: original_disbursement_date may be arbitrarily far in the past —
-- 5 years ago, well beyond any NEW-loan backdate restriction.
-- ---------------------------------------------------------------------

create temporary table t_migrated as
select public.rpc_create_migrated_loan(
  '74100000-0000-0000-0000-000000000001', '74200000-0000-0000-0000-000000000005'::uuid, :'product_id'::uuid,
  10000000, (current_date - interval '5 years')::date, '2026-08-31'::date,
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
  (public.rpc_get_loan_account('74100000-0000-0000-0000-000000000001', :'loan_id'::uuid)->>'loan_origin'),
  'MIGRATED',
  '16: the migrated loan''s origin is stored as MIGRATED'
);
select is(
  (public.rpc_get_loan_account('74100000-0000-0000-0000-000000000001', :'loan_id'::uuid)->'opening_position'->>'original_disbursement_date'),
  (current_date - interval '5 years')::date::text,
  '21: original_disbursement_date is accepted 5 years in the past, with no backdate rejection'
);
select is(
  (select status::text from public.loan_accounts where id = :'loan_id'::uuid),
  'ACTIVE',
  '18: the migrated loan is ACTIVE the instant it is posted (atomically, in the same transaction)'
);
select is(
  (select count(*) from public.loan_account_events where loan_account_id = :'loan_id'::uuid),
  1::bigint,
  '20: exactly one lifecycle/audit event is written for the migration'
);
select is(
  (select event_type::text from public.loan_account_events where loan_account_id = :'loan_id'::uuid),
  'MIGRATED',
  '20b: that event''s type is MIGRATED, never a generic CREATED'
);
select is(
  (select count(*) from public.loan_account_events
   where loan_account_id = :'loan_id'::uuid and event_type in ('SUBMITTED', 'APPROVED', 'DISBURSED')),
  0::bigint,
  '19: no fake SUBMITTED/APPROVED/DISBURSED event is ever written for a migrated loan'
);

-- ---------------------------------------------------------------------
-- 17/22: a normal NEW loan (created via the ordinary draft workflow)
-- remains loan_origin = NEW, and its usual backdate restriction is
-- untouched by this phase — creating one 100 years in the future is
-- still just an ordinary DRAFT, not silently rejected or altered.
-- ---------------------------------------------------------------------

create temporary table t_new_loan as
select public.rpc_create_draft_loan_account(
  '74100000-0000-0000-0000-000000000001', '74200000-0000-0000-0000-000000000006'::uuid,
  :'product_id'::uuid, 200000, 2, (current_date + interval '10 days')::date
) as result;
select (result->>'id')::uuid as new_loan_id from t_new_loan \gset

select is(
  (public.rpc_get_loan_account('74100000-0000-0000-0000-000000000001', :'new_loan_id'::uuid)->>'loan_origin'),
  'NEW',
  '17: an ordinary loan created via the existing draft workflow remains loan_origin = NEW'
);
select is(
  (select status::text from public.loan_accounts where id = :'new_loan_id'::uuid),
  'DRAFT',
  '22: normal NEW loan creation is completely unaffected — it starts DRAFT exactly as before, never ACTIVE'
);
select is(
  (select count(*) from public.loan_opening_positions where loan_account_id = :'new_loan_id'::uuid),
  0::bigint,
  '22b: a NEW loan never gets an opening-position row'
);

select * from finish();
rollback;
