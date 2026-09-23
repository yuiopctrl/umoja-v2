-- Prompt 09F-A: Loan Waivers & Corrections — dedicated append-only
-- ledger schema (audit decision: a dedicated loan_obligation_adjustments
-- table, NOT a reuse of contribution_charge_components — the two domains
-- store obligations completely differently; see the 09F-A audit report
-- section 7/8).
--
-- Every row is one immutable, signed accounting effect against exactly
-- one existing obligation anchor:
--   LOAN_PENALTY  -> loan_penalty_charges.id  (immutable assessment row)
--   LOAN_INTEREST -> loan_installments.id     (interest component only)
-- Principal is structurally impossible to target (no principal anchor
-- column exists, and target_type only ever accepts the two values
-- above). Rows are never UPDATEd/DELETEd by any RPC — a mistaken
-- adjustment is corrected by posting a REVERSAL row that references it
-- (reverses_adjustment_id), never by editing history.
--
-- Sign convention (locked, section 6):
--   WAIVER               amount < 0  (decreases obligation)
--   CORRECTION_DECREASE  amount < 0  (decreases obligation)
--   CORRECTION_INCREASE  amount > 0  (increases obligation)
--   REVERSAL             amount = -1 * the adjustment it reverses
-- "Effective outstanding" for a target is therefore always
-- gross + sum(loan_obligation_adjustments.amount for that target) -
-- allocated, computed by the extended loan_installment_component_states/
-- loan_penalty_charge_states (next migration) — never a second, separate
-- derivation.

create table public.loan_obligation_adjustments (
  id uuid primary key default gen_random_uuid(),
  -- Monotonic insertion-order tiebreak for the reversal dependency guard
  -- (section 17): "was a later adjustment posted on this same target"
  -- must be determinable independent of wall-clock timestamp precision
  -- (two adjustments posted in rapid succession, or in the same test
  -- transaction, can otherwise share an identical created_at).
  entry_no bigint generated always as identity,
  group_id uuid not null references public.groups (id),
  loan_account_id uuid not null references public.loan_accounts (id),

  target_type text not null,
  loan_penalty_charge_id uuid references public.loan_penalty_charges (id),
  loan_installment_id uuid references public.loan_installments (id),

  adjustment_type text not null,
  amount numeric(14, 2) not null,

  reason_code text not null,
  note text,
  effective_date date not null default current_date,

  idempotency_key text,
  reverses_adjustment_id uuid references public.loan_obligation_adjustments (id),

  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id),

  constraint loan_obligation_adjustments_target_type_valid check (
    target_type in ('LOAN_PENALTY', 'LOAN_INTEREST')
  ),
  constraint loan_obligation_adjustments_adjustment_type_valid check (
    adjustment_type in ('WAIVER', 'CORRECTION_DECREASE', 'CORRECTION_INCREASE', 'REVERSAL')
  ),

  -- Structural target consistency (section 5): a LOAN_PENALTY row is
  -- anchored ONLY via the charge (its installment relationship resolves
  -- through loan_penalty_charges.loan_installment_id, never a second,
  -- independently-storable installment reference that could drift out
  -- of sync); a LOAN_INTEREST row is anchored ONLY via the installment.
  -- Principal is structurally impossible — no column exists for it.
  constraint loan_obligation_adjustments_target_consistency check (
    (target_type = 'LOAN_PENALTY' and loan_penalty_charge_id is not null and loan_installment_id is null)
    or
    (target_type = 'LOAN_INTEREST' and loan_installment_id is not null and loan_penalty_charge_id is null)
  ),

  constraint loan_obligation_adjustments_amount_nonzero check (amount <> 0),
  constraint loan_obligation_adjustments_sign_convention check (
    (adjustment_type in ('WAIVER', 'CORRECTION_DECREASE') and amount < 0)
    or (adjustment_type = 'CORRECTION_INCREASE' and amount > 0)
    or (adjustment_type = 'REVERSAL')
  ),

  -- Locked matrix (section 2): interest correction increases are always
  -- rejected, enforced structurally, not merely by RPC validation.
  constraint loan_obligation_adjustments_no_interest_increase check (
    not (target_type = 'LOAN_INTEREST' and adjustment_type = 'CORRECTION_INCREASE')
  ),

  -- A REVERSAL must reference the adjustment it reverses; every other
  -- type must NOT — this is what makes it structurally impossible for a
  -- reversal to "masquerade as" a normal waiver/correction (section 5).
  constraint loan_obligation_adjustments_reversal_consistency check (
    (adjustment_type = 'REVERSAL' and reverses_adjustment_id is not null)
    or (adjustment_type <> 'REVERSAL' and reverses_adjustment_id is null)
  ),

  -- Reason model (section 7): WAIVER/CORRECTION each have their own
  -- fixed vocabulary (both allow OTHER); a REVERSAL's "reason" is the
  -- free-text reversal reason instead, only required to be non-blank.
  constraint loan_obligation_adjustments_reason_code_valid check (
    (adjustment_type = 'WAIVER'
      and reason_code in ('HARDSHIP', 'COMMITTEE_DECISION', 'GOODWILL', 'SETTLEMENT_CONCESSION', 'OTHER'))
    or (adjustment_type in ('CORRECTION_DECREASE', 'CORRECTION_INCREASE')
      and reason_code in ('ASSESSMENT_ERROR', 'DATA_ENTRY_ERROR', 'MIGRATION_ERROR', 'OTHER'))
    or (adjustment_type = 'REVERSAL' and btrim(reason_code) <> '')
  ),
  constraint loan_obligation_adjustments_other_requires_note check (
    reason_code <> 'OTHER' or (note is not null and btrim(note) <> '')
  )
);

