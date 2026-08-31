-- Prompt 08B: reconciliation (U-Y) and financial adjustment (Z-AC).
begin;

select plan(17);

insert into auth.users (id, email) values
  ('fd000000-0000-0000-0000-000000000001', 'p08bra-treasurer@example.com'),
  ('fd000000-0000-0000-0000-000000000002', 'p08bra-chairperson@example.com');

insert into public.groups (id, name, created_by, code) values
  ('fd100000-0000-0000-0000-000000000001', 'P08BRA Group A', 'fd000000-0000-0000-0000-000000000001', 'FDAA'),
  ('fd100000-0000-0000-0000-000000000002', 'P08BRA Group B', 'fd000000-0000-0000-0000-000000000001', 'FDBB');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('fd200000-0000-0000-0000-000000000001', 'fd100000-0000-0000-0000-000000000001', 'fd000000-0000-0000-0000-000000000001', 'FD Treasurer', 'ACTIVE', '2025-01-01', 'FDAA-2026-0001'),
  ('fd200000-0000-0000-0000-000000000002', 'fd100000-0000-0000-0000-000000000001', 'fd000000-0000-0000-0000-000000000002', 'FD Chairperson', 'ACTIVE', '2025-01-01', 'FDAA-2026-0002'),
  ('fd200000-0000-0000-0000-000000000098', 'fd100000-0000-0000-0000-000000000002', 'fd000000-0000-0000-0000-000000000001', 'FD Group B Treasurer', 'ACTIVE', '2025-01-01', 'FDBB-2026-0001');

insert into public.group_membership_roles (group_membership_id, role_id) select 'fd200000-0000-0000-0000-000000000001', id from public.roles where code = 'TREASURER';
insert into public.group_membership_roles (group_membership_id, role_id) select 'fd200000-0000-0000-0000-000000000002', id from public.roles where code = 'CHAIRPERSON';
insert into public.group_membership_roles (group_membership_id, role_id) select 'fd200000-0000-0000-0000-000000000098', id from public.roles where code = 'TREASURER';

set local role authenticated;
set local request.jwt.claim.sub to 'fd000000-0000-0000-0000-000000000001';

create temporary table t_acct as
select public.rpc_create_financial_account('fd100000-0000-0000-0000-000000000001', 'Main Cash', 'CASH', 50000, '2026-01-01') as result;
select (result->>'id')::uuid as account_id from t_acct \gset

-- ---------------------------------------------------------------------
-- U/V. system balance derived correctly, difference derived correctly.
-- ---------------------------------------------------------------------

create temporary table t_recon as
select public.rpc_create_financial_reconciliation(
  'fd100000-0000-0000-0000-000000000001', :'account_id'::uuid, 48500, '2026-02-01', null, 'month-end cash count'
) as result;
select (result->>'id')::uuid as recon_id from t_recon \gset

select is(
  (select (result->>'system_balance')::numeric from t_recon),
  50000.00::numeric,
  'U: system_balance is the authoritative derived account balance at reconciliation time'
);
select is(
  (select (result->>'stated_balance')::numeric from t_recon),
  48500.00::numeric,
  'U: stated_balance is exactly the entered statement/count figure'
);
select is(
  (select (result->>'difference')::numeric from t_recon),
  -1500.00::numeric,
  'V: difference = stated_balance - system_balance (48500 - 50000 = -1500)'
);

-- ---------------------------------------------------------------------
-- W. reconciliation creates no cashbook entry.
-- ---------------------------------------------------------------------

select is(
  (select count(*)::int from public.financial_account_entries where financial_account_id = :'account_id'::uuid),
  1,
  'W: only the opening-balance entry exists — creating a reconciliation posted zero cashbook rows'
);

-- ---------------------------------------------------------------------
-- X. completed reconciliation immutable — no direct client UPDATE
-- grant, and the only allowed RPC-driven mutation (cancel) can only
-- ever happen once.
-- ---------------------------------------------------------------------

select throws_ok(
  $sql$ update public.financial_reconciliations set stated_balance = 0 where id = (select id from public.financial_reconciliations limit 1) $sql$,
  '42501', null,
  'X: no direct client UPDATE grant exists on financial_reconciliations'
);

select public.rpc_cancel_financial_reconciliation('fd100000-0000-0000-0000-000000000001', :'recon_id'::uuid, 'entered wrong count, redoing');

