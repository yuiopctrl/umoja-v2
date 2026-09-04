-- Prompt 09E: Loan Prepayment, Early Settlement & Restructure
-- Foundation — schema layer.
--
-- CANCELLATION MODEL (section 4/6/7): a loan installment's contractual
-- row is never deleted once it has ever been reachable for payment
-- (it may already carry payment_allocations). Instead, an installment
-- that is superseded by an explicit servicing action (early
-- settlement voiding its never-to-be-earned future interest, or a
-- prepayment/restructure replacing the future schedule) is marked
-- CANCELLED via `cancelled_at` — an auditable state, never a delete
-- (section 7). A cancelled installment's outstanding is zeroed by
-- `loan_installment_component_states` (see
-- 20260913096000_extend_loan_read_rpcs_for_servicing.sql) — its
-- interest was never recognized as income and this never manufactures
-- a fake reversal of income that was never booked (section 5).
--
-- `cancelled_by_payment_id`/`created_by_payment_id` trace an
-- installment back to the exact rpc_settle_loan_early/
-- rpc_prepay_loan_principal payment that cancelled/created it, so
-- rpc_reverse_payment (extended in 20260913097000) can deterministically
-- undo exactly what that one payment did — never a broader, unscoped
-- rollback.
--
-- Future (not-yet-due, zero-allocation) installments replaced by a
-- prepayment/restructure are NEVER deleted either, for the same reason:
-- a reversal must be able to restore them. New replacement installments
-- continue the installment_number sequence from the current maximum,
-- so a cancelled row and its replacement never collide on the existing
-- (loan_account_id, installment_number) unique index.

alter table public.loan_installments
  add column cancelled_at timestamptz,
  add column cancellation_reason text,
  add column cancelled_by_payment_id uuid references public.payments (id),
  add column created_by_payment_id uuid references public.payments (id);

comment on column public.loan_installments.cancelled_at is
  'Prompt 09E. Set once, never cleared except by reversing the exact
  payment that cancelled this row (rpc_reverse_payment). A cancelled
  installment is excluded from outstanding/closure/financial-position
  derivations (loan_installment_component_states) but its row and
  original contractual values are never deleted (section 7).';
comment on column public.loan_installments.cancelled_by_payment_id is
  'The rpc_settle_loan_early/rpc_prepay_loan_principal payment whose
  action cancelled this row, if any. Lets reversal restore exactly
  this row, and only this row, never a broader rollback.';
comment on column public.loan_installments.created_by_payment_id is
  'The rpc_prepay_loan_principal payment that created this row as part
  of a recomputed future schedule (null for every installment created
  by the ordinary 09A schedule engine or a restructure). Reversal may
  only remove a row tagged this way, and only when no allocation has
  since been posted against it (see rpc_reverse_payment).';

-- ---------------------------------------------------------------------
-- payment_allocations — LOAN_PRINCIPAL_PREPAYMENT branch (section 3):
-- populated with loan_account_id only, deliberately NEVER
-- loan_installment_id — a prepayment is not tied to any one scheduled
-- installment, unlike LOAN_PRINCIPAL/LOAN_INTEREST/LOAN_PENALTY.
-- ---------------------------------------------------------------------

alter table public.payment_allocations
  drop constraint payment_allocations_target_consistency;

alter table public.payment_allocations
  add constraint payment_allocations_target_consistency check (
    (
      allocation_target_type = 'CONTRIBUTION_COMPONENT'
      and charge_id is not null
      and charge_component_id is not null
      and loan_account_id is null
      and loan_installment_id is null
      and loan_penalty_charge_id is null
    )
    or
    (
      allocation_target_type in ('LOAN_PRINCIPAL', 'LOAN_INTEREST')
      and charge_id is null
      and charge_component_id is null
      and loan_account_id is not null
      and loan_installment_id is not null
      and loan_penalty_charge_id is null
    )
    or
    (
      allocation_target_type = 'LOAN_PENALTY'
      and charge_id is null
      and charge_component_id is null
      and loan_account_id is not null
      and loan_installment_id is not null
      and loan_penalty_charge_id is not null
    )
    or
    (
      allocation_target_type = 'LOAN_PRINCIPAL_PREPAYMENT'
      and charge_id is null
      and charge_component_id is null
      and loan_account_id is not null
      and loan_installment_id is null
      and loan_penalty_charge_id is null
    )
  );

comment on column public.payment_allocations.allocation_target_type is
  'CONTRIBUTION_COMPONENT (Prompt 07) | LOAN_PRINCIPAL | LOAN_INTEREST
  (Prompt 09C) | LOAN_PENALTY (Prompt 09D) | LOAN_PRINCIPAL_PREPAYMENT
  (Prompt 09E — an explicit principal prepayment, never tied to one
  installment). Discriminates which FK group is populated — see
  payment_allocations_target_consistency.';

