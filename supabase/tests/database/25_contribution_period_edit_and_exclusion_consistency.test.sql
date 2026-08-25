-- Contribution Engine (Prompt 06A-CLOSEOUT): rpc_update_contribution_period
-- lifecycle-gating/date-revalidation/monthly-duplicate coverage, plus the
-- excluded-then-enrolled read-consistency fix on
-- rpc_get_contribution_period.
begin;

select plan(22);

insert into auth.users (id, email) values
  ('71000000-0000-0000-0000-000000000001', 'contrib25-treasurer@example.com'),
  ('71000000-0000-0000-0000-000000000002', 'contrib25-member@example.com'),
  ('71000000-0000-0000-0000-000000000003', 'contrib25-treasurer-b@example.com');

insert into public.groups (id, name, created_by, code) values
  ('71100000-0000-0000-0000-000000000001', 'Contrib25 Group A', '71000000-0000-0000-0000-000000000001', 'C25A'),
  ('71100000-0000-0000-0000-000000000002', 'Contrib25 Group B', '71000000-0000-0000-0000-000000000003', 'C25B');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('71200000-0000-0000-0000-000000000001', '71100000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000001', 'Contrib25 Treasurer', 'ACTIVE', '2025-01-01', 'C25A-2026-0001'),
  ('71200000-0000-0000-0000-000000000002', '71100000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000002', 'Contrib25 Plain Member', 'ACTIVE', '2025-01-01', 'C25A-2026-0002'),
  ('71200000-0000-0000-0000-000000000003', '71100000-0000-0000-0000-000000000001', null, 'Eligible Member A', 'ACTIVE', '2025-01-01', 'C25A-2026-0003'),
  ('71200000-0000-0000-0000-000000000004', '71100000-0000-0000-0000-000000000001', null, 'Excluded Member B', 'ACTIVE', '2025-01-01', 'C25A-2026-0004'),
  ('71200000-0000-0000-0000-000000000005', '71100000-0000-0000-0000-000000000001', null, 'Late Joiner', 'ACTIVE', '2026-03-20', 'C25A-2026-0005'),
  ('71200000-0000-0000-0000-000000000099', '71100000-0000-0000-0000-000000000002', '71000000-0000-0000-0000-000000000003', 'Contrib25 Treasurer B', 'ACTIVE', '2025-01-01', 'C25B-2026-0001');

insert into public.group_membership_roles (group_membership_id, role_id)
select '71200000-0000-0000-0000-000000000001', id from public.roles where code = 'TREASURER';
insert into public.group_membership_roles (group_membership_id, role_id)
select '71200000-0000-0000-0000-000000000002', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id)
select '71200000-0000-0000-0000-000000000099', id from public.roles where code = 'TREASURER';

insert into public.contribution_types (id, group_id, name, category, accounting_treatment, created_by) values
  ('71300000-0000-0000-0000-000000000001', '71100000-0000-0000-0000-000000000001', 'Monthly Dues', 'GENERAL', 'GROUP_INCOME', '71000000-0000-0000-0000-000000000001');

insert into public.contribution_setups (
  id, group_id, contribution_type_id, name, schedule_mode, amount_mode, fixed_amount, created_by
) values (
  '71400000-0000-0000-0000-000000000001', '71100000-0000-0000-0000-000000000001',
  '71300000-0000-0000-0000-000000000001', 'Monthly Dues Setup', 'MONTHLY', 'FIXED', 1000, '71000000-0000-0000-0000-000000000001'
);

set local role authenticated;
set local request.jwt.claim.sub to '71000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- DRAFT period can be edited.
-- ---------------------------------------------------------------------

create temporary table t_draft as
select public.rpc_create_contribution_period(
  '71100000-0000-0000-0000-000000000001', '71400000-0000-0000-0000-000000000001', 'March Dues',
  '2026-03-01', '2026-03-31', p_due_date := '2026-03-31'
) as result;

create temporary table t_draft_edited as
select public.rpc_update_contribution_period(
  '71100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_draft),
  p_label := 'March Dues (Renamed)'
) as result;

select is(
  (select result ->> 'label' from t_draft_edited),
  'March Dues (Renamed)',
  'a DRAFT period can be edited'
);

select is(
  (select result ->> 'status' from t_draft_edited),
  'DRAFT',
  'editing a DRAFT period does not change its status'
);

select is(
  (select count(*)::int from public.member_contribution_charges
   where period_id = (select (result ->> 'id')::uuid from t_draft)),
  0,
  'editing a DRAFT period creates no member charges'
);

