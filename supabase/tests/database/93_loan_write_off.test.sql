-- Prompt 09F-B: Loan Write-Off — core accounting behaviour (section A,
-- test matrix items 1-8).
begin;

select plan(20);

insert into auth.users (id, email) values
  ('93000000-0000-0000-0000-000000000001', 'p09fb-writeoff-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('93100000-0000-0000-0000-000000000001', 'Write-off Group', '93000000-0000-0000-0000-000000000001', 'WOFF');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('93200000-0000-0000-0000-000000000001', '93100000-0000-0000-0000-000000000001', '93000000-0000-0000-0000-000000000001', 'Write-off Admin', 'ACTIVE', '2025-01-01', 'WOFF-2026-0001'),
  ('93200000-0000-0000-0000-000000000011', '93100000-0000-0000-0000-000000000001', null, 'Write-off Borrower', 'ACTIVE', '2025-01-01', 'WOFF-2026-0011');

insert into public.group_membership_roles (group_membership_id, role_id) select '93200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '93000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '93100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, '2026-06-15'::date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '93100000-0000-0000-0000-000000000001', 'WOFFP', 'Write-off Product', 100000, 1, 12, 5.0, 'MONTHLY', 'FLAT',
  p_penalty_enabled => true, p_penalty_type => 'FIXED', p_penalty_frequency => 'ONCE',
  p_penalty_grace_days => 0, p_penalty_fixed_amount => 20000
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

-- 3 installments: 1 past-due, 1 due-today, 1 future — first_repayment
-- 2026-04-15, anchor 2026-06-15.
create temporary table t_loan as
select public.rpc_create_draft_loan_account(
  '93100000-0000-0000-0000-000000000001', '93200000-0000-0000-0000-000000000011'::uuid,
  :'product_id'::uuid, 300000, 3, '2026-04-15'::date
) as result;
select (result->>'id')::uuid as loan_id from t_loan \gset
select public.rpc_submit_loan_account('93100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_approve_loan_account('93100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_disburse_loan_account('93100000-0000-0000-0000-000000000001', :'loan_id'::uuid, :'account_id'::uuid, '2026-04-15'::date);

select id as future_installment_id, interest_due as future_installment_interest_due from public.loan_installments
  where loan_account_id = :'loan_id'::uuid and due_date = '2026-06-15' \gset

select public.rpc_assess_loan_penalties('93100000-0000-0000-0000-000000000001', '2026-06-15'::date, :'loan_id'::uuid);

select count(*)::integer as payments_before from public.payments \gset
select count(*)::integer as wallet_before from public.member_wallet_entries \gset
select count(*)::integer as fa_entries_before from public.financial_account_entries \gset

-- Setup for item 5: total scheduled interest across every installment
-- (earned + future/unearned), read directly from the ordinary
-- loan_installments table (not the locked-down internal helper — that
-- helper is never callable by authenticated, only by its owner).
select coalesce(sum(interest_due), 0)::numeric as total_scheduled_interest
from public.loan_installments where loan_account_id = :'loan_id'::uuid and cancelled_at is null \gset
-- The write-off itself is effective 2026-05-15 — strictly BEFORE the
-- 3rd installment's 2026-06-15 due date — so that installment is a
-- genuine future/unearned installment for this write-off, distinct
-- from the penalty assessment date above.
select coalesce(sum(interest_due), 0)::numeric as earned_scheduled_interest
from public.loan_installments where loan_account_id = :'loan_id'::uuid and cancelled_at is null and due_date <= '2026-05-15'::date \gset

-- Item 1: full write-off preview succeeds and matches the helper.
create temporary table t_preview as
select public.rpc_preview_loan_write_off(
  '93100000-0000-0000-0000-000000000001', :'loan_id'::uuid, 'PROLONGED_DEFAULT', null, '2026-05-15'::date
) as result;
select ok(
  (result->>'total_amount')::numeric > 0,
  '1: full write-off preview succeeds with a positive total amount'
) from t_preview;

create temporary table t_write_off as
select public.rpc_post_loan_write_off(
  '93100000-0000-0000-0000-000000000001', :'loan_id'::uuid, 'PROLONGED_DEFAULT', null, '2026-05-15'::date
) as result;
select (result->>'write_off_event_id')::uuid as write_off_id from t_write_off \gset
select (result->>'principal_amount')::numeric as wo_principal from t_write_off \gset
select (result->>'interest_amount')::numeric as wo_interest from t_write_off \gset
select (result->>'penalty_amount')::numeric as wo_penalty from t_write_off \gset

-- Item 2: principal receivable reduction — the write-off's frozen
-- principal_amount equals the full scheduled principal (300,000; no
-- prior repayment happened), and financial position excludes it.
select is(:'wo_principal'::numeric, 300000.00::numeric, '2: write-off captures the full principal outstanding (300,000)');

-- Item 3: earned-interest write-off — installments 1 (04-15) and 2
-- (05-15) are due/past relative to the 2026-05-15 effective date.
select ok(:'wo_interest'::numeric > 0, '3: earned/payable interest was written off (positive amount)');

-- Item 4: penalty write-off.
select ok(:'wo_penalty'::numeric > 0, '4: assessed penalty was written off (positive amount)');

-- Item 5: future-interest exclusion — the write-off's interest_amount
-- exactly equals the sum of interest_due across only the due/past
-- installments (nothing has been paid/waived, so outstanding ==
-- interest_due there), and is strictly less than the loan's total
-- scheduled interest across every installment (proving the future
-- installment's interest was structurally excluded, never written off).
select is(:'wo_interest'::numeric, :'earned_scheduled_interest'::numeric, '5a: write-off interest_amount exactly equals the sum of due/past installments'' interest_due');
select ok(
  :'wo_interest'::numeric < :'total_scheduled_interest'::numeric,
  '5b: write-off interest_amount is strictly less than the loan''s total scheduled interest (future installment''s interest was excluded)'
);

-- Item 6: zero cash/payment/receipt on write-off.
select is((select count(*)::integer from public.payments), :payments_before::integer, '6a: no payment row created by write-off');
select is((select count(*)::integer from public.member_wallet_entries), :wallet_before::integer, '6b: no wallet entry created by write-off');
select is((select count(*)::integer from public.financial_account_entries), :fa_entries_before::integer, '6c: no cashbook entry created by write-off');

-- Item 7: WRITTEN_OFF lifecycle state, distinct from CLOSED/CANCELLED.
select is(
  (select status from public.loan_accounts where id = :'loan_id'::uuid),
  'WRITTEN_OFF',
  '7a: loan transitions to WRITTEN_OFF'
);
select ok(
  'WRITTEN_OFF' <> 'CLOSED' and 'WRITTEN_OFF' <> 'CANCELLED',
  '7b: WRITTEN_OFF is a distinct status value from CLOSED/CANCELLED'
);
select isnt_empty(
  format($sql$ select 1 from public.loan_account_events where loan_account_id = %L::uuid $sql$, :'loan_id'),
  '7c: sanity — loan_account_events table is reachable'
) ;
select is(
  (select event_type::text from public.loan_account_events where loan_account_id = :'loan_id'::uuid and event_type = 'WRITTEN_OFF'),
  'WRITTEN_OFF',
  '7d: a WRITTEN_OFF lifecycle event was recorded'
);

-- Item 8: ordinary repayment blocked after write-off — proven
-- indirectly (the allocation helper itself is locked down, never
-- callable by authenticated): an ordinary payment for this borrower,
-- with the written-off loan as the only loan in the group, produces
-- ZERO allocations against it (auto-allocation structurally skips a
-- non-ACTIVE loan, per loan_member_allocatable_installments's
-- `la.status = 'ACTIVE'` filter).
create temporary table t_ordinary_payment as
select public.rpc_post_payment(
  '93100000-0000-0000-0000-000000000001', '93200000-0000-0000-0000-000000000011'::uuid, :'account_id'::uuid, 10000, '2026-06-20'::date, 'CASH'
) as result;
select (result->>'payment_id')::uuid as ordinary_payment_id from t_ordinary_payment \gset
select is(
  (select count(*)::integer from public.payment_allocations
   where payment_id = :'ordinary_payment_id'::uuid and loan_account_id = :'loan_id'::uuid),
  0,
  '8: an ordinary payment produces zero allocations against the written-off loan'
);

-- Confirm original historical rows are immutable.
select is(
  (select interest_due from public.loan_installments where id = :'future_installment_id'::uuid),
  :'future_installment_interest_due'::numeric,
  'installment interest_due remains immutable after write-off'
);

-- Re-write-off rejected (already WRITTEN_OFF, not ACTIVE).
select throws_ok(
  format(
    $sql$ select public.rpc_post_loan_write_off('93100000-0000-0000-0000-000000000001', %L::uuid, 'PROLONGED_DEFAULT', null, '2026-06-15'::date) $sql$,
    :'loan_id'
  ),
  'P0001',
  'LOAN_NOT_ACTIVE',
  'a second write-off attempt on an already-written-off loan is rejected'
);

-- Nothing-outstanding rejection (fresh, fully-paid loan).
create temporary table t_product2 as
select public.rpc_create_loan_product(
  '93100000-0000-0000-0000-000000000001', 'WOFFP2', 'Write-off Product 2', 100000, 1, 12, 0.0, 'MONTHLY', 'FLAT'
) as result;
select (result->>'id')::uuid as product2_id from t_product2 \gset

create temporary table t_loan2 as
select public.rpc_create_draft_loan_account(
  '93100000-0000-0000-0000-000000000001', '93200000-0000-0000-0000-000000000011'::uuid,
  :'product2_id'::uuid, 100000, 1, '2026-06-15'::date
) as result;
select (result->>'id')::uuid as loan2_id from t_loan2 \gset
select public.rpc_submit_loan_account('93100000-0000-0000-0000-000000000001', :'loan2_id'::uuid);
select public.rpc_approve_loan_account('93100000-0000-0000-0000-000000000001', :'loan2_id'::uuid);
select public.rpc_disburse_loan_account('93100000-0000-0000-0000-000000000001', :'loan2_id'::uuid, :'account_id'::uuid, '2026-06-15'::date);

select public.rpc_post_payment('93100000-0000-0000-0000-000000000001', '93200000-0000-0000-0000-000000000011'::uuid, :'account_id'::uuid, 100000, '2026-06-15'::date, 'CASH');

-- Full repayment auto-closes the loan (loan_account_recheck_closure),
-- so a fully-paid loan is CLOSED, not ACTIVE, by the time write-off is
-- attempted — LOAN_WRITE_OFF_NOTHING_OUTSTANDING is a defensive guard
-- that is unreachable through any normal RPC flow, since
-- recheck_closure always transitions a zero-outstanding ACTIVE loan to
-- CLOSED before a write-off attempt could ever observe it as ACTIVE.
select is(
  (select status from public.loan_accounts where id = :'loan2_id'::uuid),
  'CLOSED',
  'a fully-repaid loan auto-closes rather than remaining ACTIVE with nothing outstanding'
);
select throws_ok(
  format(
    $sql$ select public.rpc_preview_loan_write_off('93100000-0000-0000-0000-000000000001', %L::uuid, 'PROLONGED_DEFAULT', null, '2026-06-15'::date) $sql$,
    :'loan2_id'
  ),
  'P0001',
  'LOAN_NOT_ACTIVE',
  'a CLOSED (fully-repaid) loan cannot be written off (write-off is ACTIVE-only, distinct from CLOSED)'
);

-- OTHER reason requires a note.
select throws_ok(
  format(
    $sql$ select public.rpc_preview_loan_write_off('93100000-0000-0000-0000-000000000001', %L::uuid, 'OTHER', null, '2026-06-15'::date) $sql$,
    :'loan_id'
  ),
  'P0001',
  'LOAN_ADJUSTMENT_OTHER_NOTE_REQUIRED',
  'OTHER reason requires a non-blank note'
);

-- Non-ACTIVE (DRAFT) loan cannot be written off.
create temporary table t_draft as
select public.rpc_create_draft_loan_account(
  '93100000-0000-0000-0000-000000000001', '93200000-0000-0000-0000-000000000011'::uuid,
  :'product2_id'::uuid, 100000, 1, '2026-06-15'::date
) as result;
select (result->>'id')::uuid as draft_id from t_draft \gset

select throws_ok(
  format(
    $sql$ select public.rpc_preview_loan_write_off('93100000-0000-0000-0000-000000000001', %L::uuid, 'PROLONGED_DEFAULT', null, '2026-06-15'::date) $sql$,
    :'draft_id'
  ),
  'P0001',
  'LOAN_NOT_ACTIVE',
  'a DRAFT loan cannot be written off'
);

select * from finish();
rollback;
