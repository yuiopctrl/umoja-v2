-- Prompt 09B: loan disbursement failure/atomicity guarantees.
-- Items 35-49 (section 37).
begin;

select plan(16);

insert into auth.users (id, email) values
  ('2d000000-0000-0000-0000-000000000001', 'p09b-fail-admin@example.com'),
  ('2d000000-0000-0000-0000-000000000002', 'p09b-fail-treasurer@example.com'),
  ('2d000000-0000-0000-0000-000000000003', 'p09b-fail-chairperson@example.com'),
  ('2d000000-0000-0000-0000-000000000004', 'p09b-fail-other-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('2d100000-0000-0000-0000-000000000001', 'P09B Failure Group A', '2d000000-0000-0000-0000-000000000001', 'LFAA'),
  ('2d100000-0000-0000-0000-000000000002', 'P09B Failure Group B', '2d000000-0000-0000-0000-000000000004', 'LFBB');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('2d200000-0000-0000-0000-000000000001', '2d100000-0000-0000-0000-000000000001', '2d000000-0000-0000-0000-000000000001', 'LF Admin', 'ACTIVE', '2025-01-01', 'LFAA-2026-0001'),
  ('2d200000-0000-0000-0000-000000000002', '2d100000-0000-0000-0000-000000000001', '2d000000-0000-0000-0000-000000000002', 'LF Treasurer', 'ACTIVE', '2025-01-01', 'LFAA-2026-0002'),
  ('2d200000-0000-0000-0000-000000000003', '2d100000-0000-0000-0000-000000000001', '2d000000-0000-0000-0000-000000000003', 'LF Chairperson', 'ACTIVE', '2025-01-01', 'LFAA-2026-0003'),
  ('2d200000-0000-0000-0000-000000000005', '2d100000-0000-0000-0000-000000000001', null, 'LF Borrower', 'ACTIVE', '2025-01-01', 'LFAA-2026-0005'),
  ('2d200000-0000-0000-0000-000000000098', '2d100000-0000-0000-0000-000000000002', '2d000000-0000-0000-0000-000000000004', 'LF Group B Admin', 'ACTIVE', '2025-01-01', 'LFBB-2026-0001');

insert into public.group_membership_roles (group_membership_id, role_id) select '2d200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select '2d200000-0000-0000-0000-000000000002', id from public.roles where code = 'TREASURER';
insert into public.group_membership_roles (group_membership_id, role_id) select '2d200000-0000-0000-0000-000000000003', id from public.roles where code = 'CHAIRPERSON';
insert into public.group_membership_roles (group_membership_id, role_id) select '2d200000-0000-0000-0000-000000000098', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '2d000000-0000-0000-0000-000000000001';

-- Cash Box: only 800,000 — deliberately short of a 1,000,000 loan.
create temporary table t_poor_account as
select public.rpc_create_financial_account(
  '2d100000-0000-0000-0000-000000000001', 'Poor Cash Box', 'CASH', 800000, current_date
) as result;
select (result->>'id')::uuid as poor_account_id from t_poor_account \gset

-- A second, inactive account.
create temporary table t_inactive_account as
select public.rpc_create_financial_account(
  '2d100000-0000-0000-0000-000000000001', 'Retired Account', 'CASH', 2000000, current_date
) as result;
select (result->>'id')::uuid as inactive_account_id from t_inactive_account \gset
select public.rpc_update_financial_account(
  '2d100000-0000-0000-0000-000000000001', :'inactive_account_id'::uuid, null, false
);

-- A well-funded account for the idempotency scenario.
create temporary table t_rich_account as
select public.rpc_create_financial_account(
  '2d100000-0000-0000-0000-000000000001', 'Rich Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as rich_account_id from t_rich_account \gset

-- Group B's own financial account, for the cross-group check.
set local request.jwt.claim.sub to '2d000000-0000-0000-0000-000000000004';
create temporary table t_group_b_account as
select public.rpc_create_financial_account(
  '2d100000-0000-0000-0000-000000000002', 'Group B Cash', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as group_b_account_id from t_group_b_account \gset

set local request.jwt.claim.sub to '2d000000-0000-0000-0000-000000000001';
create temporary table t_product as
select public.rpc_create_loan_product(
  '2d100000-0000-0000-0000-000000000001', 'NORMAL', 'Mkopo wa Kawaida',
  100000, 1, 12, 5.0000, 'MONTHLY', 'FLAT', 10000000
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

-- Loan A: DRAFT, never submitted.
create temporary table t_loan_draft as
select public.rpc_create_draft_loan_account(
  '2d100000-0000-0000-0000-000000000001', '2d200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 300000, 3, '2026-10-01'
) as result;
select (result->>'id')::uuid as loan_draft_id from t_loan_draft \gset

-- Loan B: SUBMITTED only.
create temporary table t_loan_submitted as
select public.rpc_create_draft_loan_account(
  '2d100000-0000-0000-0000-000000000001', '2d200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 300000, 3, '2026-10-01'
) as result;
select (result->>'id')::uuid as loan_submitted_id from t_loan_submitted \gset
select public.rpc_submit_loan_account('2d100000-0000-0000-0000-000000000001', :'loan_submitted_id'::uuid);

-- Loan C: for the insufficient-funds scenario. Approved for 1,000,000
-- against the 800,000 Poor Cash Box.
create temporary table t_loan_insufficient as
select public.rpc_create_draft_loan_account(
  '2d100000-0000-0000-0000-000000000001', '2d200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 1000000, 4, '2026-10-01'
) as result;
select (result->>'id')::uuid as loan_insufficient_id from t_loan_insufficient \gset
select public.rpc_submit_loan_account('2d100000-0000-0000-0000-000000000001', :'loan_insufficient_id'::uuid);

-- Loan D: for the idempotency scenario, approved against the Rich Cash Box.
create temporary table t_loan_idempotent as
select public.rpc_create_draft_loan_account(
  '2d100000-0000-0000-0000-000000000001', '2d200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 400000, 2, '2026-10-01'
) as result;
select (result->>'id')::uuid as loan_idempotent_id from t_loan_idempotent \gset
select public.rpc_submit_loan_account('2d100000-0000-0000-0000-000000000001', :'loan_idempotent_id'::uuid);

-- Loan E: REJECTED.
create temporary table t_loan_rejected as
select public.rpc_create_draft_loan_account(
  '2d100000-0000-0000-0000-000000000001', '2d200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 200000, 2, '2026-10-01'
) as result;
select (result->>'id')::uuid as loan_rejected_id from t_loan_rejected \gset
select public.rpc_submit_loan_account('2d100000-0000-0000-0000-000000000001', :'loan_rejected_id'::uuid);

-- Loan F: CANCELLED (from SUBMITTED).
create temporary table t_loan_cancelled as
select public.rpc_create_draft_loan_account(
  '2d100000-0000-0000-0000-000000000001', '2d200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 200000, 2, '2026-10-01'
) as result;
select (result->>'id')::uuid as loan_cancelled_id from t_loan_cancelled \gset
select public.rpc_submit_loan_account('2d100000-0000-0000-0000-000000000001', :'loan_cancelled_id'::uuid);

set local request.jwt.claim.sub to '2d000000-0000-0000-0000-000000000003';
select public.rpc_approve_loan_account('2d100000-0000-0000-0000-000000000001', :'loan_insufficient_id'::uuid);
select public.rpc_approve_loan_account('2d100000-0000-0000-0000-000000000001', :'loan_idempotent_id'::uuid);
select public.rpc_reject_loan_account('2d100000-0000-0000-0000-000000000001', :'loan_rejected_id'::uuid, 'not eligible');
select public.rpc_cancel_loan_account('2d100000-0000-0000-0000-000000000001', :'loan_cancelled_id'::uuid, 'withdrawn');

set local request.jwt.claim.sub to '2d000000-0000-0000-0000-000000000002';

-- 35/36/37/38. wrong-status loans cannot disburse.
select throws_ok(
  format($sql$ select public.rpc_disburse_loan_account(
    '2d100000-0000-0000-0000-000000000001', %L, %L, current_date
  ) $sql$, :'loan_draft_id', :'rich_account_id'),
  'P0001', null,
  '35: a DRAFT loan cannot be disbursed'
);
select throws_ok(
  format($sql$ select public.rpc_disburse_loan_account(
    '2d100000-0000-0000-0000-000000000001', %L, %L, current_date
  ) $sql$, :'loan_submitted_id', :'rich_account_id'),
  'P0001', null,
  '36: a SUBMITTED (not yet APPROVED) loan cannot be disbursed'
);
select throws_ok(
  format($sql$ select public.rpc_disburse_loan_account(
    '2d100000-0000-0000-0000-000000000001', %L, %L, current_date
  ) $sql$, :'loan_rejected_id', :'rich_account_id'),
  'P0001', null,
  '37: a REJECTED loan cannot be disbursed'
);
select throws_ok(
  format($sql$ select public.rpc_disburse_loan_account(
    '2d100000-0000-0000-0000-000000000001', %L, %L, current_date
  ) $sql$, :'loan_cancelled_id', :'rich_account_id'),
  'P0001', null,
  '38: a CANCELLED loan cannot be disbursed'
);

-- 39. inactive financial account rejected.
select throws_ok(
  format($sql$ select public.rpc_disburse_loan_account(
    '2d100000-0000-0000-0000-000000000001', %L, %L, current_date
  ) $sql$, :'loan_idempotent_id', :'inactive_account_id'),
  'P0001', null,
  '39: an inactive financial account is rejected'
);

-- 40. cross-group financial account rejected.
select throws_ok(
  format($sql$ select public.rpc_disburse_loan_account(
    '2d100000-0000-0000-0000-000000000001', %L, %L, current_date
  ) $sql$, :'loan_idempotent_id', :'group_b_account_id'),
  '22023', null,
  '40: a financial account from a different group is rejected'
);

-- 41. insufficient funds rejected.
select throws_ok(
  format($sql$ select public.rpc_disburse_loan_account(
    '2d100000-0000-0000-0000-000000000001', %L, %L, current_date
  ) $sql$, :'loan_insufficient_id', :'poor_account_id'),
  'P0001', null,
  '41: insufficient balance is rejected'
);

-- 42/43/44/45. the failed insufficient-funds attempt left zero trace.
select is(
  (select count(*) from public.loan_disbursements where loan_account_id = :'loan_insufficient_id'::uuid),
  0::bigint,
  '42: the insufficient-funds failure created zero disbursement rows'
);
select is(
  (select count(*) from public.financial_account_entries where financial_account_id = :'poor_account_id'::uuid
   and source_type = 'LOAN_DISBURSEMENT'),
  0::bigint,
  '43: zero cashbook row exists after the failed attempt'
);
select isnt(
  (select status::text from public.loan_accounts where id = :'loan_insufficient_id'::uuid),
  'ACTIVE',
  '44: zero funded-receivable activation after the failed attempt'
);
select is(
  (select status::text from public.loan_accounts where id = :'loan_insufficient_id'::uuid),
  'APPROVED',
  '45: the loan remains APPROVED after the failed disbursement'
);

-- 46/47. duplicate idempotency key returns safely, never posts twice.
select lives_ok(
  format($sql$ select public.rpc_disburse_loan_account(
    '2d100000-0000-0000-0000-000000000001', %L, %L, current_date, null, null, 'idem-key-1'
  ) $sql$, :'loan_idempotent_id', :'rich_account_id'),
  'setup: loan idempotent disburses successfully the first time'
);
select lives_ok(
  format($sql$ select public.rpc_disburse_loan_account(
    '2d100000-0000-0000-0000-000000000001', %L, %L, current_date, null, null, 'idem-key-1'
  ) $sql$, :'loan_idempotent_id', :'rich_account_id'),
  '46: retrying with the same idempotency key does not raise'
);
select is(
  (select count(*) from public.loan_disbursements where loan_account_id = :'loan_idempotent_id'::uuid),
  1::bigint,
  '47: the double-tap created exactly one economic disbursement, not two'
);

-- 48. a second disbursement WITHOUT the matching idempotency key
-- against an already-ACTIVE loan is a real error, not a silent retry.
select throws_ok(
  format($sql$ select public.rpc_disburse_loan_account(
    '2d100000-0000-0000-0000-000000000001', %L, %L, current_date
  ) $sql$, :'loan_idempotent_id', :'rich_account_id'),
  'P0001', null,
  '48: a second disbursement attempt without a matching idempotency key is rejected outright'
);

-- 49. second successful disbursement is structurally impossible — a
-- raw INSERT attempting a second loan_disbursements row for the same
-- loan_account_id violates the unique index regardless of any RPC
-- logic, proven directly against the constraint itself (as the table
-- owner, bypassing the client-role grant question entirely — this
-- checks the constraint, not authorization).
reset role;
select throws_ok(
  format($sql$ insert into public.loan_disbursements (
    group_id, loan_account_id, financial_account_id, amount, effective_at, created_by
  ) values (
    '2d100000-0000-0000-0000-000000000001', %L, %L, 400000, current_date, '2d000000-0000-0000-0000-000000000002'
  ) $sql$, :'loan_idempotent_id', :'rich_account_id'),
  '23505', null,
  '49: a second loan_disbursements row for the same loan is structurally rejected (unique_violation)'
);

select * from finish();
rollback;
