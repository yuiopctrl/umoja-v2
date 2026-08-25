-- Contribution Engine (Prompt 06B): rpc_assess_contribution_penalties —
-- lifecycle gating, grace-period/threshold boundary, FIXED/PERCENTAGE
-- ONCE/RECURRING modes, cap clamping, idempotency, eligibility
-- inheritance (suspended/exited/excluded/enrolled), snapshot immutability,
-- group isolation, permission matrix, and financial safety.
begin;

select plan(44);

insert into auth.users (id, email) values
  ('a1000000-0000-0000-0000-000000000001', 'pen27-admin@example.com'),
  ('a1000000-0000-0000-0000-000000000002', 'pen27-treasurer@example.com'),
  ('a1000000-0000-0000-0000-000000000003', 'pen27-chairperson@example.com'),
  ('a1000000-0000-0000-0000-000000000004', 'pen27-secretary@example.com'),
  ('a1000000-0000-0000-0000-000000000005', 'pen27-member@example.com'),
  ('a1000000-0000-0000-0000-000000000006', 'pen27-suspended@example.com'),
  ('a1000000-0000-0000-0000-000000000007', 'pen27-exited@example.com'),
  ('a1000000-0000-0000-0000-000000000008', 'pen27-excluded@example.com'),
  ('a1000000-0000-0000-0000-000000000009', 'pen27-late-joiner@example.com'),
  ('a1000000-0000-0000-0000-000000000010', 'pen27-groupb-treasurer@example.com');

insert into public.groups (id, name, created_by, code) values
  ('a1100000-0000-0000-0000-000000000001', 'Penalty Group A', 'a1000000-0000-0000-0000-000000000001', 'P27A'),
  ('a1100000-0000-0000-0000-000000000002', 'Penalty Group B', 'a1000000-0000-0000-0000-000000000010', 'P27B');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('a1200000-0000-0000-0000-000000000001', 'a1100000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'P27 Admin', 'ACTIVE', '2025-01-01', 'P27A-2026-0001'),
  ('a1200000-0000-0000-0000-000000000002', 'a1100000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000002', 'P27 Treasurer', 'ACTIVE', '2025-01-01', 'P27A-2026-0002'),
  ('a1200000-0000-0000-0000-000000000003', 'a1100000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000003', 'P27 Chairperson', 'ACTIVE', '2025-01-01', 'P27A-2026-0003'),
  ('a1200000-0000-0000-0000-000000000004', 'a1100000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000004', 'P27 Secretary', 'ACTIVE', '2025-01-01', 'P27A-2026-0004'),
  ('a1200000-0000-0000-0000-000000000005', 'a1100000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000005', 'P27 Plain Member', 'ACTIVE', '2025-01-01', 'P27A-2026-0005'),
  ('a1200000-0000-0000-0000-000000000006', 'a1100000-0000-0000-0000-000000000001', null, 'Eligible Member', 'ACTIVE', '2025-01-01', 'P27A-2026-0006'),
  ('a1200000-0000-0000-0000-000000000007', 'a1100000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000006', 'Suspended Member', 'SUSPENDED', '2025-01-01', 'P27A-2026-0007'),
  ('a1200000-0000-0000-0000-000000000008', 'a1100000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000007', 'Exited Member', 'EXITED', '2025-01-01', 'P27A-2026-0008'),
  ('a1200000-0000-0000-0000-000000000009', 'a1100000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000008', 'Excluded Member', 'ACTIVE', '2025-01-01', 'P27A-2026-0009'),
  ('a1200000-0000-0000-0000-000000000010', 'a1100000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000009', 'Late Joiner', 'ACTIVE', '2099-01-01', 'P27A-2026-0010'),
  ('a1200000-0000-0000-0000-000000000099', 'a1100000-0000-0000-0000-000000000002', 'a1000000-0000-0000-0000-000000000010', 'P27B Treasurer', 'ACTIVE', '2025-01-01', 'P27B-2026-0001');

insert into public.group_membership_roles (group_membership_id, role_id) select 'a1200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select 'a1200000-0000-0000-0000-000000000002', id from public.roles where code = 'TREASURER';
insert into public.group_membership_roles (group_membership_id, role_id) select 'a1200000-0000-0000-0000-000000000003', id from public.roles where code = 'CHAIRPERSON';
insert into public.group_membership_roles (group_membership_id, role_id) select 'a1200000-0000-0000-0000-000000000004', id from public.roles where code = 'SECRETARY';
insert into public.group_membership_roles (group_membership_id, role_id) select 'a1200000-0000-0000-0000-000000000005', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id) select 'a1200000-0000-0000-0000-000000000099', id from public.roles where code = 'TREASURER';

insert into public.contribution_types (id, group_id, name, category, accounting_treatment, created_by) values
  ('a1300000-0000-0000-0000-000000000001', 'a1100000-0000-0000-0000-000000000001', 'Dues', 'GENERAL', 'GROUP_INCOME', 'a1000000-0000-0000-0000-000000000001');

-- Setup with NO penalty policy.
insert into public.contribution_setups (id, group_id, contribution_type_id, name, schedule_mode, amount_mode, fixed_amount, created_by) values
  ('a1400000-0000-0000-0000-000000000001', 'a1100000-0000-0000-0000-000000000001', 'a1300000-0000-0000-0000-000000000001', 'No Penalty Setup', 'ON_DEMAND', 'FIXED', 10000, 'a1000000-0000-0000-0000-000000000001');

