-- Contribution Engine (Prompt 06A): rpc_open_contribution_period --
-- atomic charge posting, idempotent double-open, the accounting
-- snapshot frozen onto contribution_periods at OPEN, the resulting
-- config lock on the type/setup, and confirmation that OPEN touches
-- only member_contribution_charges/contribution_charge_components
-- beyond the period's own row.
begin;

select plan(19);

insert into auth.users (id, email) values
  ('41000000-0000-0000-0000-000000000001', 'contrib22-treasurer@example.com'),
  ('41000000-0000-0000-0000-000000000002', 'contrib22-member@example.com');

insert into public.groups (id, name, created_by, code) values
  ('41100000-0000-0000-0000-000000000001', 'Contrib22 Group', '41000000-0000-0000-0000-000000000001', 'C22A');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  -- Treasurer/plain-member joined_at is deliberately far in the future
  -- so they are never themselves eligible for any contribution period
  -- opened in this file (their own ACTIVE membership would otherwise
  -- also be charged and skew the charge_count assertions below).
  ('41200000-0000-0000-0000-000000000001', '41100000-0000-0000-0000-000000000001', '41000000-0000-0000-0000-000000000001', 'Contrib22 Treasurer', 'ACTIVE', '2099-01-01', 'C22A-2026-0001'),
  ('41200000-0000-0000-0000-000000000002', '41100000-0000-0000-0000-000000000001', '41000000-0000-0000-0000-000000000002', 'Contrib22 Plain Member', 'ACTIVE', '2099-01-01', 'C22A-2026-0002'),
  ('41200000-0000-0000-0000-000000000003', '41100000-0000-0000-0000-000000000001', null, 'Eligible Member A', 'ACTIVE', '2025-01-01', 'C22A-2026-0003'),
  ('41200000-0000-0000-0000-000000000004', '41100000-0000-0000-0000-000000000001', null, 'Eligible Member B', 'ACTIVE', '2025-01-01', 'C22A-2026-0004');

insert into public.group_membership_roles (group_membership_id, role_id)
select '41200000-0000-0000-0000-000000000001', id from public.roles where code = 'TREASURER';
insert into public.group_membership_roles (group_membership_id, role_id)
select '41200000-0000-0000-0000-000000000002', id from public.roles where code = 'MEMBER';

insert into public.contribution_types (id, group_id, name, category, accounting_treatment, created_by) values
  ('41300000-0000-0000-0000-000000000001', '41100000-0000-0000-0000-000000000001', 'Monthly Dues', 'GENERAL', 'PASS_THROUGH', '41000000-0000-0000-0000-000000000001'),
  ('41300000-0000-0000-0000-000000000002', '41100000-0000-0000-0000-000000000001', 'Share Capital', 'SHARE', 'SHARE_CAPITAL', '41000000-0000-0000-0000-000000000001');

insert into public.contribution_setups (
  id, group_id, contribution_type_id, name, schedule_mode, amount_mode, fixed_amount, created_by
) values (
  '41400000-0000-0000-0000-000000000001', '41100000-0000-0000-0000-000000000001',
  '41300000-0000-0000-0000-000000000001', 'Monthly Dues Setup', 'MONTHLY', 'FIXED', 2000, '41000000-0000-0000-0000-000000000001'
), (
  '41400000-0000-0000-0000-000000000002', '41100000-0000-0000-0000-000000000001',
  '41300000-0000-0000-0000-000000000002', 'Share Capital Setup', 'ONE_TIME', 'FIXED', 5000, '41000000-0000-0000-0000-000000000001'
);

set local role authenticated;
set local request.jwt.claim.sub to '41000000-0000-0000-0000-000000000001';

create temporary table t_period as
select public.rpc_create_contribution_period(
  '41100000-0000-0000-0000-000000000001', '41400000-0000-0000-0000-000000000001', 'March Dues',
  '2026-03-01', '2026-03-31', p_due_date := '2026-03-31'
) as result;

-- Unauthorized open.
set local request.jwt.claim.sub to '41000000-0000-0000-0000-000000000002';

select throws_ok(
  format(
    $sql$ select public.rpc_open_contribution_period('41100000-0000-0000-0000-000000000001', %L) $sql$,
    (select result ->> 'id' from t_period)
  ),
  '42501',
  null,
  'a caller without contribution.period.open cannot open a contribution period'
);

set local request.jwt.claim.sub to '41000000-0000-0000-0000-000000000001';

create temporary table t_counts_before as
select
  (select count(*) from public.contribution_types) as types_c,
  (select count(*) from public.contribution_setups) as setups_c,
  (select count(*) from public.contribution_periods) as periods_c,
  (select count(*) from public.contribution_period_member_amounts) as pma_c,
  (select count(*) from public.contribution_period_member_exclusions) as pme_c,
  (select count(*) from public.member_contribution_charges) as charges_c,
  (select count(*) from public.contribution_charge_components) as components_c;

create temporary table t_open as
select public.rpc_open_contribution_period(
  '41100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period)
) as result;

select is(
  (select (result ->> 'already_open')::boolean from t_open),
  false,
  'the first OPEN call is not already_open'
);

select is(
  (select (result ->> 'charge_count')::int from t_open),
  2,
  'OPEN posts exactly one charge per eligible member'
);

