-- Financial Accounts + Cashbook foundation (Prompt 08A) — account
-- lifecycle, opening balance, server-derived balance, transfers,
-- idempotency, permission matrix, and group isolation.
begin;

select plan(44);

insert into auth.users (id, email) values
  ('d1000000-0000-0000-0000-000000000001', 'fa08a-admin@example.com'),
  ('d1000000-0000-0000-0000-000000000002', 'fa08a-treasurer@example.com'),
  ('d1000000-0000-0000-0000-000000000003', 'fa08a-chairperson@example.com'),
  ('d1000000-0000-0000-0000-000000000004', 'fa08a-secretary@example.com'),
  ('d1000000-0000-0000-0000-000000000005', 'fa08a-member@example.com'),
  ('d1000000-0000-0000-0000-000000000006', 'fa08a-groupb-treasurer@example.com');

insert into public.groups (id, name, created_by, code) values
  ('d1100000-0000-0000-0000-000000000001', 'FA Group A', 'd1000000-0000-0000-0000-000000000001', 'D08AA'),
  ('d1100000-0000-0000-0000-000000000002', 'FA Group B', 'd1000000-0000-0000-0000-000000000006', 'D08AB');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('d1200000-0000-0000-0000-000000000001', 'd1100000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000001', 'D08A Admin', 'ACTIVE', '2025-01-01', 'D08AA-2026-0001'),
  ('d1200000-0000-0000-0000-000000000002', 'd1100000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000002', 'D08A Treasurer', 'ACTIVE', '2025-01-01', 'D08AA-2026-0002'),
  ('d1200000-0000-0000-0000-000000000003', 'd1100000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000003', 'D08A Chairperson', 'ACTIVE', '2025-01-01', 'D08AA-2026-0003'),
  ('d1200000-0000-0000-0000-000000000004', 'd1100000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000004', 'D08A Secretary', 'ACTIVE', '2025-01-01', 'D08AA-2026-0004'),
  ('d1200000-0000-0000-0000-000000000005', 'd1100000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000005', 'D08A Member', 'ACTIVE', '2025-01-01', 'D08AA-2026-0005'),
  ('d1200000-0000-0000-0000-000000000099', 'd1100000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000006', 'D08A GroupB Treasurer', 'ACTIVE', '2025-01-01', 'D08AB-2026-0001');

insert into public.group_membership_roles (group_membership_id, role_id) select 'd1200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select 'd1200000-0000-0000-0000-000000000002', id from public.roles where code = 'TREASURER';
insert into public.group_membership_roles (group_membership_id, role_id) select 'd1200000-0000-0000-0000-000000000003', id from public.roles where code = 'CHAIRPERSON';
insert into public.group_membership_roles (group_membership_id, role_id) select 'd1200000-0000-0000-0000-000000000004', id from public.roles where code = 'SECRETARY';
insert into public.group_membership_roles (group_membership_id, role_id) select 'd1200000-0000-0000-0000-000000000005', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id) select 'd1200000-0000-0000-0000-000000000099', id from public.roles where code = 'TREASURER';

set local role authenticated;
set local request.jwt.claim.sub to 'd1000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- Account creation + opening balance.
-- ---------------------------------------------------------------------

select throws_ok(
  $sql$ select public.rpc_create_financial_account('d1100000-0000-0000-0000-000000000001', '   ', 'CASH') $sql$,
  '22023',
  null,
  'a blank account name is rejected'
);

select throws_ok(
  $sql$ select public.rpc_create_financial_account('d1100000-0000-0000-0000-000000000001', 'Main Cash', 'CASH', -500) $sql$,
  'P0001',
  'FINANCIAL_ACCOUNT_OPENING_BALANCE_MUST_BE_POSITIVE',
  'a negative opening balance is rejected'
);

create temporary table t_main_cash as
select public.rpc_create_financial_account(
  'd1100000-0000-0000-0000-000000000001', 'Main Cash', 'CASH', 50000, '2026-01-01'
) as result;