-- FIXED_ONCE setup: grace 3 days, value 500.
insert into public.contribution_setups (id, group_id, contribution_type_id, name, schedule_mode, amount_mode, fixed_amount, penalty_mode, penalty_grace_days, penalty_value, created_by) values
  ('a1400000-0000-0000-0000-000000000002', 'a1100000-0000-0000-0000-000000000001', 'a1300000-0000-0000-0000-000000000001', 'Fixed Once Setup', 'ON_DEMAND', 'FIXED', 10000, 'FIXED_ONCE', 3, 500, 'a1000000-0000-0000-0000-000000000001');

-- PERCENTAGE_ONCE setup: grace 2 days, value 10% (base 333.33 -> 33.33 rounded).
insert into public.contribution_setups (id, group_id, contribution_type_id, name, schedule_mode, amount_mode, fixed_amount, penalty_mode, penalty_grace_days, penalty_value, created_by) values
  ('a1400000-0000-0000-0000-000000000003', 'a1100000-0000-0000-0000-000000000001', 'a1300000-0000-0000-0000-000000000001', 'Percentage Once Setup', 'ON_DEMAND', 'FIXED', 333.33, 'PERCENTAGE_ONCE', 2, 10, 'a1000000-0000-0000-0000-000000000001');

-- FIXED_RECURRING setup with cap: grace 5, value 1000, cap 2500.
insert into public.contribution_setups (id, group_id, contribution_type_id, name, schedule_mode, amount_mode, fixed_amount, penalty_mode, penalty_grace_days, penalty_value, penalty_cap_amount, created_by) values
  ('a1400000-0000-0000-0000-000000000004', 'a1100000-0000-0000-0000-000000000001', 'a1300000-0000-0000-0000-000000000001', 'Fixed Recurring Setup', 'ON_DEMAND', 'FIXED', 10000, 'FIXED_RECURRING', 5, 1000, 2500, 'a1000000-0000-0000-0000-000000000001');

-- Snapshot-immutability setup: created here (not mid-test) since there
-- is no direct client INSERT grant on contribution_setups.
insert into public.contribution_setups (id, group_id, contribution_type_id, name, schedule_mode, amount_mode, fixed_amount, penalty_mode, penalty_grace_days, penalty_value, created_by) values
  ('a1400000-0000-0000-0000-000000000005', 'a1100000-0000-0000-0000-000000000001', 'a1300000-0000-0000-0000-000000000001', 'Snapshot Setup', 'ON_DEMAND', 'FIXED', 10000, 'FIXED_ONCE', 3, 500, 'a1000000-0000-0000-0000-000000000001');

-- Live UAT regression: exact reported scenario — PERCENTAGE_ONCE, value
-- 25, base 5000 -> must be 1,250 (25% of 5000), never the raw
-- unmultiplied penalty_value (25) and never 5,025.
insert into public.contribution_setups (id, group_id, contribution_type_id, name, schedule_mode, amount_mode, fixed_amount, penalty_mode, penalty_grace_days, penalty_value, created_by) values
  ('a1400000-0000-0000-0000-000000000006', 'a1100000-0000-0000-0000-000000000001', 'a1300000-0000-0000-0000-000000000001', 'Percentage Once 5000 Setup', 'ON_DEMAND', 'FIXED', 5000, 'PERCENTAGE_ONCE', 3, 25, 'a1000000-0000-0000-0000-000000000001');

-- 10% of 100,000 = 10,000 — a second, independently-chosen pair of
-- numbers proving the formula generalizes, not just for 25/5000.
insert into public.contribution_setups (id, group_id, contribution_type_id, name, schedule_mode, amount_mode, fixed_amount, penalty_mode, penalty_grace_days, penalty_value, created_by) values
  ('a1400000-0000-0000-0000-000000000007', 'a1100000-0000-0000-0000-000000000001', 'a1300000-0000-0000-0000-000000000001', 'Percentage Once 100k Setup', 'ON_DEMAND', 'FIXED', 100000, 'PERCENTAGE_ONCE', 3, 10, 'a1000000-0000-0000-0000-000000000001');

-- PERCENTAGE_RECURRING, no cap: isolates the no-compounding rule from
-- any cap-clamping that would otherwise mask a compounding bug (a
-- capped occurrence's clamped amount would look the same whether or
-- not the raw calculation compounded).
insert into public.contribution_setups (id, group_id, contribution_type_id, name, schedule_mode, amount_mode, fixed_amount, penalty_mode, penalty_grace_days, penalty_value, created_by) values
  ('a1400000-0000-0000-0000-000000000008', 'a1100000-0000-0000-0000-000000000001', 'a1300000-0000-0000-0000-000000000001', 'Percentage Recurring Uncapped Setup', 'ON_DEMAND', 'FIXED', 5000, 'PERCENTAGE_RECURRING', 5, 25, 'a1000000-0000-0000-0000-000000000001');

-- PERCENTAGE_RECURRING with a cap: proves the cap still clamps
-- correctly once the basis is the (correctly non-compounding)
-- percentage-of-BASE amount.
insert into public.contribution_setups (id, group_id, contribution_type_id, name, schedule_mode, amount_mode, fixed_amount, penalty_mode, penalty_grace_days, penalty_value, penalty_cap_amount, created_by) values
  ('a1400000-0000-0000-0000-000000000009', 'a1100000-0000-0000-0000-000000000001', 'a1300000-0000-0000-0000-000000000001', 'Percentage Recurring Capped Setup', 'ON_DEMAND', 'FIXED', 5000, 'PERCENTAGE_RECURRING', 5, 25, 2000, 'a1000000-0000-0000-0000-000000000001');

