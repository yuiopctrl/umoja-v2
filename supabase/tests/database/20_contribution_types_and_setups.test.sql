-- Contribution Engine (Prompt 06A): schema/tenancy foundation checks,
-- plus Contribution Type and Contribution Setup mutation RPCs
-- (rpc_create_contribution_type, rpc_update_contribution_type,
-- rpc_create_contribution_setup, rpc_update_contribution_setup) and the
-- contribution_compute_due_date helper.
begin;

select plan(28);

insert into auth.users (id, email) values
  ('21000000-0000-0000-0000-000000000001', 'contrib20-treasurer-a@example.com'),
  ('21000000-0000-0000-0000-000000000002', 'contrib20-member-a@example.com'),
  ('21000000-0000-0000-0000-000000000003', 'contrib20-treasurer-b@example.com');

insert into public.groups (id, name, created_by, code) values
  ('21100000-0000-0000-0000-000000000001', 'Contrib20 Group A', '21000000-0000-0000-0000-000000000001', 'C20A'),
  ('21100000-0000-0000-0000-000000000002', 'Contrib20 Group B', '21000000-0000-0000-0000-000000000003', 'C20B');

insert into public.group_memberships (id, group_id, user_id, display_name, status, member_number) values
  ('21200000-0000-0000-0000-000000000001', '21100000-0000-0000-0000-000000000001', '21000000-0000-0000-0000-000000000001', 'Contrib20 Treasurer A', 'ACTIVE', 'C20A-2026-0001'),
  ('21200000-0000-0000-0000-000000000002', '21100000-0000-0000-0000-000000000001', '21000000-0000-0000-0000-000000000002', 'Contrib20 Member A', 'ACTIVE', 'C20A-2026-0002'),
  ('21200000-0000-0000-0000-000000000003', '21100000-0000-0000-0000-000000000002', '21000000-0000-0000-0000-000000000003', 'Contrib20 Treasurer B', 'ACTIVE', 'C20B-2026-0001');

insert into public.group_membership_roles (group_membership_id, role_id)
select '21200000-0000-0000-0000-000000000001', id from public.roles where code = 'TREASURER';
insert into public.group_membership_roles (group_membership_id, role_id)
select '21200000-0000-0000-0000-000000000002', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id)
select '21200000-0000-0000-0000-000000000003', id from public.roles where code = 'TREASURER';

-- A contribution type in Group B, for the cross-group isolation checks
-- below (fixture inserted directly, bypassing RLS, like other files).
insert into public.contribution_types (id, group_id, name, category, accounting_treatment, created_by) values
  ('21300000-0000-0000-0000-000000000099', '21100000-0000-0000-0000-000000000002', 'Group B Dues', 'GENERAL', 'GROUP_INCOME', '21000000-0000-0000-0000-000000000003');

-- ---------------------------------------------------------------------
-- Schema / tenancy foundation.
-- ---------------------------------------------------------------------

select is(
  (select count(*) from pg_tables
   where schemaname = 'public'
     and tablename in (
       'contribution_types', 'contribution_setups', 'contribution_periods',
       'contribution_period_member_amounts', 'contribution_period_member_exclusions',
       'member_contribution_charges', 'contribution_charge_components'
     )),
  7::bigint,
  'all 7 Contribution Engine tables exist'
);

select is(
  (select count(*) from pg_class
   where relnamespace = 'public'::regnamespace
     and relname in (
       'contribution_types', 'contribution_setups', 'contribution_periods',
       'contribution_period_member_amounts', 'contribution_period_member_exclusions',
       'member_contribution_charges', 'contribution_charge_components'
     )
     and relrowsecurity = true),
  7::bigint,
  'RLS is enabled on all 7 Contribution Engine tables'
);

