-- Contribution Engine (Prompt 06A): rpc_cancel_contribution_period /
-- rpc_close_contribution_period state-machine coverage (DRAFT/SCHEDULED
-- -> CANCELLED, OPEN -> CLOSED, OPEN is never directly cancellable, a
-- CLOSED period is terminal and never reopenable), plus the remaining
-- cross-group tenancy check for contribution_periods.
begin;

select plan(13);

insert into auth.users (id, email) values
  ('61000000-0000-0000-0000-000000000001', 'contrib24-treasurer@example.com'),
  ('61000000-0000-0000-0000-000000000002', 'contrib24-member@example.com'),
  ('61000000-0000-0000-0000-000000000003', 'contrib24-treasurer-b@example.com');

insert into public.groups (id, name, created_by, code) values
  ('61100000-0000-0000-0000-000000000001', 'Contrib24 Group A', '61000000-0000-0000-0000-000000000001', 'C24A'),
  ('61100000-0000-0000-0000-000000000002', 'Contrib24 Group B', '61000000-0000-0000-0000-000000000003', 'C24B');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('61200000-0000-0000-0000-000000000001', '61100000-0000-0000-0000-000000000001', '61000000-0000-0000-0000-000000000001', 'Contrib24 Treasurer', 'ACTIVE', '2025-01-01', 'C24A-2026-0001'),
  ('61200000-0000-0000-0000-000000000002', '61100000-0000-0000-0000-000000000001', '61000000-0000-0000-0000-000000000002', 'Contrib24 Plain Member', 'ACTIVE', '2025-01-01', 'C24A-2026-0002'),
  ('61200000-0000-0000-0000-000000000003', '61100000-0000-0000-0000-000000000001', null, 'Eligible Member', 'ACTIVE', '2025-01-01', 'C24A-2026-0003'),
  ('61200000-0000-0000-0000-000000000099', '61100000-0000-0000-0000-000000000002', '61000000-0000-0000-0000-000000000003', 'Contrib24 Treasurer B', 'ACTIVE', '2025-01-01', 'C24B-2026-0001');

insert into public.group_membership_roles (group_membership_id, role_id)
select '61200000-0000-0000-0000-000000000001', id from public.roles where code = 'TREASURER';
insert into public.group_membership_roles (group_membership_id, role_id)
select '61200000-0000-0000-0000-000000000002', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id)
select '61200000-0000-0000-0000-000000000099', id from public.roles where code = 'TREASURER';

insert into public.contribution_types (id, group_id, name, category, accounting_treatment, created_by) values
  ('61300000-0000-0000-0000-000000000001', '61100000-0000-0000-0000-000000000001', 'Event Fee', 'GENERAL', 'GROUP_INCOME', '61000000-0000-0000-0000-000000000001');

insert into public.contribution_setups (
  id, group_id, contribution_type_id, name, schedule_mode, amount_mode, fixed_amount, created_by
) values (
  '61400000-0000-0000-0000-000000000001', '61100000-0000-0000-0000-000000000001',
  '61300000-0000-0000-0000-000000000001', 'Event Fee Setup', 'ON_DEMAND', 'FIXED', 800, '61000000-0000-0000-0000-000000000001'
);

set local role authenticated;
set local request.jwt.claim.sub to '61000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- DRAFT -> CANCELLED, idempotent double-cancel.
-- ---------------------------------------------------------------------

create temporary table t_period_draft as
select public.rpc_create_contribution_period(
  '61100000-0000-0000-0000-000000000001', '61400000-0000-0000-0000-000000000001', 'Draft Cancel Round',
  '2026-08-01', '2026-08-31', p_due_date := '2026-08-31'
) as result;

set local request.jwt.claim.sub to '61000000-0000-0000-0000-000000000002';

select throws_ok(
  format(
    $sql$ select public.rpc_cancel_contribution_period('61100000-0000-0000-0000-000000000001', %L) $sql$,
    (select result ->> 'id' from t_period_draft)
  ),
  '42501',
  null,
  'a caller without contribution.period.manage cannot cancel a period'
);

set local request.jwt.claim.sub to '61000000-0000-0000-0000-000000000001';

create temporary table t_cancel_draft as
select public.rpc_cancel_contribution_period(
  '61100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_draft)
) as result;

select is(
  (select result ->> 'status' from t_cancel_draft),
  'CANCELLED',
  'a DRAFT period can be cancelled'
);

create temporary table t_cancel_draft_again as
select public.rpc_cancel_contribution_period(
  '61100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_draft)
) as result;

select is(
  (select (result ->> 'already_cancelled')::boolean from t_cancel_draft_again),
  true,
  'cancelling an already-CANCELLED period is idempotent'
);

-- ---------------------------------------------------------------------
-- SCHEDULED -> CANCELLED.
-- ---------------------------------------------------------------------