set local role authenticated;
set local request.jwt.claim.sub to 'a1000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- Period without a penalty policy.
-- ---------------------------------------------------------------------

create temporary table t_period_none as
select public.rpc_create_contribution_period(
  'a1100000-0000-0000-0000-000000000001', 'a1400000-0000-0000-0000-000000000001', 'No Penalty Round',
  '2026-08-01', '2026-08-31', p_due_date := '2026-08-05'
) as result;

select public.rpc_open_contribution_period(
  'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_none)
);

select throws_ok(
  format(
    $sql$ select public.rpc_assess_contribution_penalties('a1100000-0000-0000-0000-000000000001', %L, '2026-09-01') $sql$,
    (select (result ->> 'id')::text from t_period_none)
  ),
  'P0001',
  'CONTRIBUTION_PERIOD_NO_PENALTY_POLICY',
  'a period with penalty_mode NONE rejects penalty assessment'
);

-- ---------------------------------------------------------------------
-- Lifecycle gating: only OPEN is eligible.
-- ---------------------------------------------------------------------

create temporary table t_period_draft as
select public.rpc_create_contribution_period(
  'a1100000-0000-0000-0000-000000000001', 'a1400000-0000-0000-0000-000000000002', 'Draft Round',
  '2026-08-01', '2026-08-31', p_due_date := '2026-08-05'
) as result;

select throws_ok(
  format(
    $sql$ select public.rpc_assess_contribution_penalties('a1100000-0000-0000-0000-000000000001', %L, '2026-09-01') $sql$,
    (select (result ->> 'id')::text from t_period_draft)
  ),
  'P0001',
  'CONTRIBUTION_PERIOD_NOT_OPEN',
  'a DRAFT period cannot be assessed'
);

create temporary table t_period_scheduled as
select public.rpc_create_contribution_period(
  'a1100000-0000-0000-0000-000000000001', 'a1400000-0000-0000-0000-000000000002', 'Scheduled Round',
  '2026-08-01', '2026-08-31', p_due_date := '2026-08-05', p_status := 'SCHEDULED'
) as result;

select throws_ok(
  format(
    $sql$ select public.rpc_assess_contribution_penalties('a1100000-0000-0000-0000-000000000001', %L, '2026-09-01') $sql$,
    (select (result ->> 'id')::text from t_period_scheduled)
  ),
  'P0001',
  'CONTRIBUTION_PERIOD_NOT_OPEN',
  'a SCHEDULED period cannot be assessed'
);

create temporary table t_period_cancelled as
select public.rpc_create_contribution_period(
  'a1100000-0000-0000-0000-000000000001', 'a1400000-0000-0000-0000-000000000002', 'Cancelled Round',
  '2026-08-01', '2026-08-31', p_due_date := '2026-08-05'
) as result;

select public.rpc_cancel_contribution_period(
  'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_cancelled)
);

select throws_ok(
  format(
    $sql$ select public.rpc_assess_contribution_penalties('a1100000-0000-0000-0000-000000000001', %L, '2026-09-01') $sql$,
    (select (result ->> 'id')::text from t_period_cancelled)
  ),
  'P0001',
  'CONTRIBUTION_PERIOD_NOT_OPEN',
  'a CANCELLED period cannot be assessed'
);

-- ---------------------------------------------------------------------
-- FIXED_ONCE: grace-period boundary, single occurrence, never repeats.
-- Only "Eligible Member" (a1200000...06) is used here so charge counts
-- stay simple — the treasurer/admin/etc all joined 2025-01-01 too and
-- would otherwise also be charged/penalized, muddying the counts.
-- ---------------------------------------------------------------------

create temporary table t_period_once as
select public.rpc_create_contribution_period(
  'a1100000-0000-0000-0000-000000000001', 'a1400000-0000-0000-0000-000000000002', 'Fixed Once Round',
  '2026-08-01', '2026-08-31', p_due_date := '2026-08-05'
) as result;

select public.rpc_exclude_contribution_period_member(
  'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_once),
  'a1200000-0000-0000-0000-000000000001'
), public.rpc_exclude_contribution_period_member(
  'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_once),
  'a1200000-0000-0000-0000-000000000002'
), public.rpc_exclude_contribution_period_member(
  'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_once),
  'a1200000-0000-0000-0000-000000000003'
), public.rpc_exclude_contribution_period_member(
  'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_once),
  'a1200000-0000-0000-0000-000000000004'
), public.rpc_exclude_contribution_period_member(
  'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_once),
  'a1200000-0000-0000-0000-000000000005'
), public.rpc_exclude_contribution_period_member(
  'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_once),
  'a1200000-0000-0000-0000-000000000009'
) from t_period_once;

select public.rpc_open_contribution_period(
  'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_once)
) from t_period_once;

select is(
  (select count(*)::int from public.member_contribution_charges
   where period_id = (select (result ->> 'id')::uuid from t_period_once)),
  1,
  'only the one non-excluded eligible member is charged'
);

-- Threshold = due_date(2026-08-05) + grace(3) = 2026-08-08.
select is(
  (select (public.rpc_assess_contribution_penalties(
    'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_once), '2026-08-07'
  ) ->> 'penalties_created_count')::int from t_period_once),
  0,
  'FIXED_ONCE: before the grace threshold, no penalty is created'
);