comment on table public.loan_obligation_adjustments is
  'Prompt 09F-A: append-only ledger of loan penalty/interest waivers,
  corrections, and their reversals. Never UPDATEd/DELETEd. Every row is
  a signed accounting effect against one immutable anchor
  (loan_penalty_charges.id or loan_installments.id) — see
  loan_installment_component_states/loan_penalty_charge_states for how
  these net into effective outstanding. Principal is structurally
  unreachable.';

-- Idempotency backstop (section 14) — the same partial-unique-index
-- pattern used by payments/loan_prepayment_events/etc across this
-- codebase.
create unique index loan_obligation_adjustments_idempotency_key_unique
  on public.loan_obligation_adjustments (group_id, idempotency_key)
  where idempotency_key is not null;

-- At most one reversal per adjustment (section 17 — "already-reversed
-- adjustment must reject"), enforced structurally as a second backstop
-- alongside the RPC-level check.
create unique index loan_obligation_adjustments_reverses_adjustment_id_unique
  on public.loan_obligation_adjustments (reverses_adjustment_id)
  where reverses_adjustment_id is not null;

create index loan_obligation_adjustments_group_id_idx on public.loan_obligation_adjustments (group_id);
create index loan_obligation_adjustments_loan_account_id_idx on public.loan_obligation_adjustments (loan_account_id, created_at);
create index loan_obligation_adjustments_loan_penalty_charge_id_idx
  on public.loan_obligation_adjustments (loan_penalty_charge_id) where loan_penalty_charge_id is not null;
create index loan_obligation_adjustments_loan_installment_id_idx
  on public.loan_obligation_adjustments (loan_installment_id) where loan_installment_id is not null;

alter table public.loan_obligation_adjustments enable row level security;

-- Read-only to clients — every write goes through the SECURITY DEFINER
-- rpc_post_loan_obligation_waiver/rpc_post_loan_obligation_correction/
-- rpc_reverse_loan_obligation_adjustment RPCs (section 16). No
-- insert/update/delete policy is ever added for authenticated — direct
-- client mutation is structurally impossible.
revoke all on public.loan_obligation_adjustments from anon, authenticated;
grant select on public.loan_obligation_adjustments to authenticated;

create policy loan_obligation_adjustments_select
  on public.loan_obligation_adjustments
  for select
  to authenticated
  using (public.has_group_permission(group_id, 'loan.view'));