-- ---------------------------------------------------------------------
-- loan_reschedule_treatment (section 4): the two explicit, user-chosen
-- future-schedule recalculation policies for a principal prepayment.
-- Never chosen automatically (section 4 — "Do NOT choose
-- automatically").
-- ---------------------------------------------------------------------

create type public.loan_reschedule_treatment as enum (
  'REDUCE_TERM',
  'REDUCE_INSTALLMENT'
);

-- ---------------------------------------------------------------------
-- loan_prepayment_events — immutable audit record of one principal
-- prepayment (section 12). One row per rpc_prepay_loan_principal call;
-- never updated or deleted.
-- ---------------------------------------------------------------------

create table public.loan_prepayment_events (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id),
  loan_account_id uuid not null references public.loan_accounts (id),
  membership_id uuid not null references public.group_memberships (id),
  payment_id uuid not null references public.payments (id),

  effective_date date not null,
  amount numeric(14, 2) not null,
  treatment public.loan_reschedule_treatment not null,

  old_future_schedule_snapshot jsonb not null,
  new_future_schedule_snapshot jsonb not null,

  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id),

  constraint loan_prepayment_events_amount_positive check (amount > 0)
);

comment on table public.loan_prepayment_events is
  'Prompt 09E: one immutable row per principal prepayment, capturing
  the future schedule exactly as it was before and after the
  recalculation, regardless of which loan_installments rows are later
  touched by any further servicing action. Never updated or deleted.';

create unique index loan_prepayment_events_payment_id_unique
  on public.loan_prepayment_events (payment_id);
create index loan_prepayment_events_group_id_idx on public.loan_prepayment_events (group_id);
create index loan_prepayment_events_loan_account_id_idx on public.loan_prepayment_events (loan_account_id);

alter table public.loan_prepayment_events enable row level security;
revoke all on public.loan_prepayment_events from anon, authenticated;

grant select on public.loan_prepayment_events to authenticated;

create policy loan_prepayment_events_select
  on public.loan_prepayment_events
  for select
  to authenticated
  using (public.has_group_permission(group_id, 'loan.view'));

-- ---------------------------------------------------------------------
-- loan_restructure_events — immutable audit record of one restructure
-- (section 6/12). No cash/payment is involved, so there is no
-- payment_id — effective_date/reason/actor are the audit anchor
-- instead.
-- ---------------------------------------------------------------------

create table public.loan_restructure_events (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id),
  loan_account_id uuid not null references public.loan_accounts (id),

  effective_date date not null,
  reason text not null,

  new_interest_rate numeric(7, 4) not null,
  new_term integer not null,
  new_first_installment_date date not null,

  old_remaining_schedule_snapshot jsonb not null,
  new_remaining_schedule_snapshot jsonb not null,

  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id),

  constraint loan_restructure_events_reason_not_blank check (btrim(reason) <> ''),
  constraint loan_restructure_events_new_term_positive check (new_term > 0),
  constraint loan_restructure_events_new_interest_rate_non_negative check (new_interest_rate >= 0)
);

comment on table public.loan_restructure_events is
  'Prompt 09E: one immutable row per confirmed restructure, capturing
  the remaining schedule exactly as it was before and after. Restructure
  changes the future contractual schedule only — already-paid history
  is untouched, and this table is never updated or deleted (section 6).';

create index loan_restructure_events_group_id_idx on public.loan_restructure_events (group_id);
create index loan_restructure_events_loan_account_id_idx on public.loan_restructure_events (loan_account_id);

alter table public.loan_restructure_events enable row level security;
revoke all on public.loan_restructure_events from anon, authenticated;

grant select on public.loan_restructure_events to authenticated;

create policy loan_restructure_events_select
  on public.loan_restructure_events
  for select
  to authenticated
  using (public.has_group_permission(group_id, 'loan.view'));

-- ---------------------------------------------------------------------
-- Permissions (section 10): three sensitive, explicit financial-
-- executor actions on an already-ACTIVE loan — deliberately separate
-- from loan.view/payment.create, following the exact ADMIN+TREASURER
-- posture already locked for loan.disburse/loan_opening.create.
-- CHAIRPERSON/SECRETARY/MEMBER get none of these; they may still VIEW
-- the resulting state via their existing loan.view grant.
-- ---------------------------------------------------------------------

insert into public.permissions (code, name, description) values
  ('loan.settle_early', 'Settle loans early', 'Settle an active loan in full ahead of its scheduled term.'),
  ('loan.prepay_principal', 'Prepay loan principal', 'Apply an explicit lump-sum principal prepayment to an active loan.'),
  ('loan.restructure', 'Restructure loans', 'Propose and confirm a controlled future-schedule restructure for an active loan.');

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where r.code = 'ADMIN'
  and p.code in ('loan.settle_early', 'loan.prepay_principal', 'loan.restructure')
on conflict do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p
  on p.code in ('loan.settle_early', 'loan.prepay_principal', 'loan.restructure')
where r.code = 'TREASURER';