-- Accounting snapshot: PASS_THROUGH.
select is(
  (select row(snapshot_type_name, snapshot_category, snapshot_accounting_treatment,
              snapshot_setup_name, snapshot_schedule_mode, snapshot_amount_mode, snapshot_fixed_amount)
   from public.contribution_periods where id = (select (result ->> 'id')::uuid from t_period))::text,
  row('Monthly Dues', 'GENERAL', 'PASS_THROUGH', 'Monthly Dues Setup', 'MONTHLY', 'FIXED', 2000.00::numeric)::text,
  'the PASS_THROUGH type/setup configuration is snapshotted onto the period at OPEN'
);

-- Only the charges/components tables gain rows; everything else is
-- unchanged beyond the period's own status update.
select is(
  (select (select count(*) from public.contribution_types)
        + (select count(*) from public.contribution_setups)
        + (select count(*) from public.contribution_periods)
        + (select count(*) from public.contribution_period_member_amounts)
        + (select count(*) from public.contribution_period_member_exclusions)),
  (select types_c + setups_c + periods_c + pma_c + pme_c from t_counts_before),
  'OPEN inserts no rows into contribution_types/setups/periods/member_amounts/exclusions'
);

select is(
  (select count(*) from public.member_contribution_charges) - (select charges_c from t_counts_before),
  2::bigint,
  'OPEN inserts exactly the expected number of member_contribution_charges rows'
);

select is(
  (select count(*) from public.contribution_charge_components) - (select components_c from t_counts_before),
  2::bigint,
  'OPEN inserts exactly the expected number of contribution_charge_components rows'
);

-- Double-open: idempotent, no duplicate charges.
create temporary table t_reopen as
select public.rpc_open_contribution_period(
  '41100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period)
) as result;

select is(
  (select (result ->> 'already_open')::boolean from t_reopen),
  true,
  'calling OPEN again on an already-OPEN period returns already_open:true'
);

select is(
  (select (result ->> 'charge_count')::int from t_reopen),
  2,
  'double-open reports the same charge_count, not a doubled one'
);

select is(
  (select count(*)::int from public.member_contribution_charges
   where period_id = (select (result ->> 'id')::uuid from t_period)),
  2,
  'double-open does not create duplicate member_contribution_charges rows'
);

-- Setup/type config lock after a period on them has been OPENed.
select throws_ok(
  $$ select public.rpc_update_contribution_setup(
    '41100000-0000-0000-0000-000000000001', '41400000-0000-0000-0000-000000000001', p_fixed_amount := 3000
  ) $$,
  'P0001',
  'CONTRIBUTION_SETUP_CONFIG_LOCKED',
  'a financially-meaningful field on a setup with an OPEN period is locked'
);

select throws_ok(
  $$ select public.rpc_update_contribution_type(
    '41100000-0000-0000-0000-000000000001', '41300000-0000-0000-0000-000000000001', p_accounting_treatment := 'GROUP_INCOME'
  ) $$,
  'P0001',
  'CONTRIBUTION_TYPE_ACCOUNTING_LOCKED',
  'the accounting treatment of a type with an OPEN period is locked'
);

select lives_ok(
  $$ select public.rpc_update_contribution_setup(
    '41100000-0000-0000-0000-000000000001', '41400000-0000-0000-0000-000000000001', p_name := 'Monthly Dues Setup Renamed'
  ) $$,
  'a non-financially-meaningful edit (name) is still allowed on a setup with an OPEN period'
);

select is(
  (select snapshot_setup_name from public.contribution_periods
   where id = (select (result ->> 'id')::uuid from t_period)),
  'Monthly Dues Setup',
  'renaming the setup after OPEN does not rewrite the already-OPEN period''s frozen snapshot'
);

select is(
  (select name from public.contribution_setups where id = '41400000-0000-0000-0000-000000000001'),
  'Monthly Dues Setup Renamed',
  'the setup''s own current name is updated by the allowed edit'
);

-- Accounting snapshot: SHARE_CAPITAL, on a separate setup/period.
create temporary table t_period_share as
select public.rpc_create_contribution_period(
  '41100000-0000-0000-0000-000000000001', '41400000-0000-0000-0000-000000000002', 'Share Capital Round 1',
  '2026-04-01', '2026-04-30', p_due_date := '2026-04-30'
) as result;

create temporary table t_open_share as
select public.rpc_open_contribution_period(
  '41100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_share)
) as result;

select is(
  (select (result ->> 'charge_count')::int from t_open_share),
  2,
  'the SHARE_CAPITAL period also charges both eligible members'
);

select is(
  (select snapshot_category from public.contribution_periods
   where id = (select (result ->> 'id')::uuid from t_period_share)),
  'SHARE',
  'the SHARE category is snapshotted onto the period at OPEN'
);

select is(
  (select snapshot_accounting_treatment from public.contribution_periods
   where id = (select (result ->> 'id')::uuid from t_period_share)),
  'SHARE_CAPITAL',
  'the SHARE_CAPITAL accounting treatment is snapshotted onto the period at OPEN'
);

select is(
  (select cc.assessed_amount from public.member_contribution_charges c
   join public.contribution_charge_components cc on cc.charge_id = c.id and cc.component_type = 'BASE'
   where c.period_id = (select (result ->> 'id')::uuid from t_period_share)
     and c.membership_id = '41200000-0000-0000-0000-000000000003'),
  5000.00::numeric,
  'the SHARE_CAPITAL period assesses the configured fixed amount as its BASE component'
);

select * from finish();

rollback;
