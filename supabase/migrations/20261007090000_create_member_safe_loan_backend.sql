-- Prompt 09G-B5-B: Member-safe loan backend (append-only).
--
-- Adds the self-service "My Loans" read surface for an authenticated member
-- viewing ONLY their own loan accounts in the selected group:
--   * loan.self_view permission (MEMBER, ADMIN) — permission seeding only;
--     runtime authorization is always has_group_permission(), never a role name
--   * rpc_get_my_loans            — paginated list of caller-owned non-DRAFT loans
--   * rpc_get_my_loan_detail      — one caller-owned loan, member-safe terms
--   * rpc_get_my_loan_schedule    — current repayment schedule + replaced/cancelled history
--   * rpc_get_my_loan_timeline    — effective-dated, NON-running-balance activity
--
-- Ownership (non-negotiable): the membership is derived ONLY from
-- current_membership_id(p_group_id); the loan must satisfy BOTH
-- loan.group_id = p_group_id AND loan.membership_id = caller membership.
-- No caller-supplied membership/user/phone/role, no officer fallback, no
-- ADMIN bypass. A loan that is missing, DRAFT, in another group, or owned
-- by another membership is reported identically (no existence oracle).
--
-- Accounting: NO financial math is re-implemented here. Balances come from
-- loan_account_summary()/loan_historical_position() (A3 contract:
-- total = principal + earned interest + penalty; scheduled unearned
-- interest excluded; WRITTEN_OFF receivable zero).
--
-- Direct table grants and RLS are NOT changed. Every new function is
-- SECURITY DEFINER with an explicit empty search_path; RPCs are
-- authenticated-only; internal helpers are not client-executable.

-- ---------------------------------------------------------------------------
-- 1. Permission (B5-A locked default grants: MEMBER, ADMIN).
-- ---------------------------------------------------------------------------

insert into public.permissions (code, name, description) values
  ('loan.self_view', 'View own loans', 'View the caller''s own loan accounts, repayment schedule and loan activity in their current group membership.');

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code = 'loan.self_view'
where r.code in ('MEMBER', 'ADMIN')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- 2. Internal read-model helpers (not client-executable).
-- ---------------------------------------------------------------------------

-- Member-facing status. DRAFT never reaches here (excluded upstream).
-- DISBURSED is a transient, never-durable lifecycle state; if ever present
-- it is presented as ACTIVE. Presentation normalization only.
create or replace function public.member_loan_status_code(p_status public.loan_account_status)
returns text
language sql
immutable
set search_path = ''
as $function$
  select case when p_status = 'DISBURSED' then 'ACTIVE' else p_status::text end;
$function$;

-- Stable origin code. A MIGRATED loan is presented as an opening position
-- (never the word MIGRATED). A NEW loan has no origin context (null).
create or replace function public.member_loan_origin_context(p_origin public.loan_origin)
returns text
language sql
immutable
set search_path = ''
as $function$
  select case when p_origin = 'MIGRATED' then 'OPENING_POSITION' else null end;
$function$;

