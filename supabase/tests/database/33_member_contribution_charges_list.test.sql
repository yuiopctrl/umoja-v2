-- Prompt 07 UAT-FIX-03: the member-centric Charges/Madeni view.
-- `rpc_list_member_contribution_charges` (every charge for one
-- membership across every period, filterable/paginated) and
-- `rpc_get_member_contribution_statement`'s new additive
-- `total_allocated` field. No contribution accounting semantics,
-- charge creation logic, or payment allocation rule is touched by
-- either — this file only proves the new/extended read surface.
begin;

select plan(22);

insert into auth.users (id, email) values
  ('f7000000-0000-0000-0000-000000000001', 'uatfix3b-treasurer@example.com'),
  ('f7000000-0000-0000-0000-000000000002', 'uatfix3b-member@example.com'),
  ('f7000000-0000-0000-0000-000000000003', 'uatfix3b-suspended@example.com'),
  ('f7000000-0000-0000-0000-000000000004', 'uatfix3b-plainmember@example.com');

insert into public.groups (id, name, created_by, code) values
  ('f7100000-0000-0000-0000-000000000001', 'UATFIX3B Group A', 'f7000000-0000-0000-0000-000000000001', 'F7AA'),
  ('f7100000-0000-0000-0000-000000000002', 'UATFIX3B Group B', 'f7000000-0000-0000-0000-000000000001', 'F7BB');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('f7200000-0000-0000-0000-000000000001', 'f7100000-0000-0000-0000-000000000001', 'f7000000-0000-0000-0000-000000000001', 'F7 Treasurer', 'ACTIVE', '2025-01-01', 'F7AA-2026-0001'),
  ('f7200000-0000-0000-0000-000000000002', 'f7100000-0000-0000-0000-000000000001', 'f7000000-0000-0000-0000-000000000002', 'F7 Member', 'ACTIVE', '2025-01-01', 'F7AA-2026-0002'),
  ('f7200000-0000-0000-0000-000000000003', 'f7100000-0000-0000-0000-000000000001', 'f7000000-0000-0000-0000-000000000003', 'F7 Suspended', 'ACTIVE', '2025-01-01', 'F7AA-2026-0003'),
  ('f7200000-0000-0000-0000-000000000004', 'f7100000-0000-0000-0000-000000000001', 'f7000000-0000-0000-0000-000000000004', 'F7 Plain Member', 'ACTIVE', '2025-01-01', 'F7AA-2026-0004'),
  ('f7200000-0000-0000-0000-000000000099', 'f7100000-0000-0000-0000-000000000002', null, 'F7B Other Group Member', 'ACTIVE', '2025-01-01', 'F7BB-2026-0001');

insert into public.group_membership_roles (group_membership_id, role_id) select 'f7200000-0000-0000-0000-000000000001', id from public.roles where code = 'TREASURER';
insert into public.group_membership_roles (group_membership_id, role_id) select 'f7200000-0000-0000-0000-000000000002', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id) select 'f7200000-0000-0000-0000-000000000003', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id) select 'f7200000-0000-0000-0000-000000000004', id from public.roles where code = 'MEMBER';

set local role authenticated;
set local request.jwt.claim.sub to 'f7000000-0000-0000-0000-000000000001';

create temporary table t_acct as
select public.rpc_create_financial_account('f7100000-0000-0000-0000-000000000001', 'Main Cash', 'CASH') as result;
select (result->>'id')::uuid as account_id from t_acct \gset

create temporary table t_type as
select public.rpc_create_contribution_type('f7100000-0000-0000-0000-000000000001', 'Ada', 'GENERAL', 'GROUP_INCOME') as result;
select (result->>'id')::uuid as type_id from t_type \gset

create temporary table t_setup as
select public.rpc_create_contribution_setup(
  'f7100000-0000-0000-0000-000000000001', :'type_id'::uuid, 'Ada Setup', 'MONTHLY', 'FIXED', p_fixed_amount => 20000
) as result;
select (result->>'id')::uuid as setup_id from t_setup \gset

create temporary table t_period_jul as
select public.rpc_create_contribution_period(
  'f7100000-0000-0000-0000-000000000001', :'setup_id'::uuid, 'Julai 2026', '2026-07-01', '2026-07-31', p_due_date => '2026-07-15'
) as result;
select (result->>'id')::uuid as period_jul_id from t_period_jul \gset
select public.rpc_open_contribution_period('f7100000-0000-0000-0000-000000000001', :'period_jul_id'::uuid);