select is(
  (select status::text from public.financial_reconciliations where id = :'recon_id'::uuid),
  'CANCELLED',
  'X: cancelling flips status to CANCELLED'
);
select is(
  (select stated_balance from public.financial_reconciliations where id = :'recon_id'::uuid),
  48500.00::numeric,
  'X: the original stated_balance evidence is preserved after cancellation, never overwritten'
);

select throws_ok(
  format(
    $sql$ select public.rpc_cancel_financial_reconciliation('fd100000-0000-0000-0000-000000000001', %L, 'cancel again') $sql$,
    :'recon_id'
  ),
  'P0001', 'FINANCIAL_RECONCILIATION_ALREADY_CANCELLED',
  'X: cancelling an already-cancelled reconciliation is rejected — only one status transition ever happens'
);

-- ---------------------------------------------------------------------
-- Y. cross-group reconciliation denied.
-- ---------------------------------------------------------------------

select throws_ok(
  $sql$ select public.rpc_create_financial_reconciliation(
    'fd100000-0000-0000-0000-000000000002',
    (select id from public.financial_accounts where group_id = 'fd100000-0000-0000-0000-000000000001' and name = 'Main Cash'),
    100, '2026-02-01'
  ) $sql$,
  '22023', null,
  'Y: creating a reconciliation against another group''s account (while operating under a different real group id) is denied'
);

-- ---------------------------------------------------------------------
-- Z. adjustment changes account balance once.
-- ---------------------------------------------------------------------

create temporary table t_adj as
select public.rpc_record_financial_adjustment(
  'fd100000-0000-0000-0000-000000000001', :'account_id'::uuid, 'DECREASE', 1500, 'verified cash shortage', '2026-02-02'
) as result;
select (result->>'adjustment_id')::uuid as adj_id from t_adj \gset

select is(
  (select (public.rpc_get_financial_account('fd100000-0000-0000-0000-000000000001', :'account_id'::uuid)->>'balance')::numeric),
  48500.00::numeric,
  'Z: the DECREASE adjustment changes the account balance exactly once (50000 - 1500 = 48500)'
);
select is(
  (select count(*)::int from public.financial_account_entries where source_type = 'FINANCIAL_ADJUSTMENT' and source_id = :'adj_id'::uuid),
  1,
  'Z: the adjustment posts exactly one cashbook entry'
);

-- ---------------------------------------------------------------------
-- AA. adjustment excluded from ordinary income/expense.
-- ---------------------------------------------------------------------

create temporary table t_position as
select public.rpc_get_financial_position('fd100000-0000-0000-0000-000000000001', null, null) as result;

select is(
  (select (result->>'expenses')::numeric from t_position),
  0.00::numeric,
  'AA: a financial adjustment is never counted as an ordinary expense'
);
select is(
  (select (result->>'group_income')::numeric from t_position),
  0.00::numeric,
  'AA: a financial adjustment is never counted as ordinary group income'
);

-- ---------------------------------------------------------------------
-- AB. adjustment audited.
-- ---------------------------------------------------------------------

select is(
  (select reason from public.financial_adjustments where id = :'adj_id'::uuid),
  'verified cash shortage',
  'AB: the adjustment records its reason'
);
select isnt(
  (select created_by from public.financial_adjustments where id = :'adj_id'::uuid),
  null,
  'AB: the adjustment records its actor (created_by)'
);

-- ---------------------------------------------------------------------
-- AC. adjustment idempotency.
-- ---------------------------------------------------------------------

create temporary table t_adj_idem_a as
select public.rpc_record_financial_adjustment(
  'fd100000-0000-0000-0000-000000000001', :'account_id'::uuid, 'INCREASE', 200, 'found extra cash', '2026-02-03', null, 'adj-key-1'
) as result;
create temporary table t_adj_idem_b as
select public.rpc_record_financial_adjustment(
  'fd100000-0000-0000-0000-000000000001', :'account_id'::uuid, 'INCREASE', 200, 'found extra cash', '2026-02-03', null, 'adj-key-1'
) as result;

select is(
  (select result->>'adjustment_id' from t_adj_idem_a),
  (select result->>'adjustment_id' from t_adj_idem_b),
  'AC: a retried identical adjustment payload with the same idempotency key returns the original, never posting twice'
);
select is(
  (select count(*)::int from public.financial_adjustments where idempotency_key = 'adj-key-1'),
  1,
  'AC: exactly one financial_adjustments row exists for the reused key'
);

select * from finish();
rollback;
