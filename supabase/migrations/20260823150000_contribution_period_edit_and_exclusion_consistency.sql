-- Prompt 06A-CLOSEOUT: DRAFT/SCHEDULED period edit
-- (rpc_update_contribution_period) + excluded/enrolled read-consistency.
--
-- 1. There was previously no way to correct a DRAFT/SCHEDULED period's
--    label/dates before OPEN short of cancelling and recreating it.
--    rpc_update_contribution_period fills that gap: only DRAFT/SCHEDULED
--    periods are editable, contribution_setup_id can never change (no
--    parameter for it at all, matching rpc_update_contribution_setup/
--    rpc_update_contribution_type's precedent of simply omitting an
--    immutable parent reference from the update signature), and every
--    other update RPC's coalesce convention is reused: a null parameter
--    means "leave this field unchanged", not "clear it".
--
-- 2. rpc_get_contribution_period's excluded_count previously counted
--    every historical contribution_period_member_exclusions row for the
--    period, including a member who was later explicitly enrolled
--    post-OPEN (rpc_enroll_member_in_contribution_period) and therefore
--    now has a charge. That misleadingly reported them as still
--    "excluded/unassessed". The exclusion row itself is deliberately
--    preserved as historical pre-open roster information (never
--    deleted/rewritten just because enrollment happened later) — only
--    the *count* semantics change: excluded_count now means "excluded
--    members who do NOT currently have a charge for this period".

-- ---------------------------------------------------------------------
-- rpc_update_contribution_period
-- ---------------------------------------------------------------------

