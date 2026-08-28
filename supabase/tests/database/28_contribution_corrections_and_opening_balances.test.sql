-- Contribution Engine (Prompt 06C): adjustments, waivers, opening
-- balances — sign convention, floor validation, idempotency,
-- CLOSED-period correction, permission matrix, group isolation, and
-- read-model net-assessed totals.
begin;

select plan(55);

insert into auth.users (id, email) values
  ('b1000000-0000-0000-0000-000000000001', 'c06c-admin@example.com'),
  ('b1000000-0000-0000-0000-000000000002', 'c06c-treasurer@example.com'),
  ('b1000000-0000-0000-0000-000000000003', 'c06c-chairperson@example.com'),
  ('b1000000-0000-0000-0000-000000000004', 'c06c-secretary@example.com'),
  ('b1000000-0000-0000-0000-000000000005', 'c06c-member@example.com'),
  ('b1000000-0000-0000-0000-000000000006', 'c06c-groupb-treasurer@example.com');

insert into public.groups (id, name, created_by, code) values
  ('b1100000-0000-0000-0000-000000000001', 'Corrections Group A', 'b1000000-0000-0000-0000-000000000001', 'B06CA'),
  ('b1100000-0000-0000-0000-000000000002', 'Corrections Group B', 'b1000000-0000-0000-0000-000000000006', 'B06CB');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('b1200000-0000-0000-0000-000000000001', 'b1100000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'C06C Admin', 'ACTIVE', '2025-01-01', 'B06CA-2026-0001'),
  ('b1200000-0000-0000-0000-000000000002', 'b1100000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002', 'C06C Treasurer', 'ACTIVE', '2025-01-01', 'B06CA-2026-0002'),
  ('b1200000-0000-0000-0000-000000000003', 'b1100000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000003', 'C06C Chairperson', 'ACTIVE', '2025-01-01', 'B06CA-2026-0003'),
  ('b1200000-0000-0000-0000-000000000004', 'b1100000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000004', 'C06C Secretary', 'ACTIVE', '2025-01-01', 'B06CA-2026-0004'),
  ('b1200000-0000-0000-0000-000000000005', 'b1100000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000005', 'C06C Plain Member', 'ACTIVE', '2025-01-01', 'B06CA-2026-0005'),
  ('b1200000-0000-0000-0000-000000000006', 'b1100000-0000-0000-0000-000000000001', null, 'Eligible One', 'ACTIVE', '2025-01-01', 'B06CA-2026-0006'),
  ('b1200000-0000-0000-0000-000000000007', 'b1100000-0000-0000-0000-000000000001', null, 'Eligible Two', 'ACTIVE', '2025-01-01', 'B06CA-2026-0007'),
  ('b1200000-0000-0000-0000-000000000008', 'b1100000-0000-0000-0000-000000000001', null, 'Eligible Three', 'ACTIVE', '2025-01-01', 'B06CA-2026-0008'),
  ('b1200000-0000-0000-0000-000000000009', 'b1100000-0000-0000-0000-000000000001', null, 'Ob Member One', 'ACTIVE', '2025-01-01', 'B06CA-2026-0009'),
  ('b1200000-0000-0000-0000-000000000010', 'b1100000-0000-0000-0000-000000000001', null, 'Ob Member Two', 'ACTIVE', '2025-01-01', 'B06CA-2026-0010'),
  ('b1200000-0000-0000-0000-000000000099', 'b1100000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000006', 'C06C GroupB Treasurer', 'ACTIVE', '2025-01-01', 'B06CB-2026-0001');

insert into public.group_membership_roles (group_membership_id, role_id) select 'b1200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select 'b1200000-0000-0000-0000-000000000002', id from public.roles where code = 'TREASURER';
insert into public.group_membership_roles (group_membership_id, role_id) select 'b1200000-0000-0000-0000-000000000003', id from public.roles where code = 'CHAIRPERSON';
insert into public.group_membership_roles (group_membership_id, role_id) select 'b1200000-0000-0000-0000-000000000004', id from public.roles where code = 'SECRETARY';
insert into public.group_membership_roles (group_membership_id, role_id) select 'b1200000-0000-0000-0000-000000000005', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id) select 'b1200000-0000-0000-0000-000000000099', id from public.roles where code = 'TREASURER';