create temporary table t_period_scheduled as
select public.rpc_create_contribution_period(
  '61100000-0000-0000-0000-000000000001', '61400000-0000-0000-0000-000000000001', 'Scheduled Cancel Round',
  '2026-09-01', '2026-09-30', p_due_date := '2026-09-30', p_status := 'SCHEDULED'
) as result;

create temporary table t_cancel_scheduled as
select public.rpc_cancel_contribution_period(
  '61100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_scheduled)
) as result;

select is(
  (select result ->> 'status' from t_cancel_scheduled),
  'CANCELLED',
  'a SCHEDULED period can be cancelled'
);

-- ---------------------------------------------------------------------
-- A DRAFT/SCHEDULED period cannot be closed (only OPEN can).
-- ---------------------------------------------------------------------

create temporary table t_period_draft2 as
select public.rpc_create_contribution_period(
  '61100000-0000-0000-0000-000000000001', '61400000-0000-0000-0000-000000000001', 'Draft Close Attempt Round',
  '2026-10-01', '2026-10-31', p_due_date := '2026-10-31'
) as result;

set local request.jwt.claim.sub to '61000000-0000-0000-0000-000000000002';

select throws_ok(
  format(
    $sql$ select public.rpc_close_contribution_period('61100000-0000-0000-0000-000000000001', %L) $sql$,
    (select result ->> 'id' from t_period_draft2)
  ),
  '42501',
  null,
  'a caller without contribution.period.close cannot close a period'
);

set local request.jwt.claim.sub to '61000000-0000-0000-0000-000000000001';

select throws_ok(
  format(
    $sql$ select public.rpc_close_contribution_period('61100000-0000-0000-0000-000000000001', %L) $sql$,
    (select result ->> 'id' from t_period_draft2)
  ),
  'P0001',
  'CONTRIBUTION_PERIOD_NOT_OPEN',
  'a DRAFT period cannot be closed directly'
);

-- ---------------------------------------------------------------------
-- OPEN -> CANCELLED is invalid; OPEN -> CLOSED is valid; CLOSED is
-- terminal (remains queryable, never reopenable).
-- ---------------------------------------------------------------------

create temporary table t_period_open as
select public.rpc_create_contribution_period(
  '61100000-0000-0000-0000-000000000001', '61400000-0000-0000-0000-000000000001', 'Open Lifecycle Round',
  '2026-11-01', '2026-11-30', p_due_date := '2026-11-30'
) as result;

select public.rpc_open_contribution_period(
  '61100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_open)
);

select throws_ok(
  format(
    $sql$ select public.rpc_cancel_contribution_period('61100000-0000-0000-0000-000000000001', %L) $sql$,
    (select result ->> 'id' from t_period_open)
  ),
  'P0001',
  'CONTRIBUTION_PERIOD_NOT_CANCELLABLE',
  'an OPEN period cannot be cancelled'
);

create temporary table t_close_open as
select public.rpc_close_contribution_period(
  '61100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_open)
) as result;

select is(
  (select result ->> 'status' from t_close_open),
  'CLOSED',
  'an OPEN period can be closed'
);

create temporary table t_close_open_again as
select public.rpc_close_contribution_period(
  '61100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_open)
) as result;

select is(
  (select (result ->> 'already_closed')::boolean from t_close_open_again),
  true,
  'closing an already-CLOSED period is idempotent'
);

create temporary table t_get_closed as
select public.rpc_get_contribution_period(
  '61100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_open)
) as result;

select is(
  (select result ->> 'status' from t_get_closed),
  'CLOSED',
  'a CLOSED period remains queryable via rpc_get_contribution_period'
);

select throws_ok(
  format(
    $sql$ select public.rpc_open_contribution_period('61100000-0000-0000-0000-000000000001', %L) $sql$,
    (select result ->> 'id' from t_period_open)
  ),
  'P0001',
  'CONTRIBUTION_PERIOD_NOT_OPENABLE',
  'a CLOSED period can never be reopened (not the idempotent already_open path)'
);

-- ---------------------------------------------------------------------
-- Cross-group tenancy: a period cannot be read/acted on under the
-- wrong group_id.
-- ---------------------------------------------------------------------

set local request.jwt.claim.sub to '61000000-0000-0000-0000-000000000003';

select throws_ok(
  format(
    $sql$ select public.rpc_get_contribution_period('61100000-0000-0000-0000-000000000002', %L) $sql$,
    (select result ->> 'id' from t_period_open)
  ),
  '22023',
  null,
  'cross-group contribution period access is blocked'
);

select throws_ok(
  format(
    $sql$ select public.rpc_cancel_contribution_period('61100000-0000-0000-0000-000000000002', %L) $sql$,
    (select result ->> 'id' from t_period_draft2)
  ),
  '22023',
  null,
  'a period from a different group cannot be cancelled by passing the wrong group_id'
);

select * from finish();

rollback;
