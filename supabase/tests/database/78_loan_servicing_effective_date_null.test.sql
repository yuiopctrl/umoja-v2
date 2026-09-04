-- Prompt 09E-UAT-BLOCKER-01: physical-device UAT found that Early
-- Settlement and Principal Prepayment previews always failed with a
-- generic error. Root cause: every 09E RPC declared
-- `p_effective_date date default current_date` but ALSO raised
-- 'Effective date is required' whenever it was null — a self-
-- contradiction, because PostgREST (which is what the Flutter/Supabase
-- client actually calls, unlike a raw SQL call) always sends every
-- declared parameter explicitly, including an explicit JSON `null`
-- when the caller never set one. A SQL DEFAULT only ever applies when
-- an argument is OMITTED entirely — never when it is explicitly NULL —
-- so every real app call hit the "Effective date is required"
-- exception instead of silently defaulting to today. This test calls
-- every affected RPC with an EXPLICIT null (exactly reproducing what
-- PostgREST sends), never merely omitting the argument, which is the
-- only way to reproduce this class of bug in pgTAP at all.
--
-- Prompt 09E-UAT-BLOCKER-01A: the fix now lives ONLY in the append-only
-- corrective migration 20260914090000 (v_effective_date normalization);
-- the original 20260913093000/094000/095000 migration files were
-- restored to their exact original, already-cloud-applied content.
-- Extended here to also prove an explicit (non-null) date still works
-- correctly, and that normal permission enforcement is completely
-- unaffected by the fix.
begin;

select plan(10);