select is(
  (select (public.rpc_assess_contribution_penalties(
    'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_once), '2026-08-08'
  ) ->> 'penalties_created_count')::int from t_period_once),
  1,
  'FIXED_ONCE: exactly at the grace threshold, the penalty is created'
);

select is(
  (select cc.assessed_amount from public.contribution_charge_components cc
   join public.member_contribution_charges c on c.id = cc.charge_id
   where c.period_id = (select (result ->> 'id')::uuid from t_period_once)
     and cc.component_type = 'PENALTY'),
  500.00::numeric,
  'FIXED_ONCE penalty amount matches the configured penalty_value'
);

select is(
  (select (public.rpc_assess_contribution_penalties(
    'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_once), '2026-08-08'
  ) ->> 'penalties_created_count')::int from t_period_once),
  0,
  'idempotent: re-running for the same assessment date creates zero duplicates'
);

select is(
  (select (public.rpc_assess_contribution_penalties(
    'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_once), '2027-01-01'
  ) ->> 'penalties_created_count')::int from t_period_once),
  0,
  'FIXED_ONCE never posts a second occurrence, no matter how much later assessment runs'
);

select is(
  (select count(*)::int from public.contribution_charge_components cc
   join public.member_contribution_charges c on c.id = cc.charge_id
   where c.period_id = (select (result ->> 'id')::uuid from t_period_once)
     and cc.component_type = 'PENALTY'),
  1,
  'FIXED_ONCE: exactly one PENALTY component ever exists for the charge'
);

select is(
  (select cc.assessed_amount from public.contribution_charge_components cc
   join public.member_contribution_charges c on c.id = cc.charge_id
   where c.period_id = (select (result ->> 'id')::uuid from t_period_once)
     and cc.component_type = 'BASE'),
  10000.00::numeric,
  'the BASE component is never modified by penalty assessment'
);

-- ---------------------------------------------------------------------
-- PERCENTAGE_ONCE: rounding.
-- ---------------------------------------------------------------------

create temporary table t_period_pct as
select public.rpc_create_contribution_period(
  'a1100000-0000-0000-0000-000000000001', 'a1400000-0000-0000-0000-000000000003', 'Percentage Once Round',
  '2026-08-01', '2026-08-31', p_due_date := '2026-08-05'
) as result;

select public.rpc_exclude_contribution_period_member(
  'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_pct), m.id
) from t_period_pct, (values
  ('a1200000-0000-0000-0000-000000000001'::uuid), ('a1200000-0000-0000-0000-000000000002'::uuid),
  ('a1200000-0000-0000-0000-000000000003'::uuid), ('a1200000-0000-0000-0000-000000000004'::uuid),
  ('a1200000-0000-0000-0000-000000000005'::uuid), ('a1200000-0000-0000-0000-000000000009'::uuid)
) as m(id);

select public.rpc_open_contribution_period(
  'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_pct)
) from t_period_pct;

select public.rpc_assess_contribution_penalties(
  'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_pct), '2026-08-08'
) from t_period_pct;

select is(
  (select cc.assessed_amount from public.contribution_charge_components cc
   join public.member_contribution_charges c on c.id = cc.charge_id
   where c.period_id = (select (result ->> 'id')::uuid from t_period_pct)
     and cc.component_type = 'PENALTY'),
  33.33::numeric,
  'PERCENTAGE_ONCE rounds 10% of 333.33 to 33.33 (2 decimal places, no float arithmetic)'
);

-- ---------------------------------------------------------------------
-- Live UAT regression: PERCENTAGE_ONCE, value 25, base 5000 must be
-- 1,250 — never 25 (the raw unmultiplied penalty_value) and never
-- 5,025 as a wrong total.
-- ---------------------------------------------------------------------

create temporary table t_period_pct5000 as
select public.rpc_create_contribution_period(
  'a1100000-0000-0000-0000-000000000001', 'a1400000-0000-0000-0000-000000000006', 'Percentage Once 5000 Round',
  '2026-08-01', '2026-08-31', p_due_date := '2026-08-05'
) as result;

select public.rpc_exclude_contribution_period_member(
  'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_pct5000), m.id
) from t_period_pct5000, (values
  ('a1200000-0000-0000-0000-000000000001'::uuid), ('a1200000-0000-0000-0000-000000000002'::uuid),
  ('a1200000-0000-0000-0000-000000000003'::uuid), ('a1200000-0000-0000-0000-000000000004'::uuid),
  ('a1200000-0000-0000-0000-000000000005'::uuid), ('a1200000-0000-0000-0000-000000000009'::uuid)
) as m(id);

select public.rpc_open_contribution_period(
  'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_pct5000)
) from t_period_pct5000;

select public.rpc_assess_contribution_penalties(
  'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_pct5000), '2026-08-08'
) from t_period_pct5000;

select is(
  (select cc.assessed_amount from public.contribution_charge_components cc
   join public.member_contribution_charges c on c.id = cc.charge_id
   where c.period_id = (select (result ->> 'id')::uuid from t_period_pct5000)
     and cc.component_type = 'PENALTY'),
  1250.00::numeric,
  'PERCENTAGE_ONCE: 25% of BASE 5,000 is 1,250 (the live-reported UAT scenario), never 25 or 5,025'
);