insert into public.contribution_types (id, group_id, name, category, accounting_treatment, created_by) values
  ('b1300000-0000-0000-0000-000000000001', 'b1100000-0000-0000-0000-000000000001', 'Dues', 'GENERAL', 'GROUP_INCOME', 'b1000000-0000-0000-0000-000000000001'),
  ('b1300000-0000-0000-0000-000000000002', 'b1100000-0000-0000-0000-000000000001', 'Hisa', 'SHARE', 'SHARE_CAPITAL', 'b1000000-0000-0000-0000-000000000001');

-- Plain FIXED setup, no penalty policy — used by every adjustment/waiver test.
insert into public.contribution_setups (id, group_id, contribution_type_id, name, schedule_mode, amount_mode, fixed_amount, created_by) values
  ('b1400000-0000-0000-0000-000000000001', 'b1100000-0000-0000-0000-000000000001', 'b1300000-0000-0000-0000-000000000001', 'Dues Setup', 'ON_DEMAND', 'FIXED', 100000, 'b1000000-0000-0000-0000-000000000001');

-- FIXED_ONCE penalty setup, for the combined BASE+PENALTY+ADJUSTMENT+WAIVER read-totals test.
insert into public.contribution_setups (id, group_id, contribution_type_id, name, schedule_mode, amount_mode, fixed_amount, penalty_mode, penalty_grace_days, penalty_value, created_by) values
  ('b1400000-0000-0000-0000-000000000002', 'b1100000-0000-0000-0000-000000000001', 'b1300000-0000-0000-0000-000000000001', 'Penalized Dues Setup', 'ON_DEMAND', 'FIXED', 100000, 'FIXED_ONCE', 3, 10000, 'b1000000-0000-0000-0000-000000000001');

set local role authenticated;
set local request.jwt.claim.sub to 'b1000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- ADJUSTMENTS — happy path (positive then negative), on one isolated
-- charge (only "Eligible One" left unexcluded).
-- ---------------------------------------------------------------------

create temporary table t_period_adj as
select public.rpc_create_contribution_period(
  'b1100000-0000-0000-0000-000000000001', 'b1400000-0000-0000-0000-000000000001', 'Adjustment Round',
  '2026-08-01', '2026-08-31', p_due_date := '2026-08-05'
) as result;

select public.rpc_exclude_contribution_period_member(
  'b1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_adj), m.id
) from t_period_adj, (values
  ('b1200000-0000-0000-0000-000000000001'::uuid), ('b1200000-0000-0000-0000-000000000002'::uuid),
  ('b1200000-0000-0000-0000-000000000003'::uuid), ('b1200000-0000-0000-0000-000000000004'::uuid),
  ('b1200000-0000-0000-0000-000000000005'::uuid), ('b1200000-0000-0000-0000-000000000007'::uuid),
  ('b1200000-0000-0000-0000-000000000008'::uuid)
) as m(id);

select public.rpc_open_contribution_period(
  'b1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_adj)
) from t_period_adj;

create temporary table t_charge_adj as
select c.id as charge_id
from public.member_contribution_charges c, t_period_adj p
where c.period_id = (select (p.result ->> 'id')::uuid)
  and c.membership_id = 'b1200000-0000-0000-0000-000000000006';

select throws_ok(
  format(
    $sql$ select public.rpc_create_contribution_adjustment('b1100000-0000-0000-0000-000000000001', %L, 0, 'zero test', '2026-08-10') $sql$,
    (select charge_id::text from t_charge_adj)
  ),
  '22023',
  'ADJUSTMENT_AMOUNT_REQUIRED',
  'a zero adjustment amount is rejected'
);

select throws_ok(
  format(
    $sql$ select public.rpc_create_contribution_adjustment('b1100000-0000-0000-0000-000000000001', %L, -150000, 'too negative', '2026-08-10') $sql$,
    (select charge_id::text from t_charge_adj)
  ),
  'P0001',
  'ADJUSTMENT_WOULD_MAKE_OBLIGATION_NEGATIVE',
  'a negative adjustment that would drive net assessed below zero is rejected'
);

select throws_ok(
  format(
    $sql$ select public.rpc_create_contribution_adjustment('b1100000-0000-0000-0000-000000000001', %L, 5000, '   ', '2026-08-10') $sql$,
    (select charge_id::text from t_charge_adj)
  ),
  '22023',
  'ADJUSTMENT_REASON_REQUIRED',
  'a blank reason is rejected'
);

select is(
  (select coalesce(sum(assessed_amount), 0) from public.contribution_charge_components where charge_id = (select charge_id from t_charge_adj)),
  100000.00::numeric,
  'the rejected attempts posted nothing — net assessed is still just BASE (100,000)'
);