select is(
  (select count(*) from (values
    ('contribution_types'), ('contribution_setups'), ('contribution_periods'),
    ('contribution_period_member_amounts'), ('contribution_period_member_exclusions'),
    ('member_contribution_charges'), ('contribution_charge_components')
  ) as t(tbl)
  where has_table_privilege('authenticated', 'public.' || t.tbl, 'INSERT')
     or has_table_privilege('authenticated', 'public.' || t.tbl, 'UPDATE')
     or has_table_privilege('authenticated', 'public.' || t.tbl, 'DELETE')),
  0::bigint,
  'no client INSERT/UPDATE/DELETE grant exists on any of the 7 Contribution Engine tables'
);

select is(
  (select count(*) from (values
    ('contribution_types'), ('contribution_setups'), ('contribution_periods'),
    ('contribution_period_member_amounts'), ('contribution_period_member_exclusions'),
    ('member_contribution_charges'), ('contribution_charge_components')
  ) as t(tbl)
  where has_table_privilege('anon', 'public.' || t.tbl, 'SELECT')
     or has_table_privilege('anon', 'public.' || t.tbl, 'INSERT')
     or has_table_privilege('anon', 'public.' || t.tbl, 'UPDATE')
     or has_table_privilege('anon', 'public.' || t.tbl, 'DELETE')),
  0::bigint,
  'anon has no grant at all on any of the 7 Contribution Engine tables'
);

select is(
  (select count(*) from (values
    ('public.rpc_create_contribution_type(uuid, text, public.contribution_category, public.contribution_accounting_treatment, text, integer)'),
    ('public.rpc_update_contribution_type(uuid, uuid, text, text, public.contribution_category, public.contribution_accounting_treatment, integer, boolean)'),
    ('public.rpc_create_contribution_setup(uuid, uuid, text, public.contribution_schedule_mode, public.contribution_amount_mode, text, numeric, integer, integer, public.contribution_penalty_mode, integer, numeric, numeric)'),
    ('public.rpc_update_contribution_setup(uuid, uuid, text, text, numeric, integer, integer, public.contribution_penalty_mode, integer, numeric, numeric, boolean)'),
    ('public.rpc_create_contribution_period(uuid, uuid, text, date, date, date, date, date, public.contribution_period_status, date)'),
    ('public.rpc_set_contribution_period_member_amounts(uuid, uuid, jsonb)'),
    ('public.rpc_exclude_contribution_period_member(uuid, uuid, uuid, text)'),
    ('public.rpc_remove_contribution_period_member_exclusion(uuid, uuid, uuid)'),
    ('public.rpc_open_contribution_period(uuid, uuid)'),
    ('public.rpc_enroll_member_in_contribution_period(uuid, uuid, uuid, numeric)'),
    ('public.rpc_close_contribution_period(uuid, uuid)'),
    ('public.rpc_cancel_contribution_period(uuid, uuid)')
  ) as f(sig)
  where has_function_privilege('anon', f.sig, 'execute')),
  0::bigint,
  'anon cannot execute any of the 12 new Contribution Engine mutation RPCs'
);

select is(
  (select count(*) from (values
    ('public.contribution_type_has_posted_period(uuid)'),
    ('public.contribution_setup_has_posted_period(uuid)'),
    ('public.contribution_period_eligible_memberships(uuid)')
  ) as f(sig)
  where has_function_privilege('authenticated', f.sig, 'execute')),
  0::bigint,
  'internal lock/eligibility helper functions are not directly executable by authenticated clients'
);

set local role authenticated;
set local request.jwt.claim.sub to '21000000-0000-0000-0000-000000000001';

select is(
  has_function_privilege('authenticated', 'public.contribution_compute_due_date(date, integer, integer)', 'execute'),
  true,
  'authenticated can execute contribution_compute_due_date'
);

-- ---------------------------------------------------------------------
-- contribution_compute_due_date: due-date defaults.
-- ---------------------------------------------------------------------

select is(
  public.contribution_compute_due_date('2027-01-01'::date, 1, 31),
  '2027-02-28'::date,
  'day 31 caps to Feb 28 in a non-leap year (period_start 2027-01-01, offset 1)'
);

select is(
  public.contribution_compute_due_date('2028-01-01'::date, 1, 31),
  '2028-02-29'::date,
  'day 31 caps to Feb 29 in a leap year (period_start 2028-01-01, offset 1)'
);

