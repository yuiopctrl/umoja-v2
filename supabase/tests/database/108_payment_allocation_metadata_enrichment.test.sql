-- Prompt 09G-B3-UX-01-FIX-01 §E: proves rpc_get_my_member_statement's
-- PAYMENT activity allocations additively carry period_label/
-- component_type for CONTRIBUTION_COMPONENT allocations (resolved via
-- the SAME charge_id/charge_component_id FKs the response already
-- returned), are null for LOAN_* allocations (no charge/
-- charge_component on those rows), and that nothing else about the
-- allocation (amount/target_type) or the function's own public
-- signature changed.
begin;

select plan(9);

-- =====================================================================
-- Fixtures
-- =====================================================================

insert into auth.users (id, email) values
  ('10800000-0000-0000-0000-000000000011', 'p09gfix01-admin@example.com'),
  ('10800000-0000-0000-0000-000000000012', 'p09gfix01-member@example.com');

insert into public.groups (id, name, created_by, code, status) values
  ('10800000-0000-0000-0000-000000000001', 'Allocation Clarity Group', '10800000-0000-0000-0000-000000000011', 'ALLOCX', 'ACTIVE');

insert into public.group_memberships (id, group_id, user_id, display_name, status, joined_at, member_number, phone) values
  ('10800000-0000-0000-0000-000000000101', '10800000-0000-0000-0000-000000000001', '10800000-0000-0000-0000-000000000011', 'Admin One', 'ACTIVE', '2026-01-01', 'ALLOCX-0001', null),
  ('10800000-0000-0000-0000-000000000102', '10800000-0000-0000-0000-000000000001', '10800000-0000-0000-0000-000000000012', 'Allocation Caller', 'ACTIVE', '2026-01-02', 'ALLOCX-0002', null);

insert into public.group_membership_roles (group_membership_id, role_id) select '10800000-0000-0000-0000-000000000101', id from public.roles where code = 'ADMIN';
insert into public.group_membership_roles (group_membership_id, role_id) select '10800000-0000-0000-0000-000000000102', id from public.roles where code = 'MEMBER' on conflict (group_membership_id, role_id) do nothing;

insert into public.financial_accounts (id, group_id, name, account_type) values
  ('10800000-0000-0000-0000-000000000201', '10800000-0000-0000-0000-000000000001', 'Cash Box', 'CASH');

-- Two DISTINCT periods/charges so two CONTRIBUTION_COMPONENT
-- allocations are provably distinguishable from each other, not just
-- from a loan allocation.
insert into public.contribution_types (id, group_id, name, category, accounting_treatment) values
  ('10800000-0000-0000-0000-000000000301', '10800000-0000-0000-0000-000000000001', 'Monthly Dues', 'GENERAL', 'GROUP_INCOME');
insert into public.contribution_setups (id, group_id, contribution_type_id, name, schedule_mode, amount_mode, fixed_amount) values
  ('10800000-0000-0000-0000-000000000302', '10800000-0000-0000-0000-000000000001', '10800000-0000-0000-0000-000000000301', 'Dues Setup', 'ON_DEMAND', 'FIXED', 50000);

insert into public.contribution_periods (id, group_id, contribution_setup_id, label, period_start, period_end, obligation_date, eligibility_date, due_date, status, purpose) values
  ('10800000-0000-0000-0000-000000000303', '10800000-0000-0000-0000-000000000001', '10800000-0000-0000-0000-000000000302', 'Ada ya Septemba', '2026-09-01', '2026-09-30', '2026-09-01', '2026-09-01', '2026-09-15', 'OPEN', 'NORMAL'),
  ('10800000-0000-0000-0000-000000000304', '10800000-0000-0000-0000-000000000001', '10800000-0000-0000-0000-000000000302', 'Mkutano Mkuu', '2026-08-01', '2026-08-31', '2026-08-01', '2026-08-01', '2026-08-15', 'OPEN', 'NORMAL');