create temporary table t_period_aug as
select public.rpc_create_contribution_period(
  'f7100000-0000-0000-0000-000000000001', :'setup_id'::uuid, 'Agosti 2026', '2026-08-01', '2026-08-31', p_due_date => '2026-08-15'
) as result;
select (result->>'id')::uuid as period_aug_id from t_period_aug \gset
select public.rpc_open_contribution_period('f7100000-0000-0000-0000-000000000001', :'period_aug_id'::uuid);

select id as charge_jul from public.member_contribution_charges
where period_id = :'period_jul_id'::uuid and membership_id = 'f7200000-0000-0000-0000-000000000002' \gset

-- Julai: waive 3000, pay in full (net 17000). Agosti: leave unpaid, overdue.
select public.rpc_waive_contribution_charge('f7100000-0000-0000-0000-000000000001', :'charge_jul'::uuid, 3000, 'goodwill');
select public.rpc_post_payment(
  'f7100000-0000-0000-0000-000000000001', 'f7200000-0000-0000-0000-000000000002', :'account_id'::uuid,
  17000, '2026-07-20', 'CASH'
);

-- ---------------------------------------------------------------------
-- Filters.
-- ---------------------------------------------------------------------

create temporary table t_default as
select public.rpc_list_member_contribution_charges(
  'f7100000-0000-0000-0000-000000000001', 'f7200000-0000-0000-0000-000000000002'
) as result;

select is(
  (select result->>'filter' from t_default), 'OUTSTANDING',
  'default filter echoes OUTSTANDING'
);
select is(
  (select jsonb_array_length(result->'items') from t_default), 1,
  'default OUTSTANDING filter shows only the still-outstanding Agosti charge'
);
select is(
  (select result->'items'->0->>'contribution_type_name' from t_default), 'Ada',
  'the outstanding item carries its contribution type name'
);
select is(
  (select (result->'items'->0->>'outstanding')::numeric from t_default), 20000.00::numeric,
  'the outstanding item reports the correct 20000 outstanding'
);

create temporary table t_all as
select public.rpc_list_member_contribution_charges(
  'f7100000-0000-0000-0000-000000000001', 'f7200000-0000-0000-0000-000000000002', 'ALL'
) as result;

select is(
  (select result->>'total_count' from t_all)::int, 2,
  'ALL filter includes both the settled Julai and outstanding Agosti charges'
);

create temporary table t_settled as
select public.rpc_list_member_contribution_charges(
  'f7100000-0000-0000-0000-000000000001', 'f7200000-0000-0000-0000-000000000002', 'settled'
) as result;

select is(
  (select jsonb_array_length(result->'items') from t_settled), 1,
  'SETTLED filter (lowercase input) shows only the fully-paid Julai charge'
);
select is(
  (select (result->'items'->0->>'net_assessed')::numeric from t_settled), 17000.00::numeric,
  'the settled Julai charge reports net_assessed of 17000 (20000 base - 3000 waiver)'
);

-- WAIVER shown as its own raw signed component, never netted away.
select is(
  (
    select cc->>'component_type'
    from t_settled, jsonb_array_elements(result->'items'->0->'components') cc
    where cc->>'component_type' = 'WAIVER'
  ),
  'WAIVER',
  'the settled charge''s components include a distinct WAIVER row'
);
select is(
  (
    select (cc->>'amount')::numeric
    from t_settled, jsonb_array_elements(result->'items'->0->'components') cc
    where cc->>'component_type' = 'WAIVER'
  ),
  -3000.00::numeric,
  'the WAIVER component carries its original negative signed amount, not netted into BASE'
);

create temporary table t_overdue as
select public.rpc_list_member_contribution_charges(
  'f7100000-0000-0000-0000-000000000001', 'f7200000-0000-0000-0000-000000000002', 'OVERDUE'
) as result;

select is(
  (select result->'items'->0->>'charge_id' from t_overdue),
  (select result->'items'->0->>'charge_id' from t_default),
  'OVERDUE filter returns the same overdue Agosti charge as the default OUTSTANDING filter'
);

-- ---------------------------------------------------------------------
-- Invalid filter rejection.
-- ---------------------------------------------------------------------

select throws_ok(
  $sql$ select public.rpc_list_member_contribution_charges(
    'f7100000-0000-0000-0000-000000000001', 'f7200000-0000-0000-0000-000000000002', 'BOGUS'
  ) $sql$,
  '22023', 'MEMBER_CHARGES_INVALID_FILTER',
  'an unrecognized filter value is rejected'
);

-- ---------------------------------------------------------------------
-- Pagination bounds.
-- ---------------------------------------------------------------------

create temporary table t_paged as
select public.rpc_list_member_contribution_charges(
  'f7100000-0000-0000-0000-000000000001', 'f7200000-0000-0000-0000-000000000002', 'ALL', 1, 0
) as result;

