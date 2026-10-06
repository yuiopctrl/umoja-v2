-- Prompt 09G-B5-A3: Loan historical position correction (append-only).
--
-- Corrects the historical loan as-of defect confirmed by 09G-B5-A1:
--   * installments were treated as existing/cancelled at every date
--     (cancellation and replacement provenance was ignored);
--   * payment reversal was judged by the CURRENT status instead of the
--     reversal effective date;
--   * scheduled/unearned interest was included in outstanding;
--   * MIGRATED loans returned current schedule amounts before their
--     original disbursement and before their opening position;
--   * a written-off loan could still show an outstanding receivable in
--     the current summary.
--
-- Locked definitions (09G-B5-A3 §B), implemented here:
--   principal outstanding   = remaining funded principal receivable
--   earned interest         = interest payable by the business date
--                             (due_date <= D), never future/unearned
--   penalty outstanding     = assessed penalties effective by D
--   total outstanding       = principal + earned interest + penalty
--   scheduled unearned      = reported separately, never in total
--   write-off               = receivable zero; NOT a repayment
--   MIGRATED before original disbursement = 0;
--   MIGRATED between original disbursement and opening = NOT_AVAILABLE;
--   MIGRATED at/after opening = authoritative opening position plus
--   subsequent effective-dated events.
--
-- Contribution helpers, wallet logic, B4 and the loan write paths
-- (component states used by preview/settlement/prepayment/restructure)
-- are NOT changed by this migration.