select is(
  (select cc.assessed_amount from public.contribution_charge_components cc
   join public.member_contribution_charges c on c.id = cc.charge_id
   where c.period_id = (select (result ->> 'id')::uuid from t_period_pct5000)
     and cc.component_type = 'BASE'),
  5000.00::numeric,
  'the BASE component remains exactly 5,000 — unmodified by the penalty component'
);

-- ---------------------------------------------------------------------
-- 10% of 100,000 = 10,000 — a second, independently-chosen pair of
-- numbers proving the formula generalizes.
-- ---------------------------------------------------------------------

create temporary table t_period_pct100k as
select public.rpc_create_contribution_period(
  'a1100000-0000-0000-0000-000000000001', 'a1400000-0000-0000-0000-000000000007', 'Percentage Once 100k Round',
  '2026-08-01', '2026-08-31', p_due_date := '2026-08-05'
) as result;

select public.rpc_exclude_contribution_period_member(
  'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_pct100k), m.id
) from t_period_pct100k, (values
  ('a1200000-0000-0000-0000-000000000001'::uuid), ('a1200000-0000-0000-0000-000000000002'::uuid),
  ('a1200000-0000-0000-0000-000000000003'::uuid), ('a1200000-0000-0000-0000-000000000004'::uuid),
  ('a1200000-0000-0000-0000-000000000005'::uuid), ('a1200000-0000-0000-0000-000000000009'::uuid)
) as m(id);

select public.rpc_open_contribution_period(
  'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_pct100k)
) from t_period_pct100k;

select public.rpc_assess_contribution_penalties(
  'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_pct100k), '2026-08-08'
) from t_period_pct100k;

select is(
  (select cc.assessed_amount from public.contribution_charge_components cc
   join public.member_contribution_charges c on c.id = cc.charge_id
   where c.period_id = (select (result ->> 'id')::uuid from t_period_pct100k)
     and cc.component_type = 'PENALTY'),
  10000.00::numeric,
  'PERCENTAGE_ONCE: 10% of BASE 100,000 is 10,000'
);

-- ---------------------------------------------------------------------
-- PERCENTAGE_RECURRING must never compound: the second occurrence is
-- still 25% of the ORIGINAL BASE (5000), not 25% of BASE + the first
-- posted penalty (which would wrongly be 1,562.50). No cap on this
-- setup, so the raw (uncapped) amount is directly observable.
-- ---------------------------------------------------------------------

create temporary table t_period_pct_rec as
select public.rpc_create_contribution_period(
  'a1100000-0000-0000-0000-000000000001', 'a1400000-0000-0000-0000-000000000008', 'Percentage Recurring Uncapped Round',
  '2026-08-01', '2026-08-31', p_due_date := '2026-08-05'
) as result;

select public.rpc_exclude_contribution_period_member(
  'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_pct_rec), m.id
) from t_period_pct_rec, (values
  ('a1200000-0000-0000-0000-000000000001'::uuid), ('a1200000-0000-0000-0000-000000000002'::uuid),
  ('a1200000-0000-0000-0000-000000000003'::uuid), ('a1200000-0000-0000-0000-000000000004'::uuid),
  ('a1200000-0000-0000-0000-000000000005'::uuid), ('a1200000-0000-0000-0000-000000000009'::uuid)
) as m(id);

select public.rpc_open_contribution_period(
  'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_pct_rec)
) from t_period_pct_rec;

-- Occurrence 1 (due + 5 days): 25% of 5,000 = 1,250.
select is(
  (select (public.rpc_assess_contribution_penalties(
    'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_pct_rec), '2026-08-10'
  ) ->> 'total_penalty_assessed_this_run')::numeric from t_period_pct_rec),
  1250.00::numeric,
  'PERCENTAGE_RECURRING occurrence 1: 25% of BASE 5,000 is 1,250'
);

-- Occurrence 2 (due + 10 days): must ALSO be 1,250 — 25% of the
-- original 5,000 BASE again, never 25% of (5,000 + 1,250) = 1,562.50.
select is(
  (select (public.rpc_assess_contribution_penalties(
    'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_pct_rec), '2026-08-15'
  ) ->> 'total_penalty_assessed_this_run')::numeric from t_period_pct_rec),
  1250.00::numeric,
  'PERCENTAGE_RECURRING occurrence 2 is also 1,250 (25% of the ORIGINAL base) — not 1,562.50 (no penalty-on-penalty compounding)'
);

select is(
  (select coalesce(sum(cc.assessed_amount), 0) from public.contribution_charge_components cc
   join public.member_contribution_charges c on c.id = cc.charge_id
   where c.period_id = (select (result ->> 'id')::uuid from t_period_pct_rec)
     and cc.component_type = 'PENALTY'),
  2500.00::numeric,
  'two non-compounding 1,250 occurrences sum to exactly 2,500'
);

-- ---------------------------------------------------------------------
-- PERCENTAGE_RECURRING with a cap: the cap still clamps correctly on
-- top of the (correctly non-compounding) percentage-of-BASE basis.
-- ---------------------------------------------------------------------

create temporary table t_period_pct_rec_capped as
select public.rpc_create_contribution_period(
  'a1100000-0000-0000-0000-000000000001', 'a1400000-0000-0000-0000-000000000009', 'Percentage Recurring Capped Round',
  '2026-08-01', '2026-08-31', p_due_date := '2026-08-05'
) as result;