create temporary table t_adjust_positive as
select public.rpc_create_contribution_adjustment(
  'b1100000-0000-0000-0000-000000000001', (select charge_id from t_charge_adj), 20000, 'undercharged', '2026-08-10'
) as result;

select is(
  (select (result ->> 'net_assessed')::numeric from t_adjust_positive),
  120000.00::numeric,
  'a positive adjustment (+20,000) increases net assessed to 120,000'
);

create temporary table t_adjust_negative as
select public.rpc_create_contribution_adjustment(
  'b1100000-0000-0000-0000-000000000001', (select charge_id from t_charge_adj), -30000, 'overcharged, correcting', '2026-08-11'
) as result;

select is(
  (select (result ->> 'net_assessed')::numeric from t_adjust_negative),
  90000.00::numeric,
  'a subsequent negative adjustment (-30,000) reduces net assessed to 90,000'
);

select is(
  (select cc.assessed_amount from public.contribution_charge_components cc
   where cc.charge_id = (select charge_id from t_charge_adj) and cc.component_type = 'BASE'),
  100000.00::numeric,
  'BASE remains exactly 100,000 — never rewritten by an adjustment'
);

-- ---------------------------------------------------------------------
-- ADJUSTMENTS — CLOSED period correction, permission matrix, group
-- isolation, idempotency. Fresh charge (Eligible Two) so it starts
-- clean at BASE-only.
-- ---------------------------------------------------------------------

create temporary table t_period_closed as
select public.rpc_create_contribution_period(
  'b1100000-0000-0000-0000-000000000001', 'b1400000-0000-0000-0000-000000000001', 'Closed Round',
  '2026-08-01', '2026-08-31', p_due_date := '2026-08-05'
) as result;

select public.rpc_exclude_contribution_period_member(
  'b1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_closed), m.id
) from t_period_closed, (values
  ('b1200000-0000-0000-0000-000000000001'::uuid), ('b1200000-0000-0000-0000-000000000002'::uuid),
  ('b1200000-0000-0000-0000-000000000003'::uuid), ('b1200000-0000-0000-0000-000000000004'::uuid),
  ('b1200000-0000-0000-0000-000000000005'::uuid), ('b1200000-0000-0000-0000-000000000006'::uuid),
  ('b1200000-0000-0000-0000-000000000008'::uuid)
) as m(id);

select public.rpc_open_contribution_period(
  'b1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_closed)
) from t_period_closed;

select public.rpc_close_contribution_period(
  'b1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_closed)
) from t_period_closed;

create temporary table t_charge_closed as
select c.id as charge_id
from public.member_contribution_charges c, t_period_closed p
where c.period_id = (select (p.result ->> 'id')::uuid)
  and c.membership_id = 'b1200000-0000-0000-0000-000000000007';

select lives_ok(
  format(
    $sql$ select public.rpc_create_contribution_adjustment('b1100000-0000-0000-0000-000000000001', %L, 5000, 'discovered after close', '2026-08-15') $sql$,
    (select charge_id::text from t_charge_closed)
  ),
  'an adjustment can be posted against a charge whose period is already CLOSED'
);

select is(
  (select status::text from public.contribution_periods p, t_period_closed t where p.id = (t.result ->> 'id')::uuid),
  'CLOSED',
  'posting the adjustment does not reopen the CLOSED period'
);

-- Idempotency: same key retried -> exactly one component, same result.
create temporary table t_idem_1 as
select public.rpc_create_contribution_adjustment(
  'b1100000-0000-0000-0000-000000000001', (select charge_id from t_charge_closed), 7000, 'idempotent test', '2026-08-16', 'idem-key-adj-1'
) as result;

create temporary table t_idem_2 as
select public.rpc_create_contribution_adjustment(
  'b1100000-0000-0000-0000-000000000001', (select charge_id from t_charge_closed), 7000, 'idempotent test', '2026-08-16', 'idem-key-adj-1'
) as result;

select is(
  (select (result ->> 'already_posted')::boolean from t_idem_2),
  true,
  'retrying the same idempotency key reports already_posted, not a fresh post'
);

select is(
  (select count(*)::int from public.contribution_charge_components
   where charge_id = (select charge_id from t_charge_closed) and component_type = 'ADJUSTMENT' and idempotency_key = 'idem-key-adj-1'),
  1,
  'exactly one ADJUSTMENT component exists for the retried idempotency key — no duplicate'
);

