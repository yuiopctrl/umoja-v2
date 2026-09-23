-- Prompt 09F-B: Loan Write-Off & Recovery — foundation schema.
--
-- ---------------------------------------------------------------------
-- LOCKED MODEL (v1, full write-off only)
-- ---------------------------------------------------------------------
-- A write-off is a LOAN-LEVEL, immutable, append-only event
-- (loan_write_off_events) that freezes the server-computed remaining
-- principal/earned-interest/penalty at the moment of write-off and
-- flips loan_accounts.status to the new 'WRITTEN_OFF' value. It is
-- deliberately NOT modeled as a 09F-A loan_obligation_adjustments row
-- (WAIVER) — a waiver forgives one component on a loan that keeps
-- being serviced; a write-off is a whole-loan lifecycle event with its
-- own recovery tracking, distinct terminal status, and reversal rules.
-- Neither loan_installments nor loan_penalty_charges nor any 09F-A
-- adjustment row is touched, deleted, or rewritten by a write-off —
-- the event table alone carries the frozen amounts, and the loan
-- simply stops being 'ACTIVE' (which already, structurally, excludes
-- it from every existing servicing/allocation path — see
-- loan_member_allocatable_installments's `la.status = 'ACTIVE'`
-- filter, 20260906090000).
--
-- Future/unearned interest (due_date > effective_date) is NEVER
-- written off — only earned/payable interest, mirroring exactly the
-- same due-date gate already used by 09F-A waiver/correction and 09E
-- early settlement. Principal has no such gate (all scheduled
-- principal, due or not, is real debt and is always included, exactly
-- as early settlement already treats it). Penalty (any due date) is
-- always included, also matching early settlement.
--
-- Recovery is a REAL cash event that reuses the existing Payment
-- Engine's own building blocks — the same public.payments table, the
-- same public.payment_generate_receipt_number(), the same
-- public.financial_account_post_entry() cashbook posting, and the
-- same public.payment_allocations table (via three new
-- allocation_target_type values, LOAN_RECOVERY_PRINCIPAL/INTEREST/
-- PENALTY, populated with loan_account_id only — the exact precedent
-- already established by LOAN_PRINCIPAL_PREPAYMENT for "not tied to
-- one installment", 20260913092000). loan_recovery_events links each
-- recovery immutably to the write-off it recovers against and to the
-- payment row it created — it never duplicates cash-handling logic.
-- Recovery reversal is NOT a bespoke mechanism: reversing the
-- underlying payment via the existing rpc_reverse_payment is the
-- entire mechanism (see 20260919094000).

alter type public.loan_account_status add value 'WRITTEN_OFF';

comment on type public.loan_account_status is
  'Prompt 09A/09F-B. WRITTEN_OFF (09F-B) is reached only from ACTIVE and
  is distinct from CANCELLED (never disbursed)/CLOSED (paid to zero
  through ordinary servicing and/or 09F-A adjustments). A written-off
  loan can be reversed back to ACTIVE only while no dependent recovery
  activity exists.';

alter type public.loan_account_event_type add value 'WRITTEN_OFF';
alter type public.loan_account_event_type add value 'WRITE_OFF_REVERSED';
alter type public.loan_account_event_type add value 'RECOVERY_RECORDED';
alter type public.loan_account_event_type add value 'RECOVERY_REVERSED';

-- ---------------------------------------------------------------------
-- loan_write_off_events — append-only. At most one non-reversed
-- WRITE_OFF row may exist per loan at a time (enforced by a partial
-- unique index below, mirroring exactly how 09F-A's
-- loan_obligation_adjustments enforces "one reversal per adjustment").
-- A REVERSAL row's three amount columns hold the exact negative of the
-- WRITE_OFF row it reverses, so summing all non-reversed rows for a
-- loan always yields the true current write-off state without ever
-- rewriting the original row.
-- ---------------------------------------------------------------------

create table public.loan_write_off_events (
  id uuid primary key default gen_random_uuid(),
  -- Monotonic insertion-order tiebreak (same rationale as 09F-A's
  -- loan_obligation_adjustments.entry_no, 20260916090000): created_at
  -- is the TRANSACTION timestamp, identical for every row inserted
  -- within one transaction, so "most recent write-off for this loan"
  -- must never be resolved via created_at alone.
  entry_no bigint generated always as identity,
  group_id uuid not null references public.groups (id),
  loan_account_id uuid not null references public.loan_accounts (id),

  event_type text not null,
  reverses_write_off_id uuid references public.loan_write_off_events (id),

  principal_amount numeric(14, 2) not null,
  interest_amount numeric(14, 2) not null,
  penalty_amount numeric(14, 2) not null,

  reason_code text not null,
  note text,
  effective_date date not null,

  created_by uuid references auth.users (id),
  created_at timestamptz not null default now(),

  constraint loan_write_off_events_event_type_valid check (
    event_type in ('WRITE_OFF', 'REVERSAL')
  ),
  constraint loan_write_off_events_reversal_consistency check (
    (event_type = 'REVERSAL' and reverses_write_off_id is not null)
    or (event_type = 'WRITE_OFF' and reverses_write_off_id is null)
  ),
  -- Sign convention: a WRITE_OFF's three amounts are each >= 0 (a
  -- component with nothing outstanding is simply written off as
  -- 0 — never negative); a REVERSAL's are each <= 0, exactly negating
  -- what it reverses. Total (principal+interest+penalty) must be > 0
  -- for a WRITE_OFF — there is nothing to write off otherwise.
  constraint loan_write_off_events_sign_convention check (
    (event_type = 'WRITE_OFF'
      and principal_amount >= 0 and interest_amount >= 0 and penalty_amount >= 0
      and (principal_amount + interest_amount + penalty_amount) > 0)
    or
    (event_type = 'REVERSAL'
      and principal_amount <= 0 and interest_amount <= 0 and penalty_amount <= 0)
  ),
  constraint loan_write_off_events_reason_code_valid check (
    (event_type = 'WRITE_OFF' and reason_code in (
      'PROLONGED_DEFAULT', 'BORROWER_DECEASED', 'BORROWER_UNTRACEABLE',
      'UNCOLLECTIBLE_COST', 'GROUP_DECISION', 'OTHER'
    ))
    or
    (event_type = 'REVERSAL' and btrim(reason_code) <> '')
  ),
  constraint loan_write_off_events_other_requires_note check (
    reason_code <> 'OTHER' or (note is not null and btrim(note) <> '')
  )
);