select public.rpc_exclude_contribution_period_member(
  'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_pct_rec_capped), m.id
) from t_period_pct_rec_capped, (values
  ('a1200000-0000-0000-0000-000000000001'::uuid), ('a1200000-0000-0000-0000-000000000002'::uuid),
  ('a1200000-0000-0000-0000-000000000003'::uuid), ('a1200000-0000-0000-0000-000000000004'::uuid),
  ('a1200000-0000-0000-0000-000000000005'::uuid), ('a1200000-0000-0000-0000-000000000009'::uuid)
) as m(id);

select public.rpc_open_contribution_period(
  'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_pct_rec_capped)
) from t_period_pct_rec_capped;

-- Occurrence 1: 1,250 (cumulative 1,250 of a 2,000 cap; 750 room left).
select public.rpc_assess_contribution_penalties(
  'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_pct_rec_capped), '2026-08-10'
) from t_period_pct_rec_capped;

-- Occurrence 2: raw would be 1,250 again (non-compounding), but only
-- 750 of cap room remains -> clamped to exactly 750, not 1,250 and not
-- the compounded-then-clamped coincidence.
select is(
  (select (public.rpc_assess_contribution_penalties(
    'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_pct_rec_capped), '2026-08-15'
  ) ->> 'total_penalty_assessed_this_run')::numeric from t_period_pct_rec_capped),
  750.00::numeric,
  'PERCENTAGE_RECURRING + cap: occurrence 2 is clamped to the remaining cap room (750), proving the cap applies after the correct non-compounding calculation'
);

select is(
  (select coalesce(sum(cc.assessed_amount), 0) from public.contribution_charge_components cc
   join public.member_contribution_charges c on c.id = cc.charge_id
   where c.period_id = (select (result ->> 'id')::uuid from t_period_pct_rec_capped)
     and cc.component_type = 'PENALTY'),
  2000.00::numeric,
  'cumulative percentage-recurring penalty never exceeds its 2,000 cap'
);

-- Far future: cap already reached -> hard stop, nothing more ever.
select is(
  (select (public.rpc_assess_contribution_penalties(
    'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_pct_rec_capped), '2028-01-01'
  ) ->> 'penalties_created_count')::int from t_period_pct_rec_capped),
  0,
  'once the cap is reached, PERCENTAGE_RECURRING also hard-stops — no further occurrences, ever'
);

-- ---------------------------------------------------------------------
-- FIXED_RECURRING: successive occurrences, cap clamping, hard stop.
-- ---------------------------------------------------------------------

create temporary table t_period_rec as
select public.rpc_create_contribution_period(
  'a1100000-0000-0000-0000-000000000001', 'a1400000-0000-0000-0000-000000000004', 'Fixed Recurring Round',
  '2026-08-01', '2026-08-31', p_due_date := '2026-08-05'
) as result;

select public.rpc_exclude_contribution_period_member(
  'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_rec), m.id
) from t_period_rec, (values
  ('a1200000-0000-0000-0000-000000000001'::uuid), ('a1200000-0000-0000-0000-000000000002'::uuid),
  ('a1200000-0000-0000-0000-000000000003'::uuid), ('a1200000-0000-0000-0000-000000000004'::uuid),
  ('a1200000-0000-0000-0000-000000000005'::uuid), ('a1200000-0000-0000-0000-000000000009'::uuid)
) as m(id);

select public.rpc_open_contribution_period(
  'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_rec)
) from t_period_rec;

-- Threshold occurrence 1 = due(2026-08-05) + 5 = 2026-08-10.
select is(
  (select (public.rpc_assess_contribution_penalties(
    'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_rec), '2026-08-10'
  ) ->> 'penalties_created_count')::int from t_period_rec),
  1,
  'FIXED_RECURRING occurrence 1 is posted once its grace period elapses'
);

-- Occurrence 2 = due + 10 = 2026-08-15.
select is(
  (select (public.rpc_assess_contribution_penalties(
    'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_rec), '2026-08-15'
  ) ->> 'penalties_created_count')::int from t_period_rec),
  1,
  'FIXED_RECURRING occurrence 2 is posted exactly once after its own grace period elapses'
);

select is(
  (select count(*)::int from public.contribution_charge_components cc
   join public.member_contribution_charges c on c.id = cc.charge_id
   where c.period_id = (select (result ->> 'id')::uuid from t_period_rec)
     and cc.component_type = 'PENALTY'),
  2,
  'both occurrence 1 and occurrence 2 coexist — occurrence 2 does not replace occurrence 1'
);

-- Occurrence 3 = due + 15 = 2026-08-20; raw 1000 would bring cumulative to
-- 3000, but cap is 2500 -> clamped to 500.
select is(
  (select (public.rpc_assess_contribution_penalties(
    'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_rec), '2026-08-20'
  ) ->> 'total_penalty_assessed_this_run')::numeric from t_period_rec),
  500.00::numeric,
  'the occurrence that would exceed the cap is clamped to the remaining room'
);

select is(
  (select coalesce(sum(cc.assessed_amount), 0) from public.contribution_charge_components cc
   join public.member_contribution_charges c on c.id = cc.charge_id
   where c.period_id = (select (result ->> 'id')::uuid from t_period_rec)
     and cc.component_type = 'PENALTY'),
  2500.00::numeric,
  'cumulative posted penalty for the charge never exceeds penalty_cap_amount'
);