-- Changing due_date only (section 8's explicit test script, step E).
create temporary table t_draft_due_date_edited as
select public.rpc_update_contribution_period(
  '71100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_draft),
  p_due_date := '2026-03-15'
) as result;

select is(
  (select result ->> 'due_date' from t_draft_due_date_edited),
  '2026-03-15',
  'changing due_date only succeeds and persists'
);

select is(
  (select result ->> 'label' from t_draft_due_date_edited),
  'March Dues (Renamed)',
  'changing due_date only leaves the label untouched'
);

-- ---------------------------------------------------------------------
-- SCHEDULED period can be edited.
-- ---------------------------------------------------------------------

create temporary table t_scheduled as
select public.rpc_create_contribution_period(
  '71100000-0000-0000-0000-000000000001', '71400000-0000-0000-0000-000000000001', 'April Dues',
  '2026-04-01', '2026-04-30', p_due_date := '2026-04-30', p_status := 'SCHEDULED'
) as result;

create temporary table t_scheduled_edited as
select public.rpc_update_contribution_period(
  '71100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_scheduled),
  p_scheduled_open_date := '2026-04-02'
) as result;

select is(
  (select result ->> 'scheduled_open_date' from t_scheduled_edited),
  '2026-04-02',
  'a SCHEDULED period can be edited'
);

-- ---------------------------------------------------------------------
-- Unauthorized edit is blocked.
-- ---------------------------------------------------------------------

set local request.jwt.claim.sub to '71000000-0000-0000-0000-000000000002';

select throws_ok(
  format(
    $sql$ select public.rpc_update_contribution_period('71100000-0000-0000-0000-000000000001', %L, p_label := 'Hacked') $sql$,
    (select (result ->> 'id')::text from t_draft)
  ),
  '42501',
  null,
  'a caller without contribution.period.manage cannot edit a period'
);

set local request.jwt.claim.sub to '71000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- Cross-group edit is blocked.
-- ---------------------------------------------------------------------

set local request.jwt.claim.sub to '71000000-0000-0000-0000-000000000003';

select throws_ok(
  format(
    $sql$ select public.rpc_update_contribution_period('71100000-0000-0000-0000-000000000002', %L, p_label := 'Hacked') $sql$,
    (select (result ->> 'id')::text from t_draft)
  ),
  '22023',
  null,
  'a period from a different group cannot be edited by passing the wrong group_id'
);

set local request.jwt.claim.sub to '71000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- Date validation still applies on edit.
-- ---------------------------------------------------------------------

select throws_ok(
  format(
    $sql$ select public.rpc_update_contribution_period('71100000-0000-0000-0000-000000000001', %L, p_period_start := '2026-03-31', p_period_end := '2026-03-01') $sql$,
    (select (result ->> 'id')::text from t_draft)
  ),
  '22023',
  'Invalid period dates',
  'an edit that puts period_start after period_end is rejected'
);

select throws_ok(
  format(
    $sql$ select public.rpc_update_contribution_period('71100000-0000-0000-0000-000000000001', %L, p_label := '   ') $sql$,
    (select (result ->> 'id')::text from t_draft)
  ),
  '22023',
  'Contribution period label cannot be blank',
  'a blank label is rejected on edit'
);

-- ---------------------------------------------------------------------
-- Monthly duplicate protection still applies after edit.
-- ---------------------------------------------------------------------

-- April Dues already exists (t_scheduled) — editing March Dues to move
-- into April must be rejected.
select throws_ok(
  format(
    $sql$ select public.rpc_update_contribution_period(
      '71100000-0000-0000-0000-000000000001', %L,
      p_period_start := '2026-04-01', p_period_end := '2026-04-30'
    ) $sql$,
    (select (result ->> 'id')::text from t_draft)
  ),
  'P0001',
  'DUPLICATE_MONTHLY_PERIOD',
  'editing a MONTHLY period into an already-used month is rejected'
);

-- Editing a period and leaving it in its own month is unaffected by the
-- duplicate check (does not collide with itself).
select lives_ok(
  format(
    $sql$ select public.rpc_update_contribution_period('71100000-0000-0000-0000-000000000001', %L, p_label := 'March Dues Again') $sql$,
    (select (result ->> 'id')::text from t_draft)
  ),
  'editing a MONTHLY period without changing its month is unaffected by duplicate protection'
);

-- ---------------------------------------------------------------------
-- Editing eligibility_date changes preview correctly.
-- ---------------------------------------------------------------------

-- Late Joiner (joined 2026-03-20) is not yet eligible under the
-- period's original 2026-03-01 eligibility_date. Moving
-- eligibility_date past their joined_at makes them newly eligible in
-- the preview — proving the edit is reflected live with no charges
-- posted yet.
create temporary table t_preview_before as
select public.rpc_preview_contribution_period_open(
  '71100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_draft)
) as result;

select is(
  (select (result ->> 'eligible_count')::int from t_preview_before),
  4,
  'the late joiner is not yet eligible under the original eligibility_date'
);

-- Move eligibility_date forward past the late joiner's joined_at so
-- they become eligible.
select public.rpc_update_contribution_period(
  '71100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_draft),
  p_eligibility_date := '2026-03-25'
) from t_draft;

create temporary table t_preview_after as
select public.rpc_preview_contribution_period_open(
  '71100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_draft)
) as result;

select is(
  (select (result ->> 'eligible_count')::int from t_preview_after)
  - (select (result ->> 'eligible_count')::int from t_preview_before),
  1,
  'moving eligibility_date past a late joiner''s joined_at makes them newly eligible in the preview'
);

select is(
  (select eligibility_date from public.contribution_periods
   where id = (select (result ->> 'id')::uuid from t_draft)),
  '2026-03-25'::date,
  'the edited eligibility_date is persisted on the period'
);

-- ---------------------------------------------------------------------
-- OPEN cannot be edited.
-- ---------------------------------------------------------------------

create temporary table t_open as
select public.rpc_create_contribution_period(
  '71100000-0000-0000-0000-000000000001', '71400000-0000-0000-0000-000000000001', 'May Dues',
  '2026-05-01', '2026-05-31', p_due_date := '2026-05-31'
) as result;

select public.rpc_open_contribution_period(
  '71100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_open)
);

select throws_ok(
  format(
    $sql$ select public.rpc_update_contribution_period('71100000-0000-0000-0000-000000000001', %L, p_label := 'Hacked') $sql$,
    (select (result ->> 'id')::text from t_open)
  ),
  'P0001',
  'CONTRIBUTION_PERIOD_NOT_EDITABLE',
  'an OPEN period cannot be edited'
);

-- ---------------------------------------------------------------------
-- CLOSED cannot be edited.
-- ---------------------------------------------------------------------

create temporary table t_closed as
select public.rpc_close_contribution_period(
  '71100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_open)
) as result;

select throws_ok(
  format(
    $sql$ select public.rpc_update_contribution_period('71100000-0000-0000-0000-000000000001', %L, p_label := 'Hacked') $sql$,
    (select (result ->> 'id')::text from t_open)
  ),
  'P0001',
  'CONTRIBUTION_PERIOD_NOT_EDITABLE',
  'a CLOSED period cannot be edited'
);

-- ---------------------------------------------------------------------
-- CANCELLED cannot be edited.
-- ---------------------------------------------------------------------

create temporary table t_to_cancel as
select public.rpc_create_contribution_period(
  '71100000-0000-0000-0000-000000000001', '71400000-0000-0000-0000-000000000001', 'June Dues',
  '2026-06-01', '2026-06-30', p_due_date := '2026-06-30'
) as result;

select public.rpc_cancel_contribution_period(
  '71100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_to_cancel)
);

select throws_ok(
  format(
    $sql$ select public.rpc_update_contribution_period('71100000-0000-0000-0000-000000000001', %L, p_label := 'Hacked') $sql$,
    (select (result ->> 'id')::text from t_to_cancel)
  ),
  'P0001',
  'CONTRIBUTION_PERIOD_NOT_EDITABLE',
  'a CANCELLED period cannot be edited'
);

-- ---------------------------------------------------------------------
-- Excluded -> explicitly enrolled consistency, post-OPEN.
-- ---------------------------------------------------------------------

create temporary table t_period_excl as
select public.rpc_create_contribution_period(
  '71100000-0000-0000-0000-000000000001', '71400000-0000-0000-0000-000000000001', 'July Dues',
  '2026-07-01', '2026-07-31', p_due_date := '2026-07-31'
) as result;

select public.rpc_exclude_contribution_period_member(
  '71100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_excl),
  '71200000-0000-0000-0000-000000000004', 'On leave'
) from t_period_excl;

create temporary table t_open_excl as
select public.rpc_open_contribution_period(
  '71100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_excl)
) as result;

create temporary table t_get_before_enroll as
select public.rpc_get_contribution_period(
  '71100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_excl)
) as result;

select is(
  (select (result ->> 'excluded_count')::int from t_get_before_enroll),
  1,
  'before enrollment, the excluded member is counted in excluded_count'
);

select public.rpc_enroll_member_in_contribution_period(
  '71100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_excl),
  '71200000-0000-0000-0000-000000000004'
) from t_period_excl;

select is(
  (select count(*)::int from public.member_contribution_charges
   where period_id = (select (result ->> 'id')::uuid from t_period_excl)
     and membership_id = '71200000-0000-0000-0000-000000000004'),
  1,
  'the previously-excluded member now has exactly one charge after explicit post-OPEN enrollment'
);

select is(
  (select count(*)::int from public.contribution_period_member_exclusions
   where period_id = (select (result ->> 'id')::uuid from t_period_excl)
     and membership_id = '71200000-0000-0000-0000-000000000004'),
  1,
  'the historical exclusion row is preserved, not deleted, after later enrollment'
);

create temporary table t_get_after_enroll as
select public.rpc_get_contribution_period(
  '71100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_excl)
) as result;

select is(
  (select (result ->> 'excluded_count')::int from t_get_after_enroll),
  0,
  'excluded_count no longer counts a member who now has a charge for the period'
);

select * from finish();

rollback;