create or replace function public.rpc_update_contribution_period(
  p_group_id uuid,
  p_period_id uuid,
  p_label text default null,
  p_period_start date default null,
  p_period_end date default null,
  p_obligation_date date default null,
  p_eligibility_date date default null,
  p_due_date date default null,
  p_scheduled_open_date date default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_period record;
  v_setup record;
  v_new_label text;
  v_new_period_start date;
  v_new_period_end date;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'contribution.period.manage') then
    raise exception 'Not authorized to manage contribution periods in this group' using errcode = '42501';
  end if;

  select * into v_period
  from public.contribution_periods
  where id = p_period_id
  for update;

  if v_period.group_id is null or v_period.group_id <> p_group_id then
    raise exception 'Contribution period not found in group' using errcode = '22023';
  end if;

  -- Locked invariant, repeated from rpc_open_contribution_period's
  -- header comment: only DRAFT/SCHEDULED periods create zero charges,
  -- so only DRAFT/SCHEDULED periods may still be edited. OPEN/CLOSED/
  -- CANCELLED are immutable through this RPC.
  if v_period.status not in ('DRAFT', 'SCHEDULED') then
    raise exception 'CONTRIBUTION_PERIOD_NOT_EDITABLE' using errcode = 'P0001';
  end if;

  if p_label is not null and btrim(p_label) = '' then
    raise exception 'Contribution period label cannot be blank' using errcode = '22023';
  end if;

  v_new_label := coalesce(nullif(btrim(p_label), ''), v_period.label);
  v_new_period_start := coalesce(p_period_start, v_period.period_start);
  v_new_period_end := coalesce(p_period_end, v_period.period_end);

  if v_new_period_start > v_new_period_end then
    raise exception 'Invalid period dates' using errcode = '22023';
  end if;

  select * into v_setup
  from public.contribution_setups
  where id = v_period.contribution_setup_id;

  -- MONTHLY duplicate-month protection, re-checked against the
  -- resulting period_start (excluding this period's own row) exactly
  -- like rpc_create_contribution_period's original check.
  if v_setup.schedule_mode = 'MONTHLY' and exists (
    select 1 from public.contribution_periods
    where contribution_setup_id = v_period.contribution_setup_id
      and id <> p_period_id
      and status <> 'CANCELLED'
      and date_trunc('month', period_start) = date_trunc('month', v_new_period_start)
  ) then
    raise exception 'DUPLICATE_MONTHLY_PERIOD' using errcode = 'P0001';
  end if;

  -- No charges exist yet (DRAFT/SCHEDULED never post any) so there is
  -- nothing to mutate beyond the period row itself — an eligibility_date
  -- change here changes future preview/open behaviour only.
  update public.contribution_periods
  set
    label = v_new_label,
    period_start = v_new_period_start,
    period_end = v_new_period_end,
    obligation_date = coalesce(p_obligation_date, obligation_date),
    eligibility_date = coalesce(p_eligibility_date, eligibility_date),
    due_date = coalesce(p_due_date, due_date),
    scheduled_open_date = coalesce(p_scheduled_open_date, scheduled_open_date)
  where id = p_period_id;

  select jsonb_build_object(
    'id', id, 'group_id', group_id, 'contribution_setup_id', contribution_setup_id,
    'label', label, 'period_start', period_start, 'period_end', period_end,
    'obligation_date', obligation_date, 'eligibility_date', eligibility_date, 'due_date', due_date,
    'status', status, 'scheduled_open_date', scheduled_open_date,
    'created_at', created_at, 'updated_at', updated_at
  )
  into v_result
  from public.contribution_periods
  where id = p_period_id;

  return v_result;
end;
$$;

revoke all on function public.rpc_update_contribution_period(uuid, uuid, text, date, date, date, date, date, date) from public;
grant execute on function public.rpc_update_contribution_period(uuid, uuid, text, date, date, date, date, date, date) to authenticated;
revoke execute on function public.rpc_update_contribution_period(uuid, uuid, text, date, date, date, date, date, date) from anon;

-- ---------------------------------------------------------------------
-- rpc_get_contribution_period — excluded_count consistency fix.
-- ---------------------------------------------------------------------
--
-- Same function as 20260823140000_create_contribution_read_rpcs.sql,
-- with only the excluded_count computation changed (see header comment
-- above): a member with an explicit pre-open exclusion who was later
-- explicitly enrolled post-OPEN now has a charge, so they no longer
-- count as currently excluded/unassessed. The exclusion row itself is
-- untouched — this only changes what the summary counts.

create or replace function public.rpc_get_contribution_period(
  p_group_id uuid,
  p_period_id uuid
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_period record;
  v_excluded_count integer;
  v_custom_amount_count integer;
  v_total_members_charged integer;
  v_total_base_assessed numeric;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'contribution.view') then
    raise exception 'Not authorized to view contributions in this group' using errcode = '42501';
  end if;

  select * into v_period from public.contribution_periods where id = p_period_id;
  if v_period.group_id is null or v_period.group_id <> p_group_id then
    raise exception 'Contribution period not found in group' using errcode = '22023';
  end if;

  -- excluded_count = excluded members who do NOT currently have a
  -- charge for this period. A member explicitly enrolled after OPEN
  -- despite an earlier pre-open exclusion keeps their historical
  -- exclusion row, but is no longer counted here.
  select count(*) into v_excluded_count
  from public.contribution_period_member_exclusions ex
  where ex.period_id = p_period_id
    and not exists (
      select 1 from public.member_contribution_charges c
      where c.period_id = ex.period_id and c.membership_id = ex.membership_id
    );

  select count(*) into v_custom_amount_count
  from public.contribution_period_member_amounts
  where period_id = p_period_id;

  select count(*), coalesce(sum(cc.assessed_amount), 0)
  into v_total_members_charged, v_total_base_assessed
  from public.member_contribution_charges c
  join public.contribution_charge_components cc
    on cc.charge_id = c.id and cc.component_type = 'BASE'
  where c.period_id = p_period_id;

  return jsonb_build_object(
    'id', v_period.id, 'group_id', v_period.group_id,
    'contribution_setup_id', v_period.contribution_setup_id,
    'label', v_period.label, 'period_start', v_period.period_start, 'period_end', v_period.period_end,
    'obligation_date', v_period.obligation_date, 'eligibility_date', v_period.eligibility_date,
    'due_date', v_period.due_date, 'status', v_period.status,
    'scheduled_open_date', v_period.scheduled_open_date,
    'opened_at', v_period.opened_at, 'opened_by', v_period.opened_by,
    'closed_at', v_period.closed_at, 'closed_by', v_period.closed_by,
    'cancelled_at', v_period.cancelled_at, 'cancelled_by', v_period.cancelled_by,
    'snapshot_type_name', v_period.snapshot_type_name,
    'snapshot_category', v_period.snapshot_category,
    'snapshot_accounting_treatment', v_period.snapshot_accounting_treatment,
    'snapshot_setup_name', v_period.snapshot_setup_name,
    'snapshot_schedule_mode', v_period.snapshot_schedule_mode,
    'snapshot_amount_mode', v_period.snapshot_amount_mode,
    'snapshot_fixed_amount', v_period.snapshot_fixed_amount,
    'snapshot_penalty_mode', v_period.snapshot_penalty_mode,
    'snapshot_penalty_grace_days', v_period.snapshot_penalty_grace_days,
    'snapshot_penalty_value', v_period.snapshot_penalty_value,
    'snapshot_penalty_cap_amount', v_period.snapshot_penalty_cap_amount,
    'created_at', v_period.created_at, 'updated_at', v_period.updated_at,
    'excluded_count', v_excluded_count,
    'custom_amount_count', v_custom_amount_count,
    'total_members_charged', v_total_members_charged,
    'total_base_assessed', v_total_base_assessed
  );
end;
$$;

revoke all on function public.rpc_get_contribution_period(uuid, uuid) from public;
grant execute on function public.rpc_get_contribution_period(uuid, uuid) to authenticated;
revoke execute on function public.rpc_get_contribution_period(uuid, uuid) from anon;
