-- Prompt 09C: loan closure/reopening (section 34, items 36-44). Loan:
-- principal 400,000, term 1, 5% MONTHLY FLAT -> one installment of
-- 20,000 interest + 400,000 principal = 420,000 total.
begin;

select plan(9);

insert into auth.users (id, email) values
  ('4d000000-0000-0000-0000-000000000001', 'p09c-close-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('4d100000-0000-0000-0000-000000000001', 'P09C Closure Group', '4d000000-0000-0000-0000-000000000001', 'LCLS');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('4d200000-0000-0000-0000-000000000001', '4d100000-0000-0000-0000-000000000001', '4d000000-0000-0000-0000-000000000001', 'LC Admin', 'ACTIVE', '2025-01-01', 'LCLS-2026-0001'),
  ('4d200000-0000-0000-0000-000000000005', '4d100000-0000-0000-0000-000000000001', null, 'LC Borrower', 'ACTIVE', '2025-01-01', 'LCLS-2026-0005');

insert into public.group_membership_roles (group_membership_id, role_id) select '4d200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '4d000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '4d100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '4d100000-0000-0000-0000-000000000001', 'NORMAL', 'Mkopo wa Kawaida',
  100000, 1, 12, 5.0000, 'MONTHLY', 'FLAT', 10000000
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

create temporary table t_loan as
select public.rpc_create_draft_loan_account(
  '4d100000-0000-0000-0000-000000000001', '4d200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 400000, 1, current_date
) as result;
select (result->>'id')::uuid as loan_id from t_loan \gset
select public.rpc_submit_loan_account('4d100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_approve_loan_account('4d100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_disburse_loan_account('4d100000-0000-0000-0000-000000000001', :'loan_id'::uuid, :'account_id'::uuid, current_date);

select id as installment_id from public.loan_installments where loan_account_id = :'loan_id'::uuid \gset

-- 37. "principal zero but interest outstanding" — structurally
-- unreachable via ordinary allocation under the locked
-- interest-before-principal priority, so this is proven directly
-- against the closure predicate itself: manufacture that exact
-- (contrived) ledger state via a raw fixture insert (bypassing the
-- ordinary posting RPCs, purely to isolate the closure boolean logic —
-- the same isolation technique 45_loan_disbursement_atomicity_failure
-- already used for its own constraint-only check), then confirm the
-- closure recheck still leaves the loan ACTIVE because interest is not
-- also zero.
reset role;
insert into public.payments (
  id, group_id, membership_id, financial_account_id, amount, effective_at, payment_method, receipt_number, created_by
) values (
  '4d900000-0000-0000-0000-000000000001', '4d100000-0000-0000-0000-000000000001'::uuid,
  '4d200000-0000-0000-0000-000000000005'::uuid, :'account_id'::uuid, 400000, current_date, 'CASH',
  'MANUAL-TEST-0001', '4d000000-0000-0000-0000-000000000001'
);
insert into public.payment_allocations (
  group_id, payment_id, membership_id, amount, allocation_target_type, loan_account_id, loan_installment_id, created_by
) values (
  '4d100000-0000-0000-0000-000000000001'::uuid, '4d900000-0000-0000-0000-000000000001', '4d200000-0000-0000-0000-000000000005'::uuid,
  400000, 'LOAN_PRINCIPAL', :'loan_id'::uuid, :'installment_id'::uuid, '4d000000-0000-0000-0000-000000000001'
);
select public.loan_account_recheck_closure(
  '4d100000-0000-0000-0000-000000000001'::uuid, :'loan_id'::uuid, '4d000000-0000-0000-0000-000000000001'::uuid
);
select is(
  (select status::text from public.loan_accounts where id = :'loan_id'::uuid),
  'ACTIVE',
  '37: principal fully settled but interest not yet zero (contrived) — the loan stays ACTIVE, never closes on principal alone'
);

-- Undo the contrived state before the real closure test below.
delete from public.payment_allocations where payment_id = '4d900000-0000-0000-0000-000000000001';
delete from public.payments where id = '4d900000-0000-0000-0000-000000000001';
set local role authenticated;
set local request.jwt.claim.sub to '4d000000-0000-0000-0000-000000000001';

-- 36/38. Pay only the interest (20,000) — a partial payment leaves the
-- loan ACTIVE, and specifically the "interest zero, principal still
-- outstanding" shape.
select public.rpc_post_payment(
  '4d100000-0000-0000-0000-000000000001', '4d200000-0000-0000-0000-000000000005'::uuid, :'account_id'::uuid,
  20000, current_date, 'CASH'
);
select is(
  (select status::text from public.loan_accounts where id = :'loan_id'::uuid),
  'ACTIVE',
  '36/38: a partial payment (interest settled, principal still outstanding) leaves the loan ACTIVE'
);

-- 39/40. Fully settle the remaining 400,000 principal — the loan
-- becomes CLOSED, with exactly one CLOSED lifecycle event.
create temporary table t_final_pay as
select public.rpc_post_payment(
  '4d100000-0000-0000-0000-000000000001', '4d200000-0000-0000-0000-000000000005'::uuid, :'account_id'::uuid,
  400000, current_date, 'CASH'
) as result;
select (result->>'payment_id')::uuid as final_payment_id from t_final_pay \gset

select is(
  (select status::text from public.loan_accounts where id = :'loan_id'::uuid),
  'CLOSED',
  '39: a loan whose principal AND interest are both fully settled becomes CLOSED'
);
select is(
  (select count(*) from public.loan_account_events where loan_account_id = :'loan_id'::uuid and event_type = 'CLOSED'),
  1::bigint,
  '40: exactly one CLOSED lifecycle event is written'
);

-- 41. a CLOSED loan cannot receive a further ordinary allocation —
-- collectibility already excludes non-ACTIVE loans (proven for every
-- other status in 47_loan_repayment_allocation_targets), so a payment
-- posted now must allocate zero of it to this loan; the whole amount
-- becomes wallet credit instead.
create temporary table t_pay_after_close as
select public.rpc_post_payment(
  '4d100000-0000-0000-0000-000000000001', '4d200000-0000-0000-0000-000000000005'::uuid, :'account_id'::uuid,
  1000, current_date, 'CASH'
) as result;
select is(
  (select (result->>'wallet_credit_amount')::numeric from t_pay_after_close),
  1000.00::numeric,
  '41: a CLOSED loan receives zero allocation — the full amount becomes wallet credit instead'
);

-- 42/43/44. Reversing the FINAL settlement reopens the loan, audited,
-- with outstanding reconciling exactly back to the pre-closure state
-- (20,000 principal... no: 400,000 principal, 0 interest, since only
-- the final principal-only payment is reversed here).
select public.rpc_reverse_payment('4d100000-0000-0000-0000-000000000001', :'final_payment_id'::uuid, 'entered in error');

select is(
  (select status::text from public.loan_accounts where id = :'loan_id'::uuid),
  'ACTIVE',
  '42: reversing the payment that closed the loan reopens it to ACTIVE'
);
select is(
  (select count(*) from public.loan_account_events where loan_account_id = :'loan_id'::uuid and event_type = 'REOPENED'),
  1::bigint,
  '43: the reopening is itself an audited lifecycle event'
);
reset role;
select is(
  (select coalesce(sum(outstanding), 0) from public.loan_installment_component_states(:'installment_id'::uuid)
   where component_type = 'PRINCIPAL'),
  400000.00::numeric,
  '44a: reopened principal outstanding reconciles exactly to its pre-closure value'
);
select is(
  (select coalesce(sum(outstanding), 0) from public.loan_installment_component_states(:'installment_id'::uuid)
   where component_type = 'INTEREST'),
  0.00::numeric,
  '44b: reopened interest outstanding reconciles exactly (still settled — only the final principal-only payment was reversed)'
);

select * from finish();
rollback;
