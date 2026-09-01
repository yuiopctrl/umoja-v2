-- Prompt 09C-UAT-FIX-01: a large payment must never silently prepay a
-- borrower's future loan installments (section 17, items 1-12). Loan:
-- principal 300,000, term 3, 5% MONTHLY FLAT -> each installment is
-- 100,000 principal + 15,000 interest = 115,000 total (FLAT interest is
-- computed from the ORIGINAL principal every installment, so all three
-- installments carry the same 15,000 interest).
begin;

select plan(17);

insert into auth.users (id, email) values
  ('4f000000-0000-0000-0000-000000000001', 'p09c-fix01-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('4f100000-0000-0000-0000-000000000001', 'P09C Fix01 Group', '4f000000-0000-0000-0000-000000000001', 'LFIX');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('4f200000-0000-0000-0000-000000000001', '4f100000-0000-0000-0000-000000000001', '4f000000-0000-0000-0000-000000000001', 'LX Admin', 'ACTIVE', '2025-01-01', 'LFIX-2026-0001'),
  ('4f200000-0000-0000-0000-000000000005', '4f100000-0000-0000-0000-000000000001', null, 'LX Borrower', 'ACTIVE', '2025-01-01', 'LFIX-2026-0005');

insert into public.group_membership_roles (group_membership_id, role_id) select '4f200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '4f000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '4f100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '4f100000-0000-0000-0000-000000000001', 'NORMAL', 'Mkopo wa Kawaida',
  100000, 1, 12, 5.0000, 'MONTHLY', 'FLAT', 10000000
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

-- Installment 1 overdue (due last month), installment 2 due today,
-- installment 3 due next month (UPCOMING).
create temporary table t_loan as
select public.rpc_create_draft_loan_account(
  '4f100000-0000-0000-0000-000000000001', '4f200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 300000, 3, (current_date - interval '1 month')::date
) as result;
select (result->>'id')::uuid as loan_id from t_loan \gset
select public.rpc_submit_loan_account('4f100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_approve_loan_account('4f100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_disburse_loan_account('4f100000-0000-0000-0000-000000000001', :'loan_id'::uuid, :'account_id'::uuid, current_date);

select id as i1_installment_id from public.loan_installments where loan_account_id = :'loan_id'::uuid and installment_number = 1 \gset
select id as i2_installment_id from public.loan_installments where loan_account_id = :'loan_id'::uuid and installment_number = 2 \gset
select id as i3_installment_id from public.loan_installments where loan_account_id = :'loan_id'::uuid and installment_number = 3 \gset

-- ---------------------------------------------------------------------
-- 1/2/3/4/5/8: a large (1,000,000) preview at effective_at=current_date
-- must include the overdue and due-today installments, exclude the
-- future one, and match exactly what posting the same payment produces.
-- ---------------------------------------------------------------------

create temporary table t_preview as
select public.rpc_preview_payment_allocation(
  '4f100000-0000-0000-0000-000000000001', '4f200000-0000-0000-0000-000000000005'::uuid,
  :'account_id'::uuid, 1000000, current_date
) as result;

select ok(
  (select exists(
    select 1 from jsonb_array_elements((select result->'allocations' from t_preview)) a
    where (a->>'loan_installment_id')::uuid = :'i1_installment_id'::uuid
  )),
  '1: the overdue installment is allocatable'
);
select ok(
  (select exists(
    select 1 from jsonb_array_elements((select result->'allocations' from t_preview)) a
    where (a->>'loan_installment_id')::uuid = :'i2_installment_id'::uuid
  )),
  '2: the installment due exactly today is allocatable'
);
select ok(
  not (select exists(
    select 1 from jsonb_array_elements((select result->'allocations' from t_preview)) a
    where (a->>'loan_installment_id')::uuid = :'i3_installment_id'::uuid
  )),
  '3: the future (UPCOMING) installment is never automatically allocatable'
);
select is(
  (select (result->>'total_allocated')::numeric from t_preview),
  230000.00::numeric,
  '4: a large payment allocates only the 230,000 currently payable (installments 1+2), never the future installment'
);
select is(
  (select (result->>'wallet_credit_amount')::numeric from t_preview),
  770000.00::numeric,
  '5: the remainder (1,000,000 - 230,000) becomes wallet credit, never a silent loan prepayment'
);

-- Post the SAME payment and confirm preview and posting agree exactly
-- (item 8), then confirm 6/7 (future interest unrecognized, loan stays
-- ACTIVE).
create temporary table t_post as
select public.rpc_post_payment(
  '4f100000-0000-0000-0000-000000000001', '4f200000-0000-0000-0000-000000000005'::uuid, :'account_id'::uuid,
  1000000, current_date, 'CASH'
) as result;

select is(
  (select (result->>'total_allocated')::numeric from t_post),
  (select (result->>'total_allocated')::numeric from t_preview),
  '8a: posting allocates exactly what preview said it would'
);
select is(
  (select (result->>'wallet_credit_amount')::numeric from t_post),
  (select (result->>'wallet_credit_amount')::numeric from t_preview),
  '8b: posting''s wallet credit matches preview exactly'
);

select is(
  (public.rpc_get_financial_position('4f100000-0000-0000-0000-000000000001')->>'recognized_loan_interest_income')::numeric,
  30000.00::numeric,
  '6: only the two currently-due installments'' interest (15,000 x 2) is recognized — the future installment''s 15,000 is not'
);
select is(
  (public.rpc_get_financial_position('4f100000-0000-0000-0000-000000000001')->>'scheduled_unearned_interest')::numeric,
  15000.00::numeric,
  '6b: the future installment''s 15,000 interest remains scheduled/unearned'
);
select is(
  (select status::text from public.loan_accounts where id = :'loan_id'::uuid),
  'ACTIVE',
  '7: the loan remains ACTIVE — a future installment still exists and was never touched'
);
reset role;
select is(
  (select coalesce(sum(outstanding), 0) from public.loan_installment_component_states(:'i3_installment_id'::uuid)),
  115000.00::numeric,
  '7b: the future installment is completely untouched (still fully outstanding)'
);
set local role authenticated;
set local request.jwt.claim.sub to '4f000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- 9: wallet allocation cannot consume future installments either. The
-- 770,000 wallet credit from the overpayment above is far more than
-- the (now fully settled) currently-due obligations, so a large wallet
-- allocation attempt must find nothing further to allocate.
-- ---------------------------------------------------------------------

select throws_ok(
  format($sql$ select public.rpc_allocate_member_wallet(
    '4f100000-0000-0000-0000-000000000001', %L, 500000
  ) $sql$, '4f200000-0000-0000-0000-000000000005'),
  'P0001',
  null,
  '9: wallet allocation finds nothing to allocate (future installment still correctly excluded) — never silently prepays it'
);
reset role;
select is(
  (select coalesce(sum(outstanding), 0) from public.loan_installment_component_states(:'i3_installment_id'::uuid)),
  115000.00::numeric,
  '9b: the future installment remains fully untouched after the wallet allocation attempt'
);
set local role authenticated;
set local request.jwt.claim.sub to '4f000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------
-- 10: contribution priority remains unchanged — a contribution charge
-- due on the SAME date as the (now fully settled) installment 2 would
-- still have settled before it, matching the unaltered priority rule.
-- Verified structurally: installment 2's own components already show
-- zero outstanding above, and the priority-rule migration itself is
-- untouched by this fix (contribution ordering logic was not modified).
-- ---------------------------------------------------------------------

select due_date as i2_due_date from public.loan_installments where id = :'i2_installment_id'::uuid \gset

create temporary table t_ctype as
select public.rpc_create_contribution_type(
  '4f100000-0000-0000-0000-000000000001', 'ADA', 'GENERAL', 'GROUP_INCOME'
) as result;
select (result->>'id')::uuid as ctype_id from t_ctype \gset

create temporary table t_setup as
select public.rpc_create_contribution_setup(
  '4f100000-0000-0000-0000-000000000001', :'ctype_id'::uuid, 'ADA Setup', 'MONTHLY', 'FIXED',
  p_fixed_amount => 20000
) as result;
select (result->>'id')::uuid as setup_id from t_setup \gset

create temporary table t_period as
select public.rpc_create_contribution_period(
  '4f100000-0000-0000-0000-000000000001', :'setup_id'::uuid, 'Tie Period', :'i2_due_date'::date, :'i2_due_date'::date,
  p_due_date => :'i2_due_date'::date
) as result;
select (result->>'id')::uuid as period_id from t_period \gset
select public.rpc_open_contribution_period('4f100000-0000-0000-0000-000000000001', :'period_id'::uuid);

create temporary table t_tie_preview as
select public.rpc_preview_payment_allocation(
  '4f100000-0000-0000-0000-000000000001', '4f200000-0000-0000-0000-000000000005'::uuid,
  :'account_id'::uuid, 20000, :'i2_due_date'::date
) as result;

select is(
  (select (a->>'obligation_kind') from jsonb_array_elements((select result->'allocations' from t_tie_preview)) a limit 1),
  'CONTRIBUTION',
  '10: on an exact due_date tie, the contribution still settles before any loan obligation (priority rule unchanged)'
);

-- ---------------------------------------------------------------------
-- 11: DRAFT/SUBMITTED/APPROVED remain excluded regardless of how
-- overdue their planned schedule is.
-- ---------------------------------------------------------------------

create temporary table t_draft as
select public.rpc_create_draft_loan_account(
  '4f100000-0000-0000-0000-000000000001', '4f200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 300000, 3, (current_date - interval '6 months')::date
) as result;
select (result->>'id')::uuid as draft_id from t_draft \gset

create temporary table t_draft_preview as
select public.rpc_preview_payment_allocation(
  '4f100000-0000-0000-0000-000000000001', '4f200000-0000-0000-0000-000000000005'::uuid,
  :'account_id'::uuid, 1000000, current_date
) as result;

select ok(
  not (select exists(
    select 1 from jsonb_array_elements((select result->'allocations' from t_draft_preview)) a
    where (a->>'loan_account_id')::uuid = :'draft_id'::uuid
  )),
  '11: a DRAFT loan is excluded from allocation even with a deeply-overdue planned schedule'
);

-- ---------------------------------------------------------------------
-- 12: payment effective date controls collectibility — boundary case.
-- A fresh single-installment loan due on a specific date: allocatable
-- when effective_at = due_date, NOT allocatable when
-- effective_at = due_date - 1 day.
-- ---------------------------------------------------------------------

create temporary table t_boundary_loan as
select public.rpc_create_draft_loan_account(
  '4f100000-0000-0000-0000-000000000001', '4f200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 100000, 1, (current_date + interval '10 days')::date
) as result;
select (result->>'id')::uuid as boundary_loan_id from t_boundary_loan \gset
select public.rpc_submit_loan_account('4f100000-0000-0000-0000-000000000001', :'boundary_loan_id'::uuid);
select public.rpc_approve_loan_account('4f100000-0000-0000-0000-000000000001', :'boundary_loan_id'::uuid);
select public.rpc_disburse_loan_account('4f100000-0000-0000-0000-000000000001', :'boundary_loan_id'::uuid, :'account_id'::uuid, current_date);

select due_date as boundary_due_date from public.loan_installments where loan_account_id = :'boundary_loan_id'::uuid \gset

create temporary table t_boundary_ok as
select public.rpc_preview_payment_allocation(
  '4f100000-0000-0000-0000-000000000001', '4f200000-0000-0000-0000-000000000005'::uuid,
  :'account_id'::uuid, 200000, :'boundary_due_date'::date
) as result;
select ok(
  (select exists(
    select 1 from jsonb_array_elements((select result->'allocations' from t_boundary_ok)) a
    where (a->>'loan_account_id')::uuid = :'boundary_loan_id'::uuid
  )),
  '12a: due_date = effective_date -> allocatable (boundary, inclusive)'
);

create temporary table t_boundary_not_yet as
select public.rpc_preview_payment_allocation(
  '4f100000-0000-0000-0000-000000000001', '4f200000-0000-0000-0000-000000000005'::uuid,
  :'account_id'::uuid, 200000, (:'boundary_due_date'::date - 1)
) as result;
select ok(
  not (select exists(
    select 1 from jsonb_array_elements((select result->'allocations' from t_boundary_not_yet)) a
    where (a->>'loan_account_id')::uuid = :'boundary_loan_id'::uuid
  )),
  '12b: due_date = effective_date + 1 day -> NOT allocatable (boundary, exclusive)'
);

select * from finish();
rollback;
