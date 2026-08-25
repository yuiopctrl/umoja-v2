-- Contribution Period lifecycle RPCs: create, member-amount
-- configuration, exclusions, open preview, atomic OPEN, post-open
-- enrollment, close, cancel.
--
-- Locked invariant: DRAFT and SCHEDULED periods create zero member
-- charges. Only rpc_open_contribution_period posts charges, and it
-- does so atomically (all-or-nothing) and idempotently (safe to
-- retry/double-submit).

-- ---------------------------------------------------------------------
-- rpc_create_contribution_period
-- ---------------------------------------------------------------------

create or replace function public.rpc_create_contribution_period(
  p_group_id uuid,
  p_contribution_setup_id uuid,
  p_label text,
  p_period_start date,
  p_period_end date,
  p_obligation_date date default null,
  p_eligibility_date date default null,
  p_due_date date default null,
  p_status public.contribution_period_status default 'DRAFT',
  p_scheduled_open_date date default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_setup record;
  v_obligation_date date;
  v_eligibility_date date;
  v_due_date date;
  v_id uuid;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'contribution.period.manage') then
    raise exception 'Not authorized to manage contribution periods in this group' using errcode = '42501';
  end if;

  if p_status not in ('DRAFT', 'SCHEDULED') then
    raise exception 'Only DRAFT or SCHEDULED periods may be created directly' using errcode = '22023';
  end if;

  if p_label is null or btrim(p_label) = '' then
    raise exception 'Contribution period label is required' using errcode = '22023';
  end if;

  if p_period_start is null or p_period_end is null or p_period_start > p_period_end then
    raise exception 'Invalid period dates' using errcode = '22023';
  end if;

  select * into v_setup
  from public.contribution_setups
  where id = p_contribution_setup_id;

  if v_setup.group_id is null or v_setup.group_id <> p_group_id then
    raise exception 'Contribution setup not found in group' using errcode = '22023';
  end if;

  if not v_setup.is_active then
    raise exception 'CONTRIBUTION_SETUP_INACTIVE' using errcode = 'P0001';
  end if;

  v_obligation_date := coalesce(p_obligation_date, p_period_start);
  v_eligibility_date := coalesce(p_eligibility_date, p_period_start);

  if p_due_date is not null then
    v_due_date := p_due_date;
  elsif v_setup.default_due_day is not null then
    v_due_date := public.contribution_compute_due_date(
      p_period_start, v_setup.default_due_month_offset, v_setup.default_due_day
    );
  else
    raise exception 'DUE_DATE_REQUIRED' using errcode = '22023';
  end if;

  if v_setup.schedule_mode = 'MONTHLY' and exists (
    select 1 from public.contribution_periods
    where contribution_setup_id = p_contribution_setup_id
      and status <> 'CANCELLED'
      and date_trunc('month', period_start) = date_trunc('month', p_period_start)
  ) then
    raise exception 'DUPLICATE_MONTHLY_PERIOD' using errcode = 'P0001';
  end if;

  insert into public.contribution_periods (
    group_id, contribution_setup_id, label, period_start, period_end,
    obligation_date, eligibility_date, due_date, status, scheduled_open_date, created_by
  ) values (
    p_group_id, p_contribution_setup_id, btrim(p_label), p_period_start, p_period_end,
    v_obligation_date, v_eligibility_date, v_due_date, p_status, p_scheduled_open_date, v_uid
  )
  returning id into v_id;

  select jsonb_build_object(
    'id', id, 'group_id', group_id, 'contribution_setup_id', contribution_setup_id,
    'label', label, 'period_start', period_start, 'period_end', period_end,
    'obligation_date', obligation_date, 'eligibility_date', eligibility_date, 'due_date', due_date,
    'status', status, 'scheduled_open_date', scheduled_open_date,
    'created_at', created_at, 'updated_at', updated_at
  )
  into v_result
  from public.contribution_periods
  where id = v_id;

  return v_result;
end;
$$;

revoke all on function public.rpc_create_contribution_period(uuid, uuid, text, date, date, date, date, date, public.contribution_period_status, date) from public;
grant execute on function public.rpc_create_contribution_period(uuid, uuid, text, date, date, date, date, date, public.contribution_period_status, date) to authenticated;
revoke execute on function public.rpc_create_contribution_period(uuid, uuid, text, date, date, date, date, date, public.contribution_period_status, date) from anon;