-- Permission matrix.
set local request.jwt.claim.sub to 'b1000000-0000-0000-0000-000000000005';

select throws_ok(
  format(
    $sql$ select public.rpc_create_contribution_adjustment('b1100000-0000-0000-0000-000000000001', %L, 1000, 'member attempt', '2026-08-10') $sql$,
    (select charge_id::text from t_charge_closed)
  ),
  '42501',
  null,
  'MEMBER cannot create a contribution adjustment'
);

set local request.jwt.claim.sub to 'b1000000-0000-0000-0000-000000000001';

-- Cross-group isolation.
set local request.jwt.claim.sub to 'b1000000-0000-0000-0000-000000000006';

select throws_ok(
  format(
    $sql$ select public.rpc_create_contribution_adjustment('b1100000-0000-0000-0000-000000000002', %L, 1000, 'wrong group', '2026-08-10') $sql$,
    (select charge_id::text from t_charge_closed)
  ),
  '22023',
  null,
  'Group B cannot adjust a Group A charge by passing Group B''s own group_id'
);

set local request.jwt.claim.sub to 'b1000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- WAIVERS — partial, full, beyond-net rejection, sign, reason, CLOSED,
-- permissions, group isolation, idempotency.
-- ---------------------------------------------------------------------

create temporary table t_period_waiver as
select public.rpc_create_contribution_period(
  'b1100000-0000-0000-0000-000000000001', 'b1400000-0000-0000-0000-000000000001', 'Waiver Round',
  '2026-08-01', '2026-08-31', p_due_date := '2026-08-05'
) as result;

select public.rpc_exclude_contribution_period_member(
  'b1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_waiver), m.id
) from t_period_waiver, (values
  ('b1200000-0000-0000-0000-000000000001'::uuid), ('b1200000-0000-0000-0000-000000000002'::uuid),
  ('b1200000-0000-0000-0000-000000000003'::uuid), ('b1200000-0000-0000-0000-000000000004'::uuid),
  ('b1200000-0000-0000-0000-000000000005'::uuid), ('b1200000-0000-0000-0000-000000000006'::uuid),
  ('b1200000-0000-0000-0000-000000000007'::uuid)
) as m(id);

select public.rpc_open_contribution_period(
  'b1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_waiver)
) from t_period_waiver;

create temporary table t_charge_waiver as
select c.id as charge_id
from public.member_contribution_charges c, t_period_waiver p
where c.period_id = (select (p.result ->> 'id')::uuid)
  and c.membership_id = 'b1200000-0000-0000-0000-000000000008';

select throws_ok(
  format(
    $sql$ select public.rpc_waive_contribution_charge('b1100000-0000-0000-0000-000000000001', %L, 0, 'zero', '2026-08-10') $sql$,
    (select charge_id::text from t_charge_waiver)
  ),
  '22023',
  'WAIVER_AMOUNT_MUST_BE_POSITIVE',
  'a zero waiver amount is rejected'
);

select throws_ok(
  format(
    $sql$ select public.rpc_waive_contribution_charge('b1100000-0000-0000-0000-000000000001', %L, -100, 'negative', '2026-08-10') $sql$,
    (select charge_id::text from t_charge_waiver)
  ),
  '22023',
  'WAIVER_AMOUNT_MUST_BE_POSITIVE',
  'a negative waiver amount is rejected (the request amount is always a positive magnitude)'
);

select throws_ok(
  format(
    $sql$ select public.rpc_waive_contribution_charge('b1100000-0000-0000-0000-000000000001', %L, 5000, '', '2026-08-10') $sql$,
    (select charge_id::text from t_charge_waiver)
  ),
  '22023',
  'WAIVER_REASON_REQUIRED',
  'a blank reason is rejected'
);

select throws_ok(
  format(
    $sql$ select public.rpc_waive_contribution_charge('b1100000-0000-0000-0000-000000000001', %L, 200000, 'too much', '2026-08-10') $sql$,
    (select charge_id::text from t_charge_waiver)
  ),
  'P0001',
  'WAIVER_EXCEEDS_NET_ASSESSED',
  'a waiver exceeding the current net assessed (100,000) is rejected'
);

create temporary table t_waiver_partial as
select public.rpc_waive_contribution_charge(
  'b1100000-0000-0000-0000-000000000001', (select charge_id from t_charge_waiver), 30000, 'partial goodwill waiver', '2026-08-12'
) as result;

