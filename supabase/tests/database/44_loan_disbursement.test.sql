-- Prompt 09B: atomic loan disbursement — happy path + accounting
-- isolation. Items 19-34 (section 36).
begin;

select plan(18);

insert into auth.users (id, email) values
  ('2c000000-0000-0000-0000-000000000001', 'p09b-disb-admin@example.com'),
  ('2c000000-0000-0000-0000-000000000002', 'p09b-disb-treasurer@example.com'),
  ('2c000000-0000-0000-0000-000000000003', 'p09b-disb-chairperson@example.com');

insert into public.groups (id, name, created_by, code) values
  ('2c100000-0000-0000-0000-000000000001', 'P09B Disbursement Group', '2c000000-0000-0000-0000-000000000001', 'LDIS');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('2c200000-0000-0000-0000-000000000001', '2c100000-0000-0000-0000-000000000001', '2c000000-0000-0000-0000-000000000001', 'LD Admin', 'ACTIVE', '2025-01-01', 'LDIS-2026-0001'),
  ('2c200000-0000-0000-0000-000000000002', '2c100000-0000-0000-0000-000000000001', '2c000000-0000-0000-0000-000000000002', 'LD Treasurer', 'ACTIVE', '2025-01-01', 'LDIS-2026-0002'),
  ('2c200000-0000-0000-0000-000000000003', '2c100000-0000-0000-0000-000000000001', '2c000000-0000-0000-0000-000000000003', 'LD Chairperson', 'ACTIVE', '2025-01-01', 'LDIS-2026-0003'),
  ('2c200000-0000-0000-0000-000000000005', '2c100000-0000-0000-0000-000000000001', null, 'LD Borrower', 'ACTIVE', '2025-01-01', 'LDIS-2026-0005');

insert into public.group_membership_roles (group_membership_id, role_id) select '2c200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select '2c200000-0000-0000-0000-000000000002', id from public.roles where code = 'TREASURER';
insert into public.group_membership_roles (group_membership_id, role_id) select '2c200000-0000-0000-0000-000000000003', id from public.roles where code = 'CHAIRPERSON';

set local role authenticated;
set local request.jwt.claim.sub to '2c000000-0000-0000-0000-000000000001';

