-- Prompt 09F-A: MIGRATED loan support (section 20/22, test matrix items
-- 32, 33). Opening arrears/penalty are materialized as ordinary
-- loan_installments/loan_penalty_charges rows (origin OPENING) — a
-- waiver targets those exactly like any NEW loan's rows, and
-- loan_opening_positions itself is never touched.
begin;

select plan(6);

insert into auth.users (id, email) values
  ('86000000-0000-0000-0000-000000000001', 'p09fa-migrated-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('86100000-0000-0000-0000-000000000001', 'Migrated Waiver Group', '86000000-0000-0000-0000-000000000001', 'MIGW');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('86200000-0000-0000-0000-000000000001', '86100000-0000-0000-0000-000000000001', '86000000-0000-0000-0000-000000000001', 'MW Admin', 'ACTIVE', '2025-01-01', 'MIGW-2026-0001'),
  ('86200000-0000-0000-0000-000000000005', '86100000-0000-0000-0000-000000000001', null, 'MW Borrower', 'ACTIVE', '2025-01-01', 'MIGW-2026-0005');

insert into public.group_membership_roles (group_membership_id, role_id) select '86200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '86000000-0000-0000-0000-000000000001';

create temporary table t_product as
select public.rpc_create_loan_product(
  '86100000-0000-0000-0000-000000000001', 'MIGWP', 'Migrated Waiver Product', 100000, 1, 24, 5.0, 'MONTHLY', 'FLAT'
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

create temporary table t_migrated as
select public.rpc_create_migrated_loan(
  '86100000-0000-0000-0000-000000000001', '86200000-0000-0000-0000-000000000005'::uuid, :'product_id'::uuid,
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
select id as opening_charge_id from public.loan_penalty_charges
  where loan_installment_id = :'arrears_installment_id'::uuid and origin = 'OPENING' \gset

-- Snapshot the opening position row exactly as created.
select row_to_json(lop.*)::text as opening_position_before
  from public.loan_opening_positions lop where lop.loan_account_id = :'loan_id'::uuid \gset

reset role;
select outstanding as opening_penalty_before from public.loan_penalty_charge_states(:'arrears_installment_id'::uuid) where charge_id = :'opening_charge_id'::uuid \gset
set local role authenticated;
set local request.jwt.claim.sub to '86000000-0000-0000-0000-000000000001';

select is(
  :'opening_penalty_before'::numeric,
  20000.00::numeric,
  'setup: the migrated loan''s opening penalty (20,000) is a normal, waivable charge'
);

-- Item 32: waive part of the MIGRATED loan's opening penalty through
-- the exact same RPC used for a NEW loan.
select public.rpc_post_loan_obligation_waiver(
  '86100000-0000-0000-0000-000000000001', :'loan_id'::uuid, 'LOAN_PENALTY', :'opening_charge_id'::uuid, 8000, 'HARDSHIP'
);

reset role;
select outstanding as opening_penalty_after from public.loan_penalty_charge_states(:'arrears_installment_id'::uuid) where charge_id = :'opening_charge_id'::uuid \gset
select row_to_json(lop.*)::text as opening_position_after
  from public.loan_opening_positions lop where lop.loan_account_id = :'loan_id'::uuid \gset
set local role authenticated;
set local request.jwt.claim.sub to '86000000-0000-0000-0000-000000000001';

select is(
  :'opening_penalty_after'::numeric,
  12000.00::numeric,
  '32: MIGRATED opening penalty is waivable through the same waiver RPC as any NEW loan (20,000 - 8,000 = 12,000)'
);
select is(
  (select penalty_amount from public.loan_penalty_charges where id = :'opening_charge_id'::uuid),
  20000.00::numeric,
  '32b: the original OPENING penalty amount is untouched'
);

-- Item 33: loan_opening_positions is byte-for-byte unchanged.
select is(
  :'opening_position_after'::text,
  :'opening_position_before'::text,
  '33: loan_opening_positions is never rewritten to implement a waiver'
);

-- No fake migrated payment/disbursement was created by the waiver.
select is(
  (select count(*)::integer from public.payments where membership_id = '86200000-0000-0000-0000-000000000005'),
  0,
  'no fake payment/disbursement is created by waiving a MIGRATED loan''s opening penalty'
);
select is(
  (public.rpc_get_financial_position('86100000-0000-0000-0000-000000000001')->>'funded_loan_principal_receivable')::numeric,
  4000000.00::numeric,
  'funded principal receivable (opening principal outstanding) is unaffected by the opening-penalty waiver'
);

select * from finish();
rollback;