-- Far future: cap already reached -> hard stop, nothing more ever.
select is(
  (select (public.rpc_assess_contribution_penalties(
    'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_rec), '2028-01-01'
  ) ->> 'penalties_created_count')::int from t_period_rec),
  0,
  'once the cap is reached, no further occurrences are ever posted, even far in the future'
);

select is(
  (select count(*)::int from public.contribution_charge_components cc
   join public.member_contribution_charges c on c.id = cc.charge_id
   where c.period_id = (select (result ->> 'id')::uuid from t_period_rec)
     and cc.component_type = 'PENALTY'),
  3,
  'exactly 3 PENALTY components exist total (no repeat-forever past the cap)'
);

select ok(
  (select bool_and(cc.assessed_amount > 0) from public.contribution_charge_components cc
   join public.member_contribution_charges c on c.id = cc.charge_id
   where c.period_id = (select (result ->> 'id')::uuid from t_period_rec)
     and cc.component_type = 'PENALTY'),
  'every posted penalty component has a strictly positive amount (schema-enforced)'
);

-- ---------------------------------------------------------------------
-- Eligibility inheritance: suspended/exited/excluded never charged, so
-- never penalized either; a post-OPEN enrolled member is penalized like
-- any other charge.
-- ---------------------------------------------------------------------

create temporary table t_period_elig as
select public.rpc_create_contribution_period(
  'a1100000-0000-0000-0000-000000000001', 'a1400000-0000-0000-0000-000000000002', 'Eligibility Round',
  '2026-08-01', '2026-08-31', p_due_date := '2026-08-05'
) as result;

select public.rpc_exclude_contribution_period_member(
  'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_elig),
  'a1200000-0000-0000-0000-000000000009'
) from t_period_elig;

select public.rpc_open_contribution_period(
  'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_elig)
) from t_period_elig;

-- Explicitly enroll the late joiner (ineligible at OPEN — joined_at is
-- 2099) after OPEN, matching the 06A post-open-enrollment workflow.
select public.rpc_enroll_member_in_contribution_period(
  'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_elig),
  'a1200000-0000-0000-0000-000000000010'
) from t_period_elig;

select public.rpc_assess_contribution_penalties(
  'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_elig), '2026-08-10'
) from t_period_elig;

select is(
  (select count(*)::int from public.contribution_charge_components cc
   join public.member_contribution_charges c on c.id = cc.charge_id
   where c.period_id = (select (result ->> 'id')::uuid from t_period_elig)
     and cc.component_type = 'PENALTY'
     and c.membership_id = 'a1200000-0000-0000-0000-000000000007'),
  0,
  'a SUSPENDED member is never charged, so never penalized either'
);

select is(
  (select count(*)::int from public.contribution_charge_components cc
   join public.member_contribution_charges c on c.id = cc.charge_id
   where c.period_id = (select (result ->> 'id')::uuid from t_period_elig)
     and cc.component_type = 'PENALTY'
     and c.membership_id = 'a1200000-0000-0000-0000-000000000008'),
  0,
  'an EXITED member is never charged, so never penalized either'
);

select is(
  (select count(*)::int from public.contribution_charge_components cc
   join public.member_contribution_charges c on c.id = cc.charge_id
   where c.period_id = (select (result ->> 'id')::uuid from t_period_elig)
     and cc.component_type = 'PENALTY'
     and c.membership_id = 'a1200000-0000-0000-0000-000000000009'),
  0,
  'an explicitly-excluded member is never charged, so never penalized either'
);

select is(
  (select count(*)::int from public.contribution_charge_components cc
   join public.member_contribution_charges c on c.id = cc.charge_id
   where c.period_id = (select (result ->> 'id')::uuid from t_period_elig)
     and cc.component_type = 'PENALTY'
     and c.membership_id = 'a1200000-0000-0000-0000-000000000010'),
  1,
  'a member explicitly enrolled after OPEN is penalized exactly like any other overdue charge'
);

select ok(
  (select count(*)::int from public.contribution_charge_components cc
   join public.member_contribution_charges c on c.id = cc.charge_id
   where c.period_id = (select (result ->> 'id')::uuid from t_period_elig)
     and cc.component_type = 'PENALTY') > 0,
  'a normally-eligible ACTIVE member is penalized once overdue'
);

-- ---------------------------------------------------------------------
-- Snapshot immutability: a live setup edit after OPEN never changes an
-- already-OPEN period's penalty behaviour.
-- ---------------------------------------------------------------------

create temporary table t_period_snap2 as
select public.rpc_create_contribution_period(
  'a1100000-0000-0000-0000-000000000001', 'a1400000-0000-0000-0000-000000000005', 'Snapshot Round 2',
  '2026-09-01', '2026-09-30', p_due_date := '2026-09-05'
) as result;

select public.rpc_exclude_contribution_period_member(
  'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_snap2), m.id
) from t_period_snap2, (values
  ('a1200000-0000-0000-0000-000000000001'::uuid), ('a1200000-0000-0000-0000-000000000002'::uuid),
  ('a1200000-0000-0000-0000-000000000003'::uuid), ('a1200000-0000-0000-0000-000000000004'::uuid),
  ('a1200000-0000-0000-0000-000000000005'::uuid), ('a1200000-0000-0000-0000-000000000009'::uuid)
) as m(id);

select public.rpc_open_contribution_period(
  'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_snap2)
) from t_period_snap2;

