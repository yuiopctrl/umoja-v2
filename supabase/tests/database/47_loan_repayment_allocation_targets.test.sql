-- Prompt 09C: loan repayment allocation targets, collectibility,
-- granularity, and priority (section 31, items 1-17). Loan: principal
-- 1,000,000, term 4, 5% MONTHLY FLAT -> each installment is exactly
-- 250,000 principal + 50,000 interest = 300,000 total.
begin;

select plan(18);

insert into auth.users (id, email) values
  ('4a000000-0000-0000-0000-000000000001', 'p09c-alloc-admin@example.com');

insert into public.groups (id, name, created_by, code) values
  ('4a100000-0000-0000-0000-000000000001', 'P09C Allocation Group', '4a000000-0000-0000-0000-000000000001', 'LALC');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('4a200000-0000-0000-0000-000000000001', '4a100000-0000-0000-0000-000000000001', '4a000000-0000-0000-0000-000000000001', 'LA Admin', 'ACTIVE', '2025-01-01', 'LALC-2026-0001'),
  ('4a200000-0000-0000-0000-000000000005', '4a100000-0000-0000-0000-000000000001', null, 'LA Borrower', 'ACTIVE', '2025-01-01', 'LALC-2026-0005'),
  ('4a200000-0000-0000-0000-000000000006', '4a100000-0000-0000-0000-000000000001', null, 'LA Borrower Two', 'ACTIVE', '2025-01-01', 'LALC-2026-0006');

insert into public.group_membership_roles (group_membership_id, role_id) select '4a200000-0000-0000-0000-000000000001', id from public.roles where code = 'ADMIN';

set local role authenticated;
set local request.jwt.claim.sub to '4a000000-0000-0000-0000-000000000001';

create temporary table t_account as
select public.rpc_create_financial_account(
  '4a100000-0000-0000-0000-000000000001', 'Cash Box', 'CASH', 5000000, current_date
) as result;
select (result->>'id')::uuid as account_id from t_account \gset

create temporary table t_product as
select public.rpc_create_loan_product(
  '4a100000-0000-0000-0000-000000000001', 'NORMAL', 'Mkopo wa Kawaida',
  100000, 1, 12, 5.0000, 'MONTHLY', 'FLAT', 10000000
) as result;
select (result->>'id')::uuid as product_id from t_product \gset

-- ---------------------------------------------------------------------
-- Collectibility (items 1-6): one loan per non-ACTIVE status, plus one
-- ACTIVE loan, all for the SAME borrower (Borrower Two, kept isolated
-- from every other test below).
-- ---------------------------------------------------------------------

create temporary table t_draft as
select public.rpc_create_draft_loan_account(
  '4a100000-0000-0000-0000-000000000001', '4a200000-0000-0000-0000-000000000006'::uuid,
  :'product_id'::uuid, 1000000, 4, current_date
) as result;
select (result->>'id')::uuid as draft_id from t_draft \gset

create temporary table t_submitted as
select public.rpc_create_draft_loan_account(
  '4a100000-0000-0000-0000-000000000001', '4a200000-0000-0000-0000-000000000006'::uuid,
  :'product_id'::uuid, 1000000, 4, current_date
) as result;
select (result->>'id')::uuid as submitted_id from t_submitted \gset
select public.rpc_submit_loan_account('4a100000-0000-0000-0000-000000000001', :'submitted_id'::uuid);

create temporary table t_approved as
select public.rpc_create_draft_loan_account(
  '4a100000-0000-0000-0000-000000000001', '4a200000-0000-0000-0000-000000000006'::uuid,
  :'product_id'::uuid, 1000000, 4, current_date
) as result;
select (result->>'id')::uuid as approved_id from t_approved \gset
select public.rpc_submit_loan_account('4a100000-0000-0000-0000-000000000001', :'approved_id'::uuid);
select public.rpc_approve_loan_account('4a100000-0000-0000-0000-000000000001', :'approved_id'::uuid);

create temporary table t_rejected as
select public.rpc_create_draft_loan_account(
  '4a100000-0000-0000-0000-000000000001', '4a200000-0000-0000-0000-000000000006'::uuid,
  :'product_id'::uuid, 1000000, 4, current_date
) as result;
select (result->>'id')::uuid as rejected_id from t_rejected \gset
select public.rpc_submit_loan_account('4a100000-0000-0000-0000-000000000001', :'rejected_id'::uuid);
select public.rpc_reject_loan_account('4a100000-0000-0000-0000-000000000001', :'rejected_id'::uuid, 'not eligible');