-- ---------------------------------------------------------------------
-- rpc_create_contribution_type
-- ---------------------------------------------------------------------

create temporary table t_type_a as
select public.rpc_create_contribution_type(
  '21100000-0000-0000-0000-000000000001', 'Monthly Dues', 'GENERAL', 'GROUP_INCOME'
) as result;

select is(
  (select result ->> 'name' from t_type_a),
  'Monthly Dues',
  'an authorized caller (contribution.type.manage) can create a contribution type'
);

select is(
  (select result ->> 'is_active' from t_type_a)::boolean,
  true,
  'a newly created contribution type is active by default'
);

set local request.jwt.claim.sub to '21000000-0000-0000-0000-000000000002';

select throws_ok(
  $$ select public.rpc_create_contribution_type('21100000-0000-0000-0000-000000000001', 'Unauthorized Type', 'GENERAL', 'GROUP_INCOME') $$,
  '42501',
  null,
  'a caller without contribution.type.manage cannot create a contribution type'
);

set local request.jwt.claim.sub to '21000000-0000-0000-0000-000000000001';

select throws_ok(
  $$ select public.rpc_create_contribution_type('21100000-0000-0000-0000-000000000001', 'Monthly Dues', 'GENERAL', 'GROUP_INCOME') $$,
  '23505',
  null,
  'a duplicate contribution type name within the same group is rejected'
);

select throws_ok(
  $$ select public.rpc_create_contribution_type('21100000-0000-0000-0000-000000000001', '   ', 'GENERAL', 'GROUP_INCOME') $$,
  '22023',
  null,
  'a blank contribution type name is rejected'
);

select throws_ok(
  $$ select public.rpc_create_contribution_type('21100000-0000-0000-0000-000000000001', 'Share Wrong Treatment', 'SHARE', 'GROUP_INCOME') $$,
  '23514',
  null,
  'a SHARE category type requires SHARE_CAPITAL accounting treatment'
);

select throws_ok(
  $$ select public.rpc_create_contribution_type('21100000-0000-0000-0000-000000000001', 'Savings Type', 'GENERAL', 'MEMBER_SAVINGS') $$,
  'P0001',
  'MEMBER_SAVINGS_NOT_AVAILABLE',
  'normal creation of a MEMBER_SAVINGS contribution type is rejected'
);

create temporary table t_type_share as
select public.rpc_create_contribution_type(
  '21100000-0000-0000-0000-000000000001', 'Share Capital', 'SHARE', 'SHARE_CAPITAL'
) as result;

select is(
  (select result ->> 'accounting_treatment' from t_type_share),
  'SHARE_CAPITAL',
  'a SHARE category type with SHARE_CAPITAL treatment is created successfully'
);

-- Cross-group read: Treasurer B cannot read Group A's contribution type.
set local request.jwt.claim.sub to '21000000-0000-0000-0000-000000000003';

select throws_ok(
  format(
    $sql$ select public.rpc_get_contribution_type('21100000-0000-0000-0000-000000000002', %L) $sql$,
    (select result ->> 'id' from t_type_a)
  ),
  '22023',
  null,
  'cross-group contribution type access is blocked (type not found under the other group)'
);

set local request.jwt.claim.sub to '21000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- rpc_create_contribution_setup / rpc_update_contribution_setup
-- ---------------------------------------------------------------------

select throws_ok(
  format(
    $sql$ select public.rpc_create_contribution_setup(
      '21100000-0000-0000-0000-000000000001', %L, 'Fixed No Amount', 'MONTHLY', 'FIXED'
    ) $sql$,
    (select result ->> 'id' from t_type_a)
  ),
  '23514',
  null,
  'a FIXED setup with no fixed_amount is rejected'
);

select throws_ok(
  format(
    $sql$ select public.rpc_create_contribution_setup(
      '21100000-0000-0000-0000-000000000001', %L, 'Custom With Amount', 'MONTHLY', 'CUSTOM_PER_MEMBER',
      p_fixed_amount := 100
    ) $sql$,
    (select result ->> 'id' from t_type_a)
  ),
  '23514',
  null,
  'a CUSTOM_PER_MEMBER setup cannot carry a fixed_amount'
);

