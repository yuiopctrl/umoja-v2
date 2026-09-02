-- Prompt 09D-UAT-BLOCKER-01: MIGRATED loan accounting (section 49,
-- items 1-8). Worked example from section 30: original principal
-- 10,000,000; opening principal outstanding 4,000,000 (arrears
-- 400,000 + future 3,600,000); opening interest arrears 80,000; future
-- interest 600,000; opening penalty arrears 20,000.
begin;

select plan(9);

insert into auth.users (id, email) values
  ('72000000-0000-0000-0000-000000000001', 'p09d-blocker-acct-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('72100000-0000-0000-0000-000000000001', 'Migrated Accounting Group', '72000000-0000-0000-0000-000000000001', 'MIGA');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('72200000-0000-0000-0000-000000000001', '72100000-0000-0000-0000-000000000001', '72000000-0000-0000-0000-000000000001', 'MA Admin', 'ACTIVE', '2025-01-01', 'MIGA-2026-0001'),
  ('72200000-0000-0000-0000-000000000005', '72100000-0000-0000-0000-000000000001', null, 'MA Borrower', 'ACTIVE', '2025-01-01', 'MIGA-2026-0005');

insert into public.group_membership_roles (group_membership_id, role_id) select '72200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '72000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '72100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '72100000-0000-0000-0000-000000000001', 'MIGPROD', 'Migration Product', 100000, 1, 24, 5.0, 'MONTHLY', 'FLAT'
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

reset role;
select public.financial_account_balance(:'account_id'::uuid) as cash_before \gset
set local role authenticated;
set local request.jwt.claim.sub to '72000000-0000-0000-0000-000000000001';
select public.rpc_get_financial_position('72100000-0000-0000-0000-000000000001') as fp_before \gset

create temporary table t_migrated as
select public.rpc_create_migrated_loan(
  '72100000-0000-0000-0000-000000000001', '72200000-0000-0000-0000-000000000005'::uuid, :'product_id'::uuid,
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
  (public.rpc_get_financial_position('72100000-0000-0000-0000-000000000001')->>'funded_loan_principal_receivable')::numeric,
  4000000.00::numeric,
  '1: migrated loan creates funded principal receivable of exactly the opening principal outstanding (4,000,000)'
);
reset role;
select is(
  (public.financial_account_balance(:'account_id'::uuid)),
  :'cash_before'::numeric,
  '2: migrated loan creates ZERO cashbook movement'
);
set local role authenticated;
set local request.jwt.claim.sub to '72000000-0000-0000-0000-000000000001';
select is(
  (public.rpc_get_financial_position('72100000-0000-0000-0000-000000000001')->>'group_income')::numeric,
  (:'fp_before'::jsonb->>'group_income')::numeric,
  '3: migrated loan creates ZERO income'
);
select is(
  (public.rpc_get_financial_position('72100000-0000-0000-0000-000000000001')->>'expenses')::numeric,
  (:'fp_before'::jsonb->>'expenses')::numeric,
  '4: migrated loan creates ZERO expense'
);
select is(
  (select count(*) from public.payments where membership_id = '72200000-0000-0000-0000-000000000005'::uuid),
  0::bigint,
  '5: migrated loan creates ZERO payment rows'
);
select is(
  (select count(*) from public.financial_account_entries where source_type = 'PAYMENT'),
  0::bigint,
  '6: migrated loan creates ZERO receipt-generating cashbook entries'
);
select is(
  (select count(*) from public.loan_disbursements where loan_account_id = :'loan_id'::uuid),
  0::bigint,
  '7: no fake loan_disbursements row is ever created for a migrated loan'
);
reset role;
select is(
  (public.financial_account_balance(:'account_id'::uuid)),
  5000000.00::numeric,
  '8: the Financial Account balance is completely unchanged (still its opening 5,000,000)'
);
set local role authenticated;
set local request.jwt.claim.sub to '72000000-0000-0000-0000-000000000001';
select is(
  (select status::text from public.loan_accounts where id = :'loan_id'::uuid),
  'ACTIVE',
  'setup: the migrated loan is operationally ACTIVE immediately'
);

select * from finish();
rollback;