-- ---------------------------------------------------------------------
-- rpc_set_contribution_period_member_amounts
-- ---------------------------------------------------------------------
--
-- p_amounts is a JSON array of {"membership_id": uuid, "amount": number
-- | null}. A null/absent amount removes that member's configured
-- amount. Atomic across the whole array.

create or replace function public.rpc_set_contribution_period_member_amounts(
  p_group_id uuid,
  p_period_id uuid,
  p_amounts jsonb
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
  v_item jsonb;
  v_membership_id uuid;
  v_amount numeric;
  v_membership_group_id uuid;
  v_count integer := 0;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'contribution.member_amount.manage') then
    raise exception 'Not authorized to manage member contribution amounts in this group' using errcode = '42501';
  end if;

  select * into v_period from public.contribution_periods where id = p_period_id for update;

  if v_period.group_id is null or v_period.group_id <> p_group_id then
    raise exception 'Contribution period not found in group' using errcode = '22023';
  end if;

  if v_period.status not in ('DRAFT', 'SCHEDULED') then
    raise exception 'CONTRIBUTION_PERIOD_NOT_EDITABLE' using errcode = 'P0001';
  end if;

  select * into v_setup from public.contribution_setups where id = v_period.contribution_setup_id;

  if v_setup.amount_mode <> 'CUSTOM_PER_MEMBER' then
    raise exception 'CONTRIBUTION_SETUP_NOT_CUSTOM_AMOUNT' using errcode = 'P0001';
  end if;

  if p_amounts is null or jsonb_typeof(p_amounts) <> 'array' then
    raise exception 'Amounts payload must be a JSON array' using errcode = '22023';
  end if;

  for v_item in select * from jsonb_array_elements(p_amounts)
  loop
    v_membership_id := (v_item ->> 'membership_id')::uuid;
    v_amount := nullif(v_item ->> 'amount', '')::numeric;

    select group_id into v_membership_group_id
    from public.group_memberships
    where id = v_membership_id;

    if v_membership_group_id is null or v_membership_group_id <> p_group_id then
      raise exception 'Membership not found in group' using errcode = '22023';
    end if;

    if v_amount is null then
      delete from public.contribution_period_member_amounts
      where period_id = p_period_id and membership_id = v_membership_id;
    else
      if v_amount <= 0 then
        raise exception 'Amount must be greater than zero' using errcode = '22023';
      end if;

      insert into public.contribution_period_member_amounts (
        period_id, group_id, membership_id, amount, created_by
      ) values (
        p_period_id, p_group_id, v_membership_id, v_amount, v_uid
      )
      on conflict (period_id, membership_id)
      do update set amount = excluded.amount, updated_at = now();
    end if;

    v_count := v_count + 1;
  end loop;

  return jsonb_build_object('period_id', p_period_id, 'updated_count', v_count);
end;
$$;

revoke all on function public.rpc_set_contribution_period_member_amounts(uuid, uuid, jsonb) from public;
grant execute on function public.rpc_set_contribution_period_member_amounts(uuid, uuid, jsonb) to authenticated;
revoke execute on function public.rpc_set_contribution_period_member_amounts(uuid, uuid, jsonb) from anon;

-- ---------------------------------------------------------------------
-- rpc_exclude_contribution_period_member /
-- rpc_remove_contribution_period_member_exclusion
-- ---------------------------------------------------------------------

create or replace function public.rpc_exclude_contribution_period_member(
  p_group_id uuid,
  p_period_id uuid,
  p_membership_id uuid,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_period record;
  v_membership_group_id uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'contribution.member_exclude') then
    raise exception 'Not authorized to exclude members from contribution periods in this group' using errcode = '42501';
  end if;

  select * into v_period from public.contribution_periods where id = p_period_id for update;

  if v_period.group_id is null or v_period.group_id <> p_group_id then
    raise exception 'Contribution period not found in group' using errcode = '22023';
  end if;

  if v_period.status not in ('DRAFT', 'SCHEDULED') then
    raise exception 'CONTRIBUTION_PERIOD_NOT_EDITABLE' using errcode = 'P0001';
  end if;

  select group_id into v_membership_group_id from public.group_memberships where id = p_membership_id;
  if v_membership_group_id is null or v_membership_group_id <> p_group_id then
    raise exception 'Membership not found in group' using errcode = '22023';
  end if;

  insert into public.contribution_period_member_exclusions (
    period_id, group_id, membership_id, reason, created_by
  ) values (
    p_period_id, p_group_id, p_membership_id, p_reason, v_uid
  )
  on conflict (period_id, membership_id)
  do update set reason = excluded.reason;

  return jsonb_build_object('period_id', p_period_id, 'membership_id', p_membership_id, 'excluded', true);