insert into public.member_contribution_charges (id, group_id, period_id, contribution_setup_id, membership_id, member_number_snapshot, member_name_snapshot, effective_at, due_date) values
  ('10800000-0000-0000-0000-000000000401', '10800000-0000-0000-0000-000000000001', '10800000-0000-0000-0000-000000000303', '10800000-0000-0000-0000-000000000302', '10800000-0000-0000-0000-000000000102', 'ALLOCX-0002', 'Allocation Caller', '2026-09-01', '2026-09-15'),
  ('10800000-0000-0000-0000-000000000402', '10800000-0000-0000-0000-000000000001', '10800000-0000-0000-0000-000000000304', '10800000-0000-0000-0000-000000000302', '10800000-0000-0000-0000-000000000102', 'ALLOCX-0002', 'Allocation Caller', '2026-08-01', '2026-08-15');

insert into public.contribution_charge_components (id, group_id, charge_id, component_type, assessed_amount, effective_at, sequence) values
  ('10800000-0000-0000-0000-000000000501', '10800000-0000-0000-0000-000000000001', '10800000-0000-0000-0000-000000000401', 'BASE', 3000, '2026-09-01', 1),
  ('10800000-0000-0000-0000-000000000502', '10800000-0000-0000-0000-000000000001', '10800000-0000-0000-0000-000000000402', 'PENALTY', 6000, '2026-08-01', 1);

-- Minimal loan, for one LOAN_PRINCIPAL allocation (proves the LEFT
-- JOIN correctly resolves null, not a crash/missing-key, for a
-- target_type with no charge/charge_component).
insert into public.loan_products (id, group_id, code, name, minimum_principal, maximum_principal, minimum_term, maximum_term, interest_rate, interest_rate_basis, interest_method) values
  ('10800000-0000-0000-0000-000000000601', '10800000-0000-0000-0000-000000000001', 'STD', 'Standard Loan', 10000, 500000, 1, 12, 5, 'MONTHLY', 'FLAT');
insert into public.loan_accounts (id, group_id, membership_id, loan_product_id, loan_number, principal_amount, interest_rate, interest_rate_basis, interest_method, term, term_unit, repayment_frequency, first_repayment_date, status) values
  ('10800000-0000-0000-0000-000000000701', '10800000-0000-0000-0000-000000000001', '10800000-0000-0000-0000-000000000102', '10800000-0000-0000-0000-000000000601', 'LN-ALLOCX-001', 250000, 5, 'MONTHLY', 'FLAT', 12, 'MONTH', 'MONTHLY', '2026-07-01', 'ACTIVE');
insert into public.loan_installments (id, group_id, loan_account_id, installment_number, due_date, principal_due, interest_due) values
  ('10800000-0000-0000-0000-000000000711', '10800000-0000-0000-0000-000000000001', '10800000-0000-0000-0000-000000000701', 1, '2026-08-01', 250000, 0);

insert into public.payments (id, group_id, membership_id, financial_account_id, amount, effective_at, payment_method, status, receipt_number) values
  ('10800000-0000-0000-0000-000000000801', '10800000-0000-0000-0000-000000000001', '10800000-0000-0000-0000-000000000102', '10800000-0000-0000-0000-000000000201', 259000, '2026-09-05', 'CASH', 'POSTED', 'ALLOCX-RCPT-0001');

insert into public.payment_allocations (id, group_id, payment_id, membership_id, allocation_target_type, charge_id, charge_component_id, amount, line_number) values
  ('10800000-0000-0000-0000-000000000811', '10800000-0000-0000-0000-000000000001', '10800000-0000-0000-0000-000000000801', '10800000-0000-0000-0000-000000000102', 'CONTRIBUTION_COMPONENT', '10800000-0000-0000-0000-000000000401', '10800000-0000-0000-0000-000000000501', 3000, 1),
  ('10800000-0000-0000-0000-000000000812', '10800000-0000-0000-0000-000000000001', '10800000-0000-0000-0000-000000000801', '10800000-0000-0000-0000-000000000102', 'CONTRIBUTION_COMPONENT', '10800000-0000-0000-0000-000000000402', '10800000-0000-0000-0000-000000000502', 6000, 2);