-- ---------------------------------------------------------------------------
-- 1. Canonical historical loan position (internal; never exposed).
--
-- Returns exactly one row. When the position cannot be reconstructed
-- from persisted authoritative data, position_state = 'NOT_AVAILABLE'
-- and every amount is NULL (never zero, never a magic negative value).
-- ---------------------------------------------------------------------------
create or replace function public.loan_historical_position(
  p_loan_account_id uuid,
  p_as_of_date date
)
returns table (
  position_state text,
  reason_code text,
  principal_outstanding numeric,
  earned_interest_outstanding numeric,
  penalty_outstanding numeric,
  total_outstanding numeric,
  scheduled_unearned_interest numeric
)
language sql
stable
security definer
set search_path = ''
as $function$
with ctx as (
  select
    la.id,
    la.loan_origin::text as origin,
    d.effective_at as disb_eff,
    d.amount as disb_amt,
    op.opening_as_of_date as open_date,
    op.original_disbursement_date as orig_date,
    op.opening_principal_outstanding as open_pr,
    op.opening_interest_arrears as open_int,
    op.opening_penalty_arrears as open_pen
  from public.loan_accounts la
  left join public.loan_disbursements d on d.loan_account_id = la.id
  left join public.loan_opening_positions op on op.loan_account_id = la.id
  where la.id = p_loan_account_id
),
gate as (
  select
    c.*,
    -- Business lower bound (exclusive) for events that move this loan.
    -- NEW: the day before disbursement, so disbursement-day events count.
    -- MIGRATED: the opening date; the opening record already includes
    -- everything up to and including that date.
    case when c.origin = 'MIGRATED' then c.open_date else c.disb_eff - 1 end as lower_excl,
    case
      when c.origin = 'NEW' and (c.disb_eff is null or p_as_of_date < c.disb_eff) then 'ZERO'
      when c.origin = 'MIGRATED' and c.open_date is null then 'NA_NO_OPENING'
      when c.origin = 'MIGRATED' and c.orig_date is not null and p_as_of_date < c.orig_date then 'ZERO'
      when c.origin = 'MIGRATED' and p_as_of_date < c.open_date then 'NA_BEFORE_OPENING'
      else 'COMPUTE'
    end as gate
  from ctx c
),
-- Installment existence, from persisted provenance only.
--   created: payment effective date (prepayment replacement), restructure
--            effective date (restructure replacement, linked by the event's
--            transaction timestamp), disbursement / opening date (originals).
--   cancelled: payment effective date (prepayment / early settlement) or
--              restructure effective date (restructure cancellation).
-- Business dates come from the event rows; created_at/cancelled_at are
-- used only to identify the event that wrote the row.
inst as (
  select
    li.id,
    li.due_date,
    li.interest_due,
    li.cancelled_at is not null as is_cancelled,
    case
      when li.created_by_payment_id is not null then
        (select p.effective_at from public.payments p where p.id = li.created_by_payment_id)
      when exists (
        select 1 from public.loan_restructure_events re
        where re.loan_account_id = li.loan_account_id and re.created_at = li.created_at
      ) then
        (select re.effective_date from public.loan_restructure_events re
         where re.loan_account_id = li.loan_account_id and re.created_at = li.created_at
         limit 1)
      -- Unmatched rows are original schedule rows. Their business start is
      -- the disbursement/opening date, not the recording timestamp: some
      -- NEW loans were recorded after their (backdated) disbursement date.
      when g.origin = 'MIGRATED' then g.open_date
      when g.origin = 'NEW' then g.disb_eff
      else null
    end as created_eff,
    case
      when li.cancelled_at is null then null
      when li.cancelled_by_payment_id is not null then
        (select p.effective_at from public.payments p where p.id = li.cancelled_by_payment_id)
      when li.cancellation_reason = 'RESTRUCTURE' then
        (select re.effective_date from public.loan_restructure_events re
         where re.loan_account_id = li.loan_account_id and re.created_at = li.cancelled_at
         limit 1)
      else null
    end as cancel_eff
  from public.loan_installments li
  cross join gate g
  where li.loan_account_id = p_loan_account_id
),
inst2 as (
  select
    i.*,
    coalesce(i.created_eff <= p_as_of_date, false)
      and (i.cancel_eff is null or i.cancel_eff > p_as_of_date) as exists_d,
    (i.created_eff is null or (i.is_cancelled and i.cancel_eff is null)) as unplaceable
  from inst i
),
flags as (
  select
    exists (select 1 from inst2 where unplaceable) as unplaceable,
    -- A reversed prepayment or early settlement deleted or restored
    -- schedule rows; between its effective date and its reversal the
    -- pre-reversal schedule is not reconstructable.
    exists (
      select 1 from public.payments p
      where p.reversed_at is not null
        and p.effective_at <= p_as_of_date
        and p.reversed_at::date > p_as_of_date
        and (
          p.id in (select pe.payment_id from public.loan_prepayment_events pe
                   where pe.loan_account_id = p_loan_account_id)
          or p.id in (select (e.metadata->>'payment_id')::uuid
                      from public.loan_account_events e
                      where e.loan_account_id = p_loan_account_id
                        and e.event_type = 'EARLY_SETTLED')
        )
    ) as schedule_reversal_window,
    -- 09G-B5-A3.1 §J: a write-off reversal is only valid after every
    -- dependent recovery has been reversed (rpc_reverse_loan_write_off
    -- enforces this). A live dependent recovery alongside an effective
    -- reversal is a malformed state: never manufacture a receivable.
    exists (
      select 1 from public.loan_recovery_events re
      join public.payments rp on rp.id = re.payment_id
      where re.loan_account_id = p_loan_account_id
        and rp.effective_at <= p_as_of_date
        and (rp.reversed_at is null or rp.reversed_at::date > p_as_of_date)
        and exists (
          select 1 from public.loan_write_off_events r
          where r.reverses_write_off_id = re.write_off_event_id
            and r.effective_date <= p_as_of_date
        )
    ) as invalid_recovery,
    exists (
      select 1 from public.loan_write_off_events wo
      where wo.loan_account_id = p_loan_account_id
        and wo.event_type = 'WRITE_OFF'
        and wo.effective_date <= p_as_of_date
        and not exists (
          select 1 from public.loan_write_off_events r
          where r.reverses_write_off_id = wo.id
            and r.effective_date <= p_as_of_date
        )
    ) as written_off
),
-- Allocations counted as of D: a payment allocation counts when its
-- payment was effective by D and not reversed by D (reversal effective
-- date, not the current status). A wallet-sourced allocation counts by
-- its wallet entry's effective date.
alloc as (
  select
    pa.loan_installment_id as iid,
    pa.allocation_target_type::text as tgt,
    pa.amount
  from public.payment_allocations pa
  cross join gate g
  left join public.payments pay on pay.id = pa.payment_id
  left join public.member_wallet_entries we on we.id = pa.wallet_entry_id
  where pa.loan_account_id = p_loan_account_id
    and (
      (pa.wallet_entry_id is null
        and pay.effective_at > g.lower_excl
        and pay.effective_at <= p_as_of_date
        and (pay.reversed_at is null or pay.reversed_at::date > p_as_of_date))
      or
      (pa.wallet_entry_id is not null
        and we.effective_at > g.lower_excl
        and we.effective_at <= p_as_of_date)
    )
),
adj as (
  select oa.target_type, oa.amount, oa.loan_installment_id as iid
  from public.loan_obligation_adjustments oa
  cross join gate g
  where oa.loan_account_id = p_loan_account_id
    and oa.effective_date > g.lower_excl
    and oa.effective_date <= p_as_of_date
),
-- 09G-B5-A3.2 penalty buckets. Obligation provenance is preserved:
--   OPENING-origin charges are the detailed representation of the opening
--   snapshot's penalty arrears (never added to it);
--   ASSESSED-origin charges are distinct Umoja obligations, effective on
--   their assessment_date (including dates on/before opening).
pen_assessed as (
  select c.id, c.penalty_amount
  from public.loan_penalty_charges c
  where c.loan_account_id = p_loan_account_id
    and c.origin::text = 'ASSESSED'
    and c.assessment_date <= p_as_of_date
),
pen_opening as (
  select c.id, c.penalty_amount
  from public.loan_penalty_charges c
  where c.loan_account_id = p_loan_account_id
    and c.origin::text = 'OPENING'
),
-- Penalty allocations effective and unreversed by D, with their business date.
pen_alloc as (
  select pa.loan_penalty_charge_id as cid, pa.amount,
         coalesce(pay.effective_at, we.effective_at) as eff
  from public.payment_allocations pa
  left join public.payments pay on pay.id = pa.payment_id
  left join public.member_wallet_entries we on we.id = pa.wallet_entry_id
  where pa.loan_account_id = p_loan_account_id
    and pa.allocation_target_type::text = 'LOAN_PENALTY'
    and (
      (pa.wallet_entry_id is null and pay.effective_at <= p_as_of_date
        and (pay.reversed_at is null or pay.reversed_at::date > p_as_of_date))
      or (pa.wallet_entry_id is not null and we.effective_at <= p_as_of_date)
    )
),
-- Penalty obligation adjustments effective by D, with their target charge.
pen_adj as (
  select oa.loan_penalty_charge_id as cid, oa.amount, oa.effective_date as eff
  from public.loan_obligation_adjustments oa
  where oa.loan_account_id = p_loan_account_id
    and oa.target_type = 'LOAN_PENALTY'
    and oa.effective_date <= p_as_of_date
),
vals as (
  select
    g.gate,
    g.origin,
    g.open_int,
    g.open_pen,
    f.unplaceable,
    f.schedule_reversal_window,
    f.invalid_recovery,
    f.written_off,
    case when g.origin = 'NEW' then g.disb_amt else g.open_pr end as base_principal,
    coalesce((select sum(a.amount) from alloc a
              where a.tgt in ('LOAN_PRINCIPAL', 'LOAN_PRINCIPAL_PREPAYMENT')), 0)
      as pr_paid,
    coalesce((select sum(i.interest_due) from inst2 i
              where i.exists_d and i.due_date <= p_as_of_date and i.due_date > g.lower_excl), 0)
      as ear_gross,
    coalesce((select sum(x.amount) from adj x
              where x.target_type = 'LOAN_INTEREST'
                and x.iid in (select i.id from inst2 i
                              where i.exists_d and i.due_date <= p_as_of_date)), 0)
      as ear_adj,
    coalesce((select sum(a.amount) from alloc a
              where a.tgt = 'LOAN_INTEREST'), 0)
      as ear_paid,
    coalesce((select sum(i.interest_due) from inst2 i
              where i.exists_d and i.due_date > p_as_of_date), 0)
      as unearned_gross,
    -- Bucket 1: imported OPENING penalty. Starts from the authoritative
    -- snapshot; only post-opening allocations/adjustments against OPENING
    -- charges reduce it. Allocations to ASSESSED charges never do.
    coalesce(g.open_pen, 0)
      + coalesce((select sum(a.amount) from pen_adj a
                  where a.cid in (select o.id from pen_opening o) and a.eff > g.lower_excl), 0)
      - coalesce((select sum(p.amount) from pen_alloc p
                  where p.cid in (select o.id from pen_opening o) and p.eff > g.lower_excl), 0)
      as pen_open_raw,
    -- Bucket 2: distinct ASSESSED penalties, each clamped on its own.
    coalesce((select sum(greatest(0, x.amt + x.adj - x.alloc))
              from (select c.id, c.penalty_amount as amt,
                           coalesce((select sum(a.amount) from pen_adj a where a.cid = c.id), 0) as adj,
                           coalesce((select sum(p.amount) from pen_alloc p where p.cid = c.id), 0) as alloc
                    from pen_assessed c) x), 0) as pen_assessed_bucket,
    -- Provenance checks: never guess which obligation a payment or
    -- snapshot amount belongs to.
    exists (select 1 from pen_alloc where cid is null) as pen_prov_unknown,
    abs(coalesce((select sum(o.penalty_amount) from pen_opening o), 0) - coalesce(g.open_pen, 0)) > 0.005
      as opening_mismatch
  from gate g
  cross join flags f
),
state as (
  select
    v.*,
    -- Provenance is only needed when the position is actually computed; a
    -- loan with no funded position yet is zero regardless of its rows.
    (v.gate in ('NA_NO_OPENING', 'NA_BEFORE_OPENING')
      or (v.gate = 'COMPUTE'
          and (v.unplaceable or v.schedule_reversal_window or v.invalid_recovery
               or v.pen_prov_unknown or v.opening_mismatch))) as is_na,
    (v.gate = 'ZERO' or v.written_off) as is_zero
  from vals v
),
out as (
  select
    s.*,
    case when s.is_na then null
         when s.is_zero then 0
         else greatest(0, s.base_principal - s.pr_paid) end as o_principal,
    case when s.is_na then null
         when s.is_zero then 0
         else greatest(0, coalesce(s.open_int, 0) + s.ear_gross + s.ear_adj - s.ear_paid) end as o_earned,
    case when s.is_na then null
         when s.is_zero then 0
         else greatest(0, s.pen_open_raw) + s.pen_assessed_bucket end as o_penalty,
    case when s.is_na then null
         when s.is_zero then 0
         else greatest(0, s.unearned_gross) end as o_unearned
  from state s
)
select
  case when o.is_na then 'NOT_AVAILABLE' else 'AVAILABLE' end::text as position_state,
  (case
     when o.gate = 'NA_NO_OPENING' then 'NO_OPENING_POSITION'
     when o.gate = 'NA_BEFORE_OPENING' then 'BEFORE_OPENING_POSITION'
     when o.gate = 'ZERO' and o.origin = 'MIGRATED' then 'BEFORE_ORIGINAL_DISBURSEMENT'
     when o.gate = 'ZERO' then 'NOT_YET_DISBURSED'
     when o.unplaceable then 'UNPLACEABLE_SCHEDULE_PROVENANCE'
     when o.schedule_reversal_window then 'REVERSED_SCHEDULE_CHANGE_WINDOW'
     when o.invalid_recovery then 'INVALID_WRITEOFF_RECOVERY_STATE'
     when o.pen_prov_unknown then 'PENALTY_ALLOCATION_PROVENANCE_UNKNOWN'
     when o.opening_mismatch then 'OPENING_PENALTY_PROVENANCE_MISMATCH'
     when o.written_off then 'WRITTEN_OFF'
     else null
   end)::text as reason_code,
  o.o_principal as principal_outstanding,
  o.o_earned as earned_interest_outstanding,
  o.o_penalty as penalty_outstanding,
  o.o_principal + o.o_earned + o.o_penalty as total_outstanding,
  o.o_unearned as scheduled_unearned_interest
from out o;
$function$;

revoke all on function public.loan_historical_position(uuid, date) from public, anon, authenticated;

comment on function public.loan_historical_position(uuid, date) is
  'Canonical historical loan position at end of day D (09G-B5-A3). '
  'Internal only. NOT_AVAILABLE returns NULL amounts, never zero. '
  'total_outstanding excludes scheduled_unearned_interest.';

-- ---------------------------------------------------------------------------
-- 2. loan_account_outstanding_as_of: total only, now the canonical total.
--    NULL when the historical position is NOT_AVAILABLE (callers must not
--    coalesce that to zero).
-- ---------------------------------------------------------------------------
create or replace function public.loan_account_outstanding_as_of(
  p_loan_account_id uuid,
  p_as_of_date date
)
returns numeric
language sql
stable
security definer
set search_path = ''
as $function$
  select h.total_outstanding
  from public.loan_historical_position(p_loan_account_id, p_as_of_date) h;
$function$;