-- Resolves the caller's OWN membership for the group, after the auth,
-- operational-membership and loan.self_view checks. Shared by all four RPCs.
create or replace function public.member_loan_membership_id(p_group_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_membership_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  if p_group_id is null then
    raise exception 'p_group_id is required' using errcode = '22023';
  end if;

  v_membership_id := public.current_membership_id(p_group_id);

  if v_membership_id is null then
    raise exception 'No active membership in this group' using errcode = '42501';
  end if;

  if not public.has_group_permission(p_group_id, 'loan.self_view') then
    raise exception 'Not authorized to view your loans in this group' using errcode = '42501';
  end if;

  return v_membership_id;
end;
$function$;

-- Activity timeline source. Every event comes from a genuine persisted
-- source row; lifecycle rows that merely duplicate a dedicated source table
-- (DISBURSED, MIGRATED, PRINCIPAL_PREPAID, RESTRUCTURED, WRITTEN_OFF,
-- WRITE_OFF_REVERSED, RECOVERY_RECORDED/REVERSED, CREATED, UPDATED) are
-- deliberately excluded so no fact appears twice.
--
-- Cash rules: ONE payments row = ONE cash event for this loan, amount =
-- the allocations attributable to THIS loan. Wallet-funded loan allocations
-- are grouped per wallet entry and are NOT cash (is_cash = false). A recovery
-- payment is the same payment classified RECOVERY_POSTED, never a second row.
--
-- Internal: callers must have already passed member_loan_membership_id() and
-- an ownership check. Not client-executable.
create or replace function public.member_loan_timeline_source(p_group_id uuid, p_loan_account_id uuid)
returns table (
  event_id uuid,
  event_type text,
  event_subtype text,
  effective_at date,
  created_at timestamptz,
  is_reversed boolean,
  amount numeric,
  is_cash boolean,
  cash_direction text,
  component_breakdown jsonb,
  metadata jsonb
)
language sql
stable
security definer
set search_path = ''
as $function$
with loan_alloc as (
  select pa.id, pa.payment_id, pa.wallet_entry_id, pa.line_number, pa.amount,
         pa.allocation_target_type::text as target
  from public.payment_allocations pa
  where pa.group_id = p_group_id
    and pa.loan_account_id = p_loan_account_id
),
payment_sums as (
  select la.payment_id,
         sum(la.amount) as total,
         sum(la.amount) filter (where la.target in ('LOAN_PRINCIPAL', 'LOAN_PRINCIPAL_PREPAYMENT', 'LOAN_RECOVERY_PRINCIPAL')) as principal,
         sum(la.amount) filter (where la.target in ('LOAN_INTEREST', 'LOAN_RECOVERY_INTEREST')) as interest,
         sum(la.amount) filter (where la.target in ('LOAN_PENALTY', 'LOAN_RECOVERY_PENALTY')) as penalty
  from loan_alloc la
  where la.payment_id is not null
  group by la.payment_id
),
wallet_sums as (
  select la.wallet_entry_id,
         (array_agg(la.id order by la.line_number, la.id))[1] as event_id,
         sum(la.amount) as total,
         sum(la.amount) filter (where la.target in ('LOAN_PRINCIPAL', 'LOAN_PRINCIPAL_PREPAYMENT', 'LOAN_RECOVERY_PRINCIPAL')) as principal,
         sum(la.amount) filter (where la.target in ('LOAN_INTEREST', 'LOAN_RECOVERY_INTEREST')) as interest,
         sum(la.amount) filter (where la.target in ('LOAN_PENALTY', 'LOAN_RECOVERY_PENALTY')) as penalty
  from loan_alloc la
  where la.wallet_entry_id is not null
  group by la.wallet_entry_id
)
-- Lifecycle events with no dedicated source table.
select e.id,
       case e.event_type::text
         when 'SUBMITTED' then 'LOAN_SUBMITTED'
         when 'APPROVED' then 'LOAN_APPROVED'
         when 'REJECTED' then 'LOAN_REJECTED'
         when 'CANCELLED' then 'LOAN_CANCELLED'
         when 'CLOSED' then 'LOAN_CLOSED'
         when 'REOPENED' then 'LOAN_REOPENED'
         when 'EARLY_SETTLED' then 'LOAN_EARLY_SETTLED'
       end,
       null::text,
       (e.created_at at time zone 'UTC')::date,
       e.created_at,
       false,
       null::numeric,
       false,
       null::text,
       null::jsonb,
       '{}'::jsonb
from public.loan_account_events e
where e.group_id = p_group_id
  and e.loan_account_id = p_loan_account_id
  and e.event_type::text in ('SUBMITTED', 'APPROVED', 'REJECTED', 'CANCELLED', 'CLOSED', 'REOPENED', 'EARLY_SETTLED')

union all

-- Disbursement (cash OUT to the member). Never fabricated for a MIGRATED loan.
select d.id,
       'LOAN_DISBURSED',
       null::text,
       d.effective_at,
       d.created_at,
       false,
       d.amount,
       true,
       'OUT',
       jsonb_build_object('principal', d.amount),
       '{}'::jsonb
from public.loan_disbursements d
where d.group_id = p_group_id
  and d.loan_account_id = p_loan_account_id

union all

-- Opening position (non-cash). The authoritative snapshot, once only.
select o.id,
       'OPENING_POSITION',
       null::text,
       o.opening_as_of_date,
       o.created_at,
       false,
       o.opening_principal_outstanding + o.opening_interest_arrears + o.opening_penalty_arrears,
       false,
       null::text,
       jsonb_build_object(
         'principal', o.opening_principal_outstanding,
         'interest', o.opening_interest_arrears,
         'penalty', o.opening_penalty_arrears
       ),
       jsonb_build_object('original_disbursement_date', o.original_disbursement_date)
from public.loan_opening_positions o
where o.group_id = p_group_id
  and o.loan_account_id = p_loan_account_id

union all

-- Payments (cash IN): one row per payment, amount attributable to this loan.
select p.id,
       case when exists (
         select 1 from public.loan_recovery_events re
         where re.payment_id = p.id and re.loan_account_id = p_loan_account_id
       ) then 'RECOVERY_POSTED' else 'PAYMENT_POSTED' end,
       null::text,
       p.effective_at,
       p.created_at,
       p.status = 'REVERSED',
       ps.total,
       true,
       'IN',
       jsonb_strip_nulls(jsonb_build_object('principal', ps.principal, 'interest', ps.interest, 'penalty', ps.penalty)),
       jsonb_build_object(
         'receipt_number', p.receipt_number,
         'payment_method', p.payment_method,
         'reversed_at', p.reversed_at
       )
from public.payments p
join payment_sums ps on ps.payment_id = p.id
where p.group_id = p_group_id

union all

-- Wallet-applied loan allocations (not cash; wallet balance applied to loan).
select ws.event_id,
       'WALLET_APPLIED',
       null::text,
       we.effective_at,
       we.created_at,
       exists (select 1 from public.member_wallet_entries r where r.reverses_entry_id = we.id),
       ws.total,
       false,
       null::text,
       jsonb_strip_nulls(jsonb_build_object('principal', ws.principal, 'interest', ws.interest, 'penalty', ws.penalty)),
       '{}'::jsonb
from wallet_sums ws
join public.member_wallet_entries we on we.id = ws.wallet_entry_id

union all

-- Penalty assessed by its economic date (assessment_date). Opening-origin
-- penalties are part of the opening snapshot and are NOT repeated here.
select pc.id,
       'PENALTY_ASSESSED',
       null::text,
       pc.assessment_date,
       pc.created_at,
       false,
       pc.penalty_amount,
       false,
       null::text,
       jsonb_build_object('penalty', pc.penalty_amount),
       jsonb_build_object('installment_number', li.installment_number)
from public.loan_penalty_charges pc
left join public.loan_installments li on li.id = pc.loan_installment_id
where pc.group_id = p_group_id
  and pc.loan_account_id = p_loan_account_id
  and pc.origin::text = 'ASSESSED'

union all

-- Obligation adjustments (non-cash). Reversal rows are their own event.
select a.id,
       case
         when a.adjustment_type = 'WAIVER' then 'OBLIGATION_WAIVER'
         when a.adjustment_type = 'REVERSAL' then 'OBLIGATION_ADJUSTMENT_REVERSED'
         else 'OBLIGATION_CORRECTION'
       end,
       a.component,
       a.effective_date,
       a.created_at,
       exists (select 1 from public.loan_obligation_adjustments r where r.reverses_adjustment_id = a.id),
       a.amount,
       false,
       null::text,
       jsonb_build_object(a.component_key, a.amount),
       jsonb_build_object('adjustment_type', a.adjustment_type, 'reason_code', a.reason_code)
from (
  select x.*,
         case x.target_type
           when 'LOAN_PRINCIPAL' then 'PRINCIPAL'
           when 'LOAN_INTEREST' then 'INTEREST'
           else 'PENALTY'
         end as component,
         case x.target_type
           when 'LOAN_PRINCIPAL' then 'principal'
           when 'LOAN_INTEREST' then 'interest'
           else 'penalty'
         end as component_key
  from public.loan_obligation_adjustments x
  where x.group_id = p_group_id
    and x.loan_account_id = p_loan_account_id
) a

union all

-- Principal prepayment (NON-CASH semantic event; its cash is the payment row).
select pe.id,
       'PRINCIPAL_PREPAYMENT',
       pe.treatment::text,
       pe.effective_date,
       pe.created_at,
       coalesce(pay.status = 'REVERSED', false),
       null::numeric,
       false,
       null::text,
       '{}'::jsonb,
       jsonb_build_object('treatment', pe.treatment::text, 'principal_reduction_amount', pe.amount)
from public.loan_prepayment_events pe
left join public.payments pay on pay.id = pe.payment_id
where pe.group_id = p_group_id
  and pe.loan_account_id = p_loan_account_id

union all

-- Restructure (NON-CASH). Internal snapshots and officer reason text are withheld.
select re.id,
       'LOAN_RESTRUCTURED',
       null::text,
       re.effective_date,
       re.created_at,
       false,
       null::numeric,
       false,
       null::text,
       '{}'::jsonb,
       jsonb_strip_nulls(jsonb_build_object(
         'new_interest_rate', re.new_interest_rate,
         'new_term', re.new_term,
         'new_first_installment_date', re.new_first_installment_date
       ))
from public.loan_restructure_events re
where re.group_id = p_group_id
  and re.loan_account_id = p_loan_account_id

union all

-- Write-off and its reversal (NON-CASH). Officer note text is withheld.
select w.id,
       case when w.event_type::text = 'REVERSAL' then 'WRITE_OFF_REVERSED' else 'WRITE_OFF' end,
       null::text,
       w.effective_date,
       w.created_at,
       exists (select 1 from public.loan_write_off_events r where r.reverses_write_off_id = w.id),
       w.principal_amount + w.interest_amount + w.penalty_amount,
       false,
       null::text,
       jsonb_build_object('principal', w.principal_amount, 'interest', w.interest_amount, 'penalty', w.penalty_amount),
       jsonb_build_object('reason_code', w.reason_code)
from public.loan_write_off_events w
where w.group_id = p_group_id
  and w.loan_account_id = p_loan_account_id;
$function$;

-- ---------------------------------------------------------------------------
-- 3. RPC: my loans (list). Caller-owned, non-DRAFT loans only. No global
--    total across loans is returned; each item carries its own position.
-- ---------------------------------------------------------------------------

create or replace function public.rpc_get_my_loans(
  p_group_id uuid,
  p_limit integer default 20,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_membership_id uuid;
  v_limit integer;
  v_offset integer;
  v_total bigint;
  v_items jsonb;
begin
  v_membership_id := public.member_loan_membership_id(p_group_id);

  v_limit := least(greatest(coalesce(p_limit, 20), 1), 200);
  v_offset := greatest(coalesce(p_offset, 0), 0);

  select count(*)
  into v_total
  from public.loan_accounts la
  where la.group_id = p_group_id
    and la.membership_id = v_membership_id
    and la.status <> 'DRAFT';

  select coalesce(jsonb_agg(page.item order by page.created_at desc, page.loan_account_id desc), '[]'::jsonb)
  into v_items
  from (
    select la.created_at,
           la.id as loan_account_id,
           jsonb_build_object(
             'loan_account_id', la.id,
             'loan_number', la.loan_number,
             'product_id', lp.id,
             'product_name', lp.name,
             'member_status', public.member_loan_status_code(la.status),
             'origin_context', public.member_loan_origin_context(la.loan_origin),
             'original_principal', case when la.loan_origin = 'MIGRATED' then op.original_principal else la.principal_amount end,
             'current_position', jsonb_build_object(
               'principal_outstanding', s.principal_outstanding,
               'interest_outstanding', s.interest_outstanding,
               'penalty_outstanding', s.penalty_outstanding,
               'total_outstanding', s.total_outstanding
             ),
             'next_due_date', s.next_due_date,
             'overdue_amount', s.overdue_amount
           ) as item
    from public.loan_accounts la
    join public.loan_products lp on lp.id = la.loan_product_id
    left join public.loan_opening_positions op on op.loan_account_id = la.id
    cross join lateral public.loan_account_summary(la.id) s
    where la.group_id = p_group_id
      and la.membership_id = v_membership_id
      and la.status <> 'DRAFT'
    order by la.created_at desc, la.id desc
    limit v_limit offset v_offset
  ) page;

  return jsonb_build_object(
    'items', v_items,
    'pagination', jsonb_build_object(
      'limit', v_limit,
      'offset', v_offset,
      'total_count', v_total,
      'has_more', (v_offset + v_limit) < v_total
    )
  );
end;
$function$;

-- ---------------------------------------------------------------------------
-- 4. RPC: my loan detail. One caller-owned loan. Terms are persisted values
--    only; penalty-policy internals, officer identity, approval notes,
--    financial account, cashbook/idempotency references and migration
--    references are NOT returned.
-- ---------------------------------------------------------------------------

create or replace function public.rpc_get_my_loan_detail(p_group_id uuid, p_loan_account_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_membership_id uuid;
  v_result jsonb;
begin
  v_membership_id := public.member_loan_membership_id(p_group_id);

  if p_loan_account_id is null then
    raise exception 'p_loan_account_id is required' using errcode = '22023';
  end if;

  select jsonb_build_object(
    'loan_account_id', la.id,
    'loan_number', la.loan_number,
    'product', jsonb_build_object('product_id', lp.id, 'product_name', lp.name),
    'member_status', public.member_loan_status_code(la.status),
    'origin_context', public.member_loan_origin_context(la.loan_origin),
    'application_date', la.application_date,
    'opening_as_of_date', op.opening_as_of_date,
    'original_principal', case when la.loan_origin = 'MIGRATED' then op.original_principal else la.principal_amount end,
    'original_disbursement_date', case when la.loan_origin = 'MIGRATED' then op.original_disbursement_date else d.effective_at end,
    'terms', jsonb_build_object(
      'interest_rate', la.interest_rate,
      'interest_rate_basis', la.interest_rate_basis,
      'interest_method', la.interest_method,
      'term', la.term,
      'term_unit', la.term_unit,
      'repayment_frequency', la.repayment_frequency,
      'first_repayment_date', la.first_repayment_date
    ),
    'final_due_date', (
      select max(li.due_date)
      from public.loan_installments li
      where li.loan_account_id = la.id
        and li.cancelled_at is null
    ),
    'current_position', jsonb_build_object(
      'principal_outstanding', s.principal_outstanding,
      'interest_outstanding', s.interest_outstanding,
      'penalty_outstanding', s.penalty_outstanding,
      'total_outstanding', s.total_outstanding
    ),
    'next_due_date', s.next_due_date,
    'overdue_amount', s.overdue_amount
  )
  into v_result
  from public.loan_accounts la
  join public.loan_products lp on lp.id = la.loan_product_id
  left join public.loan_opening_positions op on op.loan_account_id = la.id
  left join public.loan_disbursements d on d.loan_account_id = la.id
  cross join lateral public.loan_account_summary(la.id) s
  where la.id = p_loan_account_id
    and la.group_id = p_group_id
    and la.membership_id = v_membership_id
    and la.status <> 'DRAFT';

  if v_result is null then
    raise exception 'Loan account not found' using errcode = '22023';
  end if;

  return v_result;
end;
$function$;

-- ---------------------------------------------------------------------------
-- 5. RPC: my loan schedule. CURRENT repayment schedule (not an as-of
--    statement) plus replaced/cancelled history. Per-row figures are
--    contractual schedule information. Only the current_* outstanding
--    fields contribute to the account position; they are never summed here
--    into an account total. Future scheduled interest is shown separately as
--    scheduled_future_interest_outstanding and is never current interest.
--
-- member_schedule_status (deterministic, first match wins):
--   SETTLED            remaining obligation of the row is zero
--   WRITTEN_OFF        loan written off and the row still has an obligation
--   OVERDUE            outstanding and due_date < current date
--   PARTIALLY_SETTLED  part paid, not overdue (takes precedence over DUE)
--   DUE                due today with outstanding
--   UPCOMING           future effective installment
-- History rows: REPLACED when cancelled by a restructure or a principal
-- prepayment (persisted cancellation_reason codes), otherwise CANCELLED.
-- ---------------------------------------------------------------------------

create or replace function public.rpc_get_my_loan_schedule(p_group_id uuid, p_loan_account_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_membership_id uuid;
  v_status text;
  v_written_off boolean;
  v_current jsonb;
  v_history jsonb;
begin
  v_membership_id := public.member_loan_membership_id(p_group_id);

  if p_loan_account_id is null then
    raise exception 'p_loan_account_id is required' using errcode = '22023';
  end if;

  select la.status::text
  into v_status
  from public.loan_accounts la
  where la.id = p_loan_account_id
    and la.group_id = p_group_id
    and la.membership_id = v_membership_id
    and la.status <> 'DRAFT';

  if v_status is null then
    raise exception 'Loan account not found' using errcode = '22023';
  end if;

  v_written_off := v_status = 'WRITTEN_OFF';

  with rows_base as (
    select li.id,
           li.installment_number,
           li.due_date,
           li.principal_due,
           li.interest_due,
           li.total_due,
           li.cancelled_at,
           li.cancellation_reason,
           coalesce(pc.allocated, 0) as paid_principal,
           coalesce(ic.allocated, 0) as paid_interest,
           coalesce(penc.allocated, 0) as paid_penalty,
           coalesce(pc.outstanding, 0) as raw_principal,
           coalesce(ic.outstanding, 0) as raw_interest,
           coalesce(penc.outstanding, 0) as raw_penalty
    from public.loan_installments li
    left join lateral (
      select * from public.loan_installment_component_states(li.id) where component_type = 'PRINCIPAL'
    ) pc on true
    left join lateral (
      select * from public.loan_installment_component_states(li.id) where component_type = 'INTEREST'
    ) ic on true
    left join lateral (
      select * from public.loan_installment_component_states(li.id) where component_type = 'PENALTY'
    ) penc on true
    where li.loan_account_id = p_loan_account_id
      and li.group_id = p_group_id
  ),
  rows_status as (
    select rb.*,
           (rb.raw_principal + rb.raw_interest + rb.raw_penalty) as raw_total,
           (rb.paid_principal + rb.paid_interest + rb.paid_penalty) as paid_total,
           case
             when (rb.raw_principal + rb.raw_interest + rb.raw_penalty) = 0 then 'SETTLED'
             when v_written_off then 'WRITTEN_OFF'
             when rb.due_date < current_date then 'OVERDUE'
             when (rb.paid_principal + rb.paid_interest + rb.paid_penalty) > 0 then 'PARTIALLY_SETTLED'
             when rb.due_date = current_date then 'DUE'
             else 'UPCOMING'
           end as member_schedule_status
    from rows_base rb
  )
  select
    coalesce(jsonb_agg(jsonb_build_object(
      'installment_id', rs.id,
      'installment_number', rs.installment_number,
      'due_date', rs.due_date,
      'scheduled_principal', rs.principal_due,
      'scheduled_interest', rs.interest_due,
      'scheduled_total', rs.total_due,
      'paid_principal', rs.paid_principal,
      'paid_interest', rs.paid_interest,
      'paid_penalty', rs.paid_penalty,
      'current_principal_outstanding', case when v_written_off then 0 else rs.raw_principal end,
      'current_earned_interest_outstanding', case when v_written_off or rs.due_date > current_date then 0 else rs.raw_interest end,
      'current_penalty_outstanding', case when v_written_off then 0 else rs.raw_penalty end,
      'current_total_outstanding', case when v_written_off then 0
        else rs.raw_principal + case when rs.due_date <= current_date then rs.raw_interest else 0 end + rs.raw_penalty end,
      'scheduled_future_interest_outstanding', case when v_written_off or rs.due_date <= current_date then 0 else rs.raw_interest end,
      'member_schedule_status', rs.member_schedule_status
    ) order by rs.installment_number, rs.id) filter (where rs.cancelled_at is null), '[]'::jsonb),
    coalesce(jsonb_agg(jsonb_build_object(
      'installment_id', rs.id,
      'installment_number', rs.installment_number,
      'due_date', rs.due_date,
      'scheduled_principal', rs.principal_due,
      'scheduled_interest', rs.interest_due,
      'scheduled_total', rs.total_due,
      'paid_principal', rs.paid_principal,
      'paid_interest', rs.paid_interest,
      'paid_penalty', rs.paid_penalty,
      'cancelled_on', (rs.cancelled_at at time zone 'UTC')::date,
      'member_schedule_status', case when rs.cancellation_reason in ('RESTRUCTURE', 'PRINCIPAL_PREPAYMENT') then 'REPLACED' else 'CANCELLED' end,
      'replacement_reason', case when rs.cancellation_reason in ('RESTRUCTURE', 'PRINCIPAL_PREPAYMENT') then rs.cancellation_reason else null end
    ) order by rs.installment_number, rs.cancelled_at, rs.id) filter (where rs.cancelled_at is not null), '[]'::jsonb)
  into v_current, v_history
  from rows_status rs;

  return jsonb_build_object(
    'loan_account_id', p_loan_account_id,
    'member_status', public.member_loan_status_code(
      (select la.status from public.loan_accounts la where la.id = p_loan_account_id)
    ),
    'current', v_current,
    'history', v_history
  );
end;
$function$;

-- ---------------------------------------------------------------------------
-- 6. RPC: my loan timeline. Effective-dated ACTIVITY, newest first. Not a
--    running-balance statement: no balance_after, no running total.
--    Deterministic order: effective_at desc, created_at desc, event_id desc.
-- ---------------------------------------------------------------------------

create or replace function public.rpc_get_my_loan_timeline(
  p_group_id uuid,
  p_loan_account_id uuid,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_membership_id uuid;
  v_limit integer;
  v_offset integer;
  v_total bigint;
  v_items jsonb;
begin
  v_membership_id := public.member_loan_membership_id(p_group_id);

  if p_loan_account_id is null then
    raise exception 'p_loan_account_id is required' using errcode = '22023';
  end if;

  if not exists (
    select 1 from public.loan_accounts la
    where la.id = p_loan_account_id
      and la.group_id = p_group_id
      and la.membership_id = v_membership_id
      and la.status <> 'DRAFT'
  ) then
    raise exception 'Loan account not found' using errcode = '22023';
  end if;

  v_limit := least(greatest(coalesce(p_limit, 50), 1), 200);
  v_offset := greatest(coalesce(p_offset, 0), 0);

  select count(*)
  into v_total
  from public.member_loan_timeline_source(p_group_id, p_loan_account_id);

  select coalesce(jsonb_agg(jsonb_build_object(
    'event_id', ev.event_id,
    'event_type', ev.event_type,
    'event_subtype', ev.event_subtype,
    'effective_at', ev.effective_at,
    'created_at', ev.created_at,
    'is_reversed', ev.is_reversed,
    'amount', ev.amount,
    'is_cash', ev.is_cash,
    'cash_direction', ev.cash_direction,
    'component_breakdown', ev.component_breakdown,
    'metadata', ev.metadata
  ) order by ev.effective_at desc, ev.created_at desc, ev.event_id desc), '[]'::jsonb)
  into v_items
  from (
    select *
    from public.member_loan_timeline_source(p_group_id, p_loan_account_id)
    order by effective_at desc, created_at desc, event_id desc
    limit v_limit offset v_offset
  ) ev;

  return jsonb_build_object(
    'loan_account_id', p_loan_account_id,
    'items', v_items,
    'pagination', jsonb_build_object(
      'limit', v_limit,
      'offset', v_offset,
      'total_count', v_total,
      'has_more', (v_offset + v_limit) < v_total
    )
  );
end;
$function$;

-- ---------------------------------------------------------------------------
-- 7. Grants. RPCs: authenticated only. Internal helpers: not client-executable
--    (they run as the definer from within the RPCs above).
-- ---------------------------------------------------------------------------

revoke all on function public.member_loan_status_code(public.loan_account_status) from public, anon, authenticated;
revoke all on function public.member_loan_origin_context(public.loan_origin) from public, anon, authenticated;
revoke all on function public.member_loan_membership_id(uuid) from public, anon, authenticated;
revoke all on function public.member_loan_timeline_source(uuid, uuid) from public, anon, authenticated;

revoke all on function public.rpc_get_my_loans(uuid, integer, integer) from public;
revoke all on function public.rpc_get_my_loan_detail(uuid, uuid) from public;
revoke all on function public.rpc_get_my_loan_schedule(uuid, uuid) from public;
revoke all on function public.rpc_get_my_loan_timeline(uuid, uuid, integer, integer) from public;

revoke execute on function public.rpc_get_my_loans(uuid, integer, integer) from anon;
revoke execute on function public.rpc_get_my_loan_detail(uuid, uuid) from anon;
revoke execute on function public.rpc_get_my_loan_schedule(uuid, uuid) from anon;
revoke execute on function public.rpc_get_my_loan_timeline(uuid, uuid, integer, integer) from anon;

grant execute on function public.rpc_get_my_loans(uuid, integer, integer) to authenticated;
grant execute on function public.rpc_get_my_loan_detail(uuid, uuid) to authenticated;
grant execute on function public.rpc_get_my_loan_schedule(uuid, uuid) to authenticated;
grant execute on function public.rpc_get_my_loan_timeline(uuid, uuid, integer, integer) to authenticated;

comment on function public.rpc_get_my_loans(uuid, integer, integer) is
  'Caller-owned, non-DRAFT loan accounts in the selected group (09G-B5-B). '
  'Ownership via current_membership_id() + loan.self_view only. Each item '
  'carries its own canonical current position; there is no global total.';
comment on function public.rpc_get_my_loan_detail(uuid, uuid) is
  'One caller-owned loan (09G-B5-B). Member-safe identity, terms and canonical '
  'current position. Not-found and not-owned are indistinguishable.';
comment on function public.rpc_get_my_loan_schedule(uuid, uuid) is
  'Current repayment schedule plus replaced/cancelled history for one caller-owned '
  'loan (09G-B5-B). Contractual schedule information, not an as-of statement.';
comment on function public.rpc_get_my_loan_timeline(uuid, uuid, integer, integer) is
  'Effective-dated activity timeline for one caller-owned loan (09G-B5-B). Activity '
  'only: no running balance. One payment row per payment for this loan.';
