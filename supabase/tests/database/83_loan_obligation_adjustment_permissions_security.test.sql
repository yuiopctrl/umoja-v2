-- Prompt 09F-A: permissions and security posture (section 3/16, test
-- matrix items 14-18).
begin;

select plan(11);

-- Item 18: unauthenticated (no jwt claim set at all yet in this
-- transaction) is rejected, before any setup exists — the auth check is
-- always the very first thing every 09F-A RPC does.
select throws_ok(
  $$ select public.rpc_post_loan_obligation_waiver(
    '00000000-0000-0000-0000-000000000000'::uuid, '00000000-0000-0000-0000-000000000000'::uuid,
    'LOAN_PENALTY', '00000000-0000-0000-0000-000000000000'::uuid, 1000, 'HARDSHIP'
  ) $$,
  '28000',
  'Not authenticated',
  '18: an unauthenticated request is rejected before any target/permission is even resolved'
);

insert into auth.users (id, email) values
  ('83000000-0000-0000-0000-000000000001', 'p09fa-perm-admin@example.com'),
  ('83000000-0000-0000-0000-000000000002', 'p09fa-perm-treasurer@example.com'),
  ('83000000-0000-0000-0000-000000000003', 'p09fa-perm-member@example.com');

insert into public.groups (id, name, created_by, code) values
  ('83100000-0000-0000-0000-000000000001', 'Permission Group', '83000000-0000-0000-0000-000000000001', 'PERM'),
  ('83100000-0000-0000-0000-000000000002', 'Permission Other Group', '83000000-0000-0000-0000-000000000001', 'PERB');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('83200000-0000-0000-0000-000000000001', '83100000-0000-0000-0000-000000000001', '83000000-0000-0000-0000-000000000001', 'Perm Admin', 'ACTIVE', '2025-01-01', 'PERM-2026-0001'),
  ('83200000-0000-0000-0000-000000000002', '83100000-0000-0000-0000-000000000001', '83000000-0000-0000-0000-000000000002', 'Perm Treasurer', 'ACTIVE', '2025-01-01', 'PERM-2026-0002'),
  ('83200000-0000-0000-0000-000000000003', '83100000-0000-0000-0000-000000000001', '83000000-0000-0000-0000-000000000003', 'Perm Member', 'ACTIVE', '2025-01-01', 'PERM-2026-0003'),
  ('83200000-0000-0000-0000-000000000011', '83100000-0000-0000-0000-000000000001', null, 'Perm Borrower', 'ACTIVE', '2025-01-01', 'PERM-2026-0011'),
  ('83200000-0000-0000-0000-000000000021', '83100000-0000-0000-0000-000000000002', '83000000-0000-0000-0000-000000000001', 'Perm Admin (other group)', 'ACTIVE', '2025-01-01', 'PERB-2026-0001');

insert into public.group_membership_roles (group_membership_id, role_id) select '83200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select '83200000-0000-0000-0000-000000000002', id from public.roles where code = 'TREASURER';
insert into public.group_membership_roles (group_membership_id, role_id) select '83200000-0000-0000-0000-000000000003', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id) select '83200000-0000-0000-0000-000000000021', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '83000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '83100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '83100000-0000-0000-0000-000000000001', 'PERMP', 'Permission Product', 100000, 1, 12, 5.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'FIXED', p_penalty_frequency => 'ONCE',
  p_penalty_grace_days => 0, p_penalty_fixed_amount => 60000
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