-- ---------------------------------------------------------------------------
-- 3. loan_statement_schedule_position: position at D from the canonical
--    helper. Overdue split is only meaningful at the current date (it reads
--    current component state), so it is NULL for any other date and 0 for a
--    written-off loan.
-- ---------------------------------------------------------------------------
create or replace function public.loan_statement_schedule_position(
  p_loan_account_id uuid,
  p_effective_date date
)
returns table (
  principal_outstanding numeric,
  earned_interest_outstanding numeric,
  penalty_outstanding numeric,
  total_outstanding numeric,
  scheduled_unearned_interest numeric,
  overdue_principal numeric,
  overdue_interest numeric,
  overdue_penalty numeric,
  total_overdue numeric
)
language sql
stable
security definer
set search_path = ''
as $function$
  select
    h.principal_outstanding,
    h.earned_interest_outstanding,
    h.penalty_outstanding,
    h.total_outstanding,
    h.scheduled_unearned_interest,
    case when h.position_state = 'NOT_AVAILABLE' or p_effective_date <> current_date then null
         when h.reason_code = 'WRITTEN_OFF' then 0
         else ov.op end,
    case when h.position_state = 'NOT_AVAILABLE' or p_effective_date <> current_date then null
         when h.reason_code = 'WRITTEN_OFF' then 0
         else ov.oi end,
    case when h.position_state = 'NOT_AVAILABLE' or p_effective_date <> current_date then null
         when h.reason_code = 'WRITTEN_OFF' then 0
         else ov.opn end,
    case when h.position_state = 'NOT_AVAILABLE' or p_effective_date <> current_date then null
         when h.reason_code = 'WRITTEN_OFF' then 0
         else ov.op + ov.oi + ov.opn end
  from public.loan_historical_position(p_loan_account_id, p_effective_date) h
  cross join lateral (
    select
      coalesce(sum(s.outstanding) filter (where s.component_type = 'PRINCIPAL' and li.due_date < p_effective_date), 0) as op,
      coalesce(sum(s.outstanding) filter (where s.component_type = 'INTEREST' and li.due_date < p_effective_date), 0) as oi,
      coalesce(sum(s.outstanding) filter (where s.component_type = 'PENALTY' and li.due_date < p_effective_date), 0) as opn
    from public.loan_installments li
    cross join lateral public.loan_installment_component_states(li.id) s
    where li.loan_account_id = p_loan_account_id
      and li.cancelled_at is null
  ) ov;
$function$;

-- ---------------------------------------------------------------------------
-- 4. loan_account_summary: current outstanding from the canonical helper at
--    current_date. principal_repaid / interest_recognized / penalty_paid
--    remain ACTUAL posted allocations (never original minus outstanding).
--    next_due_date and overdue_amount are NULL / 0 for a written-off loan.
-- ---------------------------------------------------------------------------
create or replace function public.loan_account_summary(p_loan_account_id uuid)
returns table (
  principal_repaid numeric,
  principal_outstanding numeric,
  interest_recognized numeric,
  interest_outstanding numeric,
  penalty_paid numeric,
  penalty_outstanding numeric,
  total_outstanding numeric,
  next_due_date date,
  overdue_amount numeric
)
language sql
stable
security definer
set search_path = ''
as $function$
  select
    coalesce((
      select sum(pa.amount)
      from public.payment_allocations pa
      left join public.payments pay on pay.id = pa.payment_id
      where pa.loan_account_id = p_loan_account_id
        and pa.allocation_target_type::text in ('LOAN_PRINCIPAL', 'LOAN_PRINCIPAL_PREPAYMENT', 'LOAN_RECOVERY_PRINCIPAL')
        and (pa.wallet_entry_id is not null or pay.status = 'POSTED')
    ), 0) as principal_repaid,
    h.principal_outstanding,
    coalesce((
      select sum(pa.amount)
      from public.payment_allocations pa
      left join public.payments pay on pay.id = pa.payment_id
      where pa.loan_account_id = p_loan_account_id
        and pa.allocation_target_type::text in ('LOAN_INTEREST', 'LOAN_RECOVERY_INTEREST')
        and (pa.wallet_entry_id is not null or pay.status = 'POSTED')
    ), 0) as interest_recognized,
    h.earned_interest_outstanding as interest_outstanding,
    coalesce((
      select sum(pa.amount)
      from public.payment_allocations pa
      left join public.payments pay on pay.id = pa.payment_id
      where pa.loan_account_id = p_loan_account_id
        and pa.allocation_target_type::text in ('LOAN_PENALTY', 'LOAN_RECOVERY_PENALTY')
        and (pa.wallet_entry_id is not null or pay.status = 'POSTED')
    ), 0) as penalty_paid,
    h.penalty_outstanding,
    h.total_outstanding,
    case when h.position_state = 'NOT_AVAILABLE' or h.reason_code = 'WRITTEN_OFF' then null
         else (
           select min(x.due_date)
           from (
             select li.due_date, sum(s.outstanding) as o
             from public.loan_installments li
             cross join lateral public.loan_installment_component_states(li.id) s
             where li.loan_account_id = p_loan_account_id and li.cancelled_at is null
             group by li.id, li.due_date
           ) x
           where x.o > 0
         ) end as next_due_date,
    case when h.position_state = 'NOT_AVAILABLE' then null
         when h.reason_code = 'WRITTEN_OFF' then 0
         else coalesce((
           select sum(x.o)
           from (
             select li.due_date, sum(s.outstanding) as o
             from public.loan_installments li
             cross join lateral public.loan_installment_component_states(li.id) s
             where li.loan_account_id = p_loan_account_id and li.cancelled_at is null
             group by li.id, li.due_date
           ) x
           where x.due_date < current_date
         ), 0) end as overdue_amount
  from public.loan_historical_position(p_loan_account_id, current_date) h;
$function$;

