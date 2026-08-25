-- Contribution Engine (Prompt 06A): rpc_create_contribution_period
-- validation, the no-future-debt invariant (DRAFT/SCHEDULED periods
-- never post charges), and the eligibility roster computed by
-- public.contribution_period_eligible_memberships (ACTIVE-only,
-- join-date cutoff, rejoin back-charge protection, explicit
-- pre-open exclusion).
begin;

select plan(23);

insert into auth.users (id, email) values
  ('31000000-0000-0000-0000-000000000001', 'contrib21-treasurer@example.com'),
  ('31000000-0000-0000-0000-000000000002', 'contrib21-member@example.com');

insert into public.groups (id, name, created_by, code) values
  ('31100000-0000-0000-0000-000000000001', 'Contrib21 Group', '31000000-0000-0000-0000-000000000001', 'C21A');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  -- Treasurer/plain-member joined_at is deliberately far in the future
  -- so they are never themselves eligible for any contribution period
  -- opened in this file (their own ACTIVE membership would otherwise
  -- also be charged and skew the eligibility-roster assertions below).
  ('31200000-0000-0000-0000-000000000001', '31100000-0000-0000-0000-000000000001', '31000000-0000-0000-0000-000000000001', 'Contrib21 Treasurer', 'ACTIVE', '2099-01-01', 'C21A-2026-0001'),
  ('31200000-0000-0000-0000-000000000002', '31100000-0000-0000-0000-000000000001', '31000000-0000-0000-0000-000000000002', 'Contrib21 Plain Member', 'ACTIVE', '2099-01-01', 'C21A-2026-0002'),
  -- M1: ordinary eligible member, joined well before eligibility_date.
  ('31200000-0000-0000-0000-000000000003', '31100000-0000-0000-0000-000000000001', null, 'Eligible Member One', 'ACTIVE', '2025-01-01', 'C21A-2026-0003'),
  -- M2: SUSPENDED -- must be excluded.
  ('31200000-0000-0000-0000-000000000004', '31100000-0000-0000-0000-000000000001', null, 'Suspended Member', 'SUSPENDED', '2025-01-01', 'C21A-2026-0004'),
  -- M3: EXITED -- must be excluded.
  ('31200000-0000-0000-0000-000000000005', '31100000-0000-0000-0000-000000000001', null, 'Exited Member', 'EXITED', '2025-01-01', 'C21A-2026-0005'),
  -- M4: ACTIVE but joined after the period's eligibility_date -- excluded.
  ('31200000-0000-0000-0000-000000000006', '31100000-0000-0000-0000-000000000001', null, 'Late Joiner Member', 'ACTIVE', '2026-10-01', 'C21A-2026-0006'),
  -- M5: ACTIVE, joined long ago, but exited and rejoined during a window
  -- covering the period's eligibility_date -- must not be back-charged.
  ('31200000-0000-0000-0000-000000000007', '31100000-0000-0000-0000-000000000001', null, 'Rejoined Member', 'ACTIVE', '2024-01-01', 'C21A-2026-0007'),
  -- M6: ACTIVE, otherwise eligible, but explicitly excluded pre-open.
  ('31200000-0000-0000-0000-000000000008', '31100000-0000-0000-0000-000000000001', null, 'Explicitly Excluded Member', 'ACTIVE', '2025-01-01', 'C21A-2026-0008');

insert into public.group_membership_roles (group_membership_id, role_id)
select '31200000-0000-0000-0000-000000000001', id from public.roles where code = 'TREASURER';
insert into public.group_membership_roles (group_membership_id, role_id)
select '31200000-0000-0000-0000-000000000002', id from public.roles where code = 'MEMBER';

-- M5's rejoin history: exited 2026-06-01, rejoined (effective) 2026-09-15,
-- straddling the Sept period's eligibility_date of 2026-09-01.
insert into public.group_membership_status_history (
  group_membership_id, group_id, from_status, to_status, previous_exited_at, effective_at, action
) values (
  '31200000-0000-0000-0000-000000000007', '31100000-0000-0000-0000-000000000001',
  'EXITED', 'ACTIVE', '2026-06-01', '2026-09-15', 'REJOIN'
);

insert into public.contribution_types (id, group_id, name, category, accounting_treatment, created_by) values
  ('31300000-0000-0000-0000-000000000001', '31100000-0000-0000-0000-000000000001', 'Monthly Dues', 'GENERAL', 'GROUP_INCOME', '31000000-0000-0000-0000-000000000001');

