-- Prompt 08B: reconciliation (section 15-19).
--
-- Compares Umoja's derived account balance against externally verified
-- evidence (bank statement / mobile money statement / physical cash
-- count) at a point in time. A reconciliation record is a READ/AUDIT
-- artifact only — creating one never posts a cashbook entry (section
-- 17: "Do NOT silently alter the cashbook to force reconciliation").
-- If the stated balance differs from the system balance, that
-- difference is simply recorded; resolving it (if ever needed) is a
-- separate, explicit financial_adjustments posting (next migration).
--
-- A finalized reconciliation is immutable: no UPDATE path changes
-- system_balance/stated_balance/difference/reconciled_at once written.
-- The only allowed status transition is RECONCILED -> CANCELLED (an
-- explicit void of a mistaken record), never back, and never a second
-- transition. A correction is always a brand new reconciliation record,
-- never an edit of an old one (section 19).

create type public.financial_reconciliation_status as enum (
  'RECONCILED',
  'CANCELLED'
);

create table public.financial_reconciliations (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id),
  financial_account_id uuid not null references public.financial_accounts (id),
  period_start date,
  reconciliation_at date not null,
  system_balance numeric(14, 2) not null,
  stated_balance numeric(14, 2) not null,
  difference numeric(14, 2) not null,
  status public.financial_reconciliation_status not null default 'RECONCILED',
  notes text,
  reconciled_by uuid not null references auth.users (id),
  reconciled_at timestamptz not null default now(),
  cancelled_at timestamptz,
  cancelled_by uuid references auth.users (id),
  cancellation_reason text,
  created_at timestamptz not null default now(),

  constraint financial_reconciliations_difference_correct check (
    difference = stated_balance - system_balance
  ),
  constraint financial_reconciliations_cancellation_fields_together check (
    (status = 'RECONCILED' and cancelled_at is null and cancelled_by is null and cancellation_reason is null)
    or (status = 'CANCELLED' and cancelled_at is not null and cancelled_by is not null and cancellation_reason is not null)
  )
);

comment on table public.financial_reconciliations is
  'Immutable evidence that a financial account''s derived balance was
  compared against an external statement/count at a point in time
  (Prompt 08B). Never creates or implies a cashbook entry — a non-zero
  difference is recorded as-is, never auto-corrected. system_balance/
  stated_balance/difference/reconciled_at/reconciled_by are never
  updated after insert; the only mutation ever applied is the single
  RECONCILED -> CANCELLED status transition (voiding a mistaken
  record). A correction is always a new reconciliation row.';

create index financial_reconciliations_group_id_idx on public.financial_reconciliations (group_id);
create index financial_reconciliations_account_id_idx
  on public.financial_reconciliations (financial_account_id, reconciliation_at desc);

alter table public.financial_reconciliations enable row level security;
revoke all on public.financial_reconciliations from anon, authenticated;

grant select on public.financial_reconciliations to authenticated;

create policy financial_reconciliations_select
  on public.financial_reconciliations
  for select
  to authenticated
  using (public.has_group_permission(group_id, 'financial_reconciliation.view'));