-- ---------------------------------------------------------------------------
-- 5. Read surfaces that embed the historical/current loan position.
--    Only the loan outstanding/amount fields change:
--      * rpc_get_my_member_statement (B3): loan opening/closing use the
--        canonical position; the loan figure is NULL (NOT_AVAILABLE) if any
--        financially-existing loan at the cutoff is unavailable.
--        Contribution and wallet fields are untouched.
--      * installment-level outstanding is zero and status WRITTEN_OFF for a
--        written-off loan (no receivable displayed as outstanding).
--    Authorization, grants, signatures and every other field are unchanged.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_get_my_member_statement(p_group_id uuid, p_from_date date DEFAULT NULL::date, p_to_date date DEFAULT NULL::date, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_membership_id uuid;
  v_limit integer;
  v_offset integer;
  v_member jsonb;
  v_group jsonb;
  v_summary jsonb;
  v_activity jsonb;
  v_contrib_outstanding numeric;
  v_contrib_pending_penalty numeric;
  v_loan_outstanding numeric;
  v_loan_pending_penalty numeric;
  v_wallet_balance numeric;
  v_last_payment jsonb;
  v_opening_cutoff date;
  v_period_opening jsonb;
  v_period_closing jsonb;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  if p_group_id is null then
    raise exception 'p_group_id is required' using errcode = '22023';
  end if;

  if p_from_date is not null and p_to_date is not null and p_from_date > p_to_date then
    raise exception 'p_from_date must not be after p_to_date' using errcode = '22023';
  end if;

  v_membership_id := public.current_membership_id(p_group_id);

  if v_membership_id is null then
    raise exception 'No active membership in this group' using errcode = '42501';
  end if;

  if not public.has_group_permission(p_group_id, 'financial_report.self_view') then
    raise exception 'Not authorized to view a financial statement' using errcode = '42501';
  end if;

  v_limit := least(greatest(coalesce(p_limit, 50), 1), 200);
  v_offset := greatest(coalesce(p_offset, 0), 0);

  -- member / group metadata -----------------------------------------------

  select jsonb_build_object(
    'membership_id', gm.id,
    'display_name', gm.display_name,
    'member_number', gm.member_number,
    'membership_status', gm.status
  ),
  jsonb_build_object(
    'group_id', g.id,
    'group_name', g.name,
    'group_code', g.code,
    'currency', g.currency
  )
  into v_member, v_group
  from public.group_memberships gm
  join public.groups g on g.id = gm.group_id
  where gm.id = v_membership_id;

  -- summary (always CURRENT position — never implied "as of p_to_date") --

  select coalesce(sum(s.outstanding), 0)
  into v_contrib_outstanding
  from public.member_contribution_charges c
  cross join lateral public.contribution_charge_component_states(c.id) s
  where c.membership_id = v_membership_id and c.group_id = p_group_id;

  select coalesce(sum(s.outstanding), 0)
  into v_contrib_pending_penalty
  from public.member_contribution_charges c
  cross join lateral public.contribution_charge_component_states(c.id) s
  where c.membership_id = v_membership_id
    and c.group_id = p_group_id
    and s.component_type = 'PENALTY';

  -- 09G-B5-A3.1: the current loan figure is the same canonical aggregate as
  -- opening/closing (same loan scope, NULL when any loan is NOT_AVAILABLE).
  select case when bool_or(h.position_state = 'NOT_AVAILABLE') then null
              else coalesce(sum(h.total_outstanding), 0) end,
         case when bool_or(h.position_state = 'NOT_AVAILABLE') then null
              else coalesce(sum(h.penalty_outstanding), 0) end
  into v_loan_outstanding, v_loan_pending_penalty
  from public.loan_accounts la
  cross join lateral public.loan_historical_position(la.id, current_date) h
  where la.membership_id = v_membership_id
    and la.group_id = p_group_id;

  v_wallet_balance := public.member_wallet_balance(v_membership_id);

  select jsonb_build_object(
    'amount', p.amount,
    'effective_at', p.effective_at,
    'receipt_number', p.receipt_number
  )
  into v_last_payment
  from public.payments p
  where p.membership_id = v_membership_id
    and p.group_id = p_group_id
    and p.status = 'POSTED'
  order by p.effective_at desc, p.created_at desc
  limit 1;

  v_summary := jsonb_build_object(
    'contributions', jsonb_build_object(
      'current_outstanding', v_contrib_outstanding,
      'pending_penalties', v_contrib_pending_penalty
    ),
    'loans', jsonb_build_object(
      'current_outstanding', v_loan_outstanding,
      'pending_penalties', v_loan_pending_penalty
    ),
    'wallet', jsonb_build_object(
      'current_balance', v_wallet_balance
    ),
    'last_payment', v_last_payment
  );

  -- period.opening / period.closing (09G-B3-B-FIX-01) ----------------------

  if p_from_date is not null then
    v_opening_cutoff := p_from_date - 1;
    v_period_opening := jsonb_build_object(
      'as_of_date', v_opening_cutoff,
      'contributions', jsonb_build_object(
        'outstanding', (
          select coalesce(sum(s.outstanding), 0)
          from public.member_contribution_charges c
          cross join lateral public.contribution_charge_component_states_as_of(c.id, v_opening_cutoff) s
          where c.membership_id = v_membership_id and c.group_id = p_group_id
        )
      ),
      'loans', jsonb_build_object(
        'outstanding', (
          select case when bool_or(h.position_state = 'NOT_AVAILABLE') then null
                      else coalesce(sum(h.total_outstanding), 0) end
          from public.loan_accounts la
          cross join lateral public.loan_historical_position(la.id, v_opening_cutoff) h
          where la.membership_id = v_membership_id and la.group_id = p_group_id
        )
      ),
      'wallet', jsonb_build_object(
        'balance', public.member_wallet_balance_as_of_membership(v_membership_id, v_opening_cutoff)
      )
    );
  else
    v_period_opening := null;
  end if;

  if p_to_date is not null then
    v_period_closing := jsonb_build_object(
      'as_of_date', p_to_date,
      'contributions', jsonb_build_object(
        'outstanding', (
          select coalesce(sum(s.outstanding), 0)
          from public.member_contribution_charges c
          cross join lateral public.contribution_charge_component_states_as_of(c.id, p_to_date) s
          where c.membership_id = v_membership_id and c.group_id = p_group_id
        )
      ),
      'loans', jsonb_build_object(
        'outstanding', (
          select case when bool_or(h.position_state = 'NOT_AVAILABLE') then null
                      else coalesce(sum(h.total_outstanding), 0) end
          from public.loan_accounts la
          cross join lateral public.loan_historical_position(la.id, p_to_date) h
          where la.membership_id = v_membership_id and la.group_id = p_group_id
        )
      ),
      'wallet', jsonb_build_object(
        'balance', public.member_wallet_balance_as_of_membership(v_membership_id, p_to_date)
      )
    );
  else
    v_period_closing := null;
  end if;

  -- activity ---------------------------------------------------------------

  with activity as (
    select
      cc.id as event_id,
      'CONTRIBUTION'::text as domain,
      cc.component_type::text as event_type,
      cc.effective_at as effective_date,
      cc.assessed_amount as amount,
      false as is_reversed,
      (case cc.component_type::text
        when 'OPENING_BALANCE' then 1
        when 'BASE' then 2
        when 'PENALTY' then 3
        when 'ADJUSTMENT' then 4
        when 'WAIVER' then 5
        else 9
      end) as source_priority,
      cc.created_at as tie_created_at,
      cc.id as tie_id,
      jsonb_build_object(
        'charge_id', c.id,
        'period_id', c.period_id,
        'period_label', p.label,
        'due_date', c.due_date,
        'reason', cc.reason
      ) as metadata
    from public.contribution_charge_components cc
    join public.member_contribution_charges c on c.id = cc.charge_id
    join public.contribution_periods p on p.id = c.period_id
    where c.membership_id = v_membership_id and c.group_id = p_group_id

    union all

    select
      pay.id,
      'PAYMENT',
      'PAYMENT',
      pay.effective_at,
      pay.amount,
      pay.status = 'REVERSED',
      6,
      pay.created_at,
      pay.id,
      jsonb_build_object(
        'status', pay.status,
        'receipt_number', pay.receipt_number,
        'payment_method', pay.payment_method,
        'external_reference', pay.external_reference,
        'reversal_reason', pay.reversal_reason,
        -- 09G-B3-UX-01-FIX-01 §E: period_label/component_type are the
        -- two additive fields — resolved via the SAME charge_id/
        -- charge_component_id FKs already returned, joined exactly
        -- like the CONTRIBUTION branch above. Both are null for a
        -- LOAN_* allocation (no charge/charge_component on those rows
        -- by the table's own target-consistency check).
        'allocations', coalesce((
          select jsonb_agg(jsonb_build_object(
            'amount', pa.amount,
            'target_type', pa.allocation_target_type,
            'charge_id', pa.charge_id,
            'charge_component_id', pa.charge_component_id,
            'loan_account_id', pa.loan_account_id,
            'loan_installment_id', pa.loan_installment_id,
            'period_label', ap.label,
            'component_type', acc.component_type
          ) order by pa.created_at, pa.id)
          from public.payment_allocations pa
          left join public.contribution_charge_components acc
            on acc.id = pa.charge_component_id
          left join public.member_contribution_charges ac
            on ac.id = pa.charge_id
          left join public.contribution_periods ap
            on ap.id = ac.period_id
          where pa.payment_id = pay.id
        ), '[]'::jsonb)
      ) as metadata
    from public.payments pay
    where pay.membership_id = v_membership_id and pay.group_id = p_group_id

    union all

    select
      ld.id,
      'LOAN',
      'DISBURSEMENT',
      ld.effective_at,
      ld.amount,
      false,
      7,
      ld.created_at,
      ld.id,
      jsonb_build_object(
        'loan_account_id', la.id,
        'loan_number', la.loan_number,
        'reference', ld.reference
      )
    from public.loan_disbursements ld
    join public.loan_accounts la on la.id = ld.loan_account_id
    where la.membership_id = v_membership_id and la.group_id = p_group_id

    union all

    select
      pc.id,
      'LOAN',
      'PENALTY_ASSESSED',
      pc.assessment_date,
      pc.penalty_amount,
      false,
      12,
      pc.created_at,
      pc.id,
      jsonb_build_object(
        'loan_account_id', la.id,
        'loan_number', la.loan_number,
        'loan_installment_id', pc.loan_installment_id,
        'sequence_number', pc.sequence_number,
        'origin', pc.origin
      )
    from public.loan_penalty_charges pc
    join public.loan_accounts la on la.id = pc.loan_account_id
    where la.membership_id = v_membership_id and la.group_id = p_group_id

    union all

    select
      wo.id,
      'LOAN',
      wo.event_type,
      wo.effective_date,
      wo.principal_amount + wo.interest_amount + wo.penalty_amount,
      wo.event_type = 'REVERSAL',
      (case wo.event_type when 'WRITE_OFF' then 8 else 9 end),
      wo.created_at,
      wo.id,
      jsonb_build_object(
        'loan_account_id', la.id,
        'loan_number', la.loan_number,
        'reason_code', wo.reason_code,
        'note', wo.note,
        'principal_amount', wo.principal_amount,
        'interest_amount', wo.interest_amount,
        'penalty_amount', wo.penalty_amount
      )
    from public.loan_write_off_events wo
    join public.loan_accounts la on la.id = wo.loan_account_id
    where la.membership_id = v_membership_id and la.group_id = p_group_id

    union all

    select
      oa.id,
      'LOAN',
      oa.adjustment_type,
      oa.effective_date,
      oa.amount,
      oa.adjustment_type = 'REVERSAL',
      10,
      oa.created_at,
      oa.id,
      jsonb_build_object(
        'loan_account_id', la.id,
        'loan_number', la.loan_number,
        'target_type', oa.target_type,
        'reason_code', oa.reason_code,
        'note', oa.note
      )
    from public.loan_obligation_adjustments oa
    join public.loan_accounts la on la.id = oa.loan_account_id
    where la.membership_id = v_membership_id and la.group_id = p_group_id

    union all

    select
      re.id,
      'LOAN',
      'RESTRUCTURED',
      re.effective_date,
      0::numeric(14, 2),
      false,
      13,
      re.created_at,
      re.id,
      jsonb_build_object(
        'loan_account_id', la.id,
        'loan_number', la.loan_number,
        'reason', re.reason,
        'new_interest_rate', re.new_interest_rate,
        'new_term', re.new_term,
        'new_first_installment_date', re.new_first_installment_date
      )
    from public.loan_restructure_events re
    join public.loan_accounts la on la.id = re.loan_account_id
    where la.membership_id = v_membership_id and la.group_id = p_group_id

    union all

    select
      we.id,
      'WALLET',
      we.entry_type::text,
      we.effective_at,
      we.amount,
      we.entry_type::text = 'REVERSAL',
      11,
      we.created_at,
      we.id,
      jsonb_build_object(
        'source_type', we.source_type,
        'source_id', we.source_id
      )
    from public.member_wallet_entries we
    where we.membership_id = v_membership_id and we.group_id = p_group_id
  ),
  filtered as (
    select *
    from activity
    where (p_from_date is null or effective_date >= p_from_date)
      and (p_to_date is null or effective_date <= p_to_date)
  ),
  total as (
    select count(*) as total_count from filtered
  ),
  paged as (
    select *
    from filtered
    order by effective_date asc, source_priority asc, tie_created_at asc, tie_id asc
    limit v_limit offset v_offset
  )
  select jsonb_build_object(
    'items', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'event_id', paged.event_id,
          'domain', paged.domain,
          'event_type', paged.event_type,
          'effective_date', paged.effective_date,
          'amount', paged.amount,
          'is_reversed', paged.is_reversed,
          'metadata', paged.metadata
        )
        order by paged.effective_date asc, paged.source_priority asc, paged.tie_created_at asc, paged.tie_id asc
      )
      from paged
    ), '[]'::jsonb),
    'limit', v_limit,
    'offset', v_offset,
    'total_count', (select total_count from total),
    'has_more', (v_offset + v_limit) < (select total_count from total)
  )
  into v_activity;

  return jsonb_build_object(
    'member', v_member,
    'group', v_group,
    'period', jsonb_build_object(
      'from_date', p_from_date,
      'to_date', p_to_date,
      'opening', v_period_opening,
      'closing', v_period_closing
    ),
    'summary', v_summary,
    'activity', v_activity
  );