select is(
  (select jsonb_array_length(result->'items') from t_paged), 1,
  'limit=1 returns exactly one item'
);
select is(
  (select (result->>'total_count')::int from t_paged), 2,
  'total_count still reflects the full unpaginated match count'
);

create temporary table t_over_limit as
select public.rpc_list_member_contribution_charges(
  'f7100000-0000-0000-0000-000000000001', 'f7200000-0000-0000-0000-000000000002', 'ALL', 500, -5
) as result;

select is(
  (select (result->>'limit')::int from t_over_limit), 100,
  'a limit above 100 is clamped down to the maximum of 100'
);
select is(
  (select (result->>'offset')::int from t_over_limit), 0,
  'a negative offset is clamped up to 0'
);

-- ---------------------------------------------------------------------
-- Cross-group isolation.
-- ---------------------------------------------------------------------

select throws_ok(
  $sql$ select public.rpc_list_member_contribution_charges(
    'f7100000-0000-0000-0000-000000000001', 'f7200000-0000-0000-0000-000000000099'
  ) $sql$,
  '22023', null,
  'a membership belonging to a different group is rejected'
);

-- ---------------------------------------------------------------------
-- Permission denial (MEMBER lacks payment.view).
-- ---------------------------------------------------------------------

set local request.jwt.claim.sub to 'f7000000-0000-0000-0000-000000000004';

select throws_ok(
  $sql$ select public.rpc_list_member_contribution_charges(
    'f7100000-0000-0000-0000-000000000001', 'f7200000-0000-0000-0000-000000000002'
  ) $sql$,
  '42501', null,
  'a MEMBER without payment.view cannot list another member''s charges'
);

set local request.jwt.claim.sub to 'f7000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- rpc_get_member_contribution_statement: total_allocated is a global
-- sum across every charge, including the settled Julai charge that is
-- excluded from `charges[]`. Asserted here, before the section below
-- opens another period (which — per the well-known "period open
-- charges every active membership in the group" behavior — would
-- otherwise add a fresh charge to this same member and invalidate
-- these expected totals).
-- ---------------------------------------------------------------------

create temporary table t_statement as
select public.rpc_get_member_contribution_statement(
  'f7100000-0000-0000-0000-000000000001', 'f7200000-0000-0000-0000-000000000002'
) as result;

select is(
  (select (result->>'total_allocated')::numeric from t_statement), 17000.00::numeric,
  'total_allocated includes the settled Julai charge''s 17000 allocation even though it is excluded from charges[]'
);
select is(
  (select jsonb_array_length(result->'charges') from t_statement), 1,
  'charges[] still excludes the fully-settled Julai charge (contract unchanged)'
);
select is(
  (select (result->>'total_outstanding')::numeric from t_statement), 20000.00::numeric,
  'total_outstanding is unaffected by the new total_allocated field'
);

-- ---------------------------------------------------------------------
-- SUSPENDED membership: historical charges remain visible. The charge
-- is created while the membership is still ACTIVE (period-open charges
-- only active memberships), then the membership is suspended directly
-- so the charge predates the suspension, matching a real "member fell
-- behind, then was suspended" history.
-- ---------------------------------------------------------------------

create temporary table t_charge_suspended as
select public.rpc_create_contribution_period(
  'f7100000-0000-0000-0000-000000000001', :'setup_id'::uuid, 'Septemba 2026', '2026-09-01', '2026-09-30', p_due_date => '2026-09-15'
) as result;
select (result->>'id')::uuid as period_sep_id from t_charge_suspended \gset
select public.rpc_open_contribution_period('f7100000-0000-0000-0000-000000000001', :'period_sep_id'::uuid);

reset role;
update public.group_memberships set status = 'SUSPENDED'
where id = 'f7200000-0000-0000-0000-000000000003';
set local role authenticated;
set local request.jwt.claim.sub to 'f7000000-0000-0000-0000-000000000001';

create temporary table t_suspended_charges as
select public.rpc_list_member_contribution_charges(
  'f7100000-0000-0000-0000-000000000001', 'f7200000-0000-0000-0000-000000000003', 'ALL'
) as result;

select is(
  (select (result->>'membership_status') from t_suspended_charges), 'SUSPENDED',
  'the SUSPENDED membership''s own status is reported'
);
select is(
  (select jsonb_array_length(result->'items') from t_suspended_charges), 3,
  'a SUSPENDED membership''s historical charges (Julai/Agosti/Septemba, all charged while still ACTIVE) remain visible, never hidden by status'
);

select * from finish();
rollback;