insert into auth.users (id, email) values
  ('78000000-0000-0000-0000-000000000001', 'p09e-blocker1-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('78100000-0000-0000-0000-000000000001', 'Effective Date Null Group', '78000000-0000-0000-0000-000000000001', 'EDNL');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('78200000-0000-0000-0000-000000000001', '78100000-0000-0000-0000-000000000001', '78000000-0000-0000-0000-000000000001', 'ED Admin', 'ACTIVE', '2025-01-01', 'EDNL-2026-0001'),
  ('78200000-0000-0000-0000-000000000005', '78100000-0000-0000-0000-000000000001', null, 'ED Borrower', 'ACTIVE', '2025-01-01', 'EDNL-2026-0005');

insert into public.group_membership_roles (group_membership_id, role_id) select '78200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '78000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '78100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '78100000-0000-0000-0000-000000000001', 'EDNLP', 'Effective Date Null Product', 100000, 1, 12, 2.0, 'MONTHLY', 'FLAT'
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

create temporary table t_loan as
select public.rpc_create_draft_loan_account(
  '78100000-0000-0000-0000-000000000001', '78200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 600000, 6, (current_date + interval '1 month')::date
) as result;
select (result->>'id')::uuid as loan_id from t_loan \gset
select public.rpc_submit_loan_account('78100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_approve_loan_account('78100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_disburse_loan_account('78100000-0000-0000-0000-000000000001', :'loan_id'::uuid, :'account_id'::uuid, current_date);

-- ---------------------------------------------------------------------
-- 1: rpc_preview_loan_early_settlement with an EXPLICIT null effective
-- date (exactly what PostgREST/the Flutter client sends) must default
-- to today, never raise.
-- ---------------------------------------------------------------------

select lives_ok(
  format($sql$ select public.rpc_preview_loan_early_settlement(%L::uuid, %L::uuid, null::date) $sql$,
    '78100000-0000-0000-0000-000000000001', :'loan_id'),
  '1: rpc_preview_loan_early_settlement accepts an explicit null effective date'
);

select is(
  ((public.rpc_preview_loan_early_settlement(
    '78100000-0000-0000-0000-000000000001', :'loan_id'::uuid, null::date
  ))->>'effective_date')::date,
  current_date,
  '2: an explicit null effective date defaults to current_date, exactly like an omitted argument'
);

-- ---------------------------------------------------------------------
-- 2: rpc_preview_loan_prepayment with an explicit null effective date.
-- ---------------------------------------------------------------------

select lives_ok(
  format($sql$ select public.rpc_preview_loan_prepayment(%L::uuid, %L::uuid, 50000, 'REDUCE_TERM', null::date) $sql$,
    '78100000-0000-0000-0000-000000000001', :'loan_id'),
  '3: rpc_preview_loan_prepayment accepts an explicit null effective date'
);

-- ---------------------------------------------------------------------
-- 3: rpc_preview_loan_restructure with an explicit null effective date
-- (a second loan, since restructure requires zero overdue balance and
-- this loan already has none).
-- ---------------------------------------------------------------------

select lives_ok(
  format($sql$ select public.rpc_preview_loan_restructure(%L::uuid, %L::uuid, 8, %L::date, null::numeric, null::date) $sql$,
    '78100000-0000-0000-0000-000000000001', :'loan_id', (current_date + interval '2 months')::date),
  '4: rpc_preview_loan_restructure accepts an explicit null effective date'
);

-- ---------------------------------------------------------------------
-- 4: the write RPCs (rpc_settle_loan_early / rpc_prepay_loan_principal)
-- must equally accept an explicit null effective date, not merely
-- their preview counterparts.
-- ---------------------------------------------------------------------

select lives_ok(
  format($sql$ select public.rpc_settle_loan_early(%L::uuid, %L::uuid, %L::uuid, 'CASH', null::date) $sql$,
    '78100000-0000-0000-0000-000000000001', :'loan_id', :'account_id'),
  '5: rpc_settle_loan_early accepts an explicit null effective date'
);

create temporary table t_loan2 as
select public.rpc_create_draft_loan_account(
  '78100000-0000-0000-0000-000000000001', '78200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 600000, 6, (current_date + interval '1 month')::date
) as result;
select (result->>'id')::uuid as loan2_id from t_loan2 \gset
select public.rpc_submit_loan_account('78100000-0000-0000-0000-000000000001', :'loan2_id'::uuid);
select public.rpc_approve_loan_account('78100000-0000-0000-0000-000000000001', :'loan2_id'::uuid);
select public.rpc_disburse_loan_account('78100000-0000-0000-0000-000000000001', :'loan2_id'::uuid, :'account_id'::uuid, current_date);

select lives_ok(
  format($sql$ select public.rpc_prepay_loan_principal(%L::uuid, %L::uuid, 50000, 'REDUCE_TERM', %L::uuid, 'CASH', null::date) $sql$,
    '78100000-0000-0000-0000-000000000001', :'loan2_id', :'account_id'),
  '6: rpc_prepay_loan_principal accepts an explicit null effective date'
);

-- ---------------------------------------------------------------------
-- 7/8/9: an EXPLICIT (non-null) effective date must still be honored
-- exactly as given, never silently overridden by the coalesce fix.
-- ---------------------------------------------------------------------

create temporary table t_loan3 as
select public.rpc_create_draft_loan_account(
  '78100000-0000-0000-0000-000000000001', '78200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 600000, 6, (current_date + interval '1 month')::date
) as result;
select (result->>'id')::uuid as loan3_id from t_loan3 \gset
select public.rpc_submit_loan_account('78100000-0000-0000-0000-000000000001', :'loan3_id'::uuid);
select public.rpc_approve_loan_account('78100000-0000-0000-0000-000000000001', :'loan3_id'::uuid);
select public.rpc_disburse_loan_account('78100000-0000-0000-0000-000000000001', :'loan3_id'::uuid, :'account_id'::uuid, current_date);

select is(
  ((public.rpc_preview_loan_early_settlement(
    '78100000-0000-0000-0000-000000000001', :'loan3_id'::uuid, '2026-06-15'::date
  ))->>'effective_date')::date,
  '2026-06-15'::date,
  '7: an explicit non-null effective date is honored exactly, never overridden by the coalesce fix'
);

select is(
  ((public.rpc_preview_loan_prepayment(
    '78100000-0000-0000-0000-000000000001', :'loan3_id'::uuid, 50000, 'REDUCE_TERM', '2026-06-15'::date
  ))->>'effective_date')::date,
  '2026-06-15'::date,
  '8: rpc_preview_loan_prepayment honors an explicit non-null effective date exactly'
);

select is(
  ((public.rpc_preview_loan_restructure(
    '78100000-0000-0000-0000-000000000001', :'loan3_id'::uuid, 8, (current_date + interval '2 months')::date,
    null::numeric, '2026-06-15'::date
  ))->>'effective_date')::date,
  '2026-06-15'::date,
  '9: rpc_preview_loan_restructure honors an explicit non-null effective date exactly'
);

-- ---------------------------------------------------------------------
-- 10: no authorization regression — the coalesce fix runs AFTER the
-- permission check in every function, so a caller without the
-- required permission is still rejected exactly as before, regardless
-- of what effective date (null or explicit) they pass.
-- ---------------------------------------------------------------------

reset role;
insert into auth.users (id, email) values
  ('78000000-0000-0000-0000-000000000002', 'p09e-blocker1-member@example.com');
insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('78200000-0000-0000-0000-000000000002', '78100000-0000-0000-0000-000000000001', '78000000-0000-0000-0000-000000000002', 'ED Member (no servicing perms)', 'ACTIVE', '2025-01-01', 'EDNL-2026-0002');
insert into public.group_membership_roles (group_membership_id, role_id) select '78200000-0000-0000-0000-000000000002', id from public.roles where code = 'MEMBER';
set local role authenticated;
set local request.jwt.claim.sub to '78000000-0000-0000-0000-000000000002';

select throws_ok(
  format($sql$ select public.rpc_preview_loan_early_settlement(%L::uuid, %L::uuid, null::date) $sql$,
    '78100000-0000-0000-0000-000000000001', :'loan3_id'),
  '42501',
  null,
  '10: permission enforcement is completely unaffected by the effective-date fix'
);

select * from finish();
rollback;