end;
$function$;
CREATE OR REPLACE FUNCTION public.rpc_list_loan_installments(p_group_id uuid, p_loan_account_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid := auth.uid();
  v_items jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan_schedule.view') then
    raise exception 'Not authorized to view loan schedules in this group' using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.loan_accounts where id = p_loan_account_id and group_id = p_group_id
  ) then
    raise exception 'Loan account not found in group' using errcode = '22023';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', i.id,
    'group_id', i.group_id,
    'loan_account_id', i.loan_account_id,
    'installment_number', i.installment_number,
    'due_date', i.due_date,
    'principal_due', i.principal_due,
    'interest_due', i.interest_due,
    'total_due', i.total_due,
    'created_at', i.created_at,
    'cancelled_at', i.cancelled_at,
    'cancellation_reason', i.cancellation_reason,
    'principal_paid', coalesce(pc.allocated, 0),
    'principal_outstanding', case when exists (select 1 from public.loan_accounts la_wo where la_wo.id = p_loan_account_id and la_wo.status = 'WRITTEN_OFF') then 0 else coalesce(pc.outstanding, 0) end,
    'interest_paid', coalesce(ic.allocated, 0),
    'interest_outstanding', case when exists (select 1 from public.loan_accounts la_wo where la_wo.id = p_loan_account_id and la_wo.status = 'WRITTEN_OFF') then 0 else coalesce(ic.outstanding, 0) end,
    'penalty_paid', coalesce(penc.allocated, 0),
    'penalty_outstanding', case when exists (select 1 from public.loan_accounts la_wo where la_wo.id = p_loan_account_id and la_wo.status = 'WRITTEN_OFF') then 0 else coalesce(penc.outstanding, 0) end,
    'total_outstanding', case when exists (select 1 from public.loan_accounts la_wo where la_wo.id = p_loan_account_id and la_wo.status = 'WRITTEN_OFF') then 0 else coalesce(pc.outstanding, 0) + coalesce(ic.outstanding, 0) + coalesce(penc.outstanding, 0) end,
    'status', (
      case
        when i.cancelled_at is not null then 'CANCELLED'
        when exists (select 1 from public.loan_accounts la_wo where la_wo.id = p_loan_account_id and la_wo.status = 'WRITTEN_OFF') then 'WRITTEN_OFF'
        when coalesce(pc.outstanding, 0) + coalesce(ic.outstanding, 0) + coalesce(penc.outstanding, 0) = 0 then 'PAID'
        when i.due_date < current_date then 'OVERDUE'
        when coalesce(pc.allocated, 0) + coalesce(ic.allocated, 0) + coalesce(penc.allocated, 0) > 0 then 'PARTIALLY_PAID'
        when i.due_date = current_date then 'DUE'
        else 'UPCOMING'
      end
    )
  ) order by i.installment_number), '[]'::jsonb) into v_items
  from public.loan_installments i
  left join lateral (
    select * from public.loan_installment_component_states(i.id) where component_type = 'PRINCIPAL'
  ) pc on true
  left join lateral (
    select * from public.loan_installment_component_states(i.id) where component_type = 'INTEREST'
  ) ic on true
  left join lateral (
    select * from public.loan_installment_component_states(i.id) where component_type = 'PENALTY'
  ) penc on true
  where i.loan_account_id = p_loan_account_id and i.group_id = p_group_id;

  return jsonb_build_object('loan_account_id', p_loan_account_id, 'installments', v_items);
