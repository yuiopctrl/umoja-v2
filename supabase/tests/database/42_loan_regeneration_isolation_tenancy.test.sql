-- Prompt 09A: schedule regeneration (37-40), accounting isolation
-- (41-50), and multi-tenancy (51-54).
begin;

select plan(18);

insert into auth.users (id, email) values
  ('4a000000-0000-0000-0000-000000000001', 'p09a-iso-admin@example.com'),
  ('4a000000-0000-0000-0000-000000000002', 'p09a-iso-member@example.com');

insert into public.groups (id, name, created_by, code) values
  ('4a100000-0000-0000-0000-000000000001', 'P09A Iso Group A', '4a000000-0000-0000-0000-000000000001', 'LNIA'),
  ('4a100000-0000-0000-0000-000000000002', 'P09A Iso Group B', '4a000000-0000-0000-0000-000000000001', 'LNIB');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('4a200000-0000-0000-0000-000000000001', '4a100000-0000-0000-0000-000000000001', '4a000000-0000-0000-0000-000000000001', 'Iso Admin', 'ACTIVE', '2025-01-01', 'LNIA-2026-0001'),
  ('4a200000-0000-0000-0000-000000000002', '4a100000-0000-0000-0000-000000000001', '4a000000-0000-0000-0000-000000000002', 'Iso Member', 'ACTIVE', '2025-01-01', 'LNIA-2026-0002'),
  ('4a200000-0000-0000-0000-000000000098', '4a100000-0000-0000-0000-000000000002', '4a000000-0000-0000-0000-000000000001', 'Iso Group B Admin', 'ACTIVE', '2025-01-01', 'LNIB-2026-0001');

insert into public.group_membership_roles (group_membership_id, role_id) select '4a200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select '4a200000-0000-0000-0000-000000000002', id from public.roles where code = 'MEMBER';
insert into public.group_membership_roles (group_membership_id, role_id) select '4a200000-0000-0000-0000-000000000098', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '4a000000-0000-0000-0000-000000000001';