select throws_ok(
  format(
    $sql$ select public.rpc_create_contribution_setup(
      '21100000-0000-0000-0000-000000000001', %L, 'Bad Due Day', 'MONTHLY', 'FIXED',
      p_fixed_amount := 1000, p_default_due_day := 32
    ) $sql$,
    (select result ->> 'id' from t_type_a)
  ),
  '23514',
  null,
  'a default_due_day outside 1-31 is rejected'
);

create temporary table t_setup_a as
select public.rpc_create_contribution_setup(
  '21100000-0000-0000-0000-000000000001',
  (select result ->> 'id' from t_type_a)::uuid,
  'Monthly Dues Setup', 'MONTHLY', 'FIXED',
  p_fixed_amount := 1000, p_default_due_day := 28, p_default_due_month_offset := 0
) as result;

select is(
  (select result ->> 'schedule_mode' from t_setup_a),
  'MONTHLY',
  'a valid MONTHLY/FIXED contribution setup is created'
);

create temporary table t_setup_ondemand as
select public.rpc_create_contribution_setup(
  '21100000-0000-0000-0000-000000000001',
  (select result ->> 'id' from t_type_a)::uuid,
  'On Demand Setup', 'ON_DEMAND', 'CUSTOM_PER_MEMBER'
) as result;

select is(
  (select result ->> 'amount_mode' from t_setup_ondemand),
  'CUSTOM_PER_MEMBER',
  'an ON_DEMAND/CUSTOM_PER_MEMBER contribution setup is created'
);

create temporary table t_setup_onetime as
select public.rpc_create_contribution_setup(
  '21100000-0000-0000-0000-000000000001',
  (select result ->> 'id' from t_type_a)::uuid,
  'One Time Setup', 'ONE_TIME', 'FIXED', p_fixed_amount := 500
) as result;

select is(
  (select result ->> 'schedule_mode' from t_setup_onetime),
  'ONE_TIME',
  'a ONE_TIME/FIXED contribution setup is created'
);

-- Setup group isolation: the contribution_type_id must belong to the
-- same group as p_group_id.
select throws_ok(
  $$ select public.rpc_create_contribution_setup(
    '21100000-0000-0000-0000-000000000001', '21300000-0000-0000-0000-000000000099', 'Cross Group Setup', 'MONTHLY', 'FIXED', p_fixed_amount := 100
  ) $$,
  '22023',
  null,
  'a contribution setup cannot reference a contribution type from a different group'
);

-- Inactive setup blocks new period creation.
select public.rpc_update_contribution_setup(
  '21100000-0000-0000-0000-000000000001',
  (select result ->> 'id' from t_setup_onetime)::uuid,
  p_is_active := false
);

select throws_ok(
  format(
    $sql$ select public.rpc_create_contribution_period(
      '21100000-0000-0000-0000-000000000001', %L, 'Inactive Setup Period', current_date, current_date
    ) $sql$,
    (select result ->> 'id' from t_setup_onetime)
  ),
  'P0001',
  'CONTRIBUTION_SETUP_INACTIVE',
  'a period cannot be created against an inactive contribution setup'
);

-- Deactivate via is_active -- no hard delete. Done last so it does not
-- affect the setup tests above, which need t_type_a to remain active.
select public.rpc_update_contribution_type(
  '21100000-0000-0000-0000-000000000001',
  (select result ->> 'id' from t_type_a)::uuid,
  p_is_active := false
);

select is(
  (select is_active from public.contribution_types where id = (select result ->> 'id' from t_type_a)::uuid),
  false,
  'rpc_update_contribution_type can deactivate a type via is_active'
);

select is(
  (select count(*)::int from public.contribution_types where id = (select result ->> 'id' from t_type_a)::uuid),
  1,
  'deactivating a type does not hard-delete its row'
);

select * from finish();

rollback;
