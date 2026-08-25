-- Contribution Engine (Prompt 06A): CUSTOM_PER_MEMBER pre-open amount
-- configuration (rpc_set_contribution_period_member_amounts) and
-- post-open explicit enrollment (rpc_enroll_member_in_contribution_period).
begin;

select plan(19);

insert into auth.users (id, email) values
  ('51000000-0000-0000-0000-000000000001', 'contrib23-treasurer@example.com'),
  ('51000000-0000-0000-0000-000000000002', 'contrib23-member@example.com'),
  ('51000000-0000-0000-0000-000000000003', 'contrib23-treasurer-b@example.com');

insert into public.groups (id, name, created_by, code) values
  ('51100000-0000-0000-0000-000000000001', 'Contrib23 Group A', '51000000-0000-0000-0000-000000000001', 'C23A'),
  ('51100000-0000-0000-0000-000000000002', 'Contrib23 Group B', '51000000-0000-0000-0000-000000000003', 'C23B');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  -- Treasurer/plain-member joined_at is deliberately far in the future
  -- so they are never themselves eligible for any contribution period
  -- opened in this file (their own ACTIVE membership would otherwise
  -- also be charged/require a custom amount and skew the assertions
  -- below).
  ('51200000-0000-0000-0000-000000000001', '51100000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000001', 'Contrib23 Treasurer', 'ACTIVE', '2099-01-01', 'C23A-2026-0001'),
  ('51200000-0000-0000-0000-000000000002', '51100000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000002', 'Contrib23 Plain Member', 'ACTIVE', '2099-01-01', 'C23A-2026-0002'),
  ('51200000-0000-0000-0000-000000000003', '51100000-0000-0000-0000-000000000001', null, 'Custom Member One', 'ACTIVE', '2025-01-01', 'C23A-2026-0003'),
  ('51200000-0000-0000-0000-000000000004', '51100000-0000-0000-0000-000000000001', null, 'Custom Member Two', 'ACTIVE', '2025-01-01', 'C23A-2026-0004'),
  ('51200000-0000-0000-0000-000000000099', '51100000-0000-0000-0000-000000000002', '51000000-0000-0000-0000-000000000003', 'Contrib23 Treasurer B', 'ACTIVE', '2025-01-01', 'C23B-2026-0001');

insert into public.group_membership_roles (group_membership_id, role_id)
select '51200000-0000-0000-0000-000000000001', id from public.roles where code = 'TREASURER';
insert into public.group_membership_roles (group_membership_id, role_id)
select '51200000-0000-0000-0000-000000000002', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id)
select '51200000-0000-0000-0000-000000000099', id from public.roles where code = 'TREASURER';

insert into public.contribution_types (id, group_id, name, category, accounting_treatment, created_by) values
  ('51300000-0000-0000-0000-000000000001', '51100000-0000-0000-0000-000000000001', 'Custom Fees Type', 'GENERAL', 'GROUP_INCOME', '51000000-0000-0000-0000-000000000001');

insert into public.contribution_setups (
  id, group_id, contribution_type_id, name, schedule_mode, amount_mode, fixed_amount, created_by
) values (
  '51400000-0000-0000-0000-000000000001', '51100000-0000-0000-0000-000000000001',
  '51300000-0000-0000-0000-000000000001', 'Custom Fees Setup', 'ON_DEMAND', 'CUSTOM_PER_MEMBER', null, '51000000-0000-0000-0000-000000000001'
), (
  '51400000-0000-0000-0000-000000000002', '51100000-0000-0000-0000-000000000001',
  '51300000-0000-0000-0000-000000000001', 'Simple Fixed Setup', 'ON_DEMAND', 'FIXED', 1500, '51000000-0000-0000-0000-000000000001'
);

set local role authenticated;
set local request.jwt.claim.sub to '51000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- CUSTOM_PER_MEMBER: missing amounts block OPEN entirely, with no
-- partial charges created.
-- ---------------------------------------------------------------------

create temporary table t_period_custom as
select public.rpc_create_contribution_period(
  '51100000-0000-0000-0000-000000000001', '51400000-0000-0000-0000-000000000001', 'Custom Fees Round 1',
  '2026-05-01', '2026-05-31', p_due_date := '2026-05-31'
) as result;

set local request.jwt.claim.sub to '51000000-0000-0000-0000-000000000002';

select throws_ok(
  format(
    $sql$ select public.rpc_set_contribution_period_member_amounts(
      '51100000-0000-0000-0000-000000000001', %L,
      '[{"membership_id":"51200000-0000-0000-0000-000000000003","amount":500}]'::jsonb
    ) $sql$,
    (select result ->> 'id' from t_period_custom)
  ),
  '42501',
  null,
  'a caller without contribution.member_amount.manage cannot set per-member amounts'
);