-- No "one active WRITE_OFF per loan" unique index here: a loan can be
-- written off, reversed, and legitimately written off again later (a
-- fresh default after being reactivated). That "at most one live
-- write-off at a time" invariant is already enforced by
-- loan_accounts.status itself — rpc_post_loan_write_off requires
-- status = 'ACTIVE' (row-locked FOR UPDATE), which a loan can only be
-- in once at a time, exactly like every other loan lifecycle
-- transition in this codebase (no redundant per-status unique index
-- exists for DISBURSED/CLOSED either). A row-level index keyed only on
-- (loan_account_id) where event_type='WRITE_OFF' would incorrectly
-- block that legitimate second write-off, since the original
-- (reversed) WRITE_OFF row is never deleted or mutated.

create unique index loan_write_off_events_reverses_write_off_id_unique
  on public.loan_write_off_events (reverses_write_off_id)
  where reverses_write_off_id is not null;

create index loan_write_off_events_loan_account_id_idx
  on public.loan_write_off_events (loan_account_id);
create index loan_write_off_events_group_id_idx
  on public.loan_write_off_events (group_id);

comment on table public.loan_write_off_events is
  'Prompt 09F-B: immutable, append-only whole-loan write-off history.
  Never updated or deleted. principal_amount/interest_amount/
  penalty_amount are the frozen server-computed remaining obligation at
  write-off time (earned/payable interest only — never future/unearned;
  principal and penalty always in full, matching early settlement''s
  existing treatment). A REVERSAL row negates a WRITE_OFF row entirely,
  never partially. "At most one live write-off at a time" is enforced
  by loan_accounts.status (ACTIVE required to post), not by a table
  constraint here — a loan may be legitimately written off more than
  once over its lifetime (write off, reverse, default again later).';

alter table public.loan_write_off_events enable row level security;
revoke all on public.loan_write_off_events from anon, authenticated;
grant select on public.loan_write_off_events to authenticated;

create policy loan_write_off_events_select
  on public.loan_write_off_events
  for select
  to authenticated
  using (public.has_group_permission(group_id, 'loan.view'));

-- ---------------------------------------------------------------------
-- loan_recovery_events — append-only, one row per recovery payment.
-- payment_id links immutably to the real public.payments row this
-- recovery created (the actual cash event, via the existing Payment
-- Engine's own posting primitives — see 20260919094000).
-- write_off_event_id links immutably to the write-off being recovered
-- against. There is no separate "reversal" row for a recovery — a
-- recovery is reversed purely by reversing its underlying payment via
-- the existing rpc_reverse_payment (section C); every "remaining
-- recoverable" computation therefore joins to public.payments and
-- filters status='POSTED', exactly the same live-derivation pattern
-- used everywhere else in this codebase.
-- ---------------------------------------------------------------------

create table public.loan_recovery_events (
  id uuid primary key default gen_random_uuid(),
  -- Same monotonic tiebreak rationale as loan_write_off_events.entry_no
  -- above — used to order recovery history deterministically.
  entry_no bigint generated always as identity,
  group_id uuid not null references public.groups (id),
  loan_account_id uuid not null references public.loan_accounts (id),
  write_off_event_id uuid not null references public.loan_write_off_events (id),
  payment_id uuid not null references public.payments (id),

  principal_recovered numeric(14, 2) not null default 0,
  interest_recovered numeric(14, 2) not null default 0,
  penalty_recovered numeric(14, 2) not null default 0,

  created_by uuid references auth.users (id),
  created_at timestamptz not null default now(),

  constraint loan_recovery_events_amounts_non_negative check (
    principal_recovered >= 0 and interest_recovered >= 0 and penalty_recovered >= 0
  ),
  constraint loan_recovery_events_total_positive check (
    (principal_recovered + interest_recovered + penalty_recovered) > 0
  )
);

create unique index loan_recovery_events_payment_id_unique
  on public.loan_recovery_events (payment_id);
create index loan_recovery_events_write_off_event_id_idx
  on public.loan_recovery_events (write_off_event_id);
create index loan_recovery_events_loan_account_id_idx
  on public.loan_recovery_events (loan_account_id);
create index loan_recovery_events_group_id_idx
  on public.loan_recovery_events (group_id);

comment on table public.loan_recovery_events is
  'Prompt 09F-B: immutable, append-only recovery history. Never
  updated or deleted — reversed purely by reversing the linked
  public.payments row via the existing rpc_reverse_payment. Every
  "remaining recoverable" computation must join to public.payments and
  filter status=''POSTED'' rather than trusting this table''s presence
  alone.';

alter table public.loan_recovery_events enable row level security;
revoke all on public.loan_recovery_events from anon, authenticated;
grant select on public.loan_recovery_events to authenticated;

create policy loan_recovery_events_select
  on public.loan_recovery_events
  for select
  to authenticated
  using (public.has_group_permission(group_id, 'loan.view'));
