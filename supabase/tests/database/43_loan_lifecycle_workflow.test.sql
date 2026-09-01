-- Prompt 09B: loan lifecycle workflow (Submit/Approve/Reject/Cancel).
-- Items 1-18 (section 35).
begin;

select plan(23);

insert into auth.users (id, email) values
  ('2b000000-0000-0000-0000-000000000001', 'p09b-admin@example.com'),
  ('2b000000-0000-0000-0000-000000000002', 'p09b-treasurer@example.com'),
  ('2b000000-0000-0000-0000-000000000003', 'p09b-chairperson@example.com'),
  ('2b000000-0000-0000-0000-000000000004', 'p09b-member@example.com'),
  ('2b000000-0000-0000-0000-000000000005', 'p09b-other-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('2b100000-0000-0000-0000-000000000001', 'P09B Group A', '2b000000-0000-0000-0000-000000000001', 'LBAA'),
  ('2b100000-0000-0000-0000-000000000002', 'P09B Group B', '2b000000-0000-0000-0000-000000000005', 'LBBB');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('2b200000-0000-0000-0000-000000000001', '2b100000-0000-0000-0000-000000000001', '2b000000-0000-0000-0000-000000000001', 'LB Admin', 'ACTIVE', '2025-01-01', 'LBAA-2026-0001'),
  ('2b200000-0000-0000-0000-000000000002', '2b100000-0000-0000-0000-000000000001', '2b000000-0000-0000-0000-000000000002', 'LB Treasurer', 'ACTIVE', '2025-01-01', 'LBAA-2026-0002'),
  ('2b200000-0000-0000-0000-000000000003', '2b100000-0000-0000-0000-000000000001', '2b000000-0000-0000-0000-000000000003', 'LB Chairperson', 'ACTIVE', '2025-01-01', 'LBAA-2026-0003'),
  ('2b200000-0000-0000-0000-000000000004', '2b100000-0000-0000-0000-000000000001', '2b000000-0000-0000-0000-000000000004', 'LB Member', 'ACTIVE', '2025-01-01', 'LBAA-2026-0004'),
  ('2b200000-0000-0000-0000-000000000005', '2b100000-0000-0000-0000-000000000001', null, 'LB Borrower', 'ACTIVE', '2025-01-01', 'LBAA-2026-0005'),
  ('2b200000-0000-0000-0000-000000000098', '2b100000-0000-0000-0000-000000000002', '2b000000-0000-0000-0000-000000000005', 'LB Group B Admin', 'ACTIVE', '2025-01-01', 'LBBB-2026-0001');

insert into public.group_membership_roles (group_membership_id, role_id) select '2b200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select '2b200000-0000-0000-0000-000000000002', id from public.roles where code = 'TREASURER';
insert into public.group_membership_roles (group_membership_id, role_id) select '2b200000-0000-0000-0000-000000000003', id from public.roles where code = 'CHAIRPERSON';
insert into public.group_membership_roles (group_membership_id, role_id) select '2b200000-0000-0000-0000-000000000004', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id) select '2b200000-0000-0000-0000-000000000098', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '2b000000-0000-0000-0000-000000000001';

