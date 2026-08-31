-- Prompt 08B: manual group income/expense — items A-J.
begin;

select plan(23);

insert into auth.users (id, email) values
  ('fb000000-0000-0000-0000-000000000001', 'p08b-treasurer@example.com'),
  ('fb000000-0000-0000-0000-000000000002', 'p08b-chairperson@example.com'),
  ('fb000000-0000-0000-0000-000000000003', 'p08b-member@example.com');

insert into public.groups (id, name, created_by, code) values
  ('fb100000-0000-0000-0000-000000000001', 'P08B Group A', 'fb000000-0000-0000-0000-000000000001', 'FBAA'),
  ('fb100000-0000-0000-0000-000000000002', 'P08B Group B', 'fb000000-0000-0000-0000-000000000001', 'FBBB');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('fb200000-0000-0000-0000-000000000001', 'fb100000-0000-0000-0000-000000000001', 'fb000000-0000-0000-0000-000000000001', 'FB Treasurer', 'ACTIVE', '2025-01-01', 'FBAA-2026-0001'),
  ('fb200000-0000-0000-0000-000000000002', 'fb100000-0000-0000-0000-000000000001', 'fb000000-0000-0000-0000-000000000002', 'FB Chairperson', 'ACTIVE', '2025-01-01', 'FBAA-2026-0002'),
  ('fb200000-0000-0000-0000-000000000003', 'fb100000-0000-0000-0000-000000000001', 'fb000000-0000-0000-0000-000000000003', 'FB Member', 'ACTIVE', '2025-01-01', 'FBAA-2026-0003'),
  ('fb200000-0000-0000-0000-000000000098', 'fb100000-0000-0000-0000-000000000002', 'fb000000-0000-0000-0000-000000000001', 'FB Group B Treasurer', 'ACTIVE', '2025-01-01', 'FBBB-2026-0001');

insert into public.group_membership_roles (group_membership_id, role_id) select 'fb200000-0000-0000-0000-000000000001', id from public.roles where code = 'TREASURER';
insert into public.group_membership_roles (group_membership_id, role_id) select 'fb200000-0000-0000-0000-000000000002', id from public.roles where code = 'CHAIRPERSON';
insert into public.group_membership_roles (group_membership_id, role_id) select 'fb200000-0000-0000-0000-000000000003', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id) select 'fb200000-0000-0000-0000-000000000098', id from public.roles where code = 'TREASURER';

set local role authenticated;
set local request.jwt.claim.sub to 'fb000000-0000-0000-0000-000000000001';

create temporary table t_acct as
select public.rpc_create_financial_account('fb100000-0000-0000-0000-000000000001', 'Main Cash', 'CASH') as result;
select (result->>'id')::uuid as account_id from t_acct \gset

create temporary table t_income_cat as
select public.rpc_create_financial_category('fb100000-0000-0000-0000-000000000001', 'Donation', 'INCOME') as result;
select (result->>'id')::uuid as income_cat_id from t_income_cat \gset

create temporary table t_expense_cat as
select public.rpc_create_financial_category('fb100000-0000-0000-0000-000000000001', 'Transport', 'EXPENSE') as result;
select (result->>'id')::uuid as expense_cat_id from t_expense_cat \gset

-- ---------------------------------------------------------------------
-- A. manual income creates exactly one inflow. Balance after: 20000.
-- ---------------------------------------------------------------------

create temporary table t_income as
select public.rpc_record_manual_income(
  'fb100000-0000-0000-0000-000000000001', :'account_id'::uuid, :'income_cat_id'::uuid, 20000, '2026-07-01', 'donation'
) as result;
select (result->>'entry_id')::uuid as income_entry_id from t_income \gset

select is(
  (select count(*)::int from public.financial_account_entries where source_type = 'MANUAL_INCOME' and source_id = :'income_entry_id'::uuid),
  1,
  'A: manual income creates exactly one cashbook row'
);
select is(
  (select entry_type::text from public.financial_account_entries where source_type = 'MANUAL_INCOME' and source_id = :'income_entry_id'::uuid),
  'INFLOW',
  'A: the manual income cashbook row is an INFLOW'
);
select is(
  (select (public.rpc_get_financial_account('fb100000-0000-0000-0000-000000000001', :'account_id'::uuid)->>'balance')::numeric),
  20000.00::numeric,
  'A: the account balance reflects exactly the income amount'
);

-- ---------------------------------------------------------------------
-- B. expense creates exactly one outflow. Balance after: 12000.
-- ---------------------------------------------------------------------

create temporary table t_expense as
select public.rpc_record_expense(
  'fb100000-0000-0000-0000-000000000001', :'account_id'::uuid, :'expense_cat_id'::uuid, 8000, '2026-07-02', 'transport'
) as result;
select (result->>'entry_id')::uuid as expense_entry_id from t_expense \gset

