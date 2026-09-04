-- Prompt 09E-CLOSEOUT-BLOCKER-02 sections C/D/E: regression coverage
-- for the prepayment-reversal dependency fix (20260915090000).
-- rpc_reverse_payment's guard against reversing a principal prepayment
-- whose replacement schedule has later activity previously only
-- checked payment_allocations — a later prepayment, restructure, or
-- early settlement could supersede/cancel the replacement schedule
-- WITHOUT ever posting an allocation against it, letting reversal
-- resurrect a stale schedule alongside the new authoritative one. The
-- fix also blocks reversal whenever any of the payment's replacement
-- installments has itself been cancelled by anything since.
begin;

select plan(21);

insert into auth.users (id, email) values
  ('80000000-0000-0000-0000-000000000001', 'p09e-b2-reversal-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('80100000-0000-0000-0000-000000000001', 'Prepay Reversal Group', '80000000-0000-0000-0000-000000000001', 'PREV');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('80200000-0000-0000-0000-000000000001', '80100000-0000-0000-0000-000000000001', '80000000-0000-0000-0000-000000000001', 'PR Admin', 'ACTIVE', '2025-01-01', 'PREV-2026-0001'),
  ('80200000-0000-0000-0000-000000000011', '80100000-0000-0000-0000-000000000001', null, 'PR Borrower 1', 'ACTIVE', '2025-01-01', 'PREV-2026-0011'),
  ('80200000-0000-0000-0000-000000000012', '80100000-0000-0000-0000-000000000001', null, 'PR Borrower 2', 'ACTIVE', '2025-01-01', 'PREV-2026-0012'),
  ('80200000-0000-0000-0000-000000000013', '80100000-0000-0000-0000-000000000001', null, 'PR Borrower 3', 'ACTIVE', '2025-01-01', 'PREV-2026-0013'),
  ('80200000-0000-0000-0000-000000000014', '80100000-0000-0000-0000-000000000001', null, 'PR Borrower 4', 'ACTIVE', '2025-01-01', 'PREV-2026-0014'),
  ('80200000-0000-0000-0000-000000000015', '80100000-0000-0000-0000-000000000001', null, 'PR Borrower 5', 'ACTIVE', '2025-01-01', 'PREV-2026-0015');

insert into public.group_membership_roles (group_membership_id, role_id) select '80200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '80000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '80100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '80100000-0000-0000-0000-000000000001', 'PREVP', 'Prepay Reversal Product', 100000, 1, 12, 0, 'MONTHLY', 'FLAT'
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

-- =======================================================================
-- SCENARIO 1: A -> P1 -> B. Reverse P1 immediately. Expected PASS.
-- =======================================================================

create temporary table t_loan_s1 as
select public.rpc_create_draft_loan_account(
  '80100000-0000-0000-0000-000000000001', '80200000-0000-0000-0000-000000000011'::uuid,
  :'product_id'::uuid, 600000, 6, (current_date + interval '1 month')::date
) as result;
select (result->>'id')::uuid as loan_s1_id from t_loan_s1 \gset
select public.rpc_submit_loan_account('80100000-0000-0000-0000-000000000001', :'loan_s1_id'::uuid);
select public.rpc_approve_loan_account('80100000-0000-0000-0000-000000000001', :'loan_s1_id'::uuid);
select public.rpc_disburse_loan_account('80100000-0000-0000-0000-000000000001', :'loan_s1_id'::uuid, :'account_id'::uuid, current_date);

-- Baseline captured AFTER disbursement (a real, non-reversed cash
-- movement) but BEFORE the prepayment — reversing P1 should return
-- the balance to exactly this point, not to the account's opening
-- balance.
reset role;
select public.financial_account_balance(:'account_id'::uuid) as cash_before_s1 \gset
set local role authenticated;
set local request.jwt.claim.sub to '80000000-0000-0000-0000-000000000001';

create temporary table t_p1_s1 as
select public.rpc_prepay_loan_principal(
  '80100000-0000-0000-0000-000000000001', :'loan_s1_id'::uuid, 200000, 'REDUCE_TERM', :'account_id'::uuid, 'CASH'
) as result;
select (result->>'payment_id')::uuid as p1_s1_id from t_p1_s1 \gset

select public.rpc_reverse_payment('80100000-0000-0000-0000-000000000001', :'p1_s1_id'::uuid, 'test reversal — no later activity');

select is(
  (select count(*)::integer from public.loan_installments where loan_account_id = :'loan_s1_id'::uuid and created_by_payment_id = :'p1_s1_id'::uuid),
  0,
  '1: SCENARIO 1 — replacement schedule B is removed on reversal'
);
select is(
  (select count(*)::integer from public.loan_installments where loan_account_id = :'loan_s1_id'::uuid and cancelled_at is null),
  6,
  '2: SCENARIO 1 — original schedule A is fully restored (all 6 installments live)'
);
select is(
  (public.rpc_get_financial_position('80100000-0000-0000-0000-000000000001')->>'funded_loan_principal_receivable')::numeric,
  600000.00::numeric,
  '3: SCENARIO 1 — principal receivable is restored to the full 600,000'
);
reset role;
select is(
  (public.financial_account_balance(:'account_id'::uuid)),
  :'cash_before_s1'::numeric,
  '4: SCENARIO 1 — cashbook is fully reversed (balance back to pre-prepayment)'
);
set local role authenticated;
set local request.jwt.claim.sub to '80000000-0000-0000-0000-000000000001';
select is(
  (select count(*)::integer from public.loan_installments where loan_account_id = :'loan_s1_id'::uuid and cancelled_at is null),
  6,
  '5: SCENARIO 1 — exactly one active schedule (6 live installments, none overlapping)'
);

-- =======================================================================
-- SCENARIO 2: A -> P1 -> B -> ordinary payment against B. Reverse P1.
-- Expected BLOCKED, no mutation.
-- =======================================================================

create temporary table t_loan_s2 as
select public.rpc_create_draft_loan_account(
  '80100000-0000-0000-0000-000000000001', '80200000-0000-0000-0000-000000000012'::uuid,
  :'product_id'::uuid, 600000, 6, (current_date + interval '1 month')::date
) as result;
select (result->>'id')::uuid as loan_s2_id from t_loan_s2 \gset
select public.rpc_submit_loan_account('80100000-0000-0000-0000-000000000001', :'loan_s2_id'::uuid);
select public.rpc_approve_loan_account('80100000-0000-0000-0000-000000000001', :'loan_s2_id'::uuid);
select public.rpc_disburse_loan_account('80100000-0000-0000-0000-000000000001', :'loan_s2_id'::uuid, :'account_id'::uuid, current_date);

create temporary table t_p1_s2 as
select public.rpc_prepay_loan_principal(
  '80100000-0000-0000-0000-000000000001', :'loan_s2_id'::uuid, 200000, 'REDUCE_TERM', :'account_id'::uuid, 'CASH'
) as result;
select (result->>'payment_id')::uuid as p1_s2_id from t_p1_s2 \gset

-- B's first installment is due (current_date + 1 month) — pay it
-- ordinarily by dating the payment to match.
select public.rpc_post_payment(
  '80100000-0000-0000-0000-000000000001', '80200000-0000-0000-0000-000000000012'::uuid, :'account_id'::uuid,
  100000, (current_date + interval '1 month')::date, 'CASH'
);

select count(*)::integer as installments_s2_before_reversal_attempt from public.loan_installments where loan_account_id = :'loan_s2_id'::uuid \gset

select throws_ok(
  format($sql$ select public.rpc_reverse_payment('80100000-0000-0000-0000-000000000001', %L::uuid, 'blocked attempt') $sql$, :'p1_s2_id'),
  'P0001',
  'LOAN_PREPAYMENT_REVERSAL_BLOCKED_SUBSEQUENT_ACTIVITY',
  '6: SCENARIO 2 — reversal is BLOCKED once an ordinary payment allocated against the replacement schedule'
);
select is(
  (select status from public.payments where id = :'p1_s2_id'::uuid),
  'POSTED',
  '7: SCENARIO 2 — no mutation: P1 is still POSTED (not reversed)'
);
select is(
  (select count(*)::integer from public.loan_installments where loan_account_id = :'loan_s2_id'::uuid),
  :installments_s2_before_reversal_attempt::integer,
  '8: SCENARIO 2 — no mutation: installment row count is unchanged after the blocked attempt'
);

-- =======================================================================
-- SCENARIO 3: A -> P1 -> B -> P2 -> C. Reverse P1. Expected BLOCKED.
-- A must not become active; C remains authoritative.
-- =======================================================================

create temporary table t_loan_s3 as
select public.rpc_create_draft_loan_account(
  '80100000-0000-0000-0000-000000000001', '80200000-0000-0000-0000-000000000013'::uuid,
  :'product_id'::uuid, 600000, 6, (current_date + interval '1 month')::date
) as result;
select (result->>'id')::uuid as loan_s3_id from t_loan_s3 \gset
select public.rpc_submit_loan_account('80100000-0000-0000-0000-000000000001', :'loan_s3_id'::uuid);
select public.rpc_approve_loan_account('80100000-0000-0000-0000-000000000001', :'loan_s3_id'::uuid);
select public.rpc_disburse_loan_account('80100000-0000-0000-0000-000000000001', :'loan_s3_id'::uuid, :'account_id'::uuid, current_date);

create temporary table t_p1_s3 as
select public.rpc_prepay_loan_principal(
  '80100000-0000-0000-0000-000000000001', :'loan_s3_id'::uuid, 100000, 'REDUCE_TERM', :'account_id'::uuid, 'CASH'
) as result;
select (result->>'payment_id')::uuid as p1_s3_id from t_p1_s3 \gset

create temporary table t_p2_s3 as
select public.rpc_prepay_loan_principal(
  '80100000-0000-0000-0000-000000000001', :'loan_s3_id'::uuid, 100000, 'REDUCE_TERM', :'account_id'::uuid, 'CASH'
) as result;
select (result->>'payment_id')::uuid as p2_s3_id from t_p2_s3 \gset

select throws_ok(
  format($sql$ select public.rpc_reverse_payment('80100000-0000-0000-0000-000000000001', %L::uuid, 'blocked — superseded by P2') $sql$, :'p1_s3_id'),
  'P0001',
  'LOAN_PREPAYMENT_REVERSAL_BLOCKED_SUBSEQUENT_ACTIVITY',
  '9: SCENARIO 3 — reversing P1 is BLOCKED once P2 superseded its replacement schedule B'
);
select is(
  (select count(*)::integer from public.loan_installments where loan_account_id = :'loan_s3_id'::uuid and cancelled_by_payment_id = :'p1_s3_id'::uuid and cancelled_at is null),
  0,
  '10: SCENARIO 3 — schedule A did NOT become active again'
);
select is(
  (select count(*)::integer from public.loan_installments where loan_account_id = :'loan_s3_id'::uuid and created_by_payment_id = :'p2_s3_id'::uuid and cancelled_at is null),
  (select count(*)::integer from public.loan_installments where loan_account_id = :'loan_s3_id'::uuid and created_by_payment_id = :'p2_s3_id'::uuid),
  '11: SCENARIO 3 — schedule C (created by P2) remains fully live/authoritative'
);
select is(
  (select count(*)::integer from public.loan_installments where loan_account_id = :'loan_s3_id'::uuid and cancelled_at is null),
  (select count(*)::integer from public.loan_installments where loan_account_id = :'loan_s3_id'::uuid and created_by_payment_id = :'p2_s3_id'::uuid),
  '12: SCENARIO 3 — no overlapping active schedules (only C''s installments are live)'
);

-- =======================================================================
-- SCENARIO 4: A -> P1 -> B -> Restructure -> C. Reverse P1. Expected
-- BLOCKED.
-- =======================================================================

create temporary table t_loan_s4 as
select public.rpc_create_draft_loan_account(
  '80100000-0000-0000-0000-000000000001', '80200000-0000-0000-0000-000000000014'::uuid,
  :'product_id'::uuid, 600000, 6, (current_date + interval '1 month')::date
) as result;
select (result->>'id')::uuid as loan_s4_id from t_loan_s4 \gset
select public.rpc_submit_loan_account('80100000-0000-0000-0000-000000000001', :'loan_s4_id'::uuid);
select public.rpc_approve_loan_account('80100000-0000-0000-0000-000000000001', :'loan_s4_id'::uuid);
select public.rpc_disburse_loan_account('80100000-0000-0000-0000-000000000001', :'loan_s4_id'::uuid, :'account_id'::uuid, current_date);

create temporary table t_p1_s4 as
select public.rpc_prepay_loan_principal(
  '80100000-0000-0000-0000-000000000001', :'loan_s4_id'::uuid, 100000, 'REDUCE_TERM', :'account_id'::uuid, 'CASH'
) as result;
select (result->>'payment_id')::uuid as p1_s4_id from t_p1_s4 \gset

select public.rpc_restructure_loan(
  '80100000-0000-0000-0000-000000000001', :'loan_s4_id'::uuid, 'restructure supersedes B', 4, (current_date + interval '2 months')::date
);

select throws_ok(
  format($sql$ select public.rpc_reverse_payment('80100000-0000-0000-0000-000000000001', %L::uuid, 'blocked — superseded by restructure') $sql$, :'p1_s4_id'),
  'P0001',
  'LOAN_PREPAYMENT_REVERSAL_BLOCKED_SUBSEQUENT_ACTIVITY',
  '13: SCENARIO 4 — reversing P1 is BLOCKED once a restructure superseded its replacement schedule B'
);
select is(
  (select count(*)::integer from public.loan_installments where loan_account_id = :'loan_s4_id'::uuid and cancelled_by_payment_id = :'p1_s4_id'::uuid and cancelled_at is null),
  0,
  '14: SCENARIO 4 — schedule A did NOT become active again'
);
select is(
  (select count(*)::integer from public.loan_installments where loan_account_id = :'loan_s4_id'::uuid and cancelled_at is null),
  4,
  '15: SCENARIO 4 — no overlapping active schedules (only the restructured schedule''s 4 installments are live)'
);

-- =======================================================================
-- SCENARIO 5: A -> P1 -> B -> Early Settlement. Attempt reverse P1.
-- Expected BLOCKED.
-- =======================================================================

create temporary table t_loan_s5 as
select public.rpc_create_draft_loan_account(
  '80100000-0000-0000-0000-000000000001', '80200000-0000-0000-0000-000000000015'::uuid,
  :'product_id'::uuid, 600000, 6, (current_date + interval '1 month')::date
) as result;
select (result->>'id')::uuid as loan_s5_id from t_loan_s5 \gset
select public.rpc_submit_loan_account('80100000-0000-0000-0000-000000000001', :'loan_s5_id'::uuid);
select public.rpc_approve_loan_account('80100000-0000-0000-0000-000000000001', :'loan_s5_id'::uuid);
select public.rpc_disburse_loan_account('80100000-0000-0000-0000-000000000001', :'loan_s5_id'::uuid, :'account_id'::uuid, current_date);

create temporary table t_p1_s5 as
select public.rpc_prepay_loan_principal(
  '80100000-0000-0000-0000-000000000001', :'loan_s5_id'::uuid, 100000, 'REDUCE_TERM', :'account_id'::uuid, 'CASH'
) as result;
select (result->>'payment_id')::uuid as p1_s5_id from t_p1_s5 \gset

select public.rpc_settle_loan_early(
  '80100000-0000-0000-0000-000000000001', :'loan_s5_id'::uuid, :'account_id'::uuid, 'CASH'
);

select throws_ok(
  format($sql$ select public.rpc_reverse_payment('80100000-0000-0000-0000-000000000001', %L::uuid, 'blocked — superseded by settlement') $sql$, :'p1_s5_id'),
  'P0001',
  'LOAN_PREPAYMENT_REVERSAL_BLOCKED_SUBSEQUENT_ACTIVITY',
  '16: SCENARIO 5 — reversing P1 is BLOCKED once an early settlement superseded/closed its replacement schedule'
);
select is(
  (select status from public.loan_accounts where id = :'loan_s5_id'::uuid),
  'CLOSED',
  '17: SCENARIO 5 — the loan remains CLOSED (settlement history is not invalidated)'
);
select is(
  (select count(*)::integer from public.loan_installments where loan_account_id = :'loan_s5_id'::uuid and cancelled_at is null),
  0,
  '18: SCENARIO 5 — no active schedule reappears (A stays cancelled, B stays cancelled by settlement)'
);

-- =======================================================================
-- Cross-cutting: tenant isolation still applies to the enhanced guard.
-- =======================================================================

reset role;
insert into public.groups (id, name, created_by, code) values
  ('80100000-0000-0000-0000-000000000002', 'Prepay Reversal Other Group', '80000000-0000-0000-0000-000000000001', 'PREVB');
insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('80200000-0000-0000-0000-000000000002', '80100000-0000-0000-0000-000000000002', '80000000-0000-0000-0000-000000000001', 'PR Admin (group 2)', 'ACTIVE', '2025-01-01', 'PREVB-2026-0001');
insert into public.group_membership_roles (group_membership_id, role_id)
  select '80200000-0000-0000-0000-000000000002', id from public.roles where code = 'ADMIN';
set local role authenticated;
set local request.jwt.claim.sub to '80000000-0000-0000-0000-000000000001';

select throws_ok(
  format($sql$ select public.rpc_reverse_payment('80100000-0000-0000-0000-000000000002', %L::uuid, 'cross-tenant attempt') $sql$, :'p1_s2_id'),
  '22023',
  'Payment not found in group',
  '19: reversal correctly rejects a payment ID that does not belong to the caller''s own group'
);

select is(
  (select status from public.payments where id = :'p1_s2_id'::uuid),
  'POSTED',
  '20: cross-tenant attempt caused no mutation'
);

select is(
  (select count(*)::integer from public.loan_installments where loan_account_id = :'loan_s1_id'::uuid and cancelled_at is null and due_date > current_date),
  6,
  '21: final sanity — SCENARIO 1''s loan still shows exactly one clean active schedule, unaffected by later scenarios'
);

select * from finish();
rollback;
