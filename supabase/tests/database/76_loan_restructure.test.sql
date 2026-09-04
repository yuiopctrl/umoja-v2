-- Prompt 09E: Controlled Reschedule / Restructure Foundation.
begin;

select plan(14);

insert into auth.users (id, email) values
  ('76000000-0000-0000-0000-000000000001', 'p09e-restructure-admin@example.com'),
  ('76000000-0000-0000-0000-000000000002', 'p09e-restructure-member@example.com');

insert into public.groups (id, name, created_by, code) values
  ('76100000-0000-0000-0000-000000000001', 'Restructure Group', '76000000-0000-0000-0000-000000000001', 'REST'),
  ('76100000-0000-0000-0000-000000000002', 'Restructure Other Group', '76000000-0000-0000-0000-000000000001', 'RESTB');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('76200000-0000-0000-0000-000000000001', '76100000-0000-0000-0000-000000000001', '76000000-0000-0000-0000-000000000001', 'RS Admin', 'ACTIVE', '2025-01-01', 'REST-2026-0001'),
  ('76200000-0000-0000-0000-000000000002', '76100000-0000-0000-0000-000000000001', '76000000-0000-0000-0000-000000000002', 'RS Member', 'ACTIVE', '2025-01-01', 'REST-2026-0002'),
  ('76200000-0000-0000-0000-000000000005', '76100000-0000-0000-0000-000000000001', null, 'RS Borrower', 'ACTIVE', '2025-01-01', 'REST-2026-0005'),
  ('76200000-0000-0000-0000-000000000006', '76100000-0000-0000-0000-000000000001', null, 'RS Borrower Overdue', 'ACTIVE', '2025-01-01', 'REST-2026-0006'),
  ('76200000-0000-0000-0000-000000000009', '76100000-0000-0000-0000-000000000002', null, 'RS Other Group Borrower', 'ACTIVE', '2025-01-01', 'RESTB-2026-0009');

insert into public.group_membership_roles (group_membership_id, role_id) select '76200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select '76200000-0000-0000-0000-000000000002', id from public.roles where code = 'MEMBER';

set local role authenticated;
set local request.jwt.claim.sub to '76000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '76100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '76100000-0000-0000-0000-000000000001', 'RSP', 'Restructure Product', 100000, 1, 12, 2.0, 'MONTHLY', 'FLAT'
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

-- ---------------------------------------------------------------------
-- Permission denied.
-- ---------------------------------------------------------------------