insert into public.contribution_setups (
  id, group_id, contribution_type_id, name, schedule_mode, amount_mode, fixed_amount, created_by
) values (
  '31400000-0000-0000-0000-000000000001', '31100000-0000-0000-0000-000000000001',
  '31300000-0000-0000-0000-000000000001', 'Monthly Dues Setup', 'MONTHLY', 'FIXED', 1000, '31000000-0000-0000-0000-000000000001'
);

set local role authenticated;
set local request.jwt.claim.sub to '31000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- rpc_create_contribution_period validation.
-- ---------------------------------------------------------------------

select throws_ok(
  $$ select public.rpc_create_contribution_period(
    '31100000-0000-0000-0000-000000000001', '31400000-0000-0000-0000-000000000001', 'Bad Status Period',
    '2026-01-01', '2026-01-31', p_status := 'OPEN'
  ) $$,
  '22023',
  null,
  'a contribution period cannot be created directly with status OPEN'
);

set local request.jwt.claim.sub to '31000000-0000-0000-0000-000000000002';

select throws_ok(
  $$ select public.rpc_create_contribution_period(
    '31100000-0000-0000-0000-000000000001', '31400000-0000-0000-0000-000000000001', 'Unauthorized Period',
    '2026-01-01', '2026-01-31', p_due_date := '2026-01-31'
  ) $$,
  '42501',
  null,
  'a caller without contribution.period.manage cannot create a contribution period'
);

set local request.jwt.claim.sub to '31000000-0000-0000-0000-000000000001';

select throws_ok(
  $$ select public.rpc_create_contribution_period(
    '31100000-0000-0000-0000-000000000001', '31400000-0000-0000-0000-000000000001', 'Bad Dates Period',
    '2026-05-10', '2026-05-01', p_due_date := '2026-05-10'
  ) $$,
  '22023',
  null,
  'a period with period_start after period_end is rejected'
);

select throws_ok(
  $$ select public.rpc_create_contribution_period(
    '31100000-0000-0000-0000-000000000001', '31400000-0000-0000-0000-000000000001', '   ',
    '2026-05-01', '2026-05-31', p_due_date := '2026-05-31'
  ) $$,
  '22023',
  null,
  'a blank contribution period label is rejected'
);

select throws_ok(
  $$ select public.rpc_create_contribution_period(
    '31100000-0000-0000-0000-000000000001', '31400000-0000-0000-0000-000000000001', 'July Period No Due Date',
    '2026-07-01', '2026-07-31'
  ) $$,
  '22023',
  'DUE_DATE_REQUIRED',
  'a period with no explicit due date and no setup default_due_day is rejected'
);

-- ---------------------------------------------------------------------
-- CRITICAL -- no future debt: a SCHEDULED future period posts zero
-- charges, and opening a different period must never leak charges into it.
-- ---------------------------------------------------------------------

create temporary table t_period_dec as
select public.rpc_create_contribution_period(
  '31100000-0000-0000-0000-000000000001', '31400000-0000-0000-0000-000000000001', 'December Period',
  '2026-12-01', '2026-12-31', p_due_date := '2026-12-31', p_status := 'SCHEDULED'
) as result;

select is(
  (select result ->> 'status' from t_period_dec),
  'SCHEDULED',
  'a future SCHEDULED period is created'
);

select is(
  (select count(*)::int from public.member_contribution_charges
   where period_id = (select (result ->> 'id')::uuid from t_period_dec)),
  0,
  'a SCHEDULED period has zero member charges before it is opened'
);

create temporary table t_period_sept as
select public.rpc_create_contribution_period(
  '31100000-0000-0000-0000-000000000001', '31400000-0000-0000-0000-000000000001', 'September Period',
  '2026-09-01', '2026-09-30', p_due_date := '2026-09-30'
) as result;

select is(
  (select result ->> 'status' from t_period_sept),
  'DRAFT',
  'a period created without an explicit status defaults to DRAFT'
);

select is(
  (select count(*)::int from public.member_contribution_charges
   where period_id = (select (result ->> 'id')::uuid from t_period_sept)),
  0,
  'a DRAFT period has zero member charges before it is opened'
);

select throws_ok(
  $$ select public.rpc_create_contribution_period(
    '31100000-0000-0000-0000-000000000001', '31400000-0000-0000-0000-000000000001', 'Duplicate September Period',
    '2026-09-15', '2026-09-20', p_due_date := '2026-09-25'
  ) $$,
  'P0001',
  'DUPLICATE_MONTHLY_PERIOD',
  'a second non-cancelled period in the same month is rejected for a MONTHLY setup'
);