-- 06A's own CONTRIBUTION_SETUP_CONFIG_LOCKED guard already refuses to
-- edit a setup's penalty_* fields once ANY period under it has posted
-- (see 22_contribution_period_open_lifecycle.test.sql) — so the
-- rpc_update_contribution_setup path can never actually put a live
-- setup's penalty config out of sync with an OPEN period's snapshot.
-- To prove rpc_assess_contribution_penalties itself reads only the
-- period's frozen snapshot_penalty_* columns (defense in depth, not
-- reliant on that other lock holding), bypass the RPC layer entirely
-- with a direct superuser UPDATE — simulating "the live config
-- diverged from the snapshot" regardless of how that could happen.
reset role;
update public.contribution_setups set penalty_value = 9999
where id = 'a1400000-0000-0000-0000-000000000005';
set local role authenticated;
set local request.jwt.claim.sub to 'a1000000-0000-0000-0000-000000000001';

select public.rpc_assess_contribution_penalties(
  'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_snap2), '2026-09-08'
) from t_period_snap2;

select is(
  (select cc.assessed_amount from public.contribution_charge_components cc
   join public.member_contribution_charges c on c.id = cc.charge_id
   where c.period_id = (select (result ->> 'id')::uuid from t_period_snap2)
     and cc.component_type = 'PENALTY'),
  500.00::numeric,
  'assessment uses the period''s frozen snapshot (500), never the live setup''s edited value (9999)'
);

select is(
  (select penalty_value from public.contribution_setups where id = 'a1400000-0000-0000-0000-000000000005'),
  9999.00::numeric,
  'the live setup''s own penalty_value is indeed now 9999, confirming the edit really happened'
);

-- ---------------------------------------------------------------------
-- Group isolation.
-- ---------------------------------------------------------------------

set local request.jwt.claim.sub to 'a1000000-0000-0000-0000-000000000010';

select throws_ok(
  format(
    $sql$ select public.rpc_assess_contribution_penalties('a1100000-0000-0000-0000-000000000002', %L, '2026-09-01') $sql$,
    (select (result ->> 'id')::text from t_period_rec)
  ),
  '22023',
  null,
  'a caller in Group B cannot assess a Group A period by passing Group B''s own group_id'
);

set local request.jwt.claim.sub to 'a1000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- Permission matrix.
-- ---------------------------------------------------------------------

create temporary table t_period_perm as
select public.rpc_create_contribution_period(
  'a1100000-0000-0000-0000-000000000001', 'a1400000-0000-0000-0000-000000000002', 'Permission Round',
  '2026-08-01', '2026-08-31', p_due_date := '2026-08-05'
) as result;

select public.rpc_open_contribution_period(
  'a1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_perm)
) from t_period_perm;

select lives_ok(
  format(
    $sql$ select public.rpc_assess_contribution_penalties('a1100000-0000-0000-0000-000000000001', %L, '2026-08-08') $sql$,
    (select (result ->> 'id')::text from t_period_perm)
  ),
  'ADMIN can assess penalties'
);

set local request.jwt.claim.sub to 'a1000000-0000-0000-0000-000000000002';

select lives_ok(
  format(
    $sql$ select public.rpc_assess_contribution_penalties('a1100000-0000-0000-0000-000000000001', %L, '2026-08-09') $sql$,
    (select (result ->> 'id')::text from t_period_perm)
  ),
  'TREASURER can assess penalties'
);

set local request.jwt.claim.sub to 'a1000000-0000-0000-0000-000000000003';

select throws_ok(
  format(
    $sql$ select public.rpc_assess_contribution_penalties('a1100000-0000-0000-0000-000000000001', %L, '2026-08-09') $sql$,
    (select (result ->> 'id')::text from t_period_perm)
  ),
  '42501',
  null,
  'CHAIRPERSON cannot assess penalties'
);

set local request.jwt.claim.sub to 'a1000000-0000-0000-0000-000000000004';

select throws_ok(
  format(
    $sql$ select public.rpc_assess_contribution_penalties('a1100000-0000-0000-0000-000000000001', %L, '2026-08-09') $sql$,
    (select (result ->> 'id')::text from t_period_perm)
  ),
  '42501',
  null,
  'SECRETARY cannot assess penalties'
);

set local request.jwt.claim.sub to 'a1000000-0000-0000-0000-000000000005';

select throws_ok(
  format(
    $sql$ select public.rpc_assess_contribution_penalties('a1100000-0000-0000-0000-000000000001', %L, '2026-08-09') $sql$,
    (select (result ->> 'id')::text from t_period_perm)
  ),
  '42501',
  null,
  'MEMBER can never trigger group-wide penalty assessment'
);

-- ---------------------------------------------------------------------
-- Database-level idempotency safety net: the unique index itself
-- rejects a duplicate (charge_id, sequence) PENALTY row, independent of
-- the assessment RPC's own duplicate-avoidance logic above.
-- ---------------------------------------------------------------------

reset role;

select throws_ok(
  format(
    $sql$
      insert into public.contribution_charge_components (
        group_id, charge_id, component_type, assessed_amount, effective_at, sequence
      )
      select group_id, charge_id, 'PENALTY', 1, effective_at, sequence
      from public.contribution_charge_components
      where component_type = 'PENALTY'
      limit 1
    $sql$
  ),
  '23505',
  null,
  'the unique index blocks a second PENALTY component at the same (charge_id, sequence), independent of the RPC'
);

set local role authenticated;
set local request.jwt.claim.sub to 'a1000000-0000-0000-0000-000000000001';

select * from finish();

rollback;