select is(
  (select (result ->> 'balance')::numeric from t_main_cash),
  50000.00::numeric,
  'the new account''s balance is the opening balance amount'
);

select is(
  (select count(*)::int from public.financial_account_entries
   where financial_account_id = (select (result ->> 'id')::uuid from t_main_cash)),
  1,
  'exactly one INFLOW entry was posted for the opening balance'
);

select is(
  (select entry_type::text from public.financial_account_entries
   where financial_account_id = (select (result ->> 'id')::uuid from t_main_cash)),
  'INFLOW',
  'the opening balance entry is an INFLOW'
);

select is(
  (select source_type from public.financial_account_entries
   where financial_account_id = (select (result ->> 'id')::uuid from t_main_cash)),
  'OPENING_BALANCE',
  'the opening balance entry is tagged OPENING_BALANCE'
);

create temporary table t_bank_x as
select public.rpc_create_financial_account(
  'd1100000-0000-0000-0000-000000000001', 'Bank X', 'BANK'
) as result;

select is(
  (select (result ->> 'balance')::numeric from t_bank_x),
  0.00::numeric,
  'an account created with no opening balance starts at zero'
);

select lives_ok(
  $sql$ select public.rpc_create_financial_account('d1100000-0000-0000-0000-000000000001', 'Zero Balance Co', 'CASH', 0) $sql$,
  'a zero opening balance is accepted (simply posts no entry)'
);

select is(
  (select count(*)::int from public.financial_account_entries e
   join public.financial_accounts a on a.id = e.financial_account_id
   where a.name = 'Zero Balance Co'),
  0,
  'a zero opening balance posts no entry at all'
);

select throws_ok(
  $sql$ select public.rpc_create_financial_account('d1100000-0000-0000-0000-000000000001', 'Main Cash', 'CASH') $sql$,
  '23505',
  null,
  'a duplicate account name within the same group is rejected'
);

-- ---------------------------------------------------------------------
-- Read RPCs.
-- ---------------------------------------------------------------------

select is(
  (select (public.rpc_get_financial_account(
    'd1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_main_cash)
  ) ->> 'balance')::numeric),
  50000.00::numeric,
  'rpc_get_financial_account returns the correct server-derived balance'
);

select is(
  (select (public.rpc_list_financial_accounts('d1100000-0000-0000-0000-000000000001') ->> 'total_count')::int),
  3,
  'rpc_list_financial_accounts lists all 3 accounts created so far'
);

select is(
  (select jsonb_array_length(public.rpc_list_financial_accounts(
    'd1100000-0000-0000-0000-000000000001', null, 'Main'
  ) -> 'items')),
  1,
  'rpc_list_financial_accounts search filters by name'
);

-- ---------------------------------------------------------------------
-- rpc_update_financial_account.
-- ---------------------------------------------------------------------

select is(
  (select (public.rpc_update_financial_account(
    'd1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_bank_x), 'Bank X Renamed'
  ) ->> 'name')),
  'Bank X Renamed',
  'rpc_update_financial_account renames the account'
);

select is(
  (select (public.rpc_update_financial_account(
    'd1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_bank_x), null, false
  ) ->> 'is_active')::boolean),
  false,
  'rpc_update_financial_account deactivates the account'
);

select public.rpc_update_financial_account(
  'd1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_bank_x), null, true
) from t_bank_x;

-- ---------------------------------------------------------------------
-- Transfers.
-- ---------------------------------------------------------------------

select throws_ok(
  format(
    $sql$ select public.rpc_record_financial_account_transfer('d1100000-0000-0000-0000-000000000001', %L, %L, 1000) $sql$,
    (select (result ->> 'id')::text from t_main_cash),
    (select (result ->> 'id')::text from t_main_cash)
  ),
  'P0001',
  'FINANCIAL_ACCOUNT_TRANSFER_SAME_ACCOUNT',
  'transferring an account to itself is rejected'
);

