-- Prompt 07 / 06B integration: a charge whose net payable debt has
-- already been fully settled (via payment or wallet allocation) must
-- stop qualifying for further penalty assessment, even though it may
-- still be "overdue" by due_date alone. A partially-settled charge
-- remains fully eligible — this only ever skips a charge whose
-- outstanding, summed across every component, is already zero.
--
-- CREATE OR REPLACE on the exact same signature already established
-- for extending a locked prior-phase RPC (see
-- rpc_list_financial_account_entries in
-- 20260827090000_add_financial_account_entry_counterparty.sql) —
-- 20260824090000_create_contribution_penalty_engine.sql is never
-- edited.
--
-- Nothing else about the function changes: already-posted PENALTY
-- components and the BASE amount they were computed from are never
-- recalculated by this check; it only gates whether a *new*
-- occurrence is considered for this run.

create or replace function public.rpc_assess_contribution_penalties(
  p_group_id uuid,
  p_period_id uuid,
  p_assessment_date date default current_date
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_period record;
  v_grace_days integer;
  v_charge record;
  v_existing_count integer;
  v_existing_total numeric;
  v_base_amount numeric;
  v_occurrence integer;
  v_occurrence_due_date date;
  v_raw_amount numeric;
  v_remaining_room numeric;
  v_amount_to_post numeric;
  v_qualifying_count integer := 0;
  v_created_count integer := 0;
  v_already_current_count integer := 0;
  v_total_assessed_this_run numeric := 0;
  v_charge_created boolean;
  v_charge_outstanding numeric;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'contribution.penalty.assess') then
    raise exception 'Not authorized to assess contribution penalties in this group' using errcode = '42501';
  end if;

  if p_assessment_date is null then
    raise exception 'Assessment date is required' using errcode = '22023';
  end if;

  select * into v_period
  from public.contribution_periods
  where id = p_period_id
  for update;

  if v_period.group_id is null or v_period.group_id <> p_group_id then
    raise exception 'Contribution period not found in group' using errcode = '22023';
  end if;

  if v_period.status <> 'OPEN' then
    raise exception 'CONTRIBUTION_PERIOD_NOT_OPEN' using errcode = 'P0001';
  end if;

  if v_period.snapshot_penalty_mode is null or v_period.snapshot_penalty_mode = 'NONE' then
    raise exception 'CONTRIBUTION_PERIOD_NO_PENALTY_POLICY' using errcode = 'P0001';
  end if;

  v_grace_days := coalesce(v_period.snapshot_penalty_grace_days, 0);

  if v_period.snapshot_penalty_mode in ('FIXED_RECURRING', 'PERCENTAGE_RECURRING')
     and v_grace_days <= 0 then
    raise exception 'CONTRIBUTION_PENALTY_GRACE_DAYS_REQUIRED_FOR_RECURRING' using errcode = 'P0001';
  end if;

  for v_charge in
    select c.id as charge_id, c.due_date,
      (select cc.assessed_amount from public.contribution_charge_components cc
       where cc.charge_id = c.id and cc.component_type = 'BASE') as base_amount
    from public.member_contribution_charges c
    where c.period_id = p_period_id
    order by c.id
  loop
    if p_assessment_date <= v_charge.due_date then
      continue;
    end if;

    -- Prompt 07 integration: a fully-settled charge (outstanding = 0
    -- across every component, once payment/wallet allocations are
    -- accounted for) never qualifies for a new penalty occurrence,
    -- even though it is technically overdue by due_date alone.
    select coalesce(sum(outstanding), 0) into v_charge_outstanding
    from public.contribution_charge_component_states(v_charge.charge_id);

    if v_charge_outstanding <= 0 then
      continue;
    end if;

    v_qualifying_count := v_qualifying_count + 1;
    v_base_amount := coalesce(v_charge.base_amount, 0);

    select count(*), coalesce(sum(assessed_amount), 0)
    into v_existing_count, v_existing_total
    from public.contribution_charge_components
    where charge_id = v_charge.charge_id and component_type = 'PENALTY';

    v_charge_created := false;

    loop
      exit when v_period.snapshot_penalty_mode in ('FIXED_ONCE', 'PERCENTAGE_ONCE')
        and v_existing_count >= 1;

      v_occurrence := v_existing_count + 1;
      v_occurrence_due_date := v_charge.due_date
        + make_interval(days => v_grace_days * v_occurrence);

      exit when p_assessment_date < v_occurrence_due_date;

      v_raw_amount := case v_period.snapshot_penalty_mode
        when 'FIXED_ONCE' then v_period.snapshot_penalty_value
        when 'FIXED_RECURRING' then v_period.snapshot_penalty_value
        when 'PERCENTAGE_ONCE' then round(v_base_amount * v_period.snapshot_penalty_value / 100, 2)
        when 'PERCENTAGE_RECURRING' then round(v_base_amount * v_period.snapshot_penalty_value / 100, 2)
      end;

      if v_period.snapshot_penalty_cap_amount is not null then
        v_remaining_room := v_period.snapshot_penalty_cap_amount - v_existing_total;
        exit when v_remaining_room <= 0;
        v_amount_to_post := least(v_raw_amount, v_remaining_room);
      else
        v_amount_to_post := v_raw_amount;
      end if;

      exit when v_amount_to_post <= 0;

      insert into public.contribution_charge_components (
        group_id, charge_id, component_type, assessed_amount, effective_at, sequence, created_by
      ) values (
        p_group_id, v_charge.charge_id, 'PENALTY', v_amount_to_post, v_occurrence_due_date, v_occurrence, v_uid
      );

      v_existing_count := v_existing_count + 1;
      v_existing_total := v_existing_total + v_amount_to_post;
      v_created_count := v_created_count + 1;
      v_total_assessed_this_run := v_total_assessed_this_run + v_amount_to_post;
      v_charge_created := true;

      exit when v_period.snapshot_penalty_mode in ('FIXED_ONCE', 'PERCENTAGE_ONCE');
    end loop;

    if not v_charge_created then
      v_already_current_count := v_already_current_count + 1;
    end if;
  end loop;

  return jsonb_build_object(
    'period_id', p_period_id,
    'assessment_date', p_assessment_date,
    'qualifying_charge_count', v_qualifying_count,
    'penalties_created_count', v_created_count,
    'already_current_charge_count', v_already_current_count,
    'total_penalty_assessed_this_run', v_total_assessed_this_run
  );
end;
$$;

revoke all on function public.rpc_assess_contribution_penalties(uuid, uuid, date) from public;
grant execute on function public.rpc_assess_contribution_penalties(uuid, uuid, date) to authenticated;
revoke execute on function public.rpc_assess_contribution_penalties(uuid, uuid, date) from anon;

comment on function public.rpc_assess_contribution_penalties(uuid, uuid, date) is
  'Prompt 06B, extended by Prompt 07: atomic, idempotent penalty '
  'assessment for one OPEN period as of an explicit assessment date. '
  'A charge whose net payable (across payment + wallet allocations) is '
  'already fully settled never qualifies for a new occurrence, even '
  'while technically overdue; a partially-settled charge remains fully '
  'eligible. Already-posted PENALTY components and their original '
  'BASE-based percentage amounts are never recalculated. Safe to call '
  'repeatedly for the same date (creates nothing new) or an advancing '
  'date (creates only the newly-due occurrences for still-outstanding '
  'charges).';