select is(
  (select count(*)::int from public.financial_account_entries where source_type = 'EXPENSE' and source_id = :'expense_entry_id'::uuid),
  1,
  'B: expense creates exactly one cashbook row'
);
select is(
  (select entry_type::text from public.financial_account_entries where source_type = 'EXPENSE' and source_id = :'expense_entry_id'::uuid),
  'OUTFLOW',
  'B: the expense cashbook row is an OUTFLOW'
);
select is(
  (select (public.rpc_get_financial_account('fb100000-0000-0000-0000-000000000001', :'account_id'::uuid)->>'balance')::numeric),
  12000.00::numeric,
  'B: the account balance is debited by the expense (20000 - 8000)'
);

-- ---------------------------------------------------------------------
-- C. expense cannot overdraw account.
-- ---------------------------------------------------------------------

select throws_ok(
  $sql$ select public.rpc_record_expense(
    'fb100000-0000-0000-0000-000000000001',
    (select id from public.financial_accounts where group_id = 'fb100000-0000-0000-0000-000000000001' and name = 'Main Cash'),
    (select id from public.financial_categories where group_id = 'fb100000-0000-0000-0000-000000000001' and name = 'Transport'),
    999999, '2026-07-03', 'too much'
  ) $sql$,
  'P0001', 'FINANCIAL_ACCOUNT_INSUFFICIENT_BALANCE',
  'C: an expense exceeding the account balance is rejected atomically'
);

-- ---------------------------------------------------------------------
-- D. income/expense immutable after posting — no direct client
-- UPDATE/DELETE grant exists on financial_manual_entries at all.
-- ---------------------------------------------------------------------

select throws_ok(
  $sql$ update public.financial_manual_entries set amount = 1 where id = (select id from public.financial_manual_entries limit 1) $sql$,
  '42501', null,
  'D: no direct client UPDATE grant exists on financial_manual_entries'
);

-- ---------------------------------------------------------------------
-- E. reversal creates compensating entry. A fresh income (untouched by
-- any other spend) is reversed immediately, so there is always enough
-- balance — this proves the ordinary successful-reversal path, kept
-- deliberately separate from G's deliberately-insufficient-balance
-- case below. Balance before: 12000; +10000 income_e -> 22000; reverse
-- -> back to 12000.
-- ---------------------------------------------------------------------

create temporary table t_income_e as
select public.rpc_record_manual_income(
  'fb100000-0000-0000-0000-000000000001', :'account_id'::uuid, :'income_cat_id'::uuid, 10000, '2026-07-03', 'a fresh, untouched gift'
) as result;
select (result->>'entry_id')::uuid as income_e_entry_id from t_income_e \gset

select public.rpc_reverse_financial_manual_entry(
  'fb100000-0000-0000-0000-000000000001', :'income_e_entry_id'::uuid, 'donor requested refund'
);

select is(
  (select count(*)::int from public.financial_account_entries where source_type = 'MANUAL_INCOME_REVERSAL' and source_id = :'income_e_entry_id'::uuid),
  1,
  'E: reversing income posts exactly one compensating cashbook row'
);
select is(
  (select entry_type::text from public.financial_account_entries where source_type = 'MANUAL_INCOME_REVERSAL' and source_id = :'income_e_entry_id'::uuid),
  'OUTFLOW',
  'E: the income reversal cashbook row is an OUTFLOW (opposite direction)'
);
select is(
  (select reverses_entry_id from public.financial_account_entries where source_type = 'MANUAL_INCOME_REVERSAL' and source_id = :'income_e_entry_id'::uuid),
  (select id from public.financial_account_entries where source_type = 'MANUAL_INCOME' and source_id = :'income_e_entry_id'::uuid),
  'E: the reversal links to the original cashbook entry via reverses_entry_id'
);
select is(
  (select status::text from public.financial_manual_entries where id = :'income_e_entry_id'::uuid),
  'REVERSED',
  'E: the manual entry itself flips to REVERSED, never deleted'
);
select is(
  (select amount from public.financial_manual_entries where id = :'income_e_entry_id'::uuid),
  10000.00::numeric,
  'E: the original entry''s amount is untouched by the reversal'
);
select is(
  (select (public.rpc_get_financial_account('fb100000-0000-0000-0000-000000000001', :'account_id'::uuid)->>'balance')::numeric),
  12000.00::numeric,
  'E: the account balance returns to exactly its pre-income value (12000)'
);

-- ---------------------------------------------------------------------
-- F. entry cannot be reversed twice.
-- ---------------------------------------------------------------------

select throws_ok(
  format(
    $sql$ select public.rpc_reverse_financial_manual_entry('fb100000-0000-0000-0000-000000000001', %L, 'double reversal attempt') $sql$,
    :'income_e_entry_id'
  ),
  'P0001', 'FINANCIAL_MANUAL_ENTRY_ALREADY_REVERSED',
  'F: reversing an already-reversed entry is rejected'
);