select throws_ok(
  format(
    $sql$ select public.rpc_record_financial_account_transfer('d1100000-0000-0000-0000-000000000001', %L, %L, 0) $sql$,
    (select (result ->> 'id')::text from t_main_cash),
    (select (result ->> 'id')::text from t_bank_x)
  ),
  '22023',
  'FINANCIAL_ACCOUNT_TRANSFER_AMOUNT_MUST_BE_POSITIVE',
  'a zero transfer amount is rejected'
);

select throws_ok(
  format(
    $sql$ select public.rpc_record_financial_account_transfer('d1100000-0000-0000-0000-000000000001', %L, %L, 999999) $sql$,
    (select (result ->> 'id')::text from t_main_cash),
    (select (result ->> 'id')::text from t_bank_x)
  ),
  'P0001',
  'FINANCIAL_ACCOUNT_INSUFFICIENT_BALANCE',
  'a transfer exceeding the source account''s balance is rejected'
);

create temporary table t_transfer_1 as
select public.rpc_record_financial_account_transfer(
  'd1100000-0000-0000-0000-000000000001',
  (select (result ->> 'id')::uuid from t_main_cash),
  (select (result ->> 'id')::uuid from t_bank_x),
  20000
) as result;

select is(
  (select (result ->> 'from_balance')::numeric from t_transfer_1),
  30000.00::numeric,
  'the transfer reduces the source account balance to 30,000'
);

select is(
  (select (result ->> 'to_balance')::numeric from t_transfer_1),
  20000.00::numeric,
  'the transfer increases the destination account balance to 20,000'
);

select is(
  (select count(*)::int from public.financial_account_entries
   where transfer_reference = (select (result ->> 'transfer_reference')::uuid from t_transfer_1)),
  2,
  'the transfer posts exactly 2 linked entries (TRANSFER_OUT + TRANSFER_IN)'
);

select is(
  (select count(*)::int from public.financial_account_entries
   where transfer_reference = (select (result ->> 'transfer_reference')::uuid from t_transfer_1)
     and entry_type = 'TRANSFER_OUT'),
  1,
  'one of the pair is TRANSFER_OUT'
);

select is(
  (select count(*)::int from public.financial_account_entries
   where transfer_reference = (select (result ->> 'transfer_reference')::uuid from t_transfer_1)
     and entry_type = 'TRANSFER_IN'),
  1,
  'the other of the pair is TRANSFER_IN'
);

-- Idempotent retry.
create temporary table t_transfer_2 as
select public.rpc_record_financial_account_transfer(
  'd1100000-0000-0000-0000-000000000001',
  (select (result ->> 'id')::uuid from t_main_cash),
  (select (result ->> 'id')::uuid from t_bank_x),
  5000,
  current_date,
  null,
  null,
  'idem-transfer-1'
) as result
from t_main_cash;

create temporary table t_transfer_2_retry as
select public.rpc_record_financial_account_transfer(
  'd1100000-0000-0000-0000-000000000001',
  (select (result ->> 'id')::uuid from t_main_cash),
  (select (result ->> 'id')::uuid from t_bank_x),
  5000,
  current_date,
  null,
  null,
  'idem-transfer-1'
) as result
from t_main_cash;

select is(
  (select result ->> 'already_posted' from t_transfer_2_retry),
  'true',
  'retrying the same transfer idempotency key reports already_posted'
);

select is(
  (select count(*)::int from public.financial_account_entries
   where idempotency_key = 'idem-transfer-1'),
  2,
  'the retried idempotent transfer still has exactly 2 entries total (no duplicate pair)'
);

-- Inactive account cannot transfer.
select public.rpc_update_financial_account(
  'd1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_bank_x), null, false
) from t_bank_x;