end;
$function$;
CREATE OR REPLACE FUNCTION public.rpc_get_loan_account(p_group_id uuid, p_loan_account_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid := auth.uid();
  v_result jsonb;
  v_installments jsonb;
  v_events jsonb;
  v_disbursement jsonb;
  v_opening_position jsonb;
  v_prepayment_events jsonb;
  v_restructure_events jsonb;
  v_summary record;
  v_status text;
  v_write_off_state jsonb;
  v_principal_outstanding numeric;
  v_interest_outstanding numeric;
  v_penalty_outstanding numeric;
  v_total_outstanding numeric;
  v_next_due_date date;
  v_overdue_amount numeric;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.view') then
    raise exception 'Not authorized to view loans in this group' using errcode = '42501';
  end if;

  select la.status into v_status
  from public.loan_accounts la
  where la.id = p_loan_account_id and la.group_id = p_group_id;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', i.id,
    'group_id', i.group_id,
    'loan_account_id', i.loan_account_id,
    'installment_number', i.installment_number,
    'due_date', i.due_date,
    'principal_due', i.principal_due,
    'interest_due', i.interest_due,
    'total_due', i.total_due,
    'created_at', i.created_at,
    'cancelled_at', i.cancelled_at,
    'cancellation_reason', i.cancellation_reason,
    'principal_paid', coalesce(pc.allocated, 0),
    'principal_outstanding', case when v_status = 'WRITTEN_OFF' then 0 else coalesce(pc.outstanding, 0) end,
    'interest_paid', coalesce(ic.allocated, 0),
    'interest_outstanding', case when v_status = 'WRITTEN_OFF' then 0 else coalesce(ic.outstanding, 0) end,
    'penalty_paid', coalesce(penc.allocated, 0),
    'penalty_outstanding', case when v_status = 'WRITTEN_OFF' then 0 else coalesce(penc.outstanding, 0) end,
    'total_outstanding', case when v_status = 'WRITTEN_OFF' then 0 else coalesce(pc.outstanding, 0) + coalesce(ic.outstanding, 0) + coalesce(penc.outstanding, 0) end,
    'status', (
      case
        when i.cancelled_at is not null then 'CANCELLED'
        when v_status = 'WRITTEN_OFF' then 'WRITTEN_OFF'
        when coalesce(pc.outstanding, 0) + coalesce(ic.outstanding, 0) + coalesce(penc.outstanding, 0) = 0 then 'PAID'
        when i.due_date < current_date then 'OVERDUE'
        when coalesce(pc.allocated, 0) + coalesce(ic.allocated, 0) + coalesce(penc.allocated, 0) > 0 then 'PARTIALLY_PAID'
        when i.due_date = current_date then 'DUE'
        else 'UPCOMING'
      end
    )
  ) order by i.installment_number), '[]'::jsonb)
  into v_installments
  from public.loan_installments i
  left join lateral (
    select * from public.loan_installment_component_states(i.id) where component_type = 'PRINCIPAL'
  ) pc on true
  left join lateral (
    select * from public.loan_installment_component_states(i.id) where component_type = 'INTEREST'
  ) ic on true
  left join lateral (
    select * from public.loan_installment_component_states(i.id) where component_type = 'PENALTY'
  ) penc on true
  where i.loan_account_id = p_loan_account_id and i.group_id = p_group_id;

  select coalesce(jsonb_agg(to_jsonb(e) order by e.created_at), '[]'::jsonb)
  into v_events
  from public.loan_account_events e
  where e.loan_account_id = p_loan_account_id and e.group_id = p_group_id;

  select coalesce(jsonb_agg(to_jsonb(pe) order by pe.created_at), '[]'::jsonb)
  into v_prepayment_events
  from public.loan_prepayment_events pe
  where pe.loan_account_id = p_loan_account_id and pe.group_id = p_group_id;

  select coalesce(jsonb_agg(to_jsonb(re) order by re.created_at), '[]'::jsonb)
  into v_restructure_events
  from public.loan_restructure_events re
  where re.loan_account_id = p_loan_account_id and re.group_id = p_group_id;

  select jsonb_build_object(
    'id', d.id, 'financial_account_id', d.financial_account_id,
    'financial_account_name', fa.name,
    'amount', d.amount, 'effective_at', d.effective_at,
    'reference', d.reference, 'notes', d.notes, 'created_at', d.created_at
  )
  into v_disbursement
  from public.loan_disbursements d
  join public.financial_accounts fa on fa.id = d.financial_account_id
  where d.loan_account_id = p_loan_account_id and d.group_id = p_group_id;

  select jsonb_build_object(
    'opening_as_of_date', o.opening_as_of_date,
    'original_disbursement_date', o.original_disbursement_date,
    'original_loan_number', o.original_loan_number,
    'original_principal', o.original_principal,
    'opening_principal_outstanding', o.opening_principal_outstanding,
    'opening_principal_arrears', o.opening_principal_arrears,
    'opening_interest_arrears', o.opening_interest_arrears,
    'opening_penalty_arrears', o.opening_penalty_arrears,
    'future_scheduled_principal', o.future_scheduled_principal,
    'future_scheduled_interest', o.future_scheduled_interest,
    'arrears_due_date', o.arrears_due_date,
    'remaining_installment_count', o.remaining_installment_count,
    'next_due_date', o.next_due_date,
    'notes', o.notes,
    'created_at', o.created_at
  )
  into v_opening_position
  from public.loan_opening_positions o
  where o.loan_account_id = p_loan_account_id and o.group_id = p_group_id;

  select * into v_summary from public.loan_account_summary(p_loan_account_id);

  v_write_off_state := public.loan_write_off_recovery_state(p_loan_account_id);

  if v_status = 'WRITTEN_OFF' then
    -- Prompt 09G-02: no longer an active contractual receivable — never
    -- report the frozen pre-write-off/pre-recovery schedule figures as
    -- "current outstanding". See loan_write_off_recovery_state /
    -- rpc_get_loan_statement for the correct recovery-aware figures.
    v_principal_outstanding := 0;
    v_interest_outstanding := 0;
    v_penalty_outstanding := 0;
    v_total_outstanding := 0;
    v_next_due_date := null;
    v_overdue_amount := 0;
  else
    v_principal_outstanding := v_summary.principal_outstanding;
    v_interest_outstanding := v_summary.interest_outstanding;
    v_penalty_outstanding := v_summary.penalty_outstanding;
    v_total_outstanding := v_summary.total_outstanding;
    v_next_due_date := v_summary.next_due_date;
    v_overdue_amount := v_summary.overdue_amount;
  end if;

  select jsonb_build_object(
    'id', la.id, 'group_id', la.group_id, 'membership_id', la.membership_id,
    'borrower_display_name', gm.display_name, 'borrower_member_number', gm.member_number,
    'loan_product_id', la.loan_product_id, 'loan_product_name', lp.name, 'loan_product_code', lp.code,
    'loan_number', la.loan_number,
    'loan_origin', la.loan_origin,
    'principal_amount', la.principal_amount, 'interest_rate', la.interest_rate,
    'interest_rate_basis', la.interest_rate_basis, 'interest_method', la.interest_method,
    'term', la.term, 'term_unit', la.term_unit, 'repayment_frequency', la.repayment_frequency,
    'application_date', la.application_date,
    'proposed_disbursement_date', la.proposed_disbursement_date,
    'first_repayment_date', la.first_repayment_date,
    'status', la.status,
    'penalty_enabled', la.penalty_enabled, 'penalty_type', la.penalty_type,
    'penalty_frequency', la.penalty_frequency, 'penalty_grace_days', la.penalty_grace_days,
    'penalty_fixed_amount', la.penalty_fixed_amount, 'penalty_rate', la.penalty_rate,
    'penalty_basis', la.penalty_basis,
    'created_at', la.created_at, 'updated_at', la.updated_at,
    'installments', v_installments,
    'events', v_events,
    'prepayment_events', v_prepayment_events,
    'restructure_events', v_restructure_events,
    'disbursement', v_disbursement,
    'opening_position', v_opening_position,
    'principal_repaid', v_summary.principal_repaid,
    'principal_outstanding', v_principal_outstanding,
    'interest_recognized', v_summary.interest_recognized,
    'interest_outstanding', v_interest_outstanding,
    'penalty_paid', v_summary.penalty_paid,
    'penalty_outstanding', v_penalty_outstanding,
    'total_outstanding', v_total_outstanding,
    'next_due_date', v_next_due_date,
    'overdue_amount', v_overdue_amount,
    'written_off_total', v_write_off_state->'amount_written_off',
    'remaining_recoverable_total', v_write_off_state->'remaining_recoverable',
    'remaining_recoverable_principal', v_write_off_state->'remaining_recoverable_principal',
    'remaining_recoverable_interest', v_write_off_state->'remaining_recoverable_interest',
    'remaining_recoverable_penalty', v_write_off_state->'remaining_recoverable_penalty'
  )
  into v_result
  from public.loan_accounts la
  join public.group_memberships gm on gm.id = la.membership_id
  join public.loan_products lp on lp.id = la.loan_product_id
  where la.id = p_loan_account_id and la.group_id = p_group_id;

  if v_result is null then
    raise exception 'Loan account not found in group' using errcode = '22023';
  end if;

  return v_result;