-- ---------------------------------------------------------------------
-- G. reversing inflow cannot overdraw account. Balance before: 12000;
-- +5000 income_g -> 17000; -12500 expense_g (spends most of it,
-- including part of income_g''s own 5000) -> 4500 remaining, which is
-- less than income_g's 5000 -- reversing it would overdraw, so it must
-- be rejected.
-- ---------------------------------------------------------------------

create temporary table t_income_g as
select public.rpc_record_manual_income(
  'fb100000-0000-0000-0000-000000000001', :'account_id'::uuid, :'income_cat_id'::uuid, 5000, '2026-07-04', 'a gift that gets mostly spent'
) as result;
select (result->>'entry_id')::uuid as income_g_entry_id from t_income_g \gset

select public.rpc_record_expense(
  'fb100000-0000-0000-0000-000000000001', :'account_id'::uuid, :'expense_cat_id'::uuid, 12500, '2026-07-05', 'spend most of the balance'
);

select is(
  (select (public.rpc_get_financial_account('fb100000-0000-0000-0000-000000000001', :'account_id'::uuid)->>'balance')::numeric),
  4500.00::numeric,
  'G: balance is 4500 after spending 12500 of the 17000 available'
);

select throws_ok(
  format(
    $sql$ select public.rpc_reverse_financial_manual_entry('fb100000-0000-0000-0000-000000000001', %L, 'would overdraw') $sql$,
    :'income_g_entry_id'
  ),
  'P0001', 'FINANCIAL_ACCOUNT_INSUFFICIENT_BALANCE',
  'G: reversing a 5000 income entry when only 4500 remains is rejected rather than allowed to overdraw'
);

-- ---------------------------------------------------------------------
-- H. cross-group posting/reversal denied.
-- ---------------------------------------------------------------------

select throws_ok(
  $sql$ select public.rpc_record_manual_income(
    'fb100000-0000-0000-0000-000000000002',
    (select id from public.financial_accounts where group_id = 'fb100000-0000-0000-0000-000000000001' and name = 'Main Cash'),
    (select id from public.financial_categories where group_id = 'fb100000-0000-0000-0000-000000000001' and name = 'Donation'),
    1000, '2026-07-06'
  ) $sql$,
  '22023', null,
  'H: posting income against another group''s account is denied'
);

select throws_ok(
  format(
    $sql$ select public.rpc_reverse_financial_manual_entry('fb100000-0000-0000-0000-000000000002', %L, 'cross-group attempt') $sql$,
    :'expense_entry_id'
  ),
  '22023', null,
  'H: reversing another group''s entry (while operating under a different real group id) is denied'
);

-- ---------------------------------------------------------------------
-- I/J. idempotency: same payload safe, conflicting payload rejected.
-- ---------------------------------------------------------------------

create temporary table t_idem_a as
select public.rpc_record_manual_income(
  'fb100000-0000-0000-0000-000000000001', :'account_id'::uuid, :'income_cat_id'::uuid,
  3000, '2026-07-07', 'idempotent gift', null, 'idem-income-key-1'
) as result;
create temporary table t_idem_b as
select public.rpc_record_manual_income(
  'fb100000-0000-0000-0000-000000000001', :'account_id'::uuid, :'income_cat_id'::uuid,
  3000, '2026-07-07', 'idempotent gift', null, 'idem-income-key-1'
) as result;

select is(
  (select result->>'entry_id' from t_idem_a),
  (select result->>'entry_id' from t_idem_b),
  'I: a retried identical payload with the same idempotency key returns the original entry, never posting twice'
);
select is(
  (select (result->>'already_posted')::boolean from t_idem_b),
  true,
  'I: the retried call reports already_posted = true'
);
select is(
  (select count(*)::int from public.financial_manual_entries where idempotency_key = 'idem-income-key-1'),
  1,
  'I: exactly one financial_manual_entries row exists for the reused key'
);

select throws_ok(
  $sql$ select public.rpc_record_manual_income(
    'fb100000-0000-0000-0000-000000000001',
    (select id from public.financial_accounts where group_id = 'fb100000-0000-0000-0000-000000000001' and name = 'Main Cash'),
    (select id from public.financial_categories where group_id = 'fb100000-0000-0000-0000-000000000001' and name = 'Donation'),
    9999, '2026-07-07', 'different amount', null, 'idem-income-key-1'
  ) $sql$,
  'P0001', 'FINANCIAL_MANUAL_ENTRY_IDEMPOTENCY_KEY_CONFLICT',
  'J: the same idempotency key with a conflicting payload (different amount) is rejected, never silently posted'
);

select * from finish();
rollback;