end;
$$;

revoke all on function public.rpc_exclude_contribution_period_member(uuid, uuid, uuid, text) from public;
grant execute on function public.rpc_exclude_contribution_period_member(uuid, uuid, uuid, text) to authenticated;
revoke execute on function public.rpc_exclude_contribution_period_member(uuid, uuid, uuid, text) from anon;

create or replace function public.rpc_remove_contribution_period_member_exclusion(
  p_group_id uuid,
  p_period_id uuid,
  p_membership_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_period record;
  v_deleted integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'contribution.member_exclude') then
    raise exception 'Not authorized to exclude members from contribution periods in this group' using errcode = '42501';
  end if;

  select * into v_period from public.contribution_periods where id = p_period_id for update;

  if v_period.group_id is null or v_period.group_id <> p_group_id then
    raise exception 'Contribution period not found in group' using errcode = '22023';
  end if;

  if v_period.status not in ('DRAFT', 'SCHEDULED') then
    raise exception 'CONTRIBUTION_PERIOD_NOT_EDITABLE' using errcode = 'P0001';
  end if;

  delete from public.contribution_period_member_exclusions
  where period_id = p_period_id and membership_id = p_membership_id;
  get diagnostics v_deleted = row_count;

  return jsonb_build_object(
    'period_id', p_period_id, 'membership_id', p_membership_id,
    'excluded', false, 'removed_count', v_deleted
  );
end;
$$;

revoke all on function public.rpc_remove_contribution_period_member_exclusion(uuid, uuid, uuid) from public;
grant execute on function public.rpc_remove_contribution_period_member_exclusion(uuid, uuid, uuid) to authenticated;
revoke execute on function public.rpc_remove_contribution_period_member_exclusion(uuid, uuid, uuid) from anon;

-- ---------------------------------------------------------------------
-- rpc_preview_contribution_period_open
-- ---------------------------------------------------------------------
--
-- Server-authoritative, read-only preview. No mutation. Flutter uses
-- this to render a confirmation screen before calling
-- rpc_open_contribution_period.

create or replace function public.rpc_preview_contribution_period_open(
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
  v_setup record;
  v_eligible jsonb;
  v_excluded jsonb;
  v_missing jsonb;
  v_eligible_count integer;
  v_excluded_count integer;
  v_missing_count integer;
  v_expected_total numeric;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'contribution.period.open') then
    raise exception 'Not authorized to open contribution periods in this group' using errcode = '42501';
  end if;

  select * into v_period from public.contribution_periods where id = p_period_id;
  if v_period.group_id is null or v_period.group_id <> p_group_id then
    raise exception 'Contribution period not found in group' using errcode = '22023';
  end if;

  if v_period.status not in ('DRAFT', 'SCHEDULED') then
    raise exception 'CONTRIBUTION_PERIOD_NOT_PREVIEWABLE' using errcode = 'P0001';
  end if;

  select * into v_setup from public.contribution_setups where id = v_period.contribution_setup_id;

  select
    coalesce(jsonb_agg(jsonb_build_object(
      'membership_id', e.membership_id,
      'member_number', e.member_number,
      'display_name', e.display_name,
      'amount', case
        when v_setup.amount_mode = 'FIXED' then v_setup.fixed_amount
        else (
          select a.amount from public.contribution_period_member_amounts a
          where a.period_id = p_period_id and a.membership_id = e.membership_id
        )
      end
    ) order by e.display_name), '[]'::jsonb),
    count(*)
  into v_eligible, v_eligible_count
  from public.contribution_period_eligible_memberships(p_period_id) e;

  select
    coalesce(jsonb_agg(jsonb_build_object(
      'membership_id', gm.id,
      'member_number', gm.member_number,
      'display_name', gm.display_name,
      'reason', x.reason
    ) order by gm.display_name), '[]'::jsonb),
    count(*)
  into v_excluded, v_excluded_count
  from public.group_memberships gm
  left join public.contribution_period_member_exclusions ex
    on ex.period_id = p_period_id and ex.membership_id = gm.id
  cross join lateral (
    select case
      when ex.membership_id is not null then coalesce(ex.reason, 'EXCLUDED')
      when gm.status = 'SUSPENDED' then 'SUSPENDED'
      when gm.status = 'EXITED' then 'EXITED'
      when gm.joined_at is not null and gm.joined_at > v_period.eligibility_date then 'JOINED_AFTER_ELIGIBILITY_DATE'
      when exists (
        select 1 from public.group_membership_status_history h
        where h.group_membership_id = gm.id
          and h.action = 'REJOIN'
          and h.previous_exited_at is not null
          and h.previous_exited_at <= v_period.eligibility_date
          and h.effective_at > v_period.eligibility_date
      ) then 'EXITED_DURING_PERIOD'
      else null
    end as reason
  ) x
  where gm.group_id = p_group_id
    and x.reason is not null;

  if v_setup.amount_mode = 'CUSTOM_PER_MEMBER' then
    select
      coalesce(jsonb_agg(jsonb_build_object(
        'membership_id', e.membership_id,
        'member_number', e.member_number,
        'display_name', e.display_name
      ) order by e.display_name), '[]'::jsonb),
      count(*)
    into v_missing, v_missing_count
    from public.contribution_period_eligible_memberships(p_period_id) e
    where not exists (
      select 1 from public.contribution_period_member_amounts a
      where a.period_id = p_period_id and a.membership_id = e.membership_id
    );

    select coalesce(sum(a.amount), 0)
    into v_expected_total
    from public.contribution_period_eligible_memberships(p_period_id) e
    join public.contribution_period_member_amounts a
      on a.period_id = p_period_id and a.membership_id = e.membership_id;
  else
    v_missing := '[]'::jsonb;
    v_missing_count := 0;
    v_expected_total := coalesce(v_setup.fixed_amount, 0) * v_eligible_count;
  end if;

  return jsonb_build_object(
    'period_id', p_period_id,
    'status', v_period.status,
    'due_date', v_period.due_date,
    'amount_mode', v_setup.amount_mode,
    'eligible_count', v_eligible_count,
    'eligible_members', v_eligible,
    'excluded_count', v_excluded_count,
    'excluded_members', v_excluded,
    'missing_custom_amount_count', v_missing_count,
    'missing_custom_amount_members', v_missing,
    'expected_total_assessment', v_expected_total,
    'can_open', (v_missing_count = 0)
  );