create temporary table t_cancelled as
select public.rpc_create_draft_loan_account(
  '4a100000-0000-0000-0000-000000000001', '4a200000-0000-0000-0000-000000000006'::uuid,
  :'product_id'::uuid, 1000000, 4, current_date
) as result;
select (result->>'id')::uuid as cancelled_id from t_cancelled \gset
select public.rpc_submit_loan_account('4a100000-0000-0000-0000-000000000001', :'cancelled_id'::uuid);
select public.rpc_cancel_loan_account('4a100000-0000-0000-0000-000000000001', :'cancelled_id'::uuid, 'withdrawn');

create temporary table t_active_b2 as
select public.rpc_create_draft_loan_account(
  '4a100000-0000-0000-0000-000000000001', '4a200000-0000-0000-0000-000000000006'::uuid,
  :'product_id'::uuid, 1000000, 4, current_date
) as result;
select (result->>'id')::uuid as active_b2_id from t_active_b2 \gset
select public.rpc_submit_loan_account('4a100000-0000-0000-0000-000000000001', :'active_b2_id'::uuid);
select public.rpc_approve_loan_account('4a100000-0000-0000-0000-000000000001', :'active_b2_id'::uuid);
select public.rpc_disburse_loan_account('4a100000-0000-0000-0000-000000000001', :'active_b2_id'::uuid, :'account_id'::uuid, current_date);

create temporary table t_preview_b2 as
select public.rpc_preview_payment_allocation(
  '4a100000-0000-0000-0000-000000000001', '4a200000-0000-0000-0000-000000000006'::uuid, :'account_id'::uuid, 5000000
) as result;

-- 1. ACTIVE loan becomes an allocation target.
select ok(
  (select exists(
    select 1 from jsonb_array_elements((select result->'allocations' from t_preview_b2)) a
    where (a->>'loan_account_id')::uuid = :'active_b2_id'::uuid
  )),
  '1: an ACTIVE loan''s installments appear in the allocation preview'
);

-- 2. DRAFT excluded.
select ok(
  not (select exists(
    select 1 from jsonb_array_elements((select result->'allocations' from t_preview_b2)) a
    where (a->>'loan_account_id')::uuid = :'draft_id'::uuid
  )),
  '2: a DRAFT loan is excluded from allocation'
);

-- 3. SUBMITTED excluded.
select ok(
  not (select exists(
    select 1 from jsonb_array_elements((select result->'allocations' from t_preview_b2)) a
    where (a->>'loan_account_id')::uuid = :'submitted_id'::uuid
  )),
  '3: a SUBMITTED loan is excluded from allocation'
);

-- 4. APPROVED excluded.
select ok(
  not (select exists(
    select 1 from jsonb_array_elements((select result->'allocations' from t_preview_b2)) a
    where (a->>'loan_account_id')::uuid = :'approved_id'::uuid
  )),
  '4: an APPROVED loan is excluded from allocation'
);

-- 5. REJECTED excluded.
select ok(
  not (select exists(
    select 1 from jsonb_array_elements((select result->'allocations' from t_preview_b2)) a
    where (a->>'loan_account_id')::uuid = :'rejected_id'::uuid
  )),
  '5: a REJECTED loan is excluded from allocation'
);

-- 6. CANCELLED excluded.
select ok(
  not (select exists(
    select 1 from jsonb_array_elements((select result->'allocations' from t_preview_b2)) a
    where (a->>'loan_account_id')::uuid = :'cancelled_id'::uuid
  )),
  '6: a CANCELLED loan is excluded from allocation'
);

-- ---------------------------------------------------------------------
-- Granularity, exceed-outstanding, partial/full/multi-installment,
-- priority (items 7-16) — a fresh ACTIVE loan for the primary borrower.
-- ---------------------------------------------------------------------

