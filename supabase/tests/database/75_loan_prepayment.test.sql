-- Prompt 09E: Partial Principal Prepayment + REDUCE_TERM/
-- REDUCE_INSTALLMENT recalculation.
--
-- Loan setup (shared across REDUCE_TERM/REDUCE_INSTALLMENT cases):
-- 1,200,000 principal / 12 months / 0% interest FLAT (rate 0 keeps the
-- numeric reconciliation trivial to verify exactly), first installment
-- due one month from now -> every installment is future at prepayment
-- time. principal_due = 100,000/installment. A 500,000 prepayment
-- leaves 700,000 future principal.
--   REDUCE_INSTALLMENT: term stays 12, so 700,000/12 = 58,333.33 base
--     + remainder on the final installment.
--   REDUCE_TERM: keeps the 100,000/installment amount, so
--     ceil(700,000/100,000) = 7 new installments, last one absorbing
--     the exact remainder (0 here, since 700,000 is an exact multiple).
begin;

select plan(20);

insert into auth.users (id, email) values
  ('75000000-0000-0000-0000-000000000001', 'p09e-prepay-admin@example.com'),
  ('75000000-0000-0000-0000-000000000002', 'p09e-prepay-member@example.com');

insert into public.groups (id, name, created_by, code) values
  ('75100000-0000-0000-0000-000000000001', 'Prepayment Group', '75000000-0000-0000-0000-000000000001', 'PREP');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('75200000-0000-0000-0000-000000000001', '75100000-0000-0000-0000-000000000001', '75000000-0000-0000-0000-000000000001', 'PP Admin', 'ACTIVE', '2025-01-01', 'PREP-2026-0001'),
  ('75200000-0000-0000-0000-000000000002', '75100000-0000-0000-0000-000000000001', '75000000-0000-0000-0000-000000000002', 'PP Member', 'ACTIVE', '2025-01-01', 'PREP-2026-0002'),
  ('75200000-0000-0000-0000-000000000005', '75100000-0000-0000-0000-000000000001', null, 'PP Borrower Overdue', 'ACTIVE', '2025-01-01', 'PREP-2026-0005'),
  ('75200000-0000-0000-0000-000000000006', '75100000-0000-0000-0000-000000000001', null, 'PP Borrower Reduce Term', 'ACTIVE', '2025-01-01', 'PREP-2026-0006'),
  ('75200000-0000-0000-0000-000000000007', '75100000-0000-0000-0000-000000000001', null, 'PP Borrower Reduce Installment', 'ACTIVE', '2025-01-01', 'PREP-2026-0007');

insert into public.group_membership_roles (group_membership_id, role_id) select '75200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select '75200000-0000-0000-0000-000000000002', id from public.roles where code = 'MEMBER';

set local role authenticated;
set local request.jwt.claim.sub to '75000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '75100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product_overdue as
select public.rpc_create_loan_product(
  '75100000-0000-0000-0000-000000000001', 'PPOD', 'Prepay Overdue Product', 100000, 1, 12, 2.0, 'MONTHLY', 'FLAT'
) as result;
select (result->>'id')::uuid as product_overdue_id from t_product_overdue \gset

create temporary table t_product_zero as
select public.rpc_create_loan_product(
  '75100000-0000-0000-0000-000000000001', 'PPZ', 'Prepay Zero Rate Product', 100000, 1, 12, 0, 'MONTHLY', 'FLAT'
) as result;
select (result->>'id')::uuid as product_zero_id from t_product_zero \gset

-- ---------------------------------------------------------------------
-- Blocked cases (section 3 v1 lock).
-- ---------------------------------------------------------------------