-- Cash Box seeded with a known 5,000,000 opening balance.
create temporary table t_account as
select public.rpc_create_financial_account(
  '2c100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '2c100000-0000-0000-0000-000000000001', 'NORMAL', 'Mkopo wa Kawaida',
  100000, 1, 12, 5.0000, 'MONTHLY', 'FLAT', 10000000
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

create temporary table t_loan as
select public.rpc_create_draft_loan_account(
  '2c100000-0000-0000-0000-000000000001', '2c200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 1000000, 4, '2026-10-01'
) as result;
select (result->>'id')::uuid as loan_id from t_loan \gset

select public.rpc_submit_loan_account('2c100000-0000-0000-0000-000000000001', :'loan_id'::uuid);

set local request.jwt.claim.sub to '2c000000-0000-0000-0000-000000000003';
select public.rpc_approve_loan_account('2c100000-0000-0000-0000-000000000001', :'loan_id'::uuid);

-- Baselines before disbursement — every one of these must be
-- unchanged afterward (items 28-34).
select public.rpc_get_financial_position('2c100000-0000-0000-0000-000000000001') as before_position \gset

set local request.jwt.claim.sub to '2c000000-0000-0000-0000-000000000002';

-- 19. Approved loan disburses successfully.
select lives_ok(
  format($sql$ select public.rpc_disburse_loan_account(
    '2c100000-0000-0000-0000-000000000001', %L, %L, '2026-10-05', 'ref-1', 'first disbursement'
  ) $sql$, :'loan_id', :'account_id'),
  '19: an APPROVED loan disburses successfully'
);

-- 20. disbursement amount equals principal exactly.
select is(
  (select amount from public.loan_disbursements where loan_account_id = :'loan_id'::uuid),
  1000000.00::numeric,
  '20: disbursement amount equals the loan''s exact principal'
);

-- 21. exactly one disbursement row.
select is(
  (select count(*) from public.loan_disbursements where loan_account_id = :'loan_id'::uuid),
  1::bigint,
  '21: exactly one disbursement row exists for this loan'
);

-- 22. exactly one cashbook OUTFLOW for this disbursement.
select is(
  (select count(*) from public.financial_account_entries
   where source_type = 'LOAN_DISBURSEMENT' and source_id = (
     select id from public.loan_disbursements where loan_account_id = :'loan_id'::uuid
   )),
  1::bigint,
  '22: exactly one cashbook entry is linked to the disbursement'
);
select is(
  (select entry_type::text from public.financial_account_entries
   where source_type = 'LOAN_DISBURSEMENT' and source_id = (
     select id from public.loan_disbursements where loan_account_id = :'loan_id'::uuid
   )),
  'OUTFLOW',
  '22b: the cashbook entry is an OUTFLOW'
);

-- 23. correct financial account.
select is(
  (select financial_account_id from public.loan_disbursements where loan_account_id = :'loan_id'::uuid),
  :'account_id'::uuid,
  '23: the disbursement is linked to the chosen financial account'
);

-- 24. correct effective_at.
select is(
  (select effective_at from public.loan_disbursements where loan_account_id = :'loan_id'::uuid),
  '2026-10-05'::date,
  '24: the disbursement records the exact effective_at supplied'
);

-- 25. account balance decreases exactly by the principal (derived
-- directly from the cashbook — financial_account_balance() itself is
-- an internal helper with no client grant, by design).
select is(
  (select coalesce(sum(case when entry_type in ('INFLOW', 'TRANSFER_IN') then amount else -amount end), 0)
   from public.financial_account_entries where financial_account_id = :'account_id'::uuid),
  4000000.00::numeric,
  '25: the financial account balance decreases by exactly the principal'
);

-- 26. loan principal becomes funded receivable / 27. installments
-- collectible — status is ACTIVE (DISBURSED is transactional, never
-- observed at rest — see rpc_disburse_loan_account), and Financial
-- Position's funded_loan_principal_receivable reflects it.
select is(
  (select status::text from public.loan_accounts where id = :'loan_id'::uuid),
  'ACTIVE',
  '26: the loan transitions straight to ACTIVE (funded) on disbursement'
);
select is(
  (public.rpc_get_financial_position('2c100000-0000-0000-0000-000000000001')->>'funded_loan_principal_receivable')::numeric,
  1000000.00::numeric,
  '27: Financial Position reports the funded principal receivable exactly'
);
select is(
  (select count(*) from public.loan_installments where loan_account_id = :'loan_id'::uuid),
  4::bigint,
  '27b: the loan''s 4 installments remain in place (nothing duplicated/removed)'
);

-- 28. group income unchanged.
select is(
  (public.rpc_get_financial_position('2c100000-0000-0000-0000-000000000001')->>'group_income')::numeric,
  (:'before_position'::jsonb->>'group_income')::numeric,
  '28: group_income is unchanged by disbursement'
);

-- 29. operating expense unchanged.
select is(
  (public.rpc_get_financial_position('2c100000-0000-0000-0000-000000000001')->>'expenses')::numeric,
  (:'before_position'::jsonb->>'expenses')::numeric,
  '29: expenses (operating) are unchanged by disbursement'
);

-- 30. wallet unchanged.
select is(
  (public.rpc_get_financial_position('2c100000-0000-0000-0000-000000000001')->>'member_wallet_liability')::numeric,
  (:'before_position'::jsonb->>'member_wallet_liability')::numeric,
  '30: member_wallet_liability is unchanged by disbursement'
);

-- 31. payments unchanged.
select is(
  (select count(*) from public.payments where group_id = '2c100000-0000-0000-0000-000000000001'::uuid),
  0::bigint,
  '31: no payment row was created by disbursement'
);

-- 32. allocations unchanged.
select is(
  (select count(*) from public.payment_allocations where group_id = '2c100000-0000-0000-0000-000000000001'::uuid),
  0::bigint,
  '32: no payment allocation row was created by disbursement'
);

-- 33. receipts unchanged — a payment receipt_number only ever exists
-- on a payments row, already proven absent above; no separate
-- receipts table exists to check.
select is(
  (select count(*) from public.member_wallet_entries mwe
   join public.group_memberships gm on gm.id = mwe.membership_id
   where gm.group_id = '2c100000-0000-0000-0000-000000000001'::uuid),
  0::bigint,
  '33: no wallet entry (and therefore no receipt-linked credit) was created'
);

-- 34. contribution obligations unchanged.
select is(
  (select count(*) from public.member_contribution_charges mcc
   join public.group_memberships gm on gm.id = mcc.membership_id
   where gm.group_id = '2c100000-0000-0000-0000-000000000001'::uuid),
  0::bigint,
  '34: no contribution charge/obligation was created by disbursement'
);

select * from finish();
rollback;