-- ---------------------------------------------------------------------
-- Explicit pre-open exclusion of M6, then OPEN the September period.
-- ---------------------------------------------------------------------

select lives_ok(
  format(
    $sql$ select public.rpc_exclude_contribution_period_member(
      '31100000-0000-0000-0000-000000000001', %L, '31200000-0000-0000-0000-000000000008'
    ) $sql$,
    (select result ->> 'id' from t_period_sept)
  ),
  'an eligible member can be explicitly excluded from a DRAFT period before it opens'
);

create temporary table t_open_sept as
select public.rpc_open_contribution_period(
  '31100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_sept)
) as result;

select is(
  (select (result ->> 'charge_count')::int from t_open_sept),
  1,
  'opening the September period charges exactly the one eligible, non-excluded member'
);

select is(
  (select count(*)::int from public.member_contribution_charges
   where period_id = (select (result ->> 'id')::uuid from t_period_sept)
     and membership_id = '31200000-0000-0000-0000-000000000003'),
  1,
  'the ordinary ACTIVE member (joined before eligibility_date) is charged'
);

select is(
  (select count(*)::int from public.member_contribution_charges
   where period_id = (select (result ->> 'id')::uuid from t_period_sept)
     and membership_id = '31200000-0000-0000-0000-000000000004'),
  0,
  'a SUSPENDED member is not charged'
);

select is(
  (select count(*)::int from public.member_contribution_charges
   where period_id = (select (result ->> 'id')::uuid from t_period_sept)
     and membership_id = '31200000-0000-0000-0000-000000000005'),
  0,
  'an EXITED member is not charged'
);

select is(
  (select count(*)::int from public.member_contribution_charges
   where period_id = (select (result ->> 'id')::uuid from t_period_sept)
     and membership_id = '31200000-0000-0000-0000-000000000006'),
  0,
  'a member who joined after eligibility_date is not charged'
);

select is(
  (select count(*)::int from public.member_contribution_charges
   where period_id = (select (result ->> 'id')::uuid from t_period_sept)
     and membership_id = '31200000-0000-0000-0000-000000000007'),
  0,
  'a member exited and rejoined across the eligibility_date window is not automatically back-charged'
);

select is(
  (select count(*)::int from public.member_contribution_charges
   where period_id = (select (result ->> 'id')::uuid from t_period_sept)
     and membership_id = '31200000-0000-0000-0000-000000000008'),
  0,
  'an explicitly pre-open-excluded member is not charged'
);

select is(
  (select count(*) from public.member_contribution_charges c
   where c.period_id = (select (result ->> 'id')::uuid from t_period_sept))::int,
  (select count(*) from public.member_contribution_charges c
   join public.contribution_charge_components cc
     on cc.charge_id = c.id and cc.component_type = 'BASE'
   where c.period_id = (select (result ->> 'id')::uuid from t_period_sept))::int,
  'every posted charge has exactly one BASE component'
);

select is(
  (select cc.assessed_amount from public.member_contribution_charges c
   join public.contribution_charge_components cc on cc.charge_id = c.id and cc.component_type = 'BASE'
   where c.period_id = (select (result ->> 'id')::uuid from t_period_sept)
     and c.membership_id = '31200000-0000-0000-0000-000000000003'),
  1000.00::numeric,
  'the FIXED amount is assessed as the BASE component for the charged member'
);

select is(
  (select member_number_snapshot from public.member_contribution_charges c
   where c.period_id = (select (result ->> 'id')::uuid from t_period_sept)
     and c.membership_id = '31200000-0000-0000-0000-000000000003'),
  'C21A-2026-0003',
  'member_number_snapshot is saved correctly on the posted charge'
);

select is(
  (select member_name_snapshot from public.member_contribution_charges c
   where c.period_id = (select (result ->> 'id')::uuid from t_period_sept)
     and c.membership_id = '31200000-0000-0000-0000-000000000003'),
  'Eligible Member One',
  'member_name_snapshot is saved correctly on the posted charge'
);

select is(
  (select count(*)::int from public.member_contribution_charges
   where period_id = (select (result ->> 'id')::uuid from t_period_dec)),
  0,
  'the future SCHEDULED period still has zero charges after a different period was opened'
);

select * from finish();

rollback;