create temporary table t_product as
select public.rpc_create_loan_product(
  '2b100000-0000-0000-0000-000000000001', 'NORMAL', 'Mkopo wa Kawaida',
  100000, 1, 12, 5.0000, 'MONTHLY', 'FLAT', 10000000
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

-- Loan #1: the one carried through the whole Submit -> Approve path.
create temporary table t_loan1 as
select public.rpc_create_draft_loan_account(
  '2b100000-0000-0000-0000-000000000001', '2b200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 1000000, 4, '2026-10-01'
) as result;
select (result->>'id')::uuid as loan1_id from t_loan1 \gset

-- Loan #2: carried through Submit -> Reject.
create temporary table t_loan2 as
select public.rpc_create_draft_loan_account(
  '2b100000-0000-0000-0000-000000000001', '2b200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 500000, 3, '2026-10-01'
) as result;
select (result->>'id')::uuid as loan2_id from t_loan2 \gset

-- 1. Draft -> Submitted works.
select lives_ok(
  format($sql$ select public.rpc_submit_loan_account(
    '2b100000-0000-0000-0000-000000000001', %L
  ) $sql$, :'loan1_id'),
  '1: Draft -> Submitted works'
);
select is(
  (select status::text from public.loan_accounts where id = :'loan1_id'::uuid),
  'SUBMITTED',
  '1b: loan #1 is now SUBMITTED'
);

-- 11. lifecycle actor recorded / 12. timestamps recorded.
select is(
  (select created_by from public.loan_account_events
   where loan_account_id = :'loan1_id'::uuid and event_type = 'SUBMITTED'),
  '2b000000-0000-0000-0000-000000000001'::uuid,
  '11: SUBMITTED event records the actor'
);
select ok(
  (select created_at from public.loan_account_events
   where loan_account_id = :'loan1_id'::uuid and event_type = 'SUBMITTED') is not null,
  '12: SUBMITTED event records a timestamp'
);

-- 4. invalid Draft -> Approved rejected (loan #1 is SUBMITTED, not DRAFT,
-- so approving loan #2 — still DRAFT — must fail).
select throws_ok(
  format($sql$ select public.rpc_approve_loan_account(
    '2b100000-0000-0000-0000-000000000001', %L
  ) $sql$, :'loan2_id'),
  'P0001', null,
  '4: approving a DRAFT (not yet SUBMITTED) loan is rejected'
);

-- Now switch to the CHAIRPERSON to approve loan #1.
set local request.jwt.claim.sub to '2b000000-0000-0000-0000-000000000003';

-- 2. Submitted -> Approved works.
select lives_ok(
  format($sql$ select public.rpc_approve_loan_account(
    '2b100000-0000-0000-0000-000000000001', %L
  ) $sql$, :'loan1_id'),
  '2: Submitted -> Approved works'
);
select is(
  (select status::text from public.loan_accounts where id = :'loan1_id'::uuid),
  'APPROVED',
  '2b: loan #1 is now APPROVED'
);

-- 5. Approved -> Reject rejected.
select throws_ok(
  format($sql$ select public.rpc_reject_loan_account(
    '2b100000-0000-0000-0000-000000000001', %L, 'too late'
  ) $sql$, :'loan1_id'),
  'P0001', null,
  '5: rejecting an already-APPROVED loan is rejected'
);

-- 9. Submitted terms immutable / 10. schedule regeneration blocked
-- after submission — loan #1 is now APPROVED (well past SUBMITTED),
-- so both the ordinary edit and regenerate RPCs must refuse it.
set local request.jwt.claim.sub to '2b000000-0000-0000-0000-000000000002';
select throws_ok(
  format($sql$ select public.rpc_update_draft_loan_terms(
    '2b100000-0000-0000-0000-000000000001', %L, null, 6
  ) $sql$, :'loan1_id'),
  'P0001', null,
  '9: an APPROVED loan''s terms cannot be edited via the ordinary DRAFT-only RPC'
);
select throws_ok(
  format($sql$ select public.rpc_regenerate_loan_schedule(
    '2b100000-0000-0000-0000-000000000001', %L
  ) $sql$, :'loan1_id'),
  'P0001', null,
  '10: schedule regeneration is blocked once a loan has left DRAFT'
);

-- Submit and reject loan #2.
select lives_ok(
  format($sql$ select public.rpc_submit_loan_account(
    '2b100000-0000-0000-0000-000000000001', %L
  ) $sql$, :'loan2_id'),
  'setup: loan #2 submitted'
);

set local request.jwt.claim.sub to '2b000000-0000-0000-0000-000000000003';

-- 13. rejection reason required.
select throws_ok(
  format($sql$ select public.rpc_reject_loan_account(
    '2b100000-0000-0000-0000-000000000001', %L, ''
  ) $sql$, :'loan2_id'),
  '22023', null,
  '13: an empty rejection reason is rejected'
);

-- 3. Submitted -> Rejected works.
select lives_ok(
  format($sql$ select public.rpc_reject_loan_account(
    '2b100000-0000-0000-0000-000000000001', %L, 'insufficient collateral discussion'
  ) $sql$, :'loan2_id'),
  '3: Submitted -> Rejected works'
);
select is(
  (select status::text from public.loan_accounts where id = :'loan2_id'::uuid),
  'REJECTED',
  '3b: loan #2 is now REJECTED'
);

-- 6. Rejected -> Disburse rejected.
select throws_ok(
  format($sql$ select public.rpc_disburse_loan_account(
    '2b100000-0000-0000-0000-000000000001', %L,
    (select id from public.financial_accounts limit 1), current_date
  ) $sql$, :'loan2_id'),
  null, null,
  '6: a REJECTED loan cannot be disbursed'
);

-- 7. Cancelled -> Disburse rejected — cancel loan #1's sibling first via
-- a fresh DRAFT loan cancelled through the DRAFT-only path, then a
-- SUBMITTED-then-CANCELLED loan through the new cancel RPC.
set local request.jwt.claim.sub to '2b000000-0000-0000-0000-000000000001';
create temporary table t_loan3 as
select public.rpc_create_draft_loan_account(
  '2b100000-0000-0000-0000-000000000001', '2b200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 200000, 2, '2026-10-01'
) as result;
select (result->>'id')::uuid as loan3_id from t_loan3 \gset
select public.rpc_submit_loan_account('2b100000-0000-0000-0000-000000000001', :'loan3_id'::uuid);

set local request.jwt.claim.sub to '2b000000-0000-0000-0000-000000000003';
select lives_ok(
  format($sql$ select public.rpc_cancel_loan_account(
    '2b100000-0000-0000-0000-000000000001', %L, 'borrower withdrew request'
  ) $sql$, :'loan3_id'),
  'setup: loan #3 cancelled from SUBMITTED'
);
select throws_ok(
  format($sql$ select public.rpc_disburse_loan_account(
    '2b100000-0000-0000-0000-000000000001', %L,
    (select id from public.financial_accounts limit 1), current_date
  ) $sql$, :'loan3_id'),
  null, null,
  '7: a CANCELLED loan cannot be disbursed'
);

-- 8. Approved terms immutable (loan #1 already covered above via
-- update_draft_loan_terms/regenerate as items 9/10, both while
-- APPROVED — restated here explicitly for the "approved terms
-- immutable" checklist item).
select is(
  (select term from public.loan_accounts where id = :'loan1_id'::uuid),
  4,
  '8: an APPROVED loan''s term is unchanged by the blocked edit attempt above'
);

-- 14. lifecycle events immutable — no UPDATE/DELETE grant exists for
-- any client role on loan_account_events.
select is(
  (select count(*) from information_schema.role_table_grants
   where table_schema = 'public' and table_name = 'loan_account_events'
     and grantee in ('authenticated', 'anon')
     and privilege_type in ('INSERT', 'UPDATE', 'DELETE')),
  0::bigint,
  '14: loan_account_events grants no INSERT/UPDATE/DELETE to any client role'
);

-- 15/16/17. unauthorized submit/approve/reject rejected — a fresh
-- DRAFT (loan #4, created by ADMIN) attempted by a plain MEMBER, who
-- holds none of the new lifecycle permissions.
set local request.jwt.claim.sub to '2b000000-0000-0000-0000-000000000001';
create temporary table t_loan4 as
select public.rpc_create_draft_loan_account(
  '2b100000-0000-0000-0000-000000000001', '2b200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 150000, 2, '2026-10-01'
) as result;
select (result->>'id')::uuid as loan4_id from t_loan4 \gset

set local request.jwt.claim.sub to '2b000000-0000-0000-0000-000000000004';
select throws_ok(
  format($sql$ select public.rpc_submit_loan_account(
    '2b100000-0000-0000-0000-000000000001', %L
  ) $sql$, :'loan4_id'),
  '42501', null,
  '15: a MEMBER (no loan.submit) cannot submit a draft loan'
);

-- Submit loan #4 as ADMIN so 16/17 have a SUBMITTED loan to target.
set local request.jwt.claim.sub to '2b000000-0000-0000-0000-000000000001';
select public.rpc_submit_loan_account('2b100000-0000-0000-0000-000000000001', :'loan4_id'::uuid);

set local request.jwt.claim.sub to '2b000000-0000-0000-0000-000000000004';
select throws_ok(
  format($sql$ select public.rpc_approve_loan_account(
    '2b100000-0000-0000-0000-000000000001', %L
  ) $sql$, :'loan4_id'),
  '42501', null,
  '16: a MEMBER (no loan.approve) cannot approve a submitted loan'
);
select throws_ok(
  format($sql$ select public.rpc_reject_loan_account(
    '2b100000-0000-0000-0000-000000000001', %L, 'no permission anyway'
  ) $sql$, :'loan4_id'),
  '42501', null,
  '17: a MEMBER (no loan.reject) cannot reject a submitted loan'
);

-- 18. cross-group lifecycle action rejected — the Group B admin cannot
-- submit/approve/reject/cancel Group A's loan #1.
set local request.jwt.claim.sub to '2b000000-0000-0000-0000-000000000005';
select throws_ok(
  format($sql$ select public.rpc_approve_loan_account(
    '2b100000-0000-0000-0000-000000000002', %L
  ) $sql$, :'loan1_id'),
  '22023', null,
  '18: a Group B admin cannot approve Group A''s loan (not found in group)'
);

select * from finish();
rollback;