select is(
  (select (result ->> 'net_assessed')::numeric from t_waiver_partial),
  70000.00::numeric,
  'a partial waiver (30,000) reduces net assessed from 100,000 to 70,000'
);

select is(
  (select cc.assessed_amount from public.contribution_charge_components cc
   where cc.charge_id = (select charge_id from t_charge_waiver) and cc.component_type = 'WAIVER'),
  -30000.00::numeric,
  'the WAIVER component is stored negative (-30,000), never positive'
);

select is(
  (select cc.assessed_amount from public.contribution_charge_components cc
   where cc.charge_id = (select charge_id from t_charge_waiver) and cc.component_type = 'BASE'),
  100000.00::numeric,
  'BASE remains exactly 100,000 after the waiver'
);

create temporary table t_waiver_full as
select public.rpc_waive_contribution_charge(
  'b1100000-0000-0000-0000-000000000001', (select charge_id from t_charge_waiver), 70000, 'full waiver of the remainder', '2026-08-13'
) as result;

select is(
  (select (result ->> 'net_assessed')::numeric from t_waiver_full),
  0.00::numeric,
  'waiving the remaining 70,000 brings net assessed to exactly 0'
);

select ok(
  (select coalesce(sum(assessed_amount), 0) from public.contribution_charge_components where charge_id = (select charge_id from t_charge_waiver)) >= 0,
  'net assessed never goes negative'
);

-- CLOSED-charge waiver + idempotency, on the CLOSED charge from above
-- (which already has a +5,000 adjustment and a +7,000 idempotent
-- adjustment posted -> net assessed is 100,000 + 5,000 + 7,000 = 112,000).
select lives_ok(
  format(
    $sql$ select public.rpc_waive_contribution_charge('b1100000-0000-0000-0000-000000000001', %L, 12000, 'waiver on a CLOSED charge', '2026-08-17') $sql$,
    (select charge_id::text from t_charge_closed)
  ),
  'a waiver can be posted against a charge whose period is already CLOSED'
);

select is(
  (select status::text from public.contribution_periods p, t_period_closed t where p.id = (t.result ->> 'id')::uuid),
  'CLOSED',
  'posting the waiver does not reopen the CLOSED period'
);

-- t_charge_waiver is now fully waived (net assessed 0), so any further
-- waiver attempt on it must be rejected — sanity check before proving
-- idempotency on a charge that still has room (t_charge_adj, net 90,000).
select throws_ok(
  format(
    $sql$ select public.rpc_waive_contribution_charge('b1100000-0000-0000-0000-000000000001', %L, 1, 'never reached', '2026-08-20', 'idem-key-waiver-1') $sql$,
    (select charge_id::text from t_charge_waiver)
  ),
  'P0001',
  'WAIVER_EXCEEDS_NET_ASSESSED',
  'sanity: the fully-waived charge genuinely has zero room left for any further waiver'
);

create temporary table t_waiver_idem_a as
select public.rpc_waive_contribution_charge(
  'b1100000-0000-0000-0000-000000000001', (select charge_id from t_charge_adj), 10000, 'idempotent waiver', '2026-08-20', 'idem-key-waiver-2'
) as result;

create temporary table t_waiver_idem_b as
select public.rpc_waive_contribution_charge(
  'b1100000-0000-0000-0000-000000000001', (select charge_id from t_charge_adj), 10000, 'idempotent waiver', '2026-08-20', 'idem-key-waiver-2'
) as result;

select is(
  (select (result ->> 'already_posted')::boolean from t_waiver_idem_b),
  true,
  'retrying the same waiver idempotency key reports already_posted'
);

select is(
  (select count(*)::int from public.contribution_charge_components
   where charge_id = (select charge_id from t_charge_adj) and component_type = 'WAIVER' and idempotency_key = 'idem-key-waiver-2'),
  1,
  'exactly one WAIVER component exists for the retried idempotency key'
);

-- Permission matrix + group isolation for waiver.
set local request.jwt.claim.sub to 'b1000000-0000-0000-0000-000000000005';

select throws_ok(
  format(
    $sql$ select public.rpc_waive_contribution_charge('b1100000-0000-0000-0000-000000000001', %L, 1000, 'member attempt', '2026-08-10') $sql$,
    (select charge_id::text from t_charge_adj)
  ),
  '42501',
  null,
  'MEMBER cannot waive a contribution obligation'
);

set local request.jwt.claim.sub to 'b1000000-0000-0000-0000-000000000006';