end;
$$;

revoke all on function public.rpc_preview_contribution_period_open(uuid, uuid) from public;
grant execute on function public.rpc_preview_contribution_period_open(uuid, uuid) to authenticated;
revoke execute on function public.rpc_preview_contribution_period_open(uuid, uuid) from anon;

-- ---------------------------------------------------------------------
-- rpc_open_contribution_period — atomic, idempotent posting.
-- ---------------------------------------------------------------------

create or replace function public.rpc_open_contribution_period(
  p_group_id uuid,
  p_period_id uuid
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
  v_type record;
  v_missing_count integer;
  v_charge_count integer;
  v_total_assessed numeric;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'contribution.period.open') then
    raise exception 'Not authorized to open contribution periods in this group' using errcode = '42501';
  end if;

  select * into v_period
  from public.contribution_periods
  where id = p_period_id
  for update;

  if v_period.group_id is null or v_period.group_id <> p_group_id then
    raise exception 'Contribution period not found in group' using errcode = '22023';
  end if;

  -- Idempotent: an already-open period returns its existing posting
  -- summary rather than re-posting. Safe against double-tap/retry.
  if v_period.status = 'OPEN' then
    select count(*), coalesce(sum(cc.assessed_amount), 0)
    into v_charge_count, v_total_assessed
    from public.member_contribution_charges c
    join public.contribution_charge_components cc
      on cc.charge_id = c.id and cc.component_type = 'BASE'
    where c.period_id = p_period_id;

    return jsonb_build_object(
      'period_id', p_period_id,
      'status', 'OPEN',
      'already_open', true,
      'charge_count', v_charge_count,
      'total_base_assessed', v_total_assessed
    );
  end if;

  if v_period.status not in ('DRAFT', 'SCHEDULED') then
    raise exception 'CONTRIBUTION_PERIOD_NOT_OPENABLE' using errcode = 'P0001';
  end if;

  select * into v_setup
  from public.contribution_setups
  where id = v_period.contribution_setup_id
  for update;

  if not v_setup.is_active then
    raise exception 'CONTRIBUTION_SETUP_INACTIVE' using errcode = 'P0001';
  end if;

  select * into v_type from public.contribution_types where id = v_setup.contribution_type_id;

  if v_setup.amount_mode = 'CUSTOM_PER_MEMBER' then
    select count(*)
    into v_missing_count
    from public.contribution_period_eligible_memberships(p_period_id) e
    where not exists (
      select 1 from public.contribution_period_member_amounts a
      where a.period_id = p_period_id and a.membership_id = e.membership_id
    );

    if v_missing_count > 0 then
      raise exception 'MISSING_CUSTOM_AMOUNTS' using errcode = 'P0001';
    end if;
  end if;

  update public.contribution_periods
  set
    status = 'OPEN',
    opened_at = now(),
    opened_by = v_uid,
    snapshot_type_name = v_type.name,
    snapshot_category = v_type.category,
    snapshot_accounting_treatment = v_type.accounting_treatment,
    snapshot_setup_name = v_setup.name,
    snapshot_schedule_mode = v_setup.schedule_mode,
    snapshot_amount_mode = v_setup.amount_mode,
    snapshot_fixed_amount = v_setup.fixed_amount,
    snapshot_penalty_mode = v_setup.penalty_mode,
    snapshot_penalty_grace_days = v_setup.penalty_grace_days,
    snapshot_penalty_value = v_setup.penalty_value,
    snapshot_penalty_cap_amount = v_setup.penalty_cap_amount
  where id = p_period_id;

  with eligible as (
    select * from public.contribution_period_eligible_memberships(p_period_id)
  ),
  inserted_charges as (
    insert into public.member_contribution_charges (
      group_id, period_id, contribution_setup_id, membership_id,
      member_number_snapshot, member_name_snapshot, effective_at, due_date, created_by
    )
    select
      p_group_id, p_period_id, v_period.contribution_setup_id, e.membership_id,
      e.member_number, e.display_name, v_period.obligation_date, v_period.due_date, v_uid
    from eligible e
    returning id, membership_id
  )
  insert into public.contribution_charge_components (
    group_id, charge_id, component_type, assessed_amount, effective_at, sequence, created_by
  )
  select
    p_group_id,
    ic.id,
    'BASE',
    case
      when v_setup.amount_mode = 'FIXED' then v_setup.fixed_amount
      else (
        select a.amount from public.contribution_period_member_amounts a
        where a.period_id = p_period_id and a.membership_id = ic.membership_id
      )
    end,
    v_period.obligation_date,
    1,
    v_uid
  from inserted_charges ic;

  select count(*), coalesce(sum(cc.assessed_amount), 0)
  into v_charge_count, v_total_assessed
  from public.member_contribution_charges c
  join public.contribution_charge_components cc
    on cc.charge_id = c.id and cc.component_type = 'BASE'
  where c.period_id = p_period_id;

  return jsonb_build_object(
    'period_id', p_period_id,
    'status', 'OPEN',
    'already_open', false,
    'charge_count', v_charge_count,
    'total_base_assessed', v_total_assessed
  );