set local request.jwt.claim.sub to '51000000-0000-0000-0000-000000000001';

select lives_ok(
  format(
    $sql$ select public.rpc_set_contribution_period_member_amounts(
      '51100000-0000-0000-0000-000000000001', %L,
      '[{"membership_id":"51200000-0000-0000-0000-000000000003","amount":500}]'::jsonb
    ) $sql$,
    (select result ->> 'id' from t_period_custom)
  ),
  'a custom amount can be set for one of the two eligible members'
);

select throws_ok(
  format(
    $sql$ select public.rpc_open_contribution_period('51100000-0000-0000-0000-000000000001', %L) $sql$,
    (select result ->> 'id' from t_period_custom)
  ),
  'P0001',
  'MISSING_CUSTOM_AMOUNTS',
  'OPEN is blocked entirely while any eligible member has no configured custom amount'
);

select is(
  (select count(*)::int from public.member_contribution_charges
   where period_id = (select (result ->> 'id')::uuid from t_period_custom)),
  0,
  'no partial charges are created by a failed OPEN due to missing custom amounts'
);

select lives_ok(
  format(
    $sql$ select public.rpc_set_contribution_period_member_amounts(
      '51100000-0000-0000-0000-000000000001', %L,
      '[{"membership_id":"51200000-0000-0000-0000-000000000004","amount":750}]'::jsonb
    ) $sql$,
    (select result ->> 'id' from t_period_custom)
  ),
  'the remaining member''s custom amount can now be set'
);

create temporary table t_open_custom as
select public.rpc_open_contribution_period(
  '51100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_custom)
) as result;

select is(
  (select (result ->> 'charge_count')::int from t_open_custom),
  2,
  'OPEN succeeds once every eligible member has a configured custom amount'
);

select is(
  (select cc.assessed_amount from public.member_contribution_charges c
   join public.contribution_charge_components cc on cc.charge_id = c.id and cc.component_type = 'BASE'
   where c.period_id = (select (result ->> 'id')::uuid from t_period_custom)
     and c.membership_id = '51200000-0000-0000-0000-000000000003'),
  500.00::numeric,
  'the first member''s BASE component uses their configured custom amount'
);

select is(
  (select cc.assessed_amount from public.member_contribution_charges c
   join public.contribution_charge_components cc on cc.charge_id = c.id and cc.component_type = 'BASE'
   where c.period_id = (select (result ->> 'id')::uuid from t_period_custom)
     and c.membership_id = '51200000-0000-0000-0000-000000000004'),
  750.00::numeric,
  'the second member''s BASE component uses their configured custom amount'
);

select throws_ok(
  format(
    $sql$ select public.rpc_set_contribution_period_member_amounts(
      '51100000-0000-0000-0000-000000000001', %L,
      '[{"membership_id":"51200000-0000-0000-0000-000000000003","amount":999}]'::jsonb
    ) $sql$,
    (select result ->> 'id' from t_period_custom)
  ),
  'P0001',
  'CONTRIBUTION_PERIOD_NOT_EDITABLE',
  'per-member amounts cannot be changed once the period is OPEN'
);

-- ---------------------------------------------------------------------
-- Post-open enrollment on the CUSTOM_PER_MEMBER period.
-- ---------------------------------------------------------------------

reset role;
insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('51200000-0000-0000-0000-000000000007', '51100000-0000-0000-0000-000000000001', null, 'Custom Late Joiner', 'ACTIVE', current_date, 'C23A-2026-0007');
set local role authenticated;
set local request.jwt.claim.sub to '51000000-0000-0000-0000-000000000001';

select throws_ok(
  format(
    $sql$ select public.rpc_enroll_member_in_contribution_period(
      '51100000-0000-0000-0000-000000000001', %L, '51200000-0000-0000-0000-000000000007'
    ) $sql$,
    (select result ->> 'id' from t_period_custom)
  ),
  '22023',
  'AMOUNT_REQUIRED',
  'enrolling into a CUSTOM_PER_MEMBER period without an amount is rejected'
);

select lives_ok(
  format(
    $sql$ select public.rpc_enroll_member_in_contribution_period(
      '51100000-0000-0000-0000-000000000001', %L, '51200000-0000-0000-0000-000000000007', 333
    ) $sql$,
    (select result ->> 'id' from t_period_custom)
  ),
  'enrolling into a CUSTOM_PER_MEMBER period with an explicit amount succeeds'
);

