-- Prompt 09A: Loan Installment schema — one scheduled repayment
-- obligation per row (section J). This is a PLANNED schedule only —
-- section K is the mandatory distinction: these rows never become
-- collectible debt, are never exposed to Prompt 07 payment allocation,
-- and carry no mutable paid_amount (that would duplicate
-- allocation-ledger truth once Phase 09C introduces loan repayment
-- allocation). total_due is a generated column, never an
-- independently-writable value that could diverge from
-- principal_due + interest_due.

create table public.loan_installments (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id),
  loan_account_id uuid not null references public.loan_accounts (id),

  installment_number integer not null,
  due_date date not null,

  principal_due numeric(14, 2) not null,
  interest_due numeric(14, 2) not null,
  total_due numeric(14, 2) generated always as (principal_due + interest_due) stored,

  created_at timestamptz not null default now(),

  constraint loan_installments_number_positive check (installment_number > 0),
  constraint loan_installments_principal_non_negative check (principal_due >= 0),
  constraint loan_installments_interest_non_negative check (interest_due >= 0)
);

comment on table public.loan_installments is
  'One scheduled repayment obligation for a loan account (Prompt 09A).
  PLANNED only — never collectible debt, never exposed to payment
  allocation, until Phase 09B disburses the loan and Phase 09C
  activates repayment. total_due is always
  principal_due + interest_due, enforced by GENERATED ALWAYS rather
  than trusted as an independently-writable column. No paid_amount
  column: outstanding must eventually be derived from obligations
  minus allocations (Phase 09C), never stored here.';

create unique index loan_installments_account_number_unique
  on public.loan_installments (loan_account_id, installment_number);
create index loan_installments_group_id_idx on public.loan_installments (group_id);
create index loan_installments_loan_account_id_idx on public.loan_installments (loan_account_id);

alter table public.loan_installments enable row level security;
revoke all on public.loan_installments from anon, authenticated;

grant select on public.loan_installments to authenticated;

create policy loan_installments_select
  on public.loan_installments
  for select
  to authenticated
  using (public.has_group_permission(group_id, 'loan_schedule.view'));

-- No INSERT/UPDATE/DELETE grant to authenticated at all (section U) —
-- every row is written exclusively by the SECURITY DEFINER schedule
-- engine in 20260902094000_create_loan_schedule_engine.sql, itself
-- only reachable through the controlled RPCs in
-- 20260902095000_create_loan_account_rpcs.sql. There is no generic
-- edit/delete path over installment rows from Flutter.