end;
$$;

revoke all on function public.rpc_open_contribution_period(uuid, uuid) from public;
grant execute on function public.rpc_open_contribution_period(uuid, uuid) to authenticated;
revoke execute on function public.rpc_open_contribution_period(uuid, uuid) from anon;

-- ---------------------------------------------------------------------
-- rpc_enroll_member_in_contribution_period — explicit post-open enrollment.
-- ---------------------------------------------------------------------

create or replace function public.rpc_enroll_member_in_contribution_period(
  p_group_id uuid,
  p_period_id uuid,
  p_membership_id uuid,
  p_amount numeric default null
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
  v_membership record;
  v_amount numeric;
  v_charge_id uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'contribution.member_enroll') then
    raise exception 'Not authorized to enroll members into contribution periods in this group' using errcode = '42501';
  end if;

  select * into v_period from public.contribution_periods where id = p_period_id for update;

  if v_period.group_id is null or v_period.group_id <> p_group_id then
    raise exception 'Contribution period not found in group' using errcode = '22023';
  end if;

  if v_period.status <> 'OPEN' then
    raise exception 'CONTRIBUTION_PERIOD_NOT_OPEN' using errcode = 'P0001';
  end if;

  select id, group_id, member_number, display_name into v_membership
  from public.group_memberships
  where id = p_membership_id;

  if v_membership.group_id is null or v_membership.group_id <> p_group_id then
    raise exception 'Membership not found in group' using errcode = '22023';
  end if;

  if exists (
    select 1 from public.member_contribution_charges
    where period_id = p_period_id and membership_id = p_membership_id
  ) then
    raise exception 'MEMBER_ALREADY_CHARGED_FOR_PERIOD' using errcode = 'P0001';
  end if;

  select * into v_setup from public.contribution_setups where id = v_period.contribution_setup_id;

  if v_setup.amount_mode = 'FIXED' then
    v_amount := v_setup.fixed_amount;
  else
    if p_amount is null or p_amount <= 0 then
      raise exception 'AMOUNT_REQUIRED' using errcode = '22023';
    end if;
    v_amount := p_amount;
  end if;

  insert into public.member_contribution_charges (
    group_id, period_id, contribution_setup_id, membership_id,
    member_number_snapshot, member_name_snapshot, effective_at, due_date, created_by
  ) values (
    p_group_id, p_period_id, v_period.contribution_setup_id, p_membership_id,
    v_membership.member_number, v_membership.display_name, v_period.obligation_date, v_period.due_date, v_uid
  )
  returning id into v_charge_id;

  insert into public.contribution_charge_components (
    group_id, charge_id, component_type, assessed_amount, effective_at, sequence, created_by
  ) values (
    p_group_id, v_charge_id, 'BASE', v_amount, v_period.obligation_date, 1, v_uid
  );

  return jsonb_build_object(
    'charge_id', v_charge_id,
    'period_id', p_period_id,
    'membership_id', p_membership_id,
    'amount', v_amount
  );