select throws_ok(
  format(
    $sql$ select public.rpc_record_financial_account_transfer('d1100000-0000-0000-0000-000000000001', %L, %L, 1000) $sql$,
    (select (result ->> 'id')::text from t_main_cash),
    (select (result ->> 'id')::text from t_bank_x)
  ),
  'P0001',
  'FINANCIAL_ACCOUNT_INACTIVE',
  'transferring into an inactive account is rejected'
);

select public.rpc_update_financial_account(
  'd1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_bank_x), null, true
) from t_bank_x;

-- ---------------------------------------------------------------------
-- Entries listing.
-- ---------------------------------------------------------------------

select is(
  (select (public.rpc_list_financial_account_entries(
    'd1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_main_cash)
  ) ->> 'total_count')::int),
  3,
  'Main Cash has 3 entries: opening INFLOW + 2 TRANSFER_OUT'
);

-- UAT-FIX-03: every TRANSFER_OUT/TRANSFER_IN entry must resolve its
-- paired counterparty account; every non-transfer entry must not.
create temporary table t_main_cash_entries as
select public.rpc_list_financial_account_entries(
  'd1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_main_cash)
) as result
from t_main_cash;

select is(
  (select count(*)::int from jsonb_array_elements(
    (select result -> 'items' from t_main_cash_entries)
  ) e
  where e ->> 'entry_type' = 'TRANSFER_OUT'
    and e ->> 'counterparty_account_name' = 'Bank X Renamed'
    and (e ->> 'counterparty_account_id') = (select (result ->> 'id')::text from t_bank_x)),
  2,
  'both of Main Cash''s TRANSFER_OUT entries resolve Bank X Renamed as the counterparty (id and name)'
);

select is(
  (select e ->> 'counterparty_account_id' from jsonb_array_elements(
    (select result -> 'items' from t_main_cash_entries)
  ) e
  where e ->> 'entry_type' = 'INFLOW'),
  null::text,
  'the opening balance INFLOW entry has a null counterparty_account_id — never fabricated'
);

select is(
  (select e ->> 'counterparty_account_name' from jsonb_array_elements(
    (select result -> 'items' from t_main_cash_entries)
  ) e
  where e ->> 'entry_type' = 'INFLOW'),
  null::text,
  'the opening balance INFLOW entry has a null counterparty_account_name — never fabricated'
);

create temporary table t_bank_x_entries as
select public.rpc_list_financial_account_entries(
  'd1100000-0000-0000-0000-000000000001', (select (result ->> 'id')::uuid from t_bank_x)
) as result
from t_bank_x;

select is(
  (select count(*)::int from jsonb_array_elements(
    (select result -> 'items' from t_bank_x_entries)
  ) e
  where e ->> 'entry_type' = 'TRANSFER_IN'
    and e ->> 'counterparty_account_name' = 'Main Cash'
    and (e ->> 'counterparty_account_id') = (select (result ->> 'id')::text from t_main_cash)),
  2,
  'both of Bank X''s TRANSFER_IN entries resolve Main Cash as the counterparty (id and name)'
);

-- Cross-group isolation: Group B cannot see Group A's counterparty
-- context (structurally impossible anyway, since a transfer_reference
-- only ever links two accounts validated into the same group at
-- posting time — verified here for completeness).
set local request.jwt.claim.sub to 'd1000000-0000-0000-0000-000000000006';

select throws_ok(
  format(
    $sql$ select public.rpc_list_financial_account_entries('d1100000-0000-0000-0000-000000000002', %L) $sql$,
    (select (result ->> 'id')::text from t_main_cash)
  ),
  '22023',
  null,
  'Group B cannot list Group A''s financial account entries (counterparty context included)'
);

set local request.jwt.claim.sub to 'd1000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- Permission matrix.
-- ---------------------------------------------------------------------

set local request.jwt.claim.sub to 'd1000000-0000-0000-0000-000000000005';