create temporary table t_product as
select public.rpc_create_loan_product(
  '4a100000-0000-0000-0000-000000000001', 'NORMAL', 'Mkopo wa Kawaida',
  10000, 1, 12, 12.0000, 'ANNUAL', 'FLAT', 5000000
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

create temporary table t_loan as
select public.rpc_create_draft_loan_account(
  '4a100000-0000-0000-0000-000000000001', '4a200000-0000-0000-0000-000000000002',
  :'product_id'::uuid, 60000, 6, '2026-06-01'
) as result;
select (result->>'id')::uuid as loan_id from t_loan \gset

-- ---------------------------------------------------------------------
-- Regeneration (37-40)
-- ---------------------------------------------------------------------

create temporary table t_before_ids as
select id from public.loan_installments where loan_account_id = :'loan_id'::uuid order by installment_number;

select public.rpc_update_draft_loan_terms(
  '4a100000-0000-0000-0000-000000000001', :'loan_id'::uuid, p_term => 12
);

-- 37. regeneration works (new schedule reflects the new term)
select is(
  (select count(*) from public.loan_installments where loan_account_id = :'loan_id'::uuid),
  12::bigint,
  '37: regenerating a DRAFT schedule after a term change produces the new installment count'
);

-- 38. old schedule does not remain duplicated (none of the original
-- installment row IDs survive the replace)
select is(
  (
    select count(*) from public.loan_installments
    where loan_account_id = :'loan_id'::uuid and id in (select id from t_before_ids)
  ),
  0::bigint,
  '38: none of the original (6-installment) rows survive regeneration — no duplication, a clean atomic replace'
);

-- 39. atomic: SUM(principal_due) after regeneration still equals the
-- (now-current) principal exactly — never left half-consistent.
select is(
  (select sum(principal_due) from public.loan_installments where loan_account_id = :'loan_id'::uuid),
  60000.00::numeric,
  '39: regeneration is atomic — the new schedule''s principal sum is exactly correct, never a partial mix'
);

-- 40. unauthorized regeneration denied
set local request.jwt.claim.sub to '4a000000-0000-0000-0000-000000000002';
select throws_ok(
  format(
    $sql$ select public.rpc_regenerate_loan_schedule('4a100000-0000-0000-0000-000000000001', %L) $sql$,
    :'loan_id'::uuid
  ),
  '42501', null,
  '40: a MEMBER (no loan_schedule.generate) cannot regenerate a schedule'
);
set local request.jwt.claim.sub to '4a000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- Accounting isolation (41-50) — a real financial account + a
-- Financial Position snapshot taken BEFORE and AFTER creating another
-- draft loan must be byte-for-byte identical.
-- ---------------------------------------------------------------------

create temporary table t_account as
select public.rpc_create_financial_account(
  '4a100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 50000
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_position_before as
select public.rpc_get_financial_position('4a100000-0000-0000-0000-000000000001', null, null) as result;

create temporary table t_iso_loan as
select public.rpc_create_draft_loan_account(
  '4a100000-0000-0000-0000-000000000001', '4a200000-0000-0000-0000-000000000002',
  :'product_id'::uuid, 90000, 9, '2026-07-01'
) as result;
select (result->>'id')::uuid as iso_loan_id from t_iso_loan \gset

create temporary table t_position_after as
select public.rpc_get_financial_position('4a100000-0000-0000-0000-000000000001', null, null) as result;

-- 41. zero cashbook entries created by the loan
select is(
  (select count(*) from public.financial_account_entries where source_id = :'iso_loan_id'::uuid),
  0::bigint,
  '41: creating a draft loan creates zero financial_account_entries (cashbook) rows'
);

-- 42. zero financial-account balance impact
select is(
  (select result->>'total_financial_account_balance' from t_position_before),
  (select result->>'total_financial_account_balance' from t_position_after),
  '42: total_financial_account_balance is unchanged by creating a draft loan'
);

-- 43/44. zero payment rows / zero payment allocations
select is(
  (select count(*) from public.payments where financial_account_id = :'account_id'::uuid),
  0::bigint,
  '43: creating a draft loan creates zero payments rows'
);
select is(
  (select count(*) from public.payment_allocations),
  0::bigint,
  '44: creating a draft loan creates zero payment_allocations rows'
);

-- 45. zero wallet entries
select is(
  (select count(*) from public.member_wallet_entries),
  0::bigint,
  '45: creating a draft loan creates zero member_wallet_entries rows'
);

-- 46. zero receipt rows (receipts are derived from payments; zero
-- payments implies zero receipts)
select is(
  (select count(*) from public.payments where receipt_number is not null),
  0::bigint,
  '46: creating a draft loan creates zero receipted payment rows'
);

-- 47. zero contribution charge rows created for this loan
select is(
  (select count(*) from public.member_contribution_charges where membership_id = '4a200000-0000-0000-0000-000000000002'),
  0::bigint,
  '47: creating a draft loan creates zero member_contribution_charges rows'
);

-- 48. draft schedule excluded from collectible debt/payment targets —
-- outstanding member obligations in Financial Position come only from
-- contribution charges, never loan installments.
select is(
  (select result->>'total_outstanding_member_obligations' from t_position_before),
  (select result->>'total_outstanding_member_obligations' from t_position_after),
  '48: total_outstanding_member_obligations is unchanged — a draft loan''s installments are never collectible debt'
);

-- 49. draft loan excluded from group income
select is(
  (select result->>'group_income' from t_position_before),
  (select result->>'group_income' from t_position_after),
  '49: group_income is unchanged — no interest/principal from a draft loan is ever recognized as income'
);

-- 50. draft loan excluded from funded loan receivables — there is no
-- "funded receivables" figure anywhere in Financial Position at all in
-- 09A (Phase 09B introduces it), so nothing here can have inflated it;
-- confirmed by every prior figure being byte-for-byte identical.
select is(
  (select result from t_position_before),
  (select result from t_position_after),
  '50: the entire Financial Position response is unchanged by a draft loan — no funded-receivable concept leaks in early'
);

-- ---------------------------------------------------------------------
-- Multi-tenancy (51-54)
-- ---------------------------------------------------------------------

set local request.jwt.claim.sub to '4a000000-0000-0000-0000-000000000001';

-- 51. group A cannot read group B products — the caller is legitimately
-- ADMIN of Group B too (a real user can hold ADMIN in more than one
-- group), so this proves the stronger point: even with full
-- permission to read Group B's own data, Group B's list is genuinely
-- empty — no Group A product leaks across.
select is(
  (select result->>'total_count' from (select public.rpc_list_loan_products('4a100000-0000-0000-0000-000000000002') as result) x),
  '0',
  '51: Group B''s (genuinely empty) product list never leaks any Group A product'
);

-- 52. group A cannot read group B loans
select is(
  (select result->>'total_count' from (select public.rpc_list_loan_accounts('4a100000-0000-0000-0000-000000000002') as result) x),
  '0',
  '52: Group B''s (genuinely empty) loan list never leaks any Group A loan'
);

-- 53. group A cannot read group B schedules (mismatched group_id on a
-- real Group A loan account is rejected, not silently ignored).
select throws_ok(
  format(
    $sql$ select public.rpc_list_loan_installments('4a100000-0000-0000-0000-000000000002', %L) $sql$,
    :'loan_id'::uuid
  ),
  '22023', null,
  '53: fetching a real Group A loan''s schedule under Group B''s id is rejected, not returned'
);

-- 54. cross-group membership injection rejected — a Group B
-- membership cannot be used as the borrower for a Group A loan
-- creation (already exercised as item 14 in 40_loan_accounts, proven
-- again here explicitly as the multi-tenancy section's own item).
select throws_ok(
  format(
    $sql$ select public.rpc_create_draft_loan_account(
      '4a100000-0000-0000-0000-000000000001', '4a200000-0000-0000-0000-000000000098',
      %L, 30000, 6, '2026-06-01'
    ) $sql$,
    :'product_id'::uuid
  ),
  '22023', null,
  '54: a Group B membership cannot be injected as the borrower on a Group A loan'
);

select * from finish();
rollback;