end;
$$;

revoke all on function public.rpc_enroll_member_in_contribution_period(uuid, uuid, uuid, numeric) from public;
grant execute on function public.rpc_enroll_member_in_contribution_period(uuid, uuid, uuid, numeric) to authenticated;
revoke execute on function public.rpc_enroll_member_in_contribution_period(uuid, uuid, uuid, numeric) from anon;

-- ---------------------------------------------------------------------
-- rpc_close_contribution_period
-- ---------------------------------------------------------------------

create or replace function public.rpc_close_contribution_period(
  p_group_id uuid,
  p_period_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_period record;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'contribution.period.close') then
    raise exception 'Not authorized to close contribution periods in this group' using errcode = '42501';
  end if;

  select * into v_period from public.contribution_periods where id = p_period_id for update;

  if v_period.group_id is null or v_period.group_id <> p_group_id then
    raise exception 'Contribution period not found in group' using errcode = '22023';
  end if;

  if v_period.status = 'CLOSED' then
    return jsonb_build_object('period_id', p_period_id, 'status', 'CLOSED', 'already_closed', true);
  end if;

  if v_period.status <> 'OPEN' then
    raise exception 'CONTRIBUTION_PERIOD_NOT_OPEN' using errcode = 'P0001';
  end if;

  update public.contribution_periods
  set status = 'CLOSED', closed_at = now(), closed_by = v_uid
  where id = p_period_id;

  return jsonb_build_object('period_id', p_period_id, 'status', 'CLOSED', 'already_closed', false);
end;
$$;

revoke all on function public.rpc_close_contribution_period(uuid, uuid) from public;
grant execute on function public.rpc_close_contribution_period(uuid, uuid) to authenticated;
revoke execute on function public.rpc_close_contribution_period(uuid, uuid) from anon;

-- ---------------------------------------------------------------------
-- rpc_cancel_contribution_period
-- ---------------------------------------------------------------------

create or replace function public.rpc_cancel_contribution_period(
  p_group_id uuid,
  p_period_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_period record;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'contribution.period.manage') then
    raise exception 'Not authorized to manage contribution periods in this group' using errcode = '42501';
  end if;

  select * into v_period from public.contribution_periods where id = p_period_id for update;

  if v_period.group_id is null or v_period.group_id <> p_group_id then
    raise exception 'Contribution period not found in group' using errcode = '22023';
  end if;

  if v_period.status = 'CANCELLED' then
    return jsonb_build_object('period_id', p_period_id, 'status', 'CANCELLED', 'already_cancelled', true);
  end if;

  if v_period.status not in ('DRAFT', 'SCHEDULED') then
    raise exception 'CONTRIBUTION_PERIOD_NOT_CANCELLABLE' using errcode = 'P0001';
  end if;

  update public.contribution_periods
  set status = 'CANCELLED', cancelled_at = now(), cancelled_by = v_uid
  where id = p_period_id;

  return jsonb_build_object('period_id', p_period_id, 'status', 'CANCELLED', 'already_cancelled', false);
end;
$$;

revoke all on function public.rpc_cancel_contribution_period(uuid, uuid) from public;
grant execute on function public.rpc_cancel_contribution_period(uuid, uuid) to authenticated;
revoke execute on function public.rpc_cancel_contribution_period(uuid, uuid) from anon;