select throws_ok(
  $sql$ select public.rpc_create_financial_account('d1100000-0000-0000-0000-000000000001', 'Member Attempt', 'CASH') $sql$,
  '42501',
  null,
  'MEMBER cannot create a financial account'
);

select throws_ok(
  format(
    $sql$ select public.rpc_record_financial_account_transfer('d1100000-0000-0000-0000-000000000001', %L, %L, 100) $sql$,
    (select (result ->> 'id')::text from t_main_cash),
    (select (result ->> 'id')::text from t_bank_x)
  ),
  '42501',
  null,
  'MEMBER cannot record a financial account transfer'
);

select throws_ok(
  $sql$ select public.rpc_list_financial_accounts('d1100000-0000-0000-0000-000000000001') $sql$,
  '42501',
  null,
  'MEMBER cannot view financial accounts (no financial_account.view permission)'
);

set local request.jwt.claim.sub to 'd1000000-0000-0000-0000-000000000003';

select lives_ok(
  $sql$ select public.rpc_list_financial_accounts('d1100000-0000-0000-0000-000000000001') $sql$,
  'CHAIRPERSON can view financial accounts'
);

select throws_ok(
  $sql$ select public.rpc_create_financial_account('d1100000-0000-0000-0000-000000000001', 'Chair Attempt', 'CASH') $sql$,
  '42501',
  null,
  'CHAIRPERSON cannot create a financial account (view-only)'
);

select throws_ok(
  format(
    $sql$ select public.rpc_record_financial_account_transfer('d1100000-0000-0000-0000-000000000001', %L, %L, 100) $sql$,
    (select (result ->> 'id')::text from t_main_cash),
    (select (result ->> 'id')::text from t_bank_x)
  ),
  '42501',
  null,
  'CHAIRPERSON cannot record a financial account transfer (view-only)'
);

set local request.jwt.claim.sub to 'd1000000-0000-0000-0000-000000000004';

select lives_ok(
  $sql$ select public.rpc_list_financial_accounts('d1100000-0000-0000-0000-000000000001') $sql$,
  'SECRETARY can view financial accounts'
);

select throws_ok(
  $sql$ select public.rpc_create_financial_account('d1100000-0000-0000-0000-000000000001', 'Secretary Attempt', 'CASH') $sql$,
  '42501',
  null,
  'SECRETARY cannot create a financial account (view-only)'
);

-- ---------------------------------------------------------------------
-- Cross-group isolation.
-- ---------------------------------------------------------------------

set local request.jwt.claim.sub to 'd1000000-0000-0000-0000-000000000006';

select throws_ok(
  format(
    $sql$ select public.rpc_get_financial_account('d1100000-0000-0000-0000-000000000002', %L) $sql$,
    (select (result ->> 'id')::text from t_main_cash)
  ),
  '22023',
  null,
  'Group B cannot read Group A''s financial account'
);

select throws_ok(
  format(
    $sql$ select public.rpc_update_financial_account('d1100000-0000-0000-0000-000000000002', %L, 'Hijacked') $sql$,
    (select (result ->> 'id')::text from t_main_cash)
  ),
  '22023',
  null,
  'Group B cannot rename Group A''s financial account'
);

select throws_ok(
  format(
    $sql$ select public.rpc_record_financial_account_transfer('d1100000-0000-0000-0000-000000000002', %L, %L, 100) $sql$,
    (select (result ->> 'id')::text from t_main_cash),
    (select (result ->> 'id')::text from t_bank_x)
  ),
  '22023',
  null,
  'Group B cannot transfer using Group A''s financial accounts'
);

set local request.jwt.claim.sub to 'd1000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- Internal helper lockdown (defense in depth, section 44).
-- ---------------------------------------------------------------------

select throws_ok(
  format(
    $sql$ select public.financial_account_balance(%L) $sql$,
    (select (result ->> 'id')::text from t_main_cash)
  ),
  '42501',
  null,
  'financial_account_balance() cannot be called directly by a client — internal helper only'
);

select * from finish();

rollback;