select throws_ok(
  format(
    $sql$ select public.rpc_waive_contribution_charge('b1100000-0000-0000-0000-000000000002', %L, 1000, 'wrong group', '2026-08-10') $sql$,
    (select charge_id::text from t_charge_adj)
  ),
  '22023',
  null,
  'Group B cannot waive a Group A charge by passing Group B''s own group_id'
);

set local request.jwt.claim.sub to 'b1000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- READ TOTALS: BASE + PENALTY + ADJUSTMENT + WAIVER combined.
-- ---------------------------------------------------------------------

create temporary table t_period_combined as
select public.rpc_create_contribution_period(
  'b1100000-0000-0000-0000-000000000001', 'b1400000-0000-0000-0000-000000000002', 'Combined Round',
  '2026-08-01', '2026-08-31', p_due_date := '2026-08-05'
) as result;

select public.rpc_exclude_contribution_period_member(
  'b1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_combined), m.id
) from t_period_combined, (values
  ('b1200000-0000-0000-0000-000000000001'::uuid), ('b1200000-0000-0000-0000-000000000002'::uuid),
  ('b1200000-0000-0000-0000-000000000003'::uuid), ('b1200000-0000-0000-0000-000000000004'::uuid),
  ('b1200000-0000-0000-0000-000000000005'::uuid), ('b1200000-0000-0000-0000-000000000007'::uuid),
  ('b1200000-0000-0000-0000-000000000008'::uuid), ('b1200000-0000-0000-0000-000000000009'::uuid),
  ('b1200000-0000-0000-0000-000000000010'::uuid)
) as m(id);

select public.rpc_open_contribution_period(
  'b1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_combined)
) from t_period_combined;

select public.rpc_assess_contribution_penalties(
  'b1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_combined), '2026-08-10'
) from t_period_combined;

create temporary table t_charge_combined as
select c.id as charge_id
from public.member_contribution_charges c, t_period_combined p
where c.period_id = (select (p.result ->> 'id')::uuid)
  and c.membership_id = 'b1200000-0000-0000-0000-000000000006';

select public.rpc_create_contribution_adjustment(
  'b1100000-0000-0000-0000-000000000001', (select charge_id from t_charge_combined), 20000, 'discovered undercharge', '2026-08-12'
) from t_charge_combined;

select public.rpc_waive_contribution_charge(
  'b1100000-0000-0000-0000-000000000001', (select charge_id from t_charge_combined), 5000, 'goodwill', '2026-08-12'
) from t_charge_combined;

-- BASE 100,000 + PENALTY 10,000 + ADJUSTMENT 20,000 + WAIVER -5,000 = 125,000.
select is(
  (select coalesce(sum(assessed_amount), 0) from public.contribution_charge_components where charge_id = (select charge_id from t_charge_combined)),
  125000.00::numeric,
  'NET ASSESSED = BASE(100,000) + PENALTY(10,000) + ADJUSTMENT(20,000) + WAIVER(-5,000) = 125,000, confirmed at the storage layer (and again below via the read RPCs, never Flutter math)'
);

select is(
  (select cc.assessed_amount from public.contribution_charge_components cc
   where cc.charge_id = (select charge_id from t_charge_combined) and cc.component_type = 'PENALTY'),
  10000.00::numeric,
  'the PENALTY component remains exactly 10,000 — never rewritten by the later adjustment/waiver'
);

create temporary table t_get_period_combined as
select public.rpc_get_contribution_period(
  'b1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_combined)
) as result
from t_period_combined;

select is(
  (select (result ->> 'net_assessed_total')::numeric from t_get_period_combined),
  125000.00::numeric,
  'rpc_get_contribution_period''s net_assessed_total reflects the same combined total'
);

select is(
  (select (result ->> 'total_base_assessed')::numeric from t_get_period_combined),
  100000.00::numeric,
  'rpc_get_contribution_period''s total_base_assessed is never overwritten by corrections'
);

create temporary table t_list_charges_combined as
select public.rpc_list_contribution_period_charges(
  'b1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_combined), null
) as result
from t_period_combined;

select is(
  (select (result -> 'items' -> 0 ->> 'total_amount')::numeric from t_list_charges_combined),
  125000.00::numeric,
  'rpc_list_contribution_period_charges'' total_amount per charge is the same net-assessed figure'
);

create temporary table t_charge_detail_combined as
select public.rpc_get_contribution_charge_detail(
  'b1100000-0000-0000-0000-000000000001', (select charge_id from t_charge_combined)
) as result;

