-- Prompt 09D-UAT-BLOCKER-01: Existing Loan / Opening Loan onboarding.
--
-- Core accounting decision (section 1, locked): a loan now has an
-- authoritative ORIGIN — NEW (originated inside Umoja; unchanged 09A-
-- 09D lifecycle: DRAFT -> SUBMITTED -> APPROVED -> DISBURSE -> ACTIVE,
-- disbursement creates a cashbook OUTFLOW + funded receivable) or
-- MIGRATED (already funded before the group started using Umoja;
-- enters as an opening financial position — creates funded principal
-- receivable directly, NEVER a cashbook movement, income, expense,
-- payment, or receipt, and NEVER a fake historical disbursement row).
--
-- Existing 09A-09D loans backfill to NEW via the NOT NULL DEFAULT
-- below — no inference from dates, never silently reclassified.

create type public.loan_origin as enum (
  'NEW',
  'MIGRATED'
);

alter table public.loan_accounts
  add column loan_origin public.loan_origin not null default 'NEW';

comment on column public.loan_accounts.loan_origin is
  'Prompt 09D-UAT-BLOCKER-01. NEW = originated inside Umoja (normal
  DRAFT->...->ACTIVE lifecycle, real disbursement). MIGRATED = already
  funded before Umoja; posted via rpc_create_migrated_loan as an
  opening financial position — see loan_opening_positions. Every
  pre-existing loan backfills to NEW by this column''s default; never
  inferred from dates.';

-- ---------------------------------------------------------------------
-- loan_penalty_charges — gains an origin discriminator (section 16):
-- OPENING (historical penalty debt already owed as of migration,
-- captured directly by rpc_create_migrated_loan) vs ASSESSED (created
-- later by the 09D Penalty Engine, rpc_assess_loan_penalties). Both
-- settle through the exact same Payment Engine and both recognize
-- penalty income only on actual allocation — origin is audit/history
-- only, never a different accounting treatment.
--
-- sequence_number 0 is reserved exclusively for the (at most one)
-- OPENING charge per installment; ASSESSED occurrences keep their
-- existing 1..N numbering, scoped separately (see
-- rpc_assess_loan_penalties''s existing-count query, updated below to
-- filter origin = 'ASSESSED') so an opening charge can never consume
-- a ONCE-frequency installment''s only assessable occurrence, and
-- section 33''s requirement ("the 09D Penalty Engine must be able to
-- assess the migrated overdue obligation if it meets policy") holds.
--
-- An OPENING charge''s basis/rate/fixed-amount/policy-snapshot columns
-- are meaningless (it is an inherited historical amount, not a fresh
-- Umoja calculation) — relaxed to nullable, but only OPENING rows may
-- leave them null.
-- ---------------------------------------------------------------------

create type public.loan_penalty_charge_origin as enum (
  'OPENING',
  'ASSESSED'
);

alter table public.loan_penalty_charges
  add column origin public.loan_penalty_charge_origin not null default 'ASSESSED';

alter table public.loan_penalty_charges
  alter column penalty_type drop not null,
  alter column penalty_frequency drop not null,
  alter column penalty_basis drop not null,
  alter column penalty_grace_days drop not null,
  alter column basis_amount drop not null;

alter table public.loan_penalty_charges
  drop constraint loan_penalty_charges_sequence_positive;
alter table public.loan_penalty_charges
  add constraint loan_penalty_charges_sequence_non_negative check (sequence_number >= 0);

alter table public.loan_penalty_charges
  drop constraint loan_penalty_charges_type_consistency;
alter table public.loan_penalty_charges
  add constraint loan_penalty_charges_origin_consistency check (
    (origin = 'OPENING' and sequence_number = 0)
    or
    (
      origin = 'ASSESSED'
      and sequence_number > 0
      and penalty_type is not null
      and penalty_frequency is not null
      and penalty_basis is not null
      and penalty_grace_days is not null
      and basis_amount is not null
      and (
        (penalty_type = 'FIXED' and fixed_amount is not null and rate is null)
        or
        (penalty_type = 'PERCENTAGE' and rate is not null and fixed_amount is null)
      )
    )
  );

comment on column public.loan_penalty_charges.origin is
  'Prompt 09D-UAT-BLOCKER-01. OPENING = historical penalty debt
  captured at migration (sequence_number always 0, at most one per
  installment). ASSESSED = created by rpc_assess_loan_penalties
  (sequence_number 1..N). Both settle through the same Payment Engine
  and recognize income identically — this is audit/history only.';

-- ---------------------------------------------------------------------
-- loan_opening_positions — immutable, auditable opening-position
-- record (section 11). One row per migrated loan. Never updated or
-- deleted by any RPC in this phase (section 43) — no mutable running-
-- balance column exists; every "current outstanding" figure is still
-- derived from loan_installment_component_states/
-- loan_penalty_charge_states exactly like a NEW loan.
-- ---------------------------------------------------------------------

create table public.loan_opening_positions (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id),
  loan_account_id uuid not null references public.loan_accounts (id),

  opening_as_of_date date not null,
  original_disbursement_date date not null,
  original_loan_number text,

  original_principal numeric(14, 2) not null,
  opening_principal_outstanding numeric(14, 2) not null,
  opening_principal_arrears numeric(14, 2) not null,
  opening_interest_arrears numeric(14, 2) not null,
  opening_penalty_arrears numeric(14, 2) not null,
  future_scheduled_principal numeric(14, 2) not null,
  future_scheduled_interest numeric(14, 2) not null,
  arrears_due_date date,
  remaining_installment_count integer not null,
  next_due_date date,

  notes text,
  idempotency_key text,

  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id),

  constraint loan_opening_positions_original_principal_positive check (original_principal > 0),
  constraint loan_opening_positions_principal_outstanding_non_negative check (opening_principal_outstanding >= 0),
  constraint loan_opening_positions_principal_arrears_non_negative check (opening_principal_arrears >= 0),
  constraint loan_opening_positions_interest_arrears_non_negative check (opening_interest_arrears >= 0),
  constraint loan_opening_positions_penalty_arrears_non_negative check (opening_penalty_arrears >= 0),
  constraint loan_opening_positions_future_principal_non_negative check (future_scheduled_principal >= 0),
  constraint loan_opening_positions_future_interest_non_negative check (future_scheduled_interest >= 0),
  constraint loan_opening_positions_arrears_le_outstanding check (opening_principal_arrears <= opening_principal_outstanding),
  -- Section 20 reconciliation invariant, enforced structurally rather
  -- than merely by rpc-side care: arrears + future must reconstruct
  -- the declared opening principal outstanding exactly.
  constraint loan_opening_positions_principal_reconciles check (
    opening_principal_arrears + future_scheduled_principal = opening_principal_outstanding
  ),
  constraint loan_opening_positions_remaining_installments_non_negative check (remaining_installment_count >= 0),
  constraint loan_opening_positions_arrears_due_date_before_as_of check (
    arrears_due_date is null or arrears_due_date <= opening_as_of_date
  ),
  -- Section 48: reject a fully-settled historical loan (nothing left
  -- to operationally manage) rather than importing it as ACTIVE.
  constraint loan_opening_positions_not_fully_settled check (
    opening_principal_outstanding > 0
    or opening_interest_arrears > 0
    or opening_penalty_arrears > 0
    or future_scheduled_interest > 0
  )
);