select is(
  (select cc.assessed_amount from public.member_contribution_charges c
   join public.contribution_charge_components cc on cc.charge_id = c.id and cc.component_type = 'BASE'
   where c.period_id = (select (result ->> 'id')::uuid from t_period_custom)
     and c.membership_id = '51200000-0000-0000-0000-000000000007'),
  333.00::numeric,
  'the explicitly-enrolled member''s BASE component uses the given amount'
);

-- ---------------------------------------------------------------------
-- Post-open enrollment on a FIXED period.
-- ---------------------------------------------------------------------

create temporary table t_period_fixed as
select public.rpc_create_contribution_period(
  '51100000-0000-0000-0000-000000000001', '51400000-0000-0000-0000-000000000002', 'Simple Fixed Round 1',
  '2026-06-01', '2026-06-30', p_due_date := '2026-06-30'
) as result;

create temporary table t_open_fixed as
select public.rpc_open_contribution_period(
  '51100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_fixed)
) as result;

-- A member added after OPEN gets no automatic charge.
reset role;
insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('51200000-0000-0000-0000-000000000005', '51100000-0000-0000-0000-000000000001', null, 'Fixed Late Joiner', 'ACTIVE', current_date, 'C23A-2026-0005');
set local role authenticated;
set local request.jwt.claim.sub to '51000000-0000-0000-0000-000000000001';

select is(
  (select count(*)::int from public.member_contribution_charges
   where period_id = (select (result ->> 'id')::uuid from t_period_fixed)
     and membership_id = '51200000-0000-0000-0000-000000000005'),
  0,
  'a member added to the group after OPEN gets no automatic charge'
);

set local request.jwt.claim.sub to '51000000-0000-0000-0000-000000000002';

select throws_ok(
  format(
    $sql$ select public.rpc_enroll_member_in_contribution_period(
      '51100000-0000-0000-0000-000000000001', %L, '51200000-0000-0000-0000-000000000005'
    ) $sql$,
    (select result ->> 'id' from t_period_fixed)
  ),
  '42501',
  null,
  'a caller without contribution.member_enroll cannot enroll a member'
);

set local request.jwt.claim.sub to '51000000-0000-0000-0000-000000000001';

select lives_ok(
  format(
    $sql$ select public.rpc_enroll_member_in_contribution_period(
      '51100000-0000-0000-0000-000000000001', %L, '51200000-0000-0000-0000-000000000005'
    ) $sql$,
    (select result ->> 'id' from t_period_fixed)
  ),
  'explicit enrollment on a FIXED period succeeds and auto-uses the fixed amount'
);

select is(
  (select cc.assessed_amount from public.member_contribution_charges c
   join public.contribution_charge_components cc on cc.charge_id = c.id and cc.component_type = 'BASE'
   where c.period_id = (select (result ->> 'id')::uuid from t_period_fixed)
     and c.membership_id = '51200000-0000-0000-0000-000000000005'),
  1500.00::numeric,
  'the enrolled member''s BASE component uses the setup''s fixed amount'
);

select throws_ok(
  format(
    $sql$ select public.rpc_enroll_member_in_contribution_period(
      '51100000-0000-0000-0000-000000000001', %L, '51200000-0000-0000-0000-000000000005'
    ) $sql$,
    (select result ->> 'id' from t_period_fixed)
  ),
  'P0001',
  'MEMBER_ALREADY_CHARGED_FOR_PERIOD',
  'enrolling an already-charged member a second time is rejected'
);

select throws_ok(
  format(
    $sql$ select public.rpc_enroll_member_in_contribution_period(
      '51100000-0000-0000-0000-000000000001', %L, '51200000-0000-0000-0000-000000000099'
    ) $sql$,
    (select result ->> 'id' from t_period_fixed)
  ),
  '22023',
  null,
  'enrolling a membership from a different group is rejected'
);

select public.rpc_close_contribution_period(
  '51100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_period_fixed)
);

reset role;
insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('51200000-0000-0000-0000-000000000006', '51100000-0000-0000-0000-000000000001', null, 'Too Late Joiner', 'ACTIVE', current_date, 'C23A-2026-0006');
set local role authenticated;
set local request.jwt.claim.sub to '51000000-0000-0000-0000-000000000001';

select throws_ok(
  format(
    $sql$ select public.rpc_enroll_member_in_contribution_period(
      '51100000-0000-0000-0000-000000000001', %L, '51200000-0000-0000-0000-000000000006'
    ) $sql$,
    (select result ->> 'id' from t_period_fixed)
  ),
  'P0001',
  'CONTRIBUTION_PERIOD_NOT_OPEN',
  'a CLOSED period cannot accept new enrollment'
);

select * from finish();

rollback;
