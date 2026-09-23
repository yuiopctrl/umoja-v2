-- Prompt 09G-02: rpc_get_loan_statement — ordering/edge-case coverage
-- (test matrix scenarios 24, 25, 26, 27, 29, 30), Section O (read-only
-- accounting assertions), Section P (security), and the
-- rpc_get_loan_account regression H (cross-group/permission unchanged).
begin;

select plan(29);

-- Section P (auth-first, before any setup exists): unauthenticated is
-- rejected before any target/permission is resolved.
select throws_ok(
  $$ select public.rpc_get_loan_statement(
    '00000000-0000-0000-0000-000000000000'::uuid, '00000000-0000-0000-0000-000000000000'::uuid
  ) $$,
  '28000',
  'Not authenticated',
  'P1: an unauthenticated statement read is rejected before any target/permission is resolved'
);
select throws_ok(
  $$ select public.rpc_get_loan_account(
    '00000000-0000-0000-0000-000000000000'::uuid, '00000000-0000-0000-0000-000000000000'::uuid
  ) $$,
  '28000',
  'Not authenticated',
  'H1: an unauthenticated rpc_get_loan_account read is rejected before any target/permission is resolved'
);

insert into auth.users (id, email) values
  ('a0000000-0000-0000-0000-000000000001', 'p09g-stmt-sec-admin@example.com'),
  ('a0000000-0000-0000-0000-000000000002', 'p09g-stmt-sec-member@example.com');