-- 400,000 principal / 4 months / 2% MONTHLY FLAT, first installment due
-- 2 months ago -> installments due at -2mo/-1mo/today/+1mo. Only
-- installment 4 (due_date > today) is future; installments 1-3 are all
-- "payable" (due_date <= today) and must be fully cleared before any
-- prepayment is allowed. total_interest = 400,000*0.02*4 = 32,000
-- (8,000/installment); principal 100,000/installment.
create temporary table t_loan_overdue as
select public.rpc_create_draft_loan_account(
  '75100000-0000-0000-0000-000000000001', '75200000-0000-0000-0000-000000000005'::uuid,
  :'product_overdue_id'::uuid, 400000, 4, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_overdue_id from t_loan_overdue \gset
select public.rpc_submit_loan_account('75100000-0000-0000-0000-000000000001', :'loan_overdue_id'::uuid);
select public.rpc_approve_loan_account('75100000-0000-0000-0000-000000000001', :'loan_overdue_id'::uuid);
select public.rpc_disburse_loan_account('75100000-0000-0000-0000-000000000001', :'loan_overdue_id'::uuid, :'account_id'::uuid, (current_date - interval '2 months')::date);

select throws_ok(
  format($sql$ select public.rpc_preview_loan_prepayment(%L::uuid, %L::uuid, 50000, 'REDUCE_TERM') $sql$,
    '75100000-0000-0000-0000-000000000001', :'loan_overdue_id'),
  'P0001',
  'LOAN_PREPAYMENT_BLOCKED_OVERDUE_INTEREST',
  '1: prepayment is blocked while overdue interest is outstanding'
);

-- Fully settle installments 1-3 (the only "payable" ones — due_date
-- <= today) via an ordinary payment, leaving installment 4 (future)
-- untouched, so future_principal_outstanding remains positive.
select public.rpc_post_payment(
  '75100000-0000-0000-0000-000000000001', '75200000-0000-0000-0000-000000000005'::uuid, :'account_id'::uuid,
  324000, current_date, 'CASH'
);

select is(
  ((public.rpc_preview_loan_prepayment(
    '75100000-0000-0000-0000-000000000001', :'loan_overdue_id'::uuid, 50000, 'REDUCE_TERM'
  ))->>'future_principal_outstanding_before')::numeric,
  100000.00::numeric,
  '2: once every payable installment is cleared, prepayment preview succeeds against the remaining future principal'
);

-- ---------------------------------------------------------------------
-- REDUCE_TERM.
-- ---------------------------------------------------------------------

create temporary table t_loan_term as
select public.rpc_create_draft_loan_account(
  '75100000-0000-0000-0000-000000000001', '75200000-0000-0000-0000-000000000006'::uuid,
  :'product_zero_id'::uuid, 1200000, 12, (current_date + interval '1 month')::date
) as result;
select (result->>'id')::uuid as loan_term_id from t_loan_term \gset
select public.rpc_submit_loan_account('75100000-0000-0000-0000-000000000001', :'loan_term_id'::uuid);
select public.rpc_approve_loan_account('75100000-0000-0000-0000-000000000001', :'loan_term_id'::uuid);
select public.rpc_disburse_loan_account('75100000-0000-0000-0000-000000000001', :'loan_term_id'::uuid, :'account_id'::uuid, current_date);

create temporary table t_preview_term as
select public.rpc_preview_loan_prepayment(
  '75100000-0000-0000-0000-000000000001', :'loan_term_id'::uuid, 500000, 'REDUCE_TERM'
) as result;
select is(
  (select jsonb_array_length(result->'new_future_installments') from t_preview_term),
  7,
  '3: REDUCE_TERM preview shortens the term to 7 installments (700,000 / 100,000)'
);
select is(
  (select (result->'new_future_installments'->0->>'principal_due')::numeric from t_preview_term),
  100000.00::numeric,
  '4: REDUCE_TERM preserves the original per-installment principal amount'
);

select count(*) as payments_before_term from public.payments where membership_id = '75200000-0000-0000-0000-000000000006'::uuid \gset
select is(:payments_before_term::integer, 0, '5: prepayment preview writes nothing');

create temporary table t_prepay_term as
select public.rpc_prepay_loan_principal(
  '75100000-0000-0000-0000-000000000001', :'loan_term_id'::uuid, 500000, 'REDUCE_TERM', :'account_id'::uuid, 'CASH'
) as result;
select (result->>'payment_id')::uuid as prepay_term_payment_id from t_prepay_term \gset

select is(
  (select count(*)::integer from public.loan_installments where loan_account_id = :'loan_term_id'::uuid and cancelled_at is not null),
  12,
  '6: all 12 original installments are cancelled, never deleted'
);
select is(
  (select count(*)::integer from public.loan_installments where loan_account_id = :'loan_term_id'::uuid and created_by_payment_id = :'prepay_term_payment_id'::uuid),
  7,
  '7: exactly 7 replacement installments are created'
);
select is(
  (select coalesce(sum(principal_due), 0) from public.loan_installments
    where loan_account_id = :'loan_term_id'::uuid and created_by_payment_id = :'prepay_term_payment_id'::uuid),
  700000.00::numeric,
  '8: exact numeric reconciliation — new installments sum to exactly the remaining 700,000 principal'
);
select is(
  (select count(*)::integer from public.financial_account_entries where source_type = 'PAYMENT' and source_id = :'prepay_term_payment_id'::uuid),
  1,
  '9: prepayment creates exactly one cashbook inflow'
);
select is(
  (select receipt_number is not null from public.payments where id = :'prepay_term_payment_id'::uuid),
  true,
  '10: prepayment creates exactly one receipt'
);
select is(
  (select coalesce(sum(pa.amount), 0) from public.payment_allocations pa
    where pa.payment_id = :'prepay_term_payment_id'::uuid and pa.allocation_target_type = 'LOAN_PRINCIPAL'),
  0.00::numeric,
  '11: prepayment never allocates as ordinary LOAN_PRINCIPAL (it is LOAN_PRINCIPAL_PREPAYMENT, not income)'
);
select is(
  (select coalesce(sum(pa.amount), 0) from public.payment_allocations pa
    where pa.payment_id = :'prepay_term_payment_id'::uuid and pa.allocation_target_type = 'LOAN_INTEREST'),
  0.00::numeric,
  '12: prepayment never recognizes any interest as income'
);
select is(
  (select coalesce(sum(li.interest_due), 0) from public.loan_installments li
    where li.loan_account_id = :'loan_term_id'::uuid and li.created_by_payment_id = :'prepay_term_payment_id'::uuid),
  0.00::numeric,
  '13: recomputed future interest remains unearned (zero-rate product, all future)'
);

-- ---------------------------------------------------------------------
-- REDUCE_INSTALLMENT.
-- ---------------------------------------------------------------------

create temporary table t_loan_inst as
select public.rpc_create_draft_loan_account(
  '75100000-0000-0000-0000-000000000001', '75200000-0000-0000-0000-000000000007'::uuid,
  :'product_zero_id'::uuid, 1200000, 12, (current_date + interval '1 month')::date
) as result;
select (result->>'id')::uuid as loan_inst_id from t_loan_inst \gset
select public.rpc_submit_loan_account('75100000-0000-0000-0000-000000000001', :'loan_inst_id'::uuid);
select public.rpc_approve_loan_account('75100000-0000-0000-0000-000000000001', :'loan_inst_id'::uuid);
select public.rpc_disburse_loan_account('75100000-0000-0000-0000-000000000001', :'loan_inst_id'::uuid, :'account_id'::uuid, current_date);

create temporary table t_prepay_inst as
select public.rpc_prepay_loan_principal(
  '75100000-0000-0000-0000-000000000001', :'loan_inst_id'::uuid, 500000, 'REDUCE_INSTALLMENT', :'account_id'::uuid, 'CASH'
) as result;
select (result->>'payment_id')::uuid as prepay_inst_payment_id from t_prepay_inst \gset

select is(
  (select count(*)::integer from public.loan_installments where loan_account_id = :'loan_inst_id'::uuid and created_by_payment_id = :'prepay_inst_payment_id'::uuid),
  12,
  '14: REDUCE_INSTALLMENT preserves the original term (still 12 installments)'
);
select is(
  (select coalesce(sum(principal_due), 0) from public.loan_installments
    where loan_account_id = :'loan_inst_id'::uuid and created_by_payment_id = :'prepay_inst_payment_id'::uuid),
  700000.00::numeric,
  '15: exact numeric reconciliation — REDUCE_INSTALLMENT also sums to exactly 700,000'
);
select is(
  (select max(due_date) from public.loan_installments where loan_account_id = :'loan_inst_id'::uuid and created_by_payment_id = :'prepay_inst_payment_id'::uuid),
  (select max(due_date) from public.loan_installments where loan_account_id = :'loan_inst_id'::uuid and cancelled_at is not null),
  '16: REDUCE_INSTALLMENT preserves the original final due date'
);

-- ---------------------------------------------------------------------
-- Idempotency + security.
-- ---------------------------------------------------------------------

create temporary table t_loan_idem as
select public.rpc_create_draft_loan_account(
  '75100000-0000-0000-0000-000000000001', '75200000-0000-0000-0000-000000000006'::uuid,
  :'product_zero_id'::uuid, 600000, 6, (current_date + interval '1 month')::date
) as result;
select (result->>'id')::uuid as loan_idem_id from t_loan_idem \gset
select public.rpc_submit_loan_account('75100000-0000-0000-0000-000000000001', :'loan_idem_id'::uuid);
select public.rpc_approve_loan_account('75100000-0000-0000-0000-000000000001', :'loan_idem_id'::uuid);
select public.rpc_disburse_loan_account('75100000-0000-0000-0000-000000000001', :'loan_idem_id'::uuid, :'account_id'::uuid, current_date);

select public.rpc_prepay_loan_principal(
  '75100000-0000-0000-0000-000000000001', :'loan_idem_id'::uuid, 100000, 'REDUCE_TERM', :'account_id'::uuid, 'CASH',
  p_idempotency_key => 'prepay-idem-1'
);
select is(
  (select count(*)::integer from public.payments where idempotency_key = 'prepay-idem-1'),
  1,
  '17: retrying with the same idempotency key never creates a second payment'
);
select public.rpc_prepay_loan_principal(
  '75100000-0000-0000-0000-000000000001', :'loan_idem_id'::uuid, 100000, 'REDUCE_TERM', :'account_id'::uuid, 'CASH',
  p_idempotency_key => 'prepay-idem-1'
);
select is(
  (select count(*)::integer from public.payments where idempotency_key = 'prepay-idem-1'),
  1,
  '18: a second identical call is idempotent (still exactly one payment)'
);

set local request.jwt.claim.sub to '75000000-0000-0000-0000-000000000002';
select throws_ok(
  format($sql$ select public.rpc_prepay_loan_principal(%L::uuid, %L::uuid, 50000, 'REDUCE_TERM', %L::uuid, 'CASH') $sql$,
    '75100000-0000-0000-0000-000000000001', :'loan_term_id', :'account_id'),
  '42501',
  null,
  '19: a MEMBER without loan.prepay_principal is rejected'
);

set local request.jwt.claim.sub to '75000000-0000-0000-0000-000000000001';
select throws_ok(
  format($sql$ select public.loan_prepayment_eligibility(%L::uuid, current_date) $sql$, :'loan_term_id'),
  '42501',
  null,
  '20: loan_prepayment_eligibility is not directly executable by authenticated'
);

select * from finish();
rollback;
