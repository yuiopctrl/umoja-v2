-- Prompt 09C-UAT-FIX-02: wallet (and external payment) allocation
-- preview/posted-detail lines must carry enough semantic context —
-- loan_product_name, loan_number, installment_number, due_date — to
-- tell which loan (especially when a member holds MORE THAN ONE
-- ACTIVE loan) an allocation line settles. UX/read-model only: no
-- accounting rule/priority/posting semantic changes.
begin;

select plan(12);

insert into auth.users (id, email) values
  ('5a000000-0000-0000-0000-000000000001', 'p09c-fix02-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('5a100000-0000-0000-0000-000000000001', 'P09C Fix02 Group', '5a000000-0000-0000-0000-000000000001', 'LFX2');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('5a200000-0000-0000-0000-000000000001', '5a100000-0000-0000-0000-000000000001', '5a000000-0000-0000-0000-000000000001', 'LY Admin', 'ACTIVE', '2025-01-01', 'LFX2-2026-0001'),
  ('5a200000-0000-0000-0000-000000000005', '5a100000-0000-0000-0000-000000000001', null, 'LY Borrower', 'ACTIVE', '2025-01-01', 'LFX2-2026-0005');

insert into public.group_membership_roles (group_membership_id, role_id) select '5a200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '5a000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '5a100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

-- Two DISTINCT loan products, so each loan's own product name is
-- unambiguous evidence the correct product was resolved (not merely a
-- shared default).
create temporary table t_product_a as
select public.rpc_create_loan_product(
  '5a100000-0000-0000-0000-000000000001', 'EMLN', 'Emergency Loan',
  100000, 1, 12, 5.0000, 'MONTHLY', 'FLAT', 10000000
) as result;
select (result->>'id')::uuid as product_a_id from t_product_a \gset

create temporary table t_product_b as
select public.rpc_create_loan_product(
  '5a100000-0000-0000-0000-000000000001', 'BIZN', 'Business Loan',
  100000, 1, 12, 5.0000, 'MONTHLY', 'FLAT', 10000000
) as result;
select (result->>'id')::uuid as product_b_id from t_product_b \gset

-- Loan A: Emergency Loan, principal 200,000, term 1 -> 200,000
-- principal + 10,000 interest, due today.
create temporary table t_loan_a as
select public.rpc_create_draft_loan_account(
  '5a100000-0000-0000-0000-000000000001', '5a200000-0000-0000-0000-000000000005'::uuid,
  :'product_a_id'::uuid, 200000, 1, current_date
) as result;
select (result->>'id')::uuid as loan_a_id from t_loan_a \gset
select public.rpc_submit_loan_account('5a100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid);
select public.rpc_approve_loan_account('5a100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid);
select public.rpc_disburse_loan_account('5a100000-0000-0000-0000-000000000001', :'loan_a_id'::uuid, :'account_id'::uuid, current_date);
select loan_number as loan_a_number from public.loan_accounts where id = :'loan_a_id'::uuid \gset

-- Loan B: Business Loan, principal 500,000, term 1 -> 500,000
-- principal + 25,000 interest, due today.
create temporary table t_loan_b as
select public.rpc_create_draft_loan_account(
  '5a100000-0000-0000-0000-000000000001', '5a200000-0000-0000-0000-000000000005'::uuid,
  :'product_b_id'::uuid, 500000, 1, current_date
) as result;
select (result->>'id')::uuid as loan_b_id from t_loan_b \gset
select public.rpc_submit_loan_account('5a100000-0000-0000-0000-000000000001', :'loan_b_id'::uuid);
select public.rpc_approve_loan_account('5a100000-0000-0000-0000-000000000001', :'loan_b_id'::uuid);
select public.rpc_disburse_loan_account('5a100000-0000-0000-0000-000000000001', :'loan_b_id'::uuid, :'account_id'::uuid, current_date);
select loan_number as loan_b_number from public.loan_accounts where id = :'loan_b_id'::uuid \gset

-- ---------------------------------------------------------------------
-- 1-4 (external payment preview): a payment large enough to cover both
-- loans in full must resolve each line's product/number/installment/
-- due date correctly.
-- ---------------------------------------------------------------------

create temporary table t_pay_preview as
select public.rpc_preview_payment_allocation(
  '5a100000-0000-0000-0000-000000000001', '5a200000-0000-0000-0000-000000000005'::uuid,
  :'account_id'::uuid, 1000000, current_date
) as result;

select is(
  (select (a->>'loan_product_name') from jsonb_array_elements((select result->'allocations' from t_pay_preview)) a
   where (a->>'loan_account_id')::uuid = :'loan_a_id'::uuid limit 1),
  'Emergency Loan',
  '1: payment preview resolves loan A''s product name'
);
select is(
  (select (a->>'loan_number') from jsonb_array_elements((select result->'allocations' from t_pay_preview)) a
   where (a->>'loan_account_id')::uuid = :'loan_a_id'::uuid limit 1),
  :'loan_a_number',
  '2: payment preview resolves loan A''s loan number'
);
select is(
  (select (a->>'installment_number')::int from jsonb_array_elements((select result->'allocations' from t_pay_preview)) a
   where (a->>'loan_account_id')::uuid = :'loan_a_id'::uuid limit 1),
  1,
  '3: payment preview resolves the installment number'
);
select is(
  (select (a->>'loan_product_name') from jsonb_array_elements((select result->'allocations' from t_pay_preview)) a
   where (a->>'loan_account_id')::uuid = :'loan_b_id'::uuid limit 1),
  'Business Loan',
  '4: payment preview resolves loan B''s DIFFERENT product name — two ACTIVE loans are distinguishable'
);

-- ---------------------------------------------------------------------
-- 5-8: post the payment, generating wallet credit as a byproduct is
-- not needed here — post exactly the currently-payable total so
-- nothing overflows, then verify rpc_get_payment_detail/rpc_get_receipt
-- both carry the same semantic fields for the POSTED allocations.
-- ---------------------------------------------------------------------

create temporary table t_pay as
select public.rpc_post_payment(
  '5a100000-0000-0000-0000-000000000001', '5a200000-0000-0000-0000-000000000005'::uuid, :'account_id'::uuid,
  735000, current_date, 'CASH'
) as result;
select (result->>'payment_id')::uuid as payment_id from t_pay \gset

create temporary table t_detail as
select public.rpc_get_payment_detail('5a100000-0000-0000-0000-000000000001', :'payment_id'::uuid) as result;

select is(
  (select (a->>'loan_product_name') from jsonb_array_elements((select result->'allocations' from t_detail)) a
   where (a->>'loan_account_id')::uuid = :'loan_a_id'::uuid limit 1),
  'Emergency Loan',
  '5: rpc_get_payment_detail resolves loan A''s product name for a posted allocation'
);
select is(
  (select (a->>'loan_product_name') from jsonb_array_elements((select result->'allocations' from t_detail)) a
   where (a->>'loan_account_id')::uuid = :'loan_b_id'::uuid limit 1),
  'Business Loan',
  '6: rpc_get_payment_detail resolves loan B''s DIFFERENT product name'
);

create temporary table t_receipt as
select public.rpc_get_receipt('5a100000-0000-0000-0000-000000000001', :'payment_id'::uuid) as result;

select ok(
  (select exists(
    select 1 from jsonb_array_elements((select result->'allocations' from t_receipt)) a
    where (a->>'loan_number') = :'loan_a_number' and (a->>'loan_product_name') = 'Emergency Loan'
  )),
  '7: rpc_get_receipt resolves loan A''s number + product name together'
);
select ok(
  (select exists(
    select 1 from jsonb_array_elements((select result->'allocations' from t_receipt)) a
    where (a->>'loan_number') = :'loan_b_number' and (a->>'loan_product_name') = 'Business Loan'
  )),
  '8: rpc_get_receipt resolves loan B''s number + product name together'
);

-- ---------------------------------------------------------------------
-- 9-12: wallet allocation preview — the actual UAT-reported defect.
-- Overpay by 100,000 to create wallet credit, then preview a wallet
-- allocation against a THIRD loan (Loan A again, after a further
-- partial repayment cycle would be redundant — instead prove the
-- generic case using loan B's remainder is already zero, so create a
-- fresh third loan to exercise wallet allocation distinctly).
-- ---------------------------------------------------------------------

create temporary table t_product_c as
select public.rpc_create_loan_product(
  '5a100000-0000-0000-0000-000000000001', 'PERS', 'Personal Loan',
  100000, 1, 12, 5.0000, 'MONTHLY', 'FLAT', 10000000
) as result;
select (result->>'id')::uuid as product_c_id from t_product_c \gset

-- Loans A/B are already fully settled at this point, so with NO
-- obligation yet to consume it, this entire payment becomes wallet
-- credit — never auto-allocated to a loan that doesn't exist yet.
select public.rpc_post_payment(
  '5a100000-0000-0000-0000-000000000001', '5a200000-0000-0000-0000-000000000005'::uuid, :'account_id'::uuid,
  105000, current_date, 'CASH'
);

-- NOW create loan C — a fresh, untouched 105,000 obligation (100,000
-- principal + 5,000 interest) for the wallet allocation to settle.
create temporary table t_loan_c as
select public.rpc_create_draft_loan_account(
  '5a100000-0000-0000-0000-000000000001', '5a200000-0000-0000-0000-000000000005'::uuid,
  :'product_c_id'::uuid, 100000, 1, current_date
) as result;
select (result->>'id')::uuid as loan_c_id from t_loan_c \gset
select public.rpc_submit_loan_account('5a100000-0000-0000-0000-000000000001', :'loan_c_id'::uuid);
select public.rpc_approve_loan_account('5a100000-0000-0000-0000-000000000001', :'loan_c_id'::uuid);
select public.rpc_disburse_loan_account('5a100000-0000-0000-0000-000000000001', :'loan_c_id'::uuid, :'account_id'::uuid, current_date);
select loan_number as loan_c_number from public.loan_accounts where id = :'loan_c_id'::uuid \gset

create temporary table t_wallet_preview as
select public.rpc_preview_wallet_allocation(
  '5a100000-0000-0000-0000-000000000001', '5a200000-0000-0000-0000-000000000005'::uuid, 105000
) as result;

select is(
  (select (a->>'loan_product_name') from jsonb_array_elements((select result->'allocations' from t_wallet_preview)) a
   where (a->>'loan_account_id')::uuid = :'loan_c_id'::uuid limit 1),
  'Personal Loan',
  '9: wallet allocation preview resolves the loan product name (the exact UAT-reported gap)'
);
select is(
  (select (a->>'loan_number') from jsonb_array_elements((select result->'allocations' from t_wallet_preview)) a
   where (a->>'loan_account_id')::uuid = :'loan_c_id'::uuid limit 1),
  :'loan_c_number',
  '10: wallet allocation preview resolves the loan number'
);
select is(
  (select (a->>'installment_number')::int from jsonb_array_elements((select result->'allocations' from t_wallet_preview)) a
   where (a->>'loan_account_id')::uuid = :'loan_c_id'::uuid limit 1),
  1,
  '11: wallet allocation preview resolves the installment number'
);
select is(
  (select (a->>'due_date')::date from jsonb_array_elements((select result->'allocations' from t_wallet_preview)) a
   where (a->>'loan_account_id')::uuid = :'loan_c_id'::uuid limit 1),
  current_date,
  '12: wallet allocation preview resolves the due date'
);

select * from finish();
rollback;