comment on table public.loan_opening_positions is
  'Prompt 09D-UAT-BLOCKER-01: one immutable row per MIGRATED loan,
  capturing the exact financial position Umoja takes responsibility
  for as of opening_as_of_date. Never updated/deleted (section 43) —
  a data-entry mistake requires a future controlled correction
  workflow, not implemented here (documented limitation). Creates
  Funded Loan Principal Receivable directly; never a cashbook entry,
  income, expense, payment, or receipt.';

comment on column public.loan_opening_positions.original_disbursement_date is
  'May be arbitrarily far in the past — the normal one-month backdate
  restriction on NEW loan creation does not apply here, since this
  never creates a cashbook transaction (section 7).';
comment on column public.loan_opening_positions.opening_as_of_date is
  'The date at which Umoja takes responsibility for the opening
  position ("these are the balances that existed as at ..."), distinct
  from both created_at (system timestamp) and
  original_disbursement_date (historical reference only).';

create unique index loan_opening_positions_loan_account_unique
  on public.loan_opening_positions (loan_account_id);
create index loan_opening_positions_group_id_idx on public.loan_opening_positions (group_id);
-- Idempotency (section 26): a retried post with the same key can never
-- create a second opening position for the group.
create unique index loan_opening_positions_group_idempotency_unique
  on public.loan_opening_positions (group_id, idempotency_key)
  where idempotency_key is not null;

alter table public.loan_opening_positions enable row level security;
revoke all on public.loan_opening_positions from anon, authenticated;

grant select on public.loan_opening_positions to authenticated;

create policy loan_opening_positions_select
  on public.loan_opening_positions
  for select
  to authenticated
  using (public.has_group_permission(group_id, 'loan.view'));

-- No INSERT/UPDATE/DELETE grant to authenticated — every row is
-- written exclusively by rpc_create_migrated_loan (SECURITY DEFINER),
-- never edited or deleted afterward by any RPC in this phase.

-- ---------------------------------------------------------------------
-- Permission: loan_opening.create (section 41) — a sensitive opening-
-- balance operation, deliberately NOT folded into ordinary
-- loan.create. ADMIN/TREASURER only; CHAIRPERSON/SECRETARY continue to
-- see migrated loans via their existing loan.view grant (no new view
-- permission needed); MEMBER never.
-- ---------------------------------------------------------------------

insert into public.permissions (code, name, description) values
  ('loan_opening.create', 'Add existing (migrated) loans', 'Onboard a loan that was already funded before the group started using Umoja, as an opening financial position.');

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where r.code = 'ADMIN'
  and p.code = 'loan_opening.create'
on conflict do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code = 'loan_opening.create'
where r.code = 'TREASURER';