select is(
  (select jsonb_array_length(result -> 'components') from t_charge_detail_combined),
  4,
  'rpc_get_contribution_charge_detail returns all 4 components (BASE, PENALTY, ADJUSTMENT, WAIVER) for the combined charge'
);

select is(
  (select (result ->> 'net_assessed')::numeric from t_charge_detail_combined),
  125000.00::numeric,
  'rpc_get_contribution_charge_detail''s net_assessed matches the RPC-computed total'
);

-- Member Contribution Obligation Summary: "Eligible One" (membership
-- ...0006) has two charges group-wide — t_charge_adj (BASE 100,000,
-- net adjustment -10,000, waiver -10,000 => 80,000) and
-- t_charge_combined (BASE 100,000 + PENALTY 10,000 + ADJUSTMENT 20,000
-- + WAIVER -5,000 => 125,000). Combined: BASE 200,000 / PENALTY 10,000
-- / ADJUSTMENT 10,000 / WAIVER -15,000 / NET 205,000.
create temporary table t_member_summary as
select public.rpc_get_member_contribution_summary(
  'b1100000-0000-0000-0000-000000000001', 'b1200000-0000-0000-0000-000000000006'
) as result;

select is(
  (select (result ->> 'net_assessed')::numeric from t_member_summary),
  205000.00::numeric,
  'the Member Contribution Obligation Summary aggregates net_assessed correctly across all of a member''s charges'
);

-- ---------------------------------------------------------------------
-- OPENING BALANCES
-- ---------------------------------------------------------------------

select lives_ok(
  $sql$
    select public.rpc_import_contribution_opening_balances(
      'b1100000-0000-0000-0000-000000000001', 'b1300000-0000-0000-0000-000000000001', '2027-01-01',
      '[{"membership_id":"b1200000-0000-0000-0000-000000000009","amount":0}]'::jsonb
    )
  $sql$,
  'a zero opening balance amount is simply skipped, not imported (no error raised)'
);

select is(
  (select count(*)::int from public.member_contribution_charges c
   join public.contribution_periods p on p.id = c.period_id
   where p.purpose = 'OPENING_BALANCE' and c.membership_id = 'b1200000-0000-0000-0000-000000000009'),
  0,
  'a zero-amount entry never creates an opening balance charge'
);

select throws_ok(
  $sql$
    select public.rpc_import_contribution_opening_balances(
      'b1100000-0000-0000-0000-000000000001', 'b1300000-0000-0000-0000-000000000001', '2027-01-01',
      '[{"membership_id":"b1200000-0000-0000-0000-000000000009","amount":-500}]'::jsonb
    )
  $sql$,
  'P0001',
  'OPENING_BALANCE_AMOUNT_MUST_BE_POSITIVE',
  'a negative opening balance amount is rejected'
);

create temporary table t_ob_preview as
select public.rpc_preview_contribution_opening_balance_import(
  'b1100000-0000-0000-0000-000000000001', 'b1300000-0000-0000-0000-000000000001', '2027-01-01',
  '[{"membership_id":"b1200000-0000-0000-0000-000000000009","amount":75000},{"membership_id":"b1200000-0000-0000-0000-000000000010","amount":30000}]'::jsonb
) as result;

select is(
  (select (result ->> 'member_count')::int from t_ob_preview),
  2,
  'preview reports the correct member_count'
);

select is(
  (select (result ->> 'total_opening_obligation')::numeric from t_ob_preview),
  105000.00::numeric,
  'preview computes the correct server-authoritative total (75,000 + 30,000)'
);

create temporary table t_ob_import as
select public.rpc_import_contribution_opening_balances(
  'b1100000-0000-0000-0000-000000000001', 'b1300000-0000-0000-0000-000000000001', '2027-01-01',
  '[{"membership_id":"b1200000-0000-0000-0000-000000000009","amount":75000},{"membership_id":"b1200000-0000-0000-0000-000000000010","amount":30000}]'::jsonb
) as result;

select is(
  (select (result ->> 'imported_count')::int from t_ob_import),
  2,
  'the batch import posts exactly 2 opening balance charges'
);

select is(
  (select (result ->> 'total_opening_obligation')::numeric from t_ob_import),
  105000.00::numeric,
  'the batch import reports the correct total'
);

select is(
  (select cc.assessed_amount from public.contribution_charge_components cc
   join public.member_contribution_charges c on c.id = cc.charge_id
   where c.membership_id = 'b1200000-0000-0000-0000-000000000009' and cc.component_type = 'OPENING_BALANCE'),
  75000.00::numeric,
  'the OPENING_BALANCE component amount matches the imported value exactly'
);