end;
$function$;
CREATE OR REPLACE FUNCTION public.rpc_get_loan_statement(p_group_id uuid, p_loan_account_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid := auth.uid();
  v_header jsonb;
  v_status text;
  v_current_state jsonb;
  v_position record;
  v_write_off_state jsonb;
  v_timeline jsonb;
  v_schedule_current jsonb;
  v_schedule_history jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'loan.view') then
    raise exception 'Not authorized to view loans in this group' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'loan_account_id', la.id,
    'loan_number', la.loan_number,
    'loan_product_id', la.loan_product_id,
    'loan_product_name', lp.name,
    'membership_id', la.membership_id,
    'borrower_display_name', gm.display_name,
    'borrower_member_number', gm.member_number,
    'loan_origin', la.loan_origin,
    'principal_amount', la.principal_amount,
    'interest_rate', la.interest_rate,
    'interest_rate_basis', la.interest_rate_basis,
    'interest_method', la.interest_method,
    'term', la.term,
    'term_unit', la.term_unit,
    'first_repayment_date', la.first_repayment_date,
    'application_date', la.application_date,
    'status', la.status
  ), la.status
  into v_header, v_status
  from public.loan_accounts la
  join public.group_memberships gm on gm.id = la.membership_id
  join public.loan_products lp on lp.id = la.loan_product_id
  where la.id = p_loan_account_id and la.group_id = p_group_id;

  if v_header is null then
    raise exception 'Loan account not found in group' using errcode = '22023';
  end if;

  -- current_state -------------------------------------------------------

  v_write_off_state := public.loan_write_off_recovery_state(p_loan_account_id);

  if v_status = 'WRITTEN_OFF' then
    v_current_state := jsonb_build_object(
      'status', v_status,
      'principal_outstanding', 0,
      'earned_interest_outstanding', 0,
      'penalty_outstanding', 0,
      'total_outstanding', 0,
      'scheduled_unearned_interest', 0,
      'overdue_principal', 0,
      'overdue_interest', 0,
      'overdue_penalty', 0,
      'total_overdue', 0,
      'write_off', v_write_off_state
    );
  else
    select * into v_position
    from public.loan_statement_schedule_position(p_loan_account_id, current_date);

    v_current_state := jsonb_build_object(
      'status', v_status,
      'principal_outstanding', v_position.principal_outstanding,
      'earned_interest_outstanding', v_position.earned_interest_outstanding,
      'penalty_outstanding', v_position.penalty_outstanding,
      'total_outstanding', v_position.total_outstanding,
      'scheduled_unearned_interest', v_position.scheduled_unearned_interest,
      'overdue_principal', v_position.overdue_principal,
      'overdue_interest', v_position.overdue_interest,
      'overdue_penalty', v_position.overdue_penalty,
      'total_overdue', v_position.total_overdue,
      'write_off', v_write_off_state
    );
  end if;

  -- timeline --------------------------------------------------------------

  with events as (
    -- priority 0: loan lifecycle events (excluding types with their own
    -- richer dedicated source below)
    select
      '0:' || e.id::text as event_id,
      case e.event_type::text
        when 'CREATED' then 'LOAN_CREATED'
        when 'SUBMITTED' then 'LOAN_SUBMITTED'
        when 'APPROVED' then 'LOAN_APPROVED'
        when 'REJECTED' then 'LOAN_REJECTED'
        when 'CANCELLED' then 'LOAN_CANCELLED'
        when 'DISBURSED' then 'LOAN_DISBURSED'
        when 'CLOSED' then 'LOAN_CLOSED'
        when 'REOPENED' then 'LOAN_REOPENED'
        when 'MIGRATED' then 'LOAN_MIGRATED'
        when 'EARLY_SETTLED' then 'EARLY_SETTLEMENT'
        else e.event_type::text
      end as event_type,
      null::text as event_subtype,
      e.created_at::date as effective_at,
      e.created_at as created_at,
      0 as source_priority,
      null::bigint as local_seq,
      e.id as row_id,
      case e.event_type::text
        when 'CREATED' then 'LOAN_CREATED'
        when 'SUBMITTED' then 'LOAN_SUBMITTED'
        when 'APPROVED' then 'LOAN_APPROVED'
        when 'REJECTED' then 'LOAN_REJECTED'
        when 'CANCELLED' then 'LOAN_CANCELLED'
        when 'DISBURSED' then 'LOAN_DISBURSED'
        when 'CLOSED' then 'LOAN_CLOSED'
        when 'REOPENED' then 'LOAN_REOPENED'
        when 'MIGRATED' then 'LOAN_MIGRATED'
        when 'EARLY_SETTLED' then 'EARLY_SETTLEMENT'
        else e.event_type::text
      end as title_code,
      e.created_by as actor_user_id,
      false as is_reversed,
      null::text as reversed_by_event_id,
      null::numeric as amount,
      null::jsonb as components,
      jsonb_build_object() as "references",
      jsonb_build_object('reason', e.reason, 'from_status', e.from_status, 'to_status', e.to_status) as metadata
    from public.loan_account_events e
    where e.loan_account_id = p_loan_account_id and e.group_id = p_group_id
      and e.event_type::text not in (
        'PRINCIPAL_PREPAID', 'RESTRUCTURED', 'WRITTEN_OFF', 'WRITE_OFF_REVERSED',
        'RECOVERY_RECORDED', 'RECOVERY_REVERSED'
      )

    union all

    -- priority 1: payments (one row per payment; components aggregated,
    -- scoped strictly to THIS loan's own allocations so a payment that
    -- also touches another loan/contribution never leaks foreign amounts
    -- into this loan's statement)
    select
      '1:' || p.id::text,
      'PAYMENT_POSTED',
      case
        when exists (
          select 1 from public.payment_allocations pa2
          where pa2.payment_id = p.id and pa2.loan_account_id = p_loan_account_id
            and pa2.allocation_target_type = 'LOAN_PRINCIPAL_PREPAYMENT'
        ) then 'PRINCIPAL_PREPAYMENT'
        when exists (
          select 1 from public.payment_allocations pa2
          where pa2.payment_id = p.id and pa2.loan_account_id = p_loan_account_id
            and pa2.allocation_target_type in (
              'LOAN_RECOVERY_PRINCIPAL', 'LOAN_RECOVERY_INTEREST', 'LOAN_RECOVERY_PENALTY'
            )
        ) then 'LOAN_RECOVERY'
        else 'ORDINARY_REPAYMENT'
      end,
      p.effective_at,
      p.created_at,
      1,
      null::bigint,
      p.id,
      case
        when exists (
          select 1 from public.payment_allocations pa2
          where pa2.payment_id = p.id and pa2.loan_account_id = p_loan_account_id
            and pa2.allocation_target_type = 'LOAN_PRINCIPAL_PREPAYMENT'
        ) then 'PRINCIPAL_PREPAYMENT'
        when exists (
          select 1 from public.payment_allocations pa2
          where pa2.payment_id = p.id and pa2.loan_account_id = p_loan_account_id
            and pa2.allocation_target_type in (
              'LOAN_RECOVERY_PRINCIPAL', 'LOAN_RECOVERY_INTEREST', 'LOAN_RECOVERY_PENALTY'
            )
        ) then 'LOAN_RECOVERY'
        else 'ORDINARY_REPAYMENT'
      end,
      p.created_by,
      (p.status = 'REVERSED'),
      null::text,
      coalesce((
        select sum(pa2.amount) from public.payment_allocations pa2
        where pa2.payment_id = p.id and pa2.loan_account_id = p_loan_account_id
      ), 0),
      jsonb_build_object(
        'principal', coalesce((
          select sum(pa2.amount) from public.payment_allocations pa2
          where pa2.payment_id = p.id and pa2.loan_account_id = p_loan_account_id
            and pa2.allocation_target_type in ('LOAN_PRINCIPAL', 'LOAN_PRINCIPAL_PREPAYMENT', 'LOAN_RECOVERY_PRINCIPAL')
        ), 0),
        'interest', coalesce((
          select sum(pa2.amount) from public.payment_allocations pa2
          where pa2.payment_id = p.id and pa2.loan_account_id = p_loan_account_id
            and pa2.allocation_target_type in ('LOAN_INTEREST', 'LOAN_RECOVERY_INTEREST')
        ), 0),
        'penalty', coalesce((
          select sum(pa2.amount) from public.payment_allocations pa2
          where pa2.payment_id = p.id and pa2.loan_account_id = p_loan_account_id
            and pa2.allocation_target_type in ('LOAN_PENALTY', 'LOAN_RECOVERY_PENALTY')
        ), 0)
      ),
      jsonb_build_object('payment_id', p.id, 'receipt_number', p.receipt_number),
      jsonb_build_object(
        'payment_method', p.payment_method,
        'financial_account_id', p.financial_account_id,
        'payment_amount', p.amount,
        'reversed_at', p.reversed_at,
        'reversed_by', p.reversed_by,
        'reversal_reason', p.reversal_reason
      )
    from public.payments p
    where p.group_id = p_group_id
      and exists (
        select 1 from public.payment_allocations pa
        where pa.payment_id = p.id and pa.loan_account_id = p_loan_account_id
      )

    union all

    -- priority 2: penalty assessments
    select
      '2:' || c.id::text,
      'PENALTY_ASSESSED',
      c.origin::text,
      c.assessment_date,
      c.created_at,
      2,
      null::bigint,
      c.id,
      'PENALTY_ASSESSED',
      c.created_by,
      false,
      null::text,
      c.penalty_amount,
      jsonb_build_object('principal', 0, 'interest', 0, 'penalty', c.penalty_amount),
      jsonb_build_object(
        'penalty_charge_id', c.id, 'installment_id', c.loan_installment_id
      ),
      jsonb_build_object('sequence_number', c.sequence_number, 'origin', c.origin)
    from public.loan_penalty_charges c
    where c.loan_account_id = p_loan_account_id and c.group_id = p_group_id

    union all

    -- priority 3: obligation adjustments (waiver/correction/reversal)
    select
      '3:' || oa.id::text,
      case oa.adjustment_type
        when 'WAIVER' then 'OBLIGATION_WAIVER'
        when 'CORRECTION_INCREASE' then 'OBLIGATION_CORRECTION_INCREASE'
        when 'CORRECTION_DECREASE' then 'OBLIGATION_CORRECTION_DECREASE'
        when 'REVERSAL' then 'OBLIGATION_ADJUSTMENT_REVERSED'
        else oa.adjustment_type
      end,
      oa.target_type,
      oa.effective_date,
      oa.created_at,
      3,
      oa.entry_no,
      oa.id,
      case oa.adjustment_type
        when 'WAIVER' then 'OBLIGATION_WAIVER'
        when 'CORRECTION_INCREASE' then 'OBLIGATION_CORRECTION_INCREASE'
        when 'CORRECTION_DECREASE' then 'OBLIGATION_CORRECTION_DECREASE'
        when 'REVERSAL' then 'OBLIGATION_ADJUSTMENT_REVERSED'
        else oa.adjustment_type
      end,
      oa.created_by,
      case
        when oa.adjustment_type = 'REVERSAL' then false
        else exists (
          select 1 from public.loan_obligation_adjustments r
          where r.reverses_adjustment_id = oa.id
        )
      end,
      (
        select '3:' || r.id::text from public.loan_obligation_adjustments r
        where r.reverses_adjustment_id = oa.id
      ),
      oa.amount,
      jsonb_build_object(
        'principal', 0,
        'interest', case when oa.target_type = 'LOAN_INTEREST' then oa.amount else 0 end,
        'penalty', case when oa.target_type = 'LOAN_PENALTY' then oa.amount else 0 end
      ),
      jsonb_build_object(
        'adjustment_id', oa.id,
        'installment_id', oa.loan_installment_id,
        'penalty_charge_id', oa.loan_penalty_charge_id,
        'reverses_adjustment_id', oa.reverses_adjustment_id
      ),
      jsonb_build_object('reason_code', oa.reason_code, 'note', oa.note)
    from public.loan_obligation_adjustments oa
    where oa.loan_account_id = p_loan_account_id and oa.group_id = p_group_id

    union all

    -- priority 4: principal prepayment
    select
      '4:' || pe.id::text,
      'PRINCIPAL_PREPAYMENT',
      pe.treatment::text,
      pe.effective_date,
      pe.created_at,
      4,
      null::bigint,
      pe.id,
      'PRINCIPAL_PREPAYMENT',
      pe.created_by,
      false,
      null::text,
      pe.amount,
      jsonb_build_object('principal', pe.amount, 'interest', 0, 'penalty', 0),
      jsonb_build_object('prepayment_event_id', pe.id, 'payment_id', pe.payment_id),
      jsonb_build_object('treatment', pe.treatment)
    from public.loan_prepayment_events pe
    where pe.loan_account_id = p_loan_account_id and pe.group_id = p_group_id

    union all

    -- priority 5: restructure
    select
      '5:' || re.id::text,
      'LOAN_RESTRUCTURED',
      null::text,
      re.effective_date,
      re.created_at,
      5,
      null::bigint,
      re.id,
      'LOAN_RESTRUCTURED',
      re.created_by,
      false,
      null::text,
      null::numeric,
      null::jsonb,
      jsonb_build_object('restructure_event_id', re.id),
      jsonb_build_object(
        'reason', re.reason,
        'new_interest_rate', re.new_interest_rate,
        'new_term', re.new_term,
        'new_first_installment_date', re.new_first_installment_date
      )
    from public.loan_restructure_events re
    where re.loan_account_id = p_loan_account_id and re.group_id = p_group_id

    union all

    -- priority 6: write-off (both WRITE_OFF and REVERSAL rows)
    select
      '6:' || w.id::text,
      case w.event_type when 'WRITE_OFF' then 'WRITE_OFF' else 'WRITE_OFF_REVERSED' end,
      null::text,
      w.effective_date,
      w.created_at,
      6,
      w.entry_no,
      w.id,
      case w.event_type when 'WRITE_OFF' then 'WRITE_OFF' else 'WRITE_OFF_REVERSED' end,
      w.created_by,
      case
        when w.event_type = 'WRITE_OFF' then exists (
          select 1 from public.loan_write_off_events r where r.reverses_write_off_id = w.id
        )
        else false
      end,
      (
        select '6:' || r.id::text from public.loan_write_off_events r
        where r.reverses_write_off_id = w.id
      ),
      w.principal_amount + w.interest_amount + w.penalty_amount,
      jsonb_build_object('principal', w.principal_amount, 'interest', w.interest_amount, 'penalty', w.penalty_amount),
      jsonb_build_object('write_off_event_id', w.id, 'reverses_write_off_id', w.reverses_write_off_id),
      jsonb_build_object('reason_code', w.reason_code, 'note', w.note)
    from public.loan_write_off_events w
    where w.loan_account_id = p_loan_account_id and w.group_id = p_group_id

    union all

    -- priority 7: recovery
    select
      '7:' || re.id::text,
      'RECOVERY_POSTED',
      null::text,
      p.effective_at,
      re.created_at,
      7,
      re.entry_no,
      re.id,
      'RECOVERY_POSTED',
      re.created_by,
      (p.status = 'REVERSED'),
      null::text,
      re.principal_recovered + re.interest_recovered + re.penalty_recovered,
      jsonb_build_object('principal', re.principal_recovered, 'interest', re.interest_recovered, 'penalty', re.penalty_recovered),
      jsonb_build_object(
        'recovery_event_id', re.id, 'write_off_event_id', re.write_off_event_id,
        'payment_id', re.payment_id, 'receipt_number', p.receipt_number
      ),
      jsonb_build_object('reversed_at', p.reversed_at, 'reversed_by', p.reversed_by, 'reversal_reason', p.reversal_reason)
    from public.loan_recovery_events re
    join public.payments p on p.id = re.payment_id
    where re.loan_account_id = p_loan_account_id and re.group_id = p_group_id
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'event_id', event_id,
      'event_type', event_type,
      'event_subtype', event_subtype,
      'effective_at', effective_at,
      'created_at', created_at,
      'sequence_key', source_priority::text || ':' || coalesce(local_seq::text, '') || ':' || row_id::text,
      'title_code', title_code,
      'actor_user_id', actor_user_id,
      'is_reversed', is_reversed,
      'reversed_by_event_id', reversed_by_event_id,
      'amount', amount,
      'components', components,
      'references', "references",
      'metadata', metadata
    )
    order by effective_at, source_priority, local_seq nulls last, created_at, row_id
  ), '[]'::jsonb)
  into v_timeline
  from events;

  -- schedule ----------------------------------------------------------

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', li.id,
    'installment_number', li.installment_number,
    'due_date', li.due_date,
    'principal_due', li.principal_due,
    'interest_due', li.interest_due,
    'total_due', li.total_due,
    'principal_outstanding', case when v_status = 'WRITTEN_OFF' then 0 else pc.outstanding end,
    'interest_outstanding', case when v_status = 'WRITTEN_OFF' then 0 else ic.outstanding end,
    'penalty_outstanding', case when v_status = 'WRITTEN_OFF' then 0 else penc.outstanding end
  ) order by li.installment_number), '[]'::jsonb)
  into v_schedule_current
  from public.loan_installments li
  cross join lateral (
    select outstanding from public.loan_installment_component_states(li.id) where component_type = 'PRINCIPAL'
  ) pc
  cross join lateral (
    select outstanding from public.loan_installment_component_states(li.id) where component_type = 'INTEREST'
  ) ic
  cross join lateral (
    select outstanding from public.loan_installment_component_states(li.id) where component_type = 'PENALTY'
  ) penc
  where li.loan_account_id = p_loan_account_id and li.group_id = p_group_id
    and li.cancelled_at is null;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', li.id,
    'installment_number', li.installment_number,
    'due_date', li.due_date,
    'principal_due', li.principal_due,
    'interest_due', li.interest_due,
    'cancelled_at', li.cancelled_at,
    'cancellation_reason', li.cancellation_reason,
    'cancelled_by_payment_id', li.cancelled_by_payment_id,
    'created_by_payment_id', li.created_by_payment_id
  ) order by li.installment_number, li.cancelled_at), '[]'::jsonb)
  into v_schedule_history
  from public.loan_installments li
  where li.loan_account_id = p_loan_account_id and li.group_id = p_group_id
    and li.cancelled_at is not null;

  return jsonb_build_object(
    'header', v_header,
    'current_state', v_current_state,
    'timeline', v_timeline,
    'schedule', jsonb_build_object('current', v_schedule_current, 'history', v_schedule_history)
  );
end;
$function$;
