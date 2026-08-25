-- Contribution Engine (Prompt 06A-UAT-FIX): closes a real test gap —
-- rpc_list_contribution_period_charges had never been directly pgTAP
-- tested. Proves rpc_get_contribution_period's total_members_charged
-- can never disagree with rpc_list_contribution_period_charges'
-- total_count/returned rows for the same period, covers blank vs
-- name-search behaviour, and confirms a PASS_THROUGH active setup can be
-- used to create/open a period (UAT failure F: "PASS_THROUGH setup
-- missing in period picker" — proven here to be a pure Flutter
-- picker-staleness issue, not a backend filtering rule; the backend
-- never filtered by accounting_treatment to begin with).
begin;

select plan(9);

insert into auth.users (id, email) values
  ('81000000-0000-0000-0000-000000000001', 'contrib26-treasurer@example.com'),
  ('81000000-0000-0000-0000-000000000002', 'contrib26-suspended@example.com'),
  ('81000000-0000-0000-0000-000000000003', 'contrib26-exited@example.com');

insert into public.groups (id, name, created_by, code) values
  ('81100000-0000-0000-0000-000000000001', 'Contrib26 Group', '81000000-0000-0000-0000-000000000001', 'C26A');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('81200000-0000-0000-0000-000000000001', '81100000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000001', 'Contrib26 Treasurer', 'ACTIVE', '2025-01-01', 'C26A-2026-0001'),
  ('81200000-0000-0000-0000-000000000002', '81100000-0000-0000-0000-000000000001', null, 'Frederick Mtui', 'ACTIVE', '2025-01-01', 'C26A-2026-0002'),
  ('81200000-0000-0000-0000-000000000003', '81100000-0000-0000-0000-000000000001', null, 'Amina Juma', 'ACTIVE', '2025-01-01', 'C26A-2026-0003'),
  ('81200000-0000-0000-0000-000000000004', '81100000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000002', 'Contrib26 Suspended', 'SUSPENDED', '2025-01-01', 'C26A-2026-0004'),
  ('81200000-0000-0000-0000-000000000005', '81100000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000003', 'Contrib26 Exited', 'EXITED', '2025-01-01', 'C26A-2026-0005');

insert into public.group_membership_roles (group_membership_id, role_id)
select '81200000-0000-0000-0000-000000000001', id from public.roles where code = 'TREASURER';

-- PASS_THROUGH type + setup (UAT failure F).
insert into public.contribution_types (id, group_id, name, category, accounting_treatment, created_by) values
  ('81300000-0000-0000-0000-000000000001', '81100000-0000-0000-0000-000000000001', 'Rambirambi', 'GENERAL', 'PASS_THROUGH', '81000000-0000-0000-0000-000000000001');

insert into public.contribution_setups (
  id, group_id, contribution_type_id, name, schedule_mode, amount_mode, fixed_amount, created_by
) values (
  '81400000-0000-0000-0000-000000000001', '81100000-0000-0000-0000-000000000001',
  '81300000-0000-0000-0000-000000000001', 'Rambirambi Setup', 'ON_DEMAND', 'FIXED', 5000, '81000000-0000-0000-0000-000000000001'
);

set local role authenticated;
set local request.jwt.claim.sub to '81000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- A PASS_THROUGH active setup can be used to create and open a period.
-- ---------------------------------------------------------------------

create temporary table t_period as
select public.rpc_create_contribution_period(
  '81100000-0000-0000-0000-000000000001', '81400000-0000-0000-0000-000000000001', 'Rambirambi Round 1',
  '2026-08-01', '2026-08-31', p_due_date := '2026-08-31'
) as result;

select isnt(
  (select result ->> 'id' from t_period),
  null,
  'a PASS_THROUGH active setup can create a contribution period'
);

create temporary table t_open as
select public.rpc_open_contribution_period(
  '81100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period)
) as result;

select is(
  (select (result ->> 'charge_count')::int from t_open),
  3,
  'opening a PASS_THROUGH period charges exactly the 3 ACTIVE members (excludes SUSPENDED/EXITED)'
);

-- ---------------------------------------------------------------------
-- members_charged (rpc_get_contribution_period) can never disagree with
-- rpc_list_contribution_period_charges' total_count/returned rows.
-- ---------------------------------------------------------------------

create temporary table t_get as
select public.rpc_get_contribution_period(
  '81100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period)
) as result;

select is(
  (select (result ->> 'total_members_charged')::int from t_get),
  3,
  'rpc_get_contribution_period reports total_members_charged = 3'
);

create temporary table t_charges_blank as
select public.rpc_list_contribution_period_charges(
  '81100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period), null
) as result;

select is(
  (select (result ->> 'total_count')::int from t_charges_blank),
  (select (result ->> 'total_members_charged')::int from t_get),
  'rpc_list_contribution_period_charges'' total_count with a blank search matches members_charged exactly'
);

select is(
  (select jsonb_array_length(result -> 'items') from t_charges_blank),
  3,
  'a blank search returns all 3 posted charge rows, not zero'
);

-- ---------------------------------------------------------------------
-- Name search matches consistently.
-- ---------------------------------------------------------------------

create temporary table t_charges_name as
select public.rpc_list_contribution_period_charges(
  '81100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period), 'Frederick'
) as result;

select is(
  (select (result ->> 'total_count')::int from t_charges_name),
  1,
  'searching "Frederick" returns exactly the one matching charge'
);

select is(
  (select result -> 'items' -> 0 ->> 'member_name_snapshot' from t_charges_name),
  'Frederick Mtui',
  'the name-search result is the correct member'
);

create temporary table t_charges_partial as
select public.rpc_list_contribution_period_charges(
  '81100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period), 'fred'
) as result;

select is(
  (select (result ->> 'total_count')::int from t_charges_partial),
  1,
  'a case-insensitive partial name search ("fred") also matches Frederick Mtui'
);

-- ---------------------------------------------------------------------
-- A search matching nobody returns zero, not an error.
-- ---------------------------------------------------------------------

create temporary table t_charges_none as
select public.rpc_list_contribution_period_charges(
  '81100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period), 'Nonexistent Name'
) as result;

select is(
  (select (result ->> 'total_count')::int from t_charges_none),
  0,
  'a search matching nobody returns total_count 0, not an error'
);

select * from finish();

rollback;