create temporary table t_loan as
select public.rpc_create_draft_loan_account(
  '4a100000-0000-0000-0000-000000000001', '4a200000-0000-0000-0000-000000000005'::uuid,
  :'product_id'::uuid, 1000000, 4, (current_date - interval '3 months')::date
) as result;
select (result->>'id')::uuid as loan_id from t_loan \gset
select public.rpc_submit_loan_account('4a100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_approve_loan_account('4a100000-0000-0000-0000-000000000001', :'loan_id'::uuid);
select public.rpc_disburse_loan_account('4a100000-0000-0000-0000-000000000001', :'loan_id'::uuid, :'account_id'::uuid, current_date);

select installment_number, id as installment_id from public.loan_installments
where loan_account_id = :'loan_id'::uuid and installment_number = 1 \gset i1_
select installment_number, id as installment_id from public.loan_installments
where loan_account_id = :'loan_id'::uuid and installment_number = 2 \gset i2_

-- 7/16. A 50,000 payment (exactly installment 1's interest) settles
-- ONLY the interest component — interest-before-principal (section 7).
select public.rpc_post_payment(
  '4a100000-0000-0000-0000-000000000001', '4a200000-0000-0000-0000-000000000005'::uuid, :'account_id'::uuid,
  50000, current_date, 'CASH'
);
select is(
  (select count(*) from public.payment_allocations
   where loan_installment_id = :'i1_installment_id'::uuid and allocation_target_type = 'LOAN_INTEREST'),
  1::bigint,
  '7: interest is an independently allocatable component'
);
select is(
  (select count(*) from public.payment_allocations
   where loan_installment_id = :'i1_installment_id'::uuid and allocation_target_type = 'LOAN_PRINCIPAL'),
  0::bigint,
  '16: within an installment, INTEREST settles before PRINCIPAL (50,000 touched interest only)'
);

-- 8/11. A further 100,000 payment settles installment 1's remaining
-- 250,000 principal partially (100,000 of it) — principal is an
-- independently allocatable component, and partial payment works.
select public.rpc_post_payment(
  '4a100000-0000-0000-0000-000000000001', '4a200000-0000-0000-0000-000000000005'::uuid, :'account_id'::uuid,
  100000, current_date, 'CASH'
);
select is(
  (select sum(amount) from public.payment_allocations
   where loan_installment_id = :'i1_installment_id'::uuid and allocation_target_type = 'LOAN_PRINCIPAL'),
  100000.00::numeric,
  '8: principal is an independently allocatable component'
);
reset role;
select is(
  (select outstanding from public.loan_installment_component_states(:'i1_installment_id'::uuid) where component_type = 'PRINCIPAL'),
  150000.00::numeric,
  '11b: partial payment leaves the correct remaining principal outstanding'
);
set local role authenticated;
set local request.jwt.claim.sub to '4a000000-0000-0000-0000-000000000001';

-- 9/10/12. Allocation never exceeds outstanding — pay EXACTLY
-- installment 1's remaining 150,000 principal; installment 1 must land
-- at exactly zero outstanding (never negative/over-settled) with
-- nothing spilling into installment 2 yet (kept fully outstanding for
-- the tie-break test below).
select public.rpc_post_payment(
  '4a100000-0000-0000-0000-000000000001', '4a200000-0000-0000-0000-000000000005'::uuid, :'account_id'::uuid,
  150000, current_date, 'CASH'
);
reset role;
select is(
  (select coalesce(sum(outstanding), 0) from public.loan_installment_component_states(:'i1_installment_id'::uuid)),
  0.00::numeric,
  '9/10/12: installment 1 settles fully and exactly (never over-allocates, never under)'
);
select is(
  (select coalesce(sum(allocated), 0) from public.loan_installment_component_states(:'i2_installment_id'::uuid)),
  0.00::numeric,
  'setup check: installment 2 is still fully untouched ahead of the tie-break test below'
);
set local role authenticated;
set local request.jwt.claim.sub to '4a000000-0000-0000-0000-000000000001';

-- 15. Contribution obligations settle before loan obligations on an
-- exact due_date tie. Give the SAME borrower a contribution charge due
-- on installment 2's exact due_date, then pay just enough to cover
-- that charge alone — none of it should reach the loan.
select due_date as i2_due_date from public.loan_installments where id = :'i2_installment_id'::uuid \gset

create temporary table t_ctype as
select public.rpc_create_contribution_type(
  '4a100000-0000-0000-0000-000000000001', 'ADA', 'GENERAL', 'GROUP_INCOME'
) as result;
select (result->>'id')::uuid as ctype_id from t_ctype \gset

create temporary table t_setup as
select public.rpc_create_contribution_setup(
  '4a100000-0000-0000-0000-000000000001', :'ctype_id'::uuid, 'ADA Setup', 'MONTHLY', 'FIXED',
  p_fixed_amount => 20000
) as result;
select (result->>'id')::uuid as setup_id from t_setup \gset

create temporary table t_period as
select public.rpc_create_contribution_period(
  '4a100000-0000-0000-0000-000000000001', :'setup_id'::uuid, 'Tie Period', :'i2_due_date'::date, :'i2_due_date'::date,
  p_due_date => :'i2_due_date'::date
) as result;
select (result->>'id')::uuid as period_id from t_period \gset
select public.rpc_open_contribution_period('4a100000-0000-0000-0000-000000000001', :'period_id'::uuid);

select is(
  (select count(*) from public.member_contribution_charges
   where membership_id = '4a200000-0000-0000-0000-000000000005'::uuid and period_id = :'period_id'::uuid),
  1::bigint,
  'setup check: the tied contribution charge exists (fixture sanity, not a scored assertion)'
);

select public.rpc_post_payment(
  '4a100000-0000-0000-0000-000000000001', '4a200000-0000-0000-0000-000000000005'::uuid, :'account_id'::uuid,
  20000, current_date, 'CASH'
);
select is(
  (select count(*) from public.payment_allocations
   where membership_id = '4a200000-0000-0000-0000-000000000005'::uuid
     and allocation_target_type = 'CONTRIBUTION_COMPONENT'
     and created_at > now() - interval '5 seconds'),
  1::bigint,
  '15a: the contribution charge (same due_date as installment 2) is fully allocated'
);
reset role;
select is(
  (select coalesce(sum(allocated), 0) from public.loan_installment_component_states(:'i2_installment_id'::uuid)),
  0.00::numeric,
  '15b: on an exact due_date tie, the contribution absorbs the payment entirely — zero loan allocation occurs'
);
set local role authenticated;
set local request.jwt.claim.sub to '4a000000-0000-0000-0000-000000000001';

-- 13. Multi-installment allocation, oldest-first: a payment now larger
-- than installment 2's entire 300,000 obligation must fully settle
-- installment 2 and spill the remainder into installment 3 — never the
-- reverse order.
select public.rpc_post_payment(
  '4a100000-0000-0000-0000-000000000001', '4a200000-0000-0000-0000-000000000005'::uuid, :'account_id'::uuid,
  350000, current_date, 'CASH'
);
reset role;
select is(
  (select coalesce(sum(outstanding), 0) from public.loan_installment_component_states(:'i2_installment_id'::uuid)),
  0.00::numeric,
  '13a: installment 2 (older) settles fully first'
);
select installment_number, id as installment_id from public.loan_installments
where loan_account_id = :'loan_id'::uuid and installment_number = 3 \gset i3_
select is(
  (select coalesce(sum(allocated), 0) from public.loan_installment_component_states(:'i3_installment_id'::uuid)),
  50000.00::numeric,
  '13b: the remainder spills into installment 3 (next-oldest) only, never out of order'
);
set local role authenticated;
set local request.jwt.claim.sub to '4a000000-0000-0000-0000-000000000001';

-- 17. Cross-group loan allocation rejected — a membership from another
-- group can never be previewed/paid against this group's loan.
reset role;
insert into public.groups (id, name, created_by, code) values
  ('4a100000-0000-0000-0000-000000000099', 'Other Group', '4a000000-0000-0000-0000-000000000001', 'LALX');
insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number) values
  ('4a200000-0000-0000-0000-000000000099', '4a100000-0000-0000-0000-000000000099', null, 'Other Borrower', 'ACTIVE', '2025-01-01', 'LALX-2026-0001');
set local role authenticated;
set local request.jwt.claim.sub to '4a000000-0000-0000-0000-000000000001';

select throws_ok(
  format($sql$ select public.rpc_preview_payment_allocation(
    '4a100000-0000-0000-0000-000000000001', %L, %L, 100000
  ) $sql$, '4a200000-0000-0000-0000-000000000099', :'account_id'),
  '22023',
  null,
  '17: a membership from a different group is rejected, never allocated against this group''s loan'
);

select * from finish();
rollback;