insert into public.payment_allocations (id, group_id, payment_id, membership_id, allocation_target_type, loan_account_id, loan_installment_id, amount, line_number) values
  ('10800000-0000-0000-0000-000000000813', '10800000-0000-0000-0000-000000000001', '10800000-0000-0000-0000-000000000801', '10800000-0000-0000-0000-000000000102', 'LOAN_PRINCIPAL', '10800000-0000-0000-0000-000000000701', '10800000-0000-0000-0000-000000000711', 250000, 3);

-- =====================================================================
-- Assertions
-- =====================================================================

set local request.jwt.claim.sub to '10800000-0000-0000-0000-000000000012';
set local role authenticated;

-- 1: public signature unchanged by this migration — still no
-- membership_id/user_id/phone/role_id parameter.
select is(
  (select count(*)::integer from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'rpc_get_my_member_statement'
     and pg_get_function_arguments(p.oid) = 'p_group_id uuid, p_from_date date DEFAULT NULL::date, p_to_date date DEFAULT NULL::date, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0'),
  1,
  '1: rpc_get_my_member_statement signature is unchanged by the enrichment'
);

create temp table resp as
select public.rpc_get_my_member_statement('10800000-0000-0000-0000-000000000001'::uuid, null, null, 100, 0) as doc;

create temp table allocs as
select a.value as alloc
from resp, jsonb_array_elements(resp.doc -> 'activity' -> 'items') i(value)
cross join lateral jsonb_array_elements(i.value -> 'metadata' -> 'allocations') a(value)
where (i.value ->> 'domain') = 'PAYMENT';

-- 2/3: the BASE allocation (Ada ya Septemba) carries its real period
-- label and component_type — not a bare "Contribution".
select is(
  (select alloc ->> 'period_label' from allocs where alloc ->> 'charge_component_id' = '10800000-0000-0000-0000-000000000501'),
  'Ada ya Septemba',
  '2: the BASE allocation''s period_label is the real persisted contribution_periods.label'
);
select is(
  (select alloc ->> 'component_type' from allocs where alloc ->> 'charge_component_id' = '10800000-0000-0000-0000-000000000501'),
  'BASE',
  '3: the BASE allocation''s component_type is the real persisted contribution_charge_components.component_type'
);

-- 4/5: the PENALTY allocation (Mkutano Mkuu) is distinguishable from
-- the BASE allocation above — different period, different component
-- type — never mislabeled as an ordinary BASE contribution.
select is(
  (select alloc ->> 'period_label' from allocs where alloc ->> 'charge_component_id' = '10800000-0000-0000-0000-000000000502'),
  'Mkutano Mkuu',
  '4: the PENALTY allocation''s period_label is its own distinct period, not the BASE allocation''s'
);
select is(
  (select alloc ->> 'component_type' from allocs where alloc ->> 'charge_component_id' = '10800000-0000-0000-0000-000000000502'),
  'PENALTY',
  '5: the PENALTY allocation''s component_type is PENALTY, never BASE'
);

-- 6/7: the LOAN_PRINCIPAL allocation has no charge/charge_component —
-- period_label/component_type resolve to null (deterministic
-- non-leakage), never a fabricated/fallback value.
select is(
  (select alloc ->> 'period_label' from allocs where alloc ->> 'loan_installment_id' = '10800000-0000-0000-0000-000000000711'),
  null,
  '6: a LOAN_PRINCIPAL allocation has null period_label'
);
select is(
  (select alloc ->> 'component_type' from allocs where alloc ->> 'loan_installment_id' = '10800000-0000-0000-0000-000000000711'),
  null,
  '7: a LOAN_PRINCIPAL allocation has null component_type'
);

-- 8/9: additive only — amount/target_type for every allocation are
-- exactly what was persisted, unchanged by this enrichment.
select is(
  (select sum((alloc ->> 'amount')::numeric) from allocs),
  259000::numeric,
  '8: allocation amounts are unchanged by the enrichment (3000 + 6000 + 250000)'
);
select is(
  (select alloc ->> 'target_type' from allocs where alloc ->> 'charge_component_id' = '10800000-0000-0000-0000-000000000501'),
  'CONTRIBUTION_COMPONENT',
  '9: target_type is still returned unchanged alongside the new fields'
);

select * from finish();
rollback;
