-- Prompt 09D-UAT-BLOCKER-03: SIMPLE existing-loan import + pre-post
-- schedule preview.
--
-- Problem (section A): requiring a treasurer to manually know
-- principal/interest/penalty PER historical overdue installment is
-- unnecessarily hard when only the original contract terms and the
-- total outstanding arrears are actually known. This migration adds a
-- SIMPLE import mode alongside the existing (unchanged, still fully
-- supported) DETAILED per-installment mode from BLOCKER-02, plus a
-- server-authoritative, non-persisting PREVIEW step that both modes
-- share before any loan is ever created.
--
-- ---------------------------------------------------------------------
-- SIMPLE reconstruction (section D-H) — worked example from section B:
--   original principal 20,000,000; contracted interest 2,000,000;
--   monthly installment 1,834,000; 5 historical unpaid installments;
--   total historical arrears (from old records) 9,494,606.
--
--   contractual_historical_arrears = 5 x 1,834,000 = 9,170,000
--   legacy_penalty_total = 9,494,606 - 9,170,000 = 324,606
--
-- The legacy penalty is a BROUGHT-FORWARD BALANCE only (section B/Z) —
-- it is never a reconstruction of whatever historical penalty rule the
-- group used before Umoja (which may have been whole-balance-based,
-- compounding, or otherwise incompatible with 09D). It is persisted as
-- ordinary OPENING-origin loan_penalty_charges rows, exactly like
-- BLOCKER-01/02, so it settles through the same Payment Engine and
-- remains excluded from 09D's post-migration percentage basis (which
-- already excludes ALL existing penalty regardless of origin).
--
-- Principal/interest split (section F): the ONLY authoritative
-- schedule-generation logic in this codebase is 09A's
-- loan_schedule_compute() trunc-with-remainder-on-the-final-installment
-- technique. Since the real-world monthly installment figure the user
-- already knows (1,834,000) does not evenly divide out of
-- principal/term or interest/term (the worked example's own numbers
-- are NOT a perfectly clean multiple: 12 x 1,834,000 = 22,008,000, not
-- 20,000,000 + 2,000,000 = 22,000,000 — a realistic property of
-- imported historical loans), this migration reuses 09A's exact SPLIT
-- ALGORITHM (equal shares via trunc(total/n, 2), remainder on the
-- final share) applied to the two totals that actually need splitting:
-- the historical arrears total (into per-installment principal/
-- interest) and the loan's overall principal/interest (into a
-- historical portion + a future portion). This preserves the identical
-- exact-money rounding discipline as 09A/BLOCKER-01/02 while still
-- landing on the section-G worked totals (9,170,000 / 324,606) exactly,
-- which the historical schedule engine's rate-based total (a DIFFERENT
-- quantity — the *original* rate applied over the *full* original
-- term) cannot reproduce bit-for-bit given the example's own figures.
--
-- Overall principal/interest split (historical vs future) uses a
-- single proportional fraction — principal_fraction = original_principal
-- / (original_principal + contracted_interest) — applied to the
-- historical contractual arrears total, with the future portion taken
-- as the EXACT remainder against the loan's true original_principal/
-- contracted_interest (never re-derived independently), so:
--   historical_principal + future_principal = original_principal   (exact)
--   historical_interest  + future_interest  = contracted_interest  (exact)
-- by construction, with zero drift regardless of how historical_total
-- and future_total (which are informational cash-due figures, not an
-- independent accounting split) happen to relate to principal+interest.
--
-- ---------------------------------------------------------------------
-- Legacy penalty distribution rule (section H) — EQUAL SPLIT across the
-- historical installments, trunc(total/n, 2) with the exact remainder
-- on the LAST (most recent) historical installment. Alternatives
-- considered:
--   - "oldest-first waterfall" (assign the full penalty to the oldest
--     installment first, capped at some per-installment maximum, then
--     spill to the next): rejected — a legacy penalty balance has no
--     natural per-installment cap to wall against (unlike principal),
--     so a waterfall's "cap" would be arbitrary, not more auditable.
--   - "proportional to each installment's own contractual outstanding":
--     in Simple Import every historical installment shares the exact
--     same monthly_installment_amount by construction, so a
--     proportional rule DEGENERATES to the equal split anyway — the
--     equal-split formula already IS the proportional one here, with a
--     simpler, single well-known formula and zero extra computation.
-- Equal split (remainder on the final/most-recent installment) is
-- therefore chosen: it reuses the codebase's one existing rounding
-- idiom exactly, is trivially auditable (one line of arithmetic), and
-- guarantees SUM(opening penalty rows) = the supplied legacy penalty
-- total exactly, with zero drift. This is explicitly an IMPORT
-- ALLOCATION for opening-balance/reporting purposes only — never a
-- claim that historical penalty was actually assessed this way.
--
-- ---------------------------------------------------------------------
-- Preview architecture (section J/O/P): rpc_preview_migrated_loan
-- shares the SAME reconstruction function used internally by
-- rpc_create_migrated_loan (extended below with p_mode) — never a
-- second, drifting calculator. The preview touches ZERO tables (no
-- loan account, no opening position, no installment, no penalty charge,
-- no cashbook entry) and returns the full historical/future schedule,
-- aggregates, and a zero-cash/zero-income accounting preview. Posting
-- ALWAYS recomputes the same reconstruction server-side from the raw
-- contract inputs — a stale or tampered Flutter-held preview payload
-- can never become authoritative, since Flutter never submits computed
-- principal/interest totals directly; only the original contract
-- figures (principal, contracted interest, monthly installment,
-- historical count, total arrears) are ever accepted as SIMPLE-mode
-- input.