insert into public.groups (id, name, created_by, code) values
  ('a0100000-0000-0000-0000-000000000001', 'Statement Sec Group', 'a0000000-0000-0000-0000-000000000001', 'STSEC'),
  ('a0100000-0000-0000-0000-000000000002', 'Statement Sec Other Group', 'a0000000-0000-0000-0000-000000000001', 'STSEB');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('a0200000-0000-0000-0000-000000000001', 'a0100000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'St Sec Admin', 'ACTIVE', '2025-01-01', 'STSEC-2026-0001'),
  ('a0200000-0000-0000-0000-000000000002', 'a0100000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000002', 'St Sec Member', 'ACTIVE', '2025-01-01', 'STSEC-2026-0002'),
  ('a0200000-0000-0000-0000-000000000011', 'a0100000-0000-0000-0000-000000000001', null, 'St Sec Borrower', 'ACTIVE', '2025-01-01', 'STSEC-2026-0011'),
  ('a0200000-0000-0000-0000-000000000021', 'a0100000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'St Sec Admin (other group)', 'ACTIVE', '2025-01-01', 'STSEB-2026-0001');

insert into public.group_membership_roles (group_membership_id, role_id) select 'a0200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select 'a0200000-0000-0000-0000-000000000002', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id) select 'a0200000-0000-0000-0000-000000000021', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to 'a0000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  'a0100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, '2026-04-15'::date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  'a0100000-0000-0000-0000-000000000001', 'STSECP', 'Statement Sec Product', 100000, 1, 12, 5.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'FIXED', p_penalty_frequency => 'ONCE',
  p_penalty_grace_days => 0, p_penalty_fixed_amount => 20000
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

create temporary table t_loan as
select public.rpc_create_draft_loan_account(
  'a0100000-0000-0000-0000-000000000001', 'a0200000-0000-0000-0000-000000000011'::uuid,
  :'product_id'::uuid, 200000, 2, '2026-04-15'::date
) as result;
select (result->>'id')::uuid as loan_id from t_loan \gset
select public.rpc_submit_loan_account('a0100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_approve_loan_account('a0100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_disburse_loan_account('a0100000-0000-0000-0000-000000000001', :'loan_id'::uuid, :'account_id'::uuid, '2026-04-15'::date);

-- 27: deterministic same-time ordering — assess the penalty (source
-- priority 2) FIRST in wall-clock/created_at terms, then post an
-- ordinary payment (source priority 1) dated the SAME business day.
-- If the timeline were ever ordered by created_at alone, the penalty
-- (inserted first) would appear before the payment; the correct
-- priority-based ordering must still place the payment first.
select public.rpc_assess_loan_penalties('a0100000-0000-0000-0000-000000000001', '2026-05-16'::date, :'loan_id'::uuid);
create temporary table t_payment as
select public.rpc_post_payment('a0100000-0000-0000-0000-000000000001', 'a0200000-0000-0000-0000-000000000011'::uuid, :'account_id'::uuid, 5000, '2026-05-16'::date, 'CASH') as result;
select (result->>'payment_id')::uuid as payment_id from t_payment \gset

create temporary table t_stmt as
select public.rpc_get_loan_statement('a0100000-0000-0000-0000-000000000001', :'loan_id'::uuid) as result;

select is(
  (
    select (min(e1.elem->>'sequence_key') < min(e2.elem->>'sequence_key'))
    from (
      select e as elem from t_stmt, jsonb_array_elements(result->'timeline') e
      where e->>'event_type' = 'PAYMENT_POSTED' and e->'references'->>'payment_id' = :'payment_id'::text
    ) e1,
    (
      select e as elem from t_stmt, jsonb_array_elements(result->'timeline') e
      where e->>'event_type' = 'PENALTY_ASSESSED'
    ) e2
  ),
  true,
  '27: same business-day payment (priority 1) sorts strictly before every penalty assessment (priority 2), despite the penalties having been created first'
);

-- 26: reversed events remain visible (never removed from the timeline)
select public.rpc_reverse_payment('a0100000-0000-0000-0000-000000000001', :'payment_id'::uuid, 'test reversal');
create temporary table t_stmt_reversed as
select public.rpc_get_loan_statement('a0100000-0000-0000-0000-000000000001', :'loan_id'::uuid) as result;
select ok(
  exists (select 1 from t_stmt_reversed, jsonb_array_elements(result->'timeline') e
   where e->>'event_type' = 'PAYMENT_POSTED' and e->'references'->>'payment_id' = :'payment_id'::text
     and (e->>'is_reversed')::boolean = true),
  '26: a reversed payment event remains visible in the timeline, marked is_reversed=true, never removed'
);

-- =====================================================================
-- 29: future/unearned interest excluded from earned/current outstanding
-- =====================================================================

create temporary table t_loan_future as
select public.rpc_create_draft_loan_account(
  'a0100000-0000-0000-0000-000000000001', 'a0200000-0000-0000-0000-000000000011'::uuid,
  :'product_id'::uuid, 200000, 2, '2026-09-01'::date
) as result;
select (result->>'id')::uuid as loan_future_id from t_loan_future \gset
select public.rpc_submit_loan_account('a0100000-0000-0000-0000-000000000001', :'loan_future_id'::uuid);
select public.rpc_approve_loan_account('a0100000-0000-0000-0000-000000000001', :'loan_future_id'::uuid);
select public.rpc_disburse_loan_account('a0100000-0000-0000-0000-000000000001', :'loan_future_id'::uuid, :'account_id'::uuid, '2026-09-01'::date);

select coalesce(sum(interest_due) filter (where due_date <= current_date), 0) as expected_earned_interest,
       coalesce(sum(interest_due) filter (where due_date > current_date), 0) as expected_unearned_interest,
       coalesce(sum(principal_due), 0) as expected_total_principal
from public.loan_installments where loan_account_id = :'loan_future_id'::uuid \gset

create temporary table t_stmt_future as
select public.rpc_get_loan_statement('a0100000-0000-0000-0000-000000000001', :'loan_future_id'::uuid) as result;

select is(
  (select (result->'current_state'->>'earned_interest_outstanding')::numeric from t_stmt_future),
  :'expected_earned_interest'::numeric,
  '29a: earned_interest_outstanding equals only the interest of due-or-past installments'
);
select is(
  (select (result->'current_state'->>'scheduled_unearned_interest')::numeric from t_stmt_future),
  :'expected_unearned_interest'::numeric,
  '29b: scheduled_unearned_interest equals only the interest of not-yet-due installments'
);
select is(
  (select (result->'current_state'->>'principal_outstanding')::numeric from t_stmt_future),
  :'expected_total_principal'::numeric,
  '29c: principal_outstanding is never due-date-gated — the full outstanding principal across every installment'
);
select ok(
  (select jsonb_array_length(result->'timeline') from t_stmt_future) = 4,
  '29d: future/not-yet-due installments themselves are never listed as timeline events (only the 4 lifecycle events so far)'
);

-- =====================================================================
-- 30: a single multi-installment payment appears exactly once
-- =====================================================================

create temporary table t_loan_multi as
select public.rpc_create_draft_loan_account(
  'a0100000-0000-0000-0000-000000000001', 'a0200000-0000-0000-0000-000000000011'::uuid,
  :'product_id'::uuid, 200000, 2, '2026-04-15'::date
) as result;
select (result->>'id')::uuid as loan_multi_id from t_loan_multi \gset
select public.rpc_submit_loan_account('a0100000-0000-0000-0000-000000000001', :'loan_multi_id'::uuid);
select public.rpc_approve_loan_account('a0100000-0000-0000-0000-000000000001', :'loan_multi_id'::uuid);
select public.rpc_disburse_loan_account('a0100000-0000-0000-0000-000000000001', :'loan_multi_id'::uuid, :'account_id'::uuid, '2026-04-15'::date);

select coalesce(sum(total_due), 0) as full_payoff_amount
from public.loan_installments where loan_account_id = :'loan_multi_id'::uuid \gset

create temporary table t_payment_multi as
select public.rpc_post_payment('a0100000-0000-0000-0000-000000000001', 'a0200000-0000-0000-0000-000000000011'::uuid, :'account_id'::uuid, :'full_payoff_amount'::numeric, '2026-05-15'::date, 'CASH') as result;
select (result->>'payment_id')::uuid as payment_multi_id from t_payment_multi \gset

-- Derive the expected component sum from the payment's OWN allocation
-- rows (the same source the statement RPC itself aggregates from),
-- rather than assuming the whole full_payoff_amount was necessarily
-- applied as principal+interest (e.g. an overpayment above what the
-- servicing rules currently accept as due may be handled differently).
select coalesce(sum(pa.amount) filter (
    where pa.allocation_target_type in ('LOAN_PRINCIPAL', 'LOAN_PRINCIPAL_PREPAYMENT', 'LOAN_RECOVERY_PRINCIPAL')
  ), 0)
  + coalesce(sum(pa.amount) filter (
    where pa.allocation_target_type in ('LOAN_INTEREST', 'LOAN_RECOVERY_INTEREST')
  ), 0) as expected_components_multi
from public.payment_allocations pa
where pa.payment_id = :'payment_multi_id'::uuid and pa.loan_account_id = :'loan_multi_id'::uuid \gset

create temporary table t_stmt_multi as
select public.rpc_get_loan_statement('a0100000-0000-0000-0000-000000000001', :'loan_multi_id'::uuid) as result;

select is(
  (select count(*)::integer from t_stmt_multi, jsonb_array_elements(result->'timeline') e where e->>'event_type' = 'PAYMENT_POSTED'),
  1,
  '30a: a single payment spanning both installments appears exactly once in the timeline, never fragmented per installment'
);
select is(
  (select ((e->'components'->>'principal')::numeric + (e->'components'->>'interest')::numeric)
   from t_stmt_multi, jsonb_array_elements(result->'timeline') e where e->>'event_type' = 'PAYMENT_POSTED'),
  :'expected_components_multi'::numeric,
  '30b: the single payment event''s aggregated components sum to exactly its own actual principal+interest allocations, matching payment_allocations'
);

-- =====================================================================
-- Section O: read-only / accounting-safety assertions
-- =====================================================================

reset role;
select count(*)::integer as payments_before from public.payments \gset
select count(*)::integer as allocations_before from public.payment_allocations \gset
select count(*)::integer as installments_before from public.loan_installments \gset
select count(*)::integer as penalty_charges_before from public.loan_penalty_charges \gset
select count(*)::integer as adjustments_before from public.loan_obligation_adjustments \gset
select count(*)::integer as write_off_events_before from public.loan_write_off_events \gset
select count(*)::integer as recovery_events_before from public.loan_recovery_events \gset
select count(*)::integer as account_events_before from public.loan_account_events \gset
select count(*)::integer as fa_entries_before from public.financial_account_entries \gset
select count(*)::integer as wallet_entries_before from public.member_wallet_entries \gset
set local role authenticated;
set local request.jwt.claim.sub to 'a0000000-0000-0000-0000-000000000001';

create temporary table t_stmt_o1 as
select public.rpc_get_loan_statement('a0100000-0000-0000-0000-000000000001', :'loan_id'::uuid) as result;
create temporary table t_stmt_o2 as
select public.rpc_get_loan_statement('a0100000-0000-0000-0000-000000000001', :'loan_id'::uuid) as result;
create temporary table t_stmt_o3 as
select public.rpc_get_loan_statement('a0100000-0000-0000-0000-000000000001', :'loan_id'::uuid) as result;

select ok(
  (select result from t_stmt_o1) = (select result from t_stmt_o2)
  and (select result from t_stmt_o2) = (select result from t_stmt_o3),
  'O1: three consecutive calls to rpc_get_loan_statement return byte-for-byte identical results'
);

reset role;
select is((select count(*)::integer from public.payments), :payments_before, 'O2: payments row count unchanged after reading the statement');
select is((select count(*)::integer from public.payment_allocations), :allocations_before, 'O3: payment_allocations row count unchanged after reading the statement');
select is((select count(*)::integer from public.loan_installments), :installments_before, 'O4: loan_installments row count unchanged after reading the statement');
select is((select count(*)::integer from public.loan_penalty_charges), :penalty_charges_before, 'O5: loan_penalty_charges row count unchanged after reading the statement');
select is((select count(*)::integer from public.loan_obligation_adjustments), :adjustments_before, 'O6: loan_obligation_adjustments row count unchanged after reading the statement');
select is((select count(*)::integer from public.loan_write_off_events), :write_off_events_before, 'O7: loan_write_off_events row count unchanged after reading the statement');
select is((select count(*)::integer from public.loan_recovery_events), :recovery_events_before, 'O8: loan_recovery_events row count unchanged after reading the statement');
select is((select count(*)::integer from public.loan_account_events), :account_events_before, 'O9: loan_account_events row count unchanged after reading the statement');
select is((select count(*)::integer from public.financial_account_entries), :fa_entries_before, 'O10: financial_account_entries row count unchanged after reading the statement (no phantom cashbook entries)');
select is((select count(*)::integer from public.member_wallet_entries), :wallet_entries_before, 'O11: member_wallet_entries row count unchanged after reading the statement');

select ok(
  (select provolatile = 's' from pg_proc where proname = 'rpc_get_loan_statement' and pronamespace = 'public'::regnamespace),
  'O12: rpc_get_loan_statement is declared STABLE (structural read-only guarantee)'
);
set local role authenticated;
set local request.jwt.claim.sub to 'a0000000-0000-0000-0000-000000000001';

-- =====================================================================
-- Section P (continued): authorization / tenant isolation / grants
-- =====================================================================

-- P2: authenticated without loan.view is rejected.
set local request.jwt.claim.sub to 'a0000000-0000-0000-0000-000000000002';
select throws_ok(
  format($sql$ select public.rpc_get_loan_statement('a0100000-0000-0000-0000-000000000001', %L::uuid) $sql$, :'loan_id'),
  '42501',
  'Not authorized to view loans in this group',
  'P2: MEMBER (no loan.view) is rejected from reading the statement'
);
select throws_ok(
  format($sql$ select public.rpc_get_loan_account('a0100000-0000-0000-0000-000000000001', %L::uuid) $sql$, :'loan_id'),
  '42501',
  'Not authorized to view loans in this group',
  'H2: MEMBER (no loan.view) is rejected from rpc_get_loan_account'
);

-- P3/24: the correct group is accepted.
set local request.jwt.claim.sub to 'a0000000-0000-0000-0000-000000000001';
select ok(
  (select result->'header'->>'loan_account_id' from (
    select public.rpc_get_loan_statement('a0100000-0000-0000-0000-000000000001', :'loan_id'::uuid) as result
  ) t) = :'loan_id'::text,
  'P3/24a: the loan''s own group is accepted and returns its own header'
);

-- P4/24: cross-group / tenant isolation — a different group's real
-- loan id is rejected exactly like a not-found, never leaking data.
select throws_ok(
  format($sql$ select public.rpc_get_loan_statement('a0100000-0000-0000-0000-000000000002', %L::uuid) $sql$, :'loan_id'),
  '22023',
  'Loan account not found in group',
  'P4/24b: cross-group statement read against another group''s real loan is rejected'
);
select throws_ok(
  format($sql$ select public.rpc_get_loan_account('a0100000-0000-0000-0000-000000000002', %L::uuid) $sql$, :'loan_id'),
  '22023',
  'Loan account not found in group',
  'H3: cross-group rpc_get_loan_account read against another group''s real loan is rejected'
);

-- P5: no anon EXECUTE grant on rpc_get_loan_statement.
reset role;
select is(
  (select count(*)::integer from information_schema.routine_privileges
   where routine_schema = 'public' and routine_name = 'rpc_get_loan_statement' and grantee = 'anon'),
  0,
  'P5: no anon EXECUTE grant exists on rpc_get_loan_statement'
);

-- P6: neither internal helper is callable by anon/authenticated/public.
select is(
  (select count(*)::integer from information_schema.routine_privileges
   where routine_schema = 'public'
     and routine_name in ('loan_statement_schedule_position', 'loan_write_off_recovery_state')
     and grantee in ('anon', 'authenticated', 'public')),
  0,
  'P6: zero EXECUTE grants to anon/authenticated/public exist on either new internal helper'
);

select * from finish();
rollback;
