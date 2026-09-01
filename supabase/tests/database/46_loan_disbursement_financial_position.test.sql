-- Prompt 09B: Financial Position integration — concrete before/after
-- example (section 38).
begin;

select plan(10);

insert into auth.users (id, email) values
  ('2e000000-0000-0000-0000-000000000001', 'p09b-fp-admin@example.com'),
  ('2e000000-0000-0000-0000-000000000002', 'p09b-fp-treasurer@example.com'),
  ('2e000000-0000-0000-0000-000000000003', 'p09b-fp-chairperson@example.com');

insert into public.groups (id, name, created_by, code) values
  ('2e100000-0000-0000-0000-000000000001', 'P09B Financial Position Group', '2e000000-0000-0000-0000-000000000001', 'LFPP');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('2e200000-0000-0000-0000-000000000001', '2e100000-0000-0000-0000-000000000001', '2e000000-0000-0000-0000-000000000001', 'LFP Admin', 'ACTIVE', '2025-01-01', 'LFPP-2026-0001'),
  ('2e200000-0000-0000-0000-000000000002', '2e100000-0000-0000-0000-000000000001', '2e000000-0000-0000-0000-000000000002', 'LFP Treasurer', 'ACTIVE', '2025-01-01', 'LFPP-2026-0002'),
  ('2e200000-0000-0000-0000-000000000003', '2e100000-0000-0000-0000-000000000001', '2e000000-0000-0000-0000-000000000003', 'LFP Chairperson', 'ACTIVE', '2025-01-01', 'LFPP-2026-0003'),
  ('2e200000-0000-0000-0000-000000000005', '2e100000-0000-0000-0000-000000000001', null, 'LFP Borrower', 'ACTIVE', '2025-01-01', 'LFPP-2026-0005');

insert into public.group_membership_roles (group_membership_id, role_id) select '2e200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select '2e200000-0000-0000-0000-000000000002', id from public.roles where code = 'TREASURER';
insert into public.group_membership_roles (group_membership_id, role_id) select '2e200000-0000-0000-0000-000000000003', id from public.roles where code = 'CHAIRPERSON';

set local role authenticated;
set local request.jwt.claim.sub to '2e000000-0000-0000-0000-000000000001';

-- Cash = 5,000,000; Funded Loan Principal Receivable = 0.
create temporary table t_account as
select public.rpc_create_financial_account(
  '2e100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '2e100000-0000-0000-0000-000000000001', 'NORMAL', 'Mkopo wa Kawaida',
  100000, 1, 12, 5.0000, 'MONTHLY', 'FLAT', 10000000
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

create temporary table t_loan as
select public.rpc_create_draft_loan_account(
  '2e100000-0000-0000-0000-000000000001', '2e200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 1000000, 4, '2026-10-01'
) as result;
select (result->>'id')::uuid as loan_id from t_loan \gset

select public.rpc_submit_loan_account('2e100000-0000-0000-0000-000000000001', :'loan_id'::uuid);

-- Before disbursement — assert the exact starting figures.
select is(
  (public.rpc_get_financial_position('2e100000-0000-0000-0000-000000000001')->>'total_financial_account_balance')::numeric,
  5000000.00::numeric,
  'Before: Cash = 5,000,000'
);
select is(
  (public.rpc_get_financial_position('2e100000-0000-0000-0000-000000000001')->>'funded_loan_principal_receivable')::numeric,
  0.00::numeric,
  'Before: Funded Loan Principal Receivable = 0'
);

set local request.jwt.claim.sub to '2e000000-0000-0000-0000-000000000003';
select public.rpc_approve_loan_account('2e100000-0000-0000-0000-000000000001', :'loan_id'::uuid);

-- Also verify: approved-but-not-disbursed changes NONE of the tracked
-- figures — Approval is authorization only (section 2/38).
select is(
  (public.rpc_get_financial_position('2e100000-0000-0000-0000-000000000001')->>'total_financial_account_balance')::numeric,
  5000000.00::numeric,
  'Approved-but-not-disbursed: Cash is still 5,000,000'
);
select is(
  (public.rpc_get_financial_position('2e100000-0000-0000-0000-000000000001')->>'funded_loan_principal_receivable')::numeric,
  0.00::numeric,
  'Approved-but-not-disbursed: Funded Loan Principal Receivable is still 0'
);

select public.rpc_get_financial_position('2e100000-0000-0000-0000-000000000001') as before_position \gset

-- Disburse 1,000,000.
set local request.jwt.claim.sub to '2e000000-0000-0000-0000-000000000002';
select public.rpc_disburse_loan_account(
  '2e100000-0000-0000-0000-000000000001', :'loan_id'::uuid, :'account_id'::uuid, current_date
);

-- After: Cash = 4,000,000; Funded Principal Receivable = 1,000,000.
select is(
  (public.rpc_get_financial_position('2e100000-0000-0000-0000-000000000001')->>'total_financial_account_balance')::numeric,
  4000000.00::numeric,
  'After: Cash = 4,000,000'
);
select is(
  (public.rpc_get_financial_position('2e100000-0000-0000-0000-000000000001')->>'funded_loan_principal_receivable')::numeric,
  1000000.00::numeric,
  'After: Funded Loan Principal Receivable = 1,000,000'
);

-- operating expense / group income / pass-through / wallet / share
-- capital all unchanged from the pre-disbursement snapshot.
select is(
  (public.rpc_get_financial_position('2e100000-0000-0000-0000-000000000001')->>'expenses')::numeric,
  (:'before_position'::jsonb->>'expenses')::numeric,
  'operating expense unchanged'
);
select is(
  (public.rpc_get_financial_position('2e100000-0000-0000-0000-000000000001')->>'group_income')::numeric,
  (:'before_position'::jsonb->>'group_income')::numeric,
  'group income unchanged'
);
select is(
  (public.rpc_get_financial_position('2e100000-0000-0000-0000-000000000001')->>'pass_through_received')::numeric,
  (:'before_position'::jsonb->>'pass_through_received')::numeric,
  'pass-through unchanged'
);
select is(
  (public.rpc_get_financial_position('2e100000-0000-0000-0000-000000000001')->>'member_wallet_liability')::numeric,
  (:'before_position'::jsonb->>'member_wallet_liability')::numeric,
  'wallet liability unchanged'
);

select * from finish();
rollback;