create temporary table t_loan as
select public.rpc_create_draft_loan_account(
  '76100000-0000-0000-0000-000000000001', '76200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 600000, 6, (current_date + interval '1 month')::date
) as result;
select (result->>'id')::uuid as loan_id from t_loan \gset
select public.rpc_submit_loan_account('76100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_approve_loan_account('76100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_disburse_loan_account('76100000-0000-0000-0000-000000000001', :'loan_id'::uuid, :'account_id'::uuid, current_date);

set local request.jwt.claim.sub to '76000000-0000-0000-0000-000000000002';
select throws_ok(
  format($sql$ select public.rpc_restructure_loan(%L::uuid, %L::uuid, 'hardship', 8, %L::date) $sql$,
    '76100000-0000-0000-0000-000000000001', :'loan_id', (current_date + interval '2 months')::date),
  '42501',
  null,
  '1: a MEMBER without loan.restructure is rejected'
);
set local request.jwt.claim.sub to '76000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- Blocked with overdue balances.
-- ---------------------------------------------------------------------

create temporary table t_loan_overdue as
select public.rpc_create_draft_loan_account(
  '76100000-0000-0000-0000-000000000001', '76200000-0000-0000-0000-000000000006'::uuid,
  :'product_id'::uuid, 300000, 3, (current_date - interval '3 months')::date
) as result;
select (result->>'id')::uuid as loan_overdue_id from t_loan_overdue \gset
select public.rpc_submit_loan_account('76100000-0000-0000-0000-000000000001', :'loan_overdue_id'::uuid);
select public.rpc_approve_loan_account('76100000-0000-0000-0000-000000000001', :'loan_overdue_id'::uuid);
select public.rpc_disburse_loan_account('76100000-0000-0000-0000-000000000001', :'loan_overdue_id'::uuid, :'account_id'::uuid, (current_date - interval '3 months')::date);

select throws_ok(
  format($sql$ select public.rpc_preview_loan_restructure(%L::uuid, %L::uuid, 6, %L::date) $sql$,
    '76100000-0000-0000-0000-000000000001', :'loan_overdue_id', (current_date + interval '1 month')::date),
  'P0001',
  'LOAN_RESTRUCTURE_BLOCKED_OVERDUE_BALANCE',
  '2: restructure preview is blocked while any overdue balance exists'
);
select throws_ok(
  format($sql$ select public.rpc_restructure_loan(%L::uuid, %L::uuid, 'hardship', 6, %L::date) $sql$,
    '76100000-0000-0000-0000-000000000001', :'loan_overdue_id', (current_date + interval '1 month')::date),
  'P0001',
  'LOAN_RESTRUCTURE_BLOCKED_OVERDUE_BALANCE',
  '3: restructure write path independently re-validates and blocks the same way'
);

-- ---------------------------------------------------------------------
-- Preview writes nothing; confirm changes the future schedule only.
-- ---------------------------------------------------------------------

select count(*) as installments_before from public.loan_installments where loan_account_id = :'loan_id'::uuid \gset
create temporary table t_restructure_preview as
select public.rpc_preview_loan_restructure(
  '76100000-0000-0000-0000-000000000001', :'loan_id'::uuid, 8, (current_date + interval '2 months')::date
) as result;
select is(
  (select count(*)::integer from public.loan_installments where loan_account_id = :'loan_id'::uuid),
  :installments_before::integer,
  '4: restructure preview creates zero new/cancelled installment rows'
);
select is(
  (select jsonb_array_length(result->'new_installments') from t_restructure_preview),
  8,
  '5: restructure preview proposes the requested 8-installment schedule'
);

select coalesce(jsonb_agg(jsonb_build_object('installment_number', installment_number, 'due_date', due_date)), '[]'::jsonb) as paid_history_before
from public.loan_installments where loan_account_id = :'loan_id'::uuid \gset

create temporary table t_restructure_confirm as
select public.rpc_restructure_loan(
  '76100000-0000-0000-0000-000000000001', :'loan_id'::uuid, 'Borrower hardship request', 8, (current_date + interval '2 months')::date
) as result;

select is(
  (select count(*)::integer from public.loan_installments where loan_account_id = :'loan_id'::uuid and cancelled_at is not null),
  6,
  '6: restructure cancels every prior (future) installment, never deletes'
);
select is(
  (select count(*)::integer from public.loan_installments where loan_account_id = :'loan_id'::uuid and cancelled_at is null),
  8,
  '7: restructure inserts exactly the proposed new 8-installment schedule'
);
select is(
  (select cancellation_reason from public.loan_installments where loan_account_id = :'loan_id'::uuid and cancelled_at is not null limit 1),
  'RESTRUCTURE',
  '8: cancelled installments record the correct cancellation reason'
);

-- ---------------------------------------------------------------------
-- Audit event immutability + content.
-- ---------------------------------------------------------------------

select is(
  (select count(*)::integer from public.loan_restructure_events where loan_account_id = :'loan_id'::uuid),
  1,
  '9: exactly one immutable restructure event is recorded'
);
select is(
  (select reason from public.loan_restructure_events where loan_account_id = :'loan_id'::uuid),
  'Borrower hardship request',
  '10: the restructure event stores the exact reason given'
);
select is(
  (select new_term from public.loan_restructure_events where loan_account_id = :'loan_id'::uuid),
  8,
  '11: the restructure event stores the exact new term'
);
select throws_ok(
  format($sql$ update public.loan_restructure_events set reason = 'tampered' where loan_account_id = %L::uuid $sql$, :'loan_id'),
  '42501',
  null,
  '12: loan_restructure_events is not directly writable by authenticated (immutable)'
);
select is(
  (select count(*)::integer from public.loan_account_events where loan_account_id = :'loan_id'::uuid and event_type = 'RESTRUCTURED'),
  1,
  '13: a RESTRUCTURED event is also recorded on the unified loan_account_events audit trail'
);

-- ---------------------------------------------------------------------
-- Cross-group UUID injection rejected.
-- ---------------------------------------------------------------------

select throws_ok(
  format($sql$ select public.rpc_preview_loan_restructure(%L::uuid, %L::uuid, 6, %L::date) $sql$,
    '76100000-0000-0000-0000-000000000002', :'loan_id', (current_date + interval '1 month')::date),
  '42501',
  null,
  '14: restructuring a loan under a group the caller has no role in is rejected'
);

select * from finish();
rollback;