create function public.compute_simple_migrated_loan_reconstruction(
  p_original_principal numeric,
  p_contracted_interest_amount numeric,
  p_monthly_installment_amount numeric,
  p_historical_unpaid_count integer,
  p_total_historical_arrears numeric,
  p_next_due_date date
)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_contractual_historical_arrears numeric;
  v_legacy_penalty_total numeric;
  v_principal_fraction numeric;
  v_hist_principal_total numeric;
  v_hist_interest_total numeric;
  v_future_principal_total numeric;
  v_future_interest_total numeric;
  v_base_principal numeric;
  v_remainder_principal numeric;
  v_base_interest numeric;
  v_remainder_interest numeric;
  v_base_penalty numeric;
  v_remainder_penalty numeric;
  v_historical jsonb := '[]'::jsonb;
  v_due_date date;
  i integer;
begin
  if p_original_principal is null or p_original_principal <= 0 then
    raise exception 'LOAN_OPENING_ORIGINAL_PRINCIPAL_MUST_BE_POSITIVE' using errcode = '22023';
  end if;
  if coalesce(p_contracted_interest_amount, -1) < 0 then
    raise exception 'LOAN_OPENING_SIMPLE_CONTRACTED_INTEREST_INVALID' using errcode = '22023';
  end if;
  if p_monthly_installment_amount is null or p_monthly_installment_amount <= 0 then
    raise exception 'LOAN_OPENING_SIMPLE_INSTALLMENT_AMOUNT_INVALID' using errcode = '22023';
  end if;
  if coalesce(p_historical_unpaid_count, -1) < 0 then
    raise exception 'LOAN_OPENING_SIMPLE_HISTORICAL_COUNT_INVALID' using errcode = '22023';
  end if;
  if coalesce(p_total_historical_arrears, -1) < 0 then
    raise exception 'LOAN_OPENING_SIMPLE_TOTAL_ARREARS_INVALID' using errcode = '22023';
  end if;
  if p_historical_unpaid_count > 0 and p_next_due_date is null then
    raise exception 'LOAN_OPENING_NEXT_DUE_DATE_REQUIRED' using errcode = '22023';
  end if;

  v_contractual_historical_arrears := p_historical_unpaid_count * p_monthly_installment_amount;

  -- Section G: reject rather than silently create a negative penalty.
  if p_total_historical_arrears < v_contractual_historical_arrears then
    raise exception 'LOAN_OPENING_SIMPLE_ARREARS_BELOW_CONTRACTUAL' using errcode = '22023';
  end if;

  v_legacy_penalty_total := p_total_historical_arrears - v_contractual_historical_arrears;

  if (p_original_principal + p_contracted_interest_amount) <= 0 then
    raise exception 'LOAN_OPENING_SIMPLE_CONTRACTED_INTEREST_INVALID' using errcode = '22023';
  end if;
  v_principal_fraction := p_original_principal / (p_original_principal + p_contracted_interest_amount);

  v_hist_principal_total := round(v_contractual_historical_arrears * v_principal_fraction, 2);
  v_hist_interest_total := v_contractual_historical_arrears - v_hist_principal_total;
  v_future_principal_total := p_original_principal - v_hist_principal_total;
  v_future_interest_total := p_contracted_interest_amount - v_hist_interest_total;

  if v_future_principal_total < 0 or v_future_interest_total < 0 then
    raise exception 'LOAN_OPENING_SIMPLE_RECONSTRUCTION_INCONSISTENT' using errcode = '22023';
  end if;

  if p_historical_unpaid_count > 0 then
    v_base_principal := trunc(v_hist_principal_total / p_historical_unpaid_count, 2);
    v_remainder_principal := v_hist_principal_total - v_base_principal * p_historical_unpaid_count;
    v_base_interest := trunc(v_hist_interest_total / p_historical_unpaid_count, 2);
    v_remainder_interest := v_hist_interest_total - v_base_interest * p_historical_unpaid_count;
    v_base_penalty := trunc(v_legacy_penalty_total / p_historical_unpaid_count, 2);
    v_remainder_penalty := v_legacy_penalty_total - v_base_penalty * p_historical_unpaid_count;

    for i in 1..p_historical_unpaid_count loop
      -- Oldest first: due dates count backward, month-safe, anchored to
      -- p_next_due_date (never cumulative), matching 09A/BLOCKER-01's
      -- own anchoring discipline.
      v_due_date := (p_next_due_date - make_interval(months => p_historical_unpaid_count - i + 1))::date;
      v_historical := v_historical || jsonb_build_object(
        'due_date', v_due_date,
        'principal_outstanding', v_base_principal + (case when i = p_historical_unpaid_count then v_remainder_principal else 0 end),
        'interest_outstanding', v_base_interest + (case when i = p_historical_unpaid_count then v_remainder_interest else 0 end),
        'opening_penalty_outstanding', v_base_penalty + (case when i = p_historical_unpaid_count then v_remainder_penalty else 0 end)
      );
    end loop;
  end if;

  return jsonb_build_object(
    'contractual_historical_arrears', v_contractual_historical_arrears,
    'legacy_penalty_total', v_legacy_penalty_total,
    'historical_installments', v_historical,
    'opening_principal_outstanding', p_original_principal,
    'future_scheduled_principal', v_future_principal_total,
    'future_scheduled_interest', v_future_interest_total
  );
end;
$$;

revoke all on function public.compute_simple_migrated_loan_reconstruction(
  numeric, numeric, numeric, integer, numeric, date
) from public, anon, authenticated;

comment on function public.compute_simple_migrated_loan_reconstruction is
  'Prompt 09D-UAT-BLOCKER-03: pure, side-effect-free SIMPLE-import
  reconstruction — shared by rpc_preview_migrated_loan and
  rpc_create_migrated_loan (SIMPLE mode) so preview and posting can
  never drift. See migration comment for the full derivation and the
  documented legacy-penalty-distribution rule (equal split, remainder
  on the most recent historical installment).';