create temporary table t_loan as
select public.rpc_create_draft_loan_account(
  '83100000-0000-0000-0000-000000000001', '83200000-0000-0000-0000-000000000011'::uuid,
  :'product_id'::uuid, 500000, 1, (current_date - interval '2 months')::date
) as result;
select (result->>'id')::uuid as loan_id from t_loan \gset
select public.rpc_submit_loan_account('83100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_approve_loan_account('83100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_disburse_loan_account('83100000-0000-0000-0000-000000000001', :'loan_id'::uuid, :'account_id'::uuid, current_date);
select id as installment_id from public.loan_installments where loan_account_id = :'loan_id'::uuid \gset

select public.rpc_assess_loan_penalties('83100000-0000-0000-0000-000000000001', current_date, :'loan_id'::uuid);
select id as charge_id from public.loan_penalty_charges where loan_installment_id = :'installment_id'::uuid \gset

-- Item 14: TREASURER can post a waiver.
set local request.jwt.claim.sub to '83000000-0000-0000-0000-000000000002';
create temporary table t_treasurer_waiver as
select public.rpc_post_loan_obligation_waiver(
  '83100000-0000-0000-0000-000000000001', :'loan_id'::uuid, 'LOAN_PENALTY', :'charge_id'::uuid, 10000, 'HARDSHIP'
) as result;
select is((result->>'adjustment_type')::text, 'WAIVER', '14: TREASURER can post a waiver') from t_treasurer_waiver;

-- Item 15: TREASURER cannot post a correction of any kind.
select throws_ok(
  format(
    $sql$ select public.rpc_post_loan_obligation_correction('83100000-0000-0000-0000-000000000001', %L::uuid, 'LOAN_PENALTY', %L::uuid, 'CORRECTION_DECREASE', 1000, 'ASSESSMENT_ERROR') $sql$,
    :'loan_id', :'charge_id'
  ),
  '42501',
  'Not authorized to correct loan obligations in this group',
  '15: TREASURER cannot post a correction (loan.correct is ADMIN-only)'
);

-- MEMBER cannot post a waiver either.
set local request.jwt.claim.sub to '83000000-0000-0000-0000-000000000003';
select throws_ok(
  format(
    $sql$ select public.rpc_post_loan_obligation_waiver('83100000-0000-0000-0000-000000000001', %L::uuid, 'LOAN_PENALTY', %L::uuid, 1000, 'HARDSHIP') $sql$,
    :'loan_id', :'charge_id'
  ),
  '42501',
  'Not authorized to waive loan obligations in this group',
  'MEMBER has neither loan.waive nor loan.correct by default'
);

-- Item 16: ADMIN can post a correction (both decrease and increase).
set local request.jwt.claim.sub to '83000000-0000-0000-0000-000000000001';
create temporary table t_admin_correction as
select public.rpc_post_loan_obligation_correction(
  '83100000-0000-0000-0000-000000000001', :'loan_id'::uuid, 'LOAN_PENALTY', :'charge_id'::uuid,
  'CORRECTION_DECREASE', 5000, 'ASSESSMENT_ERROR'
) as result;
select is((result->>'adjustment_type')::text, 'CORRECTION_DECREASE', '16: ADMIN can post a correction decrease') from t_admin_correction;

create temporary table t_admin_increase as
select public.rpc_post_loan_obligation_correction(
  '83100000-0000-0000-0000-000000000001', :'loan_id'::uuid, 'LOAN_PENALTY', :'charge_id'::uuid,
  'CORRECTION_INCREASE', 5000, 'ASSESSMENT_ERROR'
) as result;
select is((result->>'adjustment_type')::text, 'CORRECTION_INCREASE', '16b: ADMIN (with loan.correct_increase) can post a correction increase') from t_admin_increase;

-- Item 17: cross-group attack — an ADMIN of group 2 cannot target group
-- 1's loan/charge via the write RPCs, the reversal RPC, or the read RPC.
set local request.jwt.claim.sub to '83000000-0000-0000-0000-000000000001';
select throws_ok(
  format(
    $sql$ select public.rpc_post_loan_obligation_waiver('83100000-0000-0000-0000-000000000002', %L::uuid, 'LOAN_PENALTY', %L::uuid, 1000, 'HARDSHIP') $sql$,
    :'loan_id', :'charge_id'
  ),
  '22023',
  'Loan account not found in group',
  '17: cross-group waiver attempt against another group''s real loan/charge is rejected'
);
select throws_ok(
  format(
    $sql$ select public.rpc_list_loan_obligation_adjustments('83100000-0000-0000-0000-000000000002', %L::uuid) $sql$,
    :'loan_id'
  ),
  '22023',
  'Loan account not found in group',
  '17b: cross-group read of another group''s adjustment history is rejected'
);
select throws_ok(
  format(
    $sql$ select public.rpc_reverse_loan_obligation_adjustment('83100000-0000-0000-0000-000000000002', %L::uuid, 'cross-group attempt') $sql$,
    (select id from public.loan_obligation_adjustments where loan_account_id = :'loan_id'::uuid limit 1)
  ),
  '22023',
  'Adjustment not found in group',
  '17c: cross-group reversal attempt against another group''s real adjustment is rejected'
);

-- No anon execution: the anon role has zero EXECUTE grant on any of the
-- five public RPCs.
reset role;
select is(
  (select count(*)::integer from information_schema.routine_privileges
   where routine_schema = 'public'
     and routine_name in (
       'rpc_preview_loan_obligation_waiver', 'rpc_post_loan_obligation_waiver',
       'rpc_preview_loan_obligation_correction', 'rpc_post_loan_obligation_correction',
       'rpc_reverse_loan_obligation_adjustment', 'rpc_list_loan_obligation_adjustments'
     )
     and grantee = 'anon'),
  0,
  'no anon EXECUTE grant exists on any 09F-A RPC'
);
select is(
  (select count(*)::integer from information_schema.role_table_grants
   where table_schema = 'public' and table_name = 'loan_obligation_adjustments'
     and grantee = 'authenticated' and privilege_type in ('INSERT', 'UPDATE', 'DELETE')),
  0,
  'no direct INSERT/UPDATE/DELETE grant exists for authenticated on loan_obligation_adjustments'
);

select * from finish();
rollback;
