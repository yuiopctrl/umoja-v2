-- Prompt 09F-B: Loan Recovery — real cash event via the existing
-- Payment Engine (section B, test matrix items 9-13).
begin;

select plan(15);

insert into auth.users (id, email) values
  ('94000000-0000-0000-0000-000000000001', 'p09fb-recovery-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('94100000-0000-0000-0000-000000000001', 'Recovery Group', '94000000-0000-0000-0000-000000000001', 'RCVY');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('94200000-0000-0000-0000-000000000001', '94100000-0000-0000-0000-000000000001', '94000000-0000-0000-0000-000000000001', 'Recovery Admin', 'ACTIVE', '2025-01-01', 'RCVY-2026-0001'),
  ('94200000-0000-0000-0000-000000000011', '94100000-0000-0000-0000-000000000001', null, 'Recovery Borrower', 'ACTIVE', '2025-01-01', 'RCVY-2026-0011');

insert into public.group_membership_roles (group_membership_id, role_id) select '94200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '94000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '94100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, '2026-06-15'::date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '94100000-0000-0000-0000-000000000001', 'RCVYP', 'Recovery Product', 100000, 1, 12, 5.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'FIXED', p_penalty_frequency => 'ONCE',
  p_penalty_grace_days => 0, p_penalty_fixed_amount => 20000
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

create temporary table t_loan as
select public.rpc_create_draft_loan_account(
  '94100000-0000-0000-0000-000000000001', '94200000-0000-0000-0000-000000000011'::uuid,
  :'product_id'::uuid, 300000, 3, '2026-04-15'::date
) as result;
select (result->>'id')::uuid as loan_id from t_loan \gset
select public.rpc_submit_loan_account('94100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_approve_loan_account('94100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_disburse_loan_account('94100000-0000-0000-0000-000000000001', :'loan_id'::uuid, :'account_id'::uuid, '2026-04-15'::date);
select public.rpc_assess_loan_penalties('94100000-0000-0000-0000-000000000001', '2026-06-15'::date, :'loan_id'::uuid);

create temporary table t_write_off as
select public.rpc_post_loan_write_off(
  '94100000-0000-0000-0000-000000000001', :'loan_id'::uuid, 'PROLONGED_DEFAULT', null, '2026-06-15'::date
) as result;
select (result->>'write_off_event_id')::uuid as write_off_id from t_write_off \gset
select (result->>'penalty_amount')::numeric as wo_penalty from t_write_off \gset
select (result->>'interest_amount')::numeric as wo_interest from t_write_off \gset
select (result->>'principal_amount')::numeric as wo_principal from t_write_off \gset
select (result->>'total_amount')::numeric as wo_total from t_write_off \gset

-- rejects recovery against a target that is not WRITTEN_OFF.
create temporary table t_product2 as
select public.rpc_create_loan_product(
  '94100000-0000-0000-0000-000000000001', 'RCVYP2', 'Recovery Product 2', 100000, 1, 12, 0.0, 'MONTHLY', 'FLAT'
) as result;
select (result->>'id')::uuid as product2_id from t_product2 \gset
create temporary table t_active_loan as
select public.rpc_create_draft_loan_account(
  '94100000-0000-0000-0000-000000000001', '94200000-0000-0000-0000-000000000011'::uuid,
  :'product2_id'::uuid, 100000, 1, '2026-06-15'::date
) as result;
select (result->>'id')::uuid as active_loan_id from t_active_loan \gset
select public.rpc_submit_loan_account('94100000-0000-0000-0000-000000000001', :'active_loan_id'::uuid);
select public.rpc_approve_loan_account('94100000-0000-0000-0000-000000000001', :'active_loan_id'::uuid);
select public.rpc_disburse_loan_account('94100000-0000-0000-0000-000000000001', :'active_loan_id'::uuid, :'account_id'::uuid, '2026-06-15'::date);

select throws_ok(
  format(
    $sql$ select public.rpc_preview_loan_recovery('94100000-0000-0000-0000-000000000001', %L::uuid, 10000, '2026-06-15'::date) $sql$,
    :'active_loan_id'
  ),
  'P0001',
  'LOAN_RECOVERY_TARGET_NOT_WRITTEN_OFF',
  'recovery is rejected against a loan that is not WRITTEN_OFF'
);

-- Item 9/10: partial recovery, PENALTY -> INTEREST -> PRINCIPAL order.
-- Recover exactly the penalty amount plus a bit of interest.
create temporary table t_recovery1 as
select public.rpc_post_loan_recovery(
  '94100000-0000-0000-0000-000000000001', :'loan_id'::uuid,
  :'wo_penalty'::numeric + 1000, :'account_id'::uuid, 'CASH', '2026-07-01'::date
) as result;
select (result->'allocation'->>'penalty')::numeric as r1_penalty from t_recovery1 \gset
select (result->'allocation'->>'interest')::numeric as r1_interest from t_recovery1 \gset
select (result->'allocation'->>'principal')::numeric as r1_principal from t_recovery1 \gset
select (result->>'payment_id')::uuid as r1_payment_id from t_recovery1 \gset

select is(:'r1_penalty'::numeric, :'wo_penalty'::numeric, '9a: first recovery fully allocates the penalty component first');
select is(:'r1_interest'::numeric, 1000.00::numeric, '9b: remainder after penalty is allocated to interest');
select is(:'r1_principal'::numeric, 0.00::numeric, '10: principal receives nothing while penalty/interest remain outstanding');

-- Item 6-equivalent for recovery: it DOES create real cash artefacts
-- (a real payment + cashbook inflow), unlike write-off.
select isnt(:'r1_payment_id'::uuid, null, 'recovery creates a real payment row');
select ok(
  exists (
    select 1 from public.financial_account_entries
    where source_type = 'LOAN_RECOVERY' and source_id = :'r1_payment_id'::uuid and entry_type = 'INFLOW'
  ),
  'recovery posts a real cashbook INFLOW entry'
);

-- Loan remains WRITTEN_OFF — never auto-reactivated by a recovery.
select is(
  (select status from public.loan_accounts where id = :'loan_id'::uuid),
  'WRITTEN_OFF',
  'the loan remains WRITTEN_OFF after a partial recovery (no auto-reactivation)'
);

-- Item 11: multiple recoveries accumulate correctly. Remaining
-- recoverable balance is read via the dedicated read RPC
-- (rpc_get_loan_write_off_summary) rather than the locked-down internal
-- helper, which is never callable by authenticated.
create temporary table t_summary1 as
select public.rpc_get_loan_write_off_summary('94100000-0000-0000-0000-000000000001', :'loan_id'::uuid) as result;
select (result->'remaining_recoverable'->>'interest')::numeric as interest_remaining_after_r1 from t_summary1 \gset

create temporary table t_recovery2 as
select public.rpc_post_loan_recovery(
  '94100000-0000-0000-0000-000000000001', :'loan_id'::uuid,
  :'interest_remaining_after_r1'::numeric, :'account_id'::uuid, 'CASH', '2026-07-05'::date
) as result;
select (result->'allocation'->>'interest')::numeric as r2_interest from t_recovery2 \gset

select is(
  :'r2_interest'::numeric, :'interest_remaining_after_r1'::numeric,
  '11: a second recovery correctly picks up exactly the remaining interest balance'
);

create temporary table t_summary2 as
select public.rpc_get_loan_write_off_summary('94100000-0000-0000-0000-000000000001', :'loan_id'::uuid) as result;
select is(
  (result->'remaining_recoverable'->>'interest')::numeric,
  0.00::numeric,
  '11b: after two recoveries, remaining interest is fully exhausted'
) from t_summary2;

-- Item 12: over-recovery rejected — attempt to recover more than the
-- total remaining recoverable balance.
select (result->'remaining_recoverable'->>'principal')::numeric as principal_remaining from t_summary2 \gset
select throws_ok(
  format(
    $sql$ select public.rpc_post_loan_recovery('94100000-0000-0000-0000-000000000001', %L::uuid, %L::numeric, %L::uuid, 'CASH', '2026-07-10'::date) $sql$,
    :'loan_id', (:'principal_remaining'::numeric + 1), :'account_id'
  ),
  'P0001',
  'LOAN_RECOVERY_EXCEEDS_REMAINING_BALANCE',
  '12: a recovery amount exceeding the remaining recoverable balance is rejected'
);

-- Confirm the rejected over-recovery attempt posted nothing.
select is(
  (select count(*)::integer from public.payments where financial_account_id = :'account_id'::uuid and amount = (:'principal_remaining'::numeric + 1)),
  0,
  '12b: the rejected over-recovery created no payment row'
);

-- Item 13: recovery reversal integrates with rpc_reverse_payment. The
-- rejected over-recovery attempt above posted nothing, so
-- principal_remaining is still the true remaining principal balance.
create temporary table t_recovery3 as
select public.rpc_post_loan_recovery(
  '94100000-0000-0000-0000-000000000001', :'loan_id'::uuid,
  :'principal_remaining'::numeric, :'account_id'::uuid, 'CASH', '2026-07-15'::date
) as result;
select (result->>'payment_id')::uuid as r3_payment_id from t_recovery3 \gset

create temporary table t_summary3 as
select public.rpc_get_loan_write_off_summary('94100000-0000-0000-0000-000000000001', :'loan_id'::uuid) as result;
select is(
  (result->'remaining_recoverable'->>'principal')::numeric,
  0.00::numeric,
  '13a: after the third recovery, remaining recoverable balance is fully zero'
) from t_summary3;

select public.rpc_reverse_payment('94100000-0000-0000-0000-000000000001', :'r3_payment_id'::uuid, 'Recorded in error');

create temporary table t_summary4 as
select public.rpc_get_loan_write_off_summary('94100000-0000-0000-0000-000000000001', :'loan_id'::uuid) as result;
select is(
  (result->'remaining_recoverable'->>'principal')::numeric,
  :'principal_remaining'::numeric,
  '13b: reversing the recovery payment exactly restores the recoverable principal balance'
) from t_summary4;

select is(
  (select status from public.payments where id = :'r3_payment_id'::uuid),
  'REVERSED',
  '13c: the recovery payment itself is marked REVERSED'
);

select is(
  (select status from public.loan_accounts where id = :'loan_id'::uuid),
  'WRITTEN_OFF',
  '13d: reversing a recovery payment does not touch the WRITTEN_OFF loan status (recheck_closure is a no-op for WRITTEN_OFF)'
);

select * from finish();
rollback;