select is(
  (select c.member_number_snapshot from public.member_contribution_charges c
   where c.membership_id = 'b1200000-0000-0000-0000-000000000009'
     and c.period_id = (select (result ->> 'period_id')::uuid from t_ob_import)),
  'B06CA-2026-0009',
  'the opening-balance charge snapshots the member number, same as a normal charge'
);

select is(
  (select p.snapshot_accounting_treatment::text from public.contribution_periods p
   where p.id = (select (result ->> 'period_id')::uuid from t_ob_import)),
  'GROUP_INCOME',
  'the opening balance preserves the GROUP_INCOME accounting treatment of the Dues type'
);

select is(
  (select c.effective_at from public.member_contribution_charges c
   where c.membership_id = 'b1200000-0000-0000-0000-000000000009'
     and c.period_id = (select (result ->> 'period_id')::uuid from t_ob_import)),
  '2027-01-01'::date,
  'the opening-balance charge''s effective_at is the declared cutover/effective date'
);

select is(
  (select count(*)::int from public.contribution_periods where purpose = 'OPENING_BALANCE'),
  1,
  'exactly one system OPENING_BALANCE period was auto-provisioned for this (group, type, date)'
);

create temporary table t_normal_periods_after_ob as
select public.rpc_list_contribution_periods('b1100000-0000-0000-0000-000000000001') as result;

select is(
  (select (result ->> 'total_count')::int from t_normal_periods_after_ob),
  4,
  'rpc_list_contribution_periods reports only the 4 explicitly-created NORMAL periods — the auto-provisioned opening-balance system period is excluded, never pollutes the normal list'
);

-- Duplicate import protection: re-importing the same member for the
-- same (group, type, effective_at) is rejected atomically.
select throws_ok(
  $sql$
    select public.rpc_import_contribution_opening_balances(
      'b1100000-0000-0000-0000-000000000001', 'b1300000-0000-0000-0000-000000000001', '2027-01-01',
      '[{"membership_id":"b1200000-0000-0000-0000-000000000009","amount":75000}]'::jsonb
    )
  $sql$,
  'P0001',
  'OPENING_BALANCE_ALREADY_IMPORTED',
  'importing an opening balance twice for the same member/type/date is rejected'
);

select is(
  (select count(*)::int from public.member_contribution_charges c
   join public.contribution_periods p on p.id = c.period_id
   where p.purpose = 'OPENING_BALANCE' and c.membership_id = 'b1200000-0000-0000-0000-000000000009'),
  1,
  'the duplicate rejection does not create a second opening-balance charge'
);

select ok(
  (select true from public.contribution_charge_components cc
   join public.member_contribution_charges c on c.id = cc.charge_id
   where c.membership_id = 'b1200000-0000-0000-0000-000000000010' and cc.component_type = 'OPENING_BALANCE') is not null,
  'the second member''s opening balance (imported earlier in the same batch) remains intact'
);

-- Unauthorized / cross-group for opening balance management.
set local request.jwt.claim.sub to 'b1000000-0000-0000-0000-000000000005';

select throws_ok(
  $sql$
    select public.rpc_import_contribution_opening_balances(
      'b1100000-0000-0000-0000-000000000001', 'b1300000-0000-0000-0000-000000000001', '2027-01-01',
      '[{"membership_id":"b1200000-0000-0000-0000-000000000009","amount":1000}]'::jsonb
    )
  $sql$,
  '42501',
  null,
  'MEMBER cannot import contribution opening balances'
);

set local request.jwt.claim.sub to 'b1000000-0000-0000-0000-000000000001';

-- Hisa (SHARE / SHARE_CAPITAL) opening balance preserves its own
-- classification, distinct from Dues.
create temporary table t_ob_hisa as
select public.rpc_import_contribution_opening_balances(
  'b1100000-0000-0000-0000-000000000001', 'b1300000-0000-0000-0000-000000000002', '2027-01-01',
  '[{"membership_id":"b1200000-0000-0000-0000-000000000009","amount":15000}]'::jsonb
) as result;

select is(
  (select p.snapshot_accounting_treatment::text from public.contribution_periods p
   where p.id = (select (result ->> 'period_id')::uuid from t_ob_hisa)),
  'SHARE_CAPITAL',
  'a Hisa opening balance is classified SHARE_CAPITAL, not lumped in as ordinary GROUP_INCOME'
);

select * from finish();

rollback;
