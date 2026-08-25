-- Prompt 06B: Contribution Penalty Assessment & Posting.
--
-- Builds the penalty engine on top of 06A's already-locked
-- configuration (contribution_setups.penalty_*, snapshotted onto
-- contribution_periods.snapshot_penalty_* at OPEN) and already-locked
-- component model (contribution_charge_components.component_type
-- already includes 'PENALTY' — added in 06A, never used until now).
--
-- No new tables. No parallel penalty hierarchy. A posted penalty is
-- exactly one more row in the existing contribution_charge_components
-- table, component_type = 'PENALTY'.
--
-- Design decisions confirmed with the product owner before writing any
-- of this (06A's schema has exactly one rate/grace/cap per setup — no
-- multi-level table):
--
-- 1. "Level" = successive recurrence occurrence, not a distinct
--    escalating rate. FIXED_ONCE/PERCENTAGE_ONCE assess at most one
--    PENALTY component per charge, ever. FIXED_RECURRING/
--    PERCENTAGE_RECURRING assess one component per elapsed
--    penalty_grace_days interval since due_date (component #1 due at
--    due_date + grace_days, #2 at due_date + 2*grace_days, ...),
--    numbered via the existing contribution_charge_components.sequence
--    column — no new "level" table/column.
-- 2. "Outstanding" — 06A has no payment/wallet subsystem at all (no
--    paid_amount anywhere), so every posted charge is, by construction,
--    fully outstanding for as long as it exists. Eligibility is simply
--    "this charge exists and is now overdue" — this does not invent a
--    payment concept; it is the only state 06A's schema can represent.
-- 3. Percentage basis is always the charge's original BASE component
--    assessed_amount, every occurrence — matches the locked "no
--    penalty-on-penalty" rule (docs/product/contributions.md).
-- 4. penalty_cap_amount is a hard, cumulative cap per charge: once the
--    sum of a charge's PENALTY components would reach/exceed the cap,
--    the next occurrence is clamped to the remaining room (possibly
--    zero) and no further occurrences are ever posted for that charge.
--    No locked doc describes "repeat the final level past the cap," so
--    that behavior is not implemented.

-- ---------------------------------------------------------------------
-- Permission: contribution.penalty.assess
-- ---------------------------------------------------------------------
--
-- A financially-sensitive group-wide mutation — deliberately not
-- granted to every contribution role. Mapped like every other
-- money-affecting contribution permission: ADMIN (always, via the
-- cross-join in 20260819080633_create_roles_and_permissions.sql, which
-- predates this code and must be re-granted explicitly) and TREASURER
-- (the role that already holds every other contribution money
-- permission). CHAIRPERSON/SECRETARY keep their existing narrower
-- grants (view/open/close, view-only) unchanged. MEMBER never receives
-- it.

insert into public.permissions (code, name, description) values
  ('contribution.penalty.assess', 'Assess contribution penalties', 'Run penalty assessment against an OPEN contribution period''s posted charges.');

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where r.code = 'ADMIN'
  and p.code = 'contribution.penalty.assess'
on conflict do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code = 'contribution.penalty.assess'
where r.code = 'TREASURER';

-- ---------------------------------------------------------------------
-- Idempotency at the database level: at most one PENALTY component per
-- (charge, occurrence number). Mirrors
-- contribution_charge_components_one_base_per_charge's precedent for
-- BASE.
-- ---------------------------------------------------------------------

create unique index contribution_charge_components_one_penalty_per_charge_sequence
  on public.contribution_charge_components (charge_id, sequence)
  where component_type = 'PENALTY';

-- ---------------------------------------------------------------------
-- rpc_assess_contribution_penalties
-- ---------------------------------------------------------------------
--
-- Atomic, idempotent, server-authoritative penalty assessment for one
-- OPEN period as of p_assessment_date (explicit, not implicitly now() —
-- deterministic/testable/auditable). Uses only the period's frozen
-- snapshot_penalty_* columns — never the live contribution_setups row —
-- so a later edit to the setup's penalty configuration can never alter
-- an already-OPEN period's penalty behaviour.
--
-- Safe to call repeatedly: re-running with the same p_assessment_date
-- creates zero additional components; advancing p_assessment_date only
-- ever creates the newly-due occurrences.

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

  -- Only an OPEN period has posted charges to assess at all — see
  -- header comment for why CLOSED/CANCELLED/DRAFT/SCHEDULED are not
  -- eligible.
  if v_period.status <> 'OPEN' then
    raise exception 'CONTRIBUTION_PERIOD_NOT_OPEN' using errcode = 'P0001';
  end if;

  if v_period.snapshot_penalty_mode is null or v_period.snapshot_penalty_mode = 'NONE' then
    raise exception 'CONTRIBUTION_PERIOD_NO_PENALTY_POLICY' using errcode = 'P0001';
  end if;

  v_grace_days := coalesce(v_period.snapshot_penalty_grace_days, 0);

  if v_period.snapshot_penalty_mode in ('FIXED_RECURRING', 'PERCENTAGE_RECURRING')
     and v_grace_days <= 0 then
    -- A zero/negative recurrence interval would never terminate a
    -- per-occurrence loop bounded only by a fixed assessment date.
    -- 06A's own setup validation never required grace_days > 0 for a
    -- RECURRING mode, so this guards against that configuration state
    -- rather than assuming it cannot exist.
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
      -- Not yet overdue at all — never qualifies regardless of grace.
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
  'Prompt 06B: atomic, idempotent penalty assessment for one OPEN '
  'period as of an explicit assessment date. Reads only the period''s '
  'frozen snapshot_penalty_* columns, never the live contribution_setups '
  'row. Posts contribution_charge_components rows (component_type '
  'PENALTY) — never touches BASE components or member_contribution_charges. '
  'Safe to call repeatedly for the same date (creates nothing new) or an '
  'advancing date (creates only the newly-due occurrences).';

-- ---------------------------------------------------------------------
-- rpc_get_contribution_period — add penalty summary fields.
-- ---------------------------------------------------------------------
--
-- Same function as 20260823150000's version, with total_penalty_assessed
-- and penalty_charge_count added to the summary block.

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
  v_total_penalty_assessed numeric;
  v_penalty_charge_count integer;
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

  select coalesce(sum(cc.assessed_amount), 0), count(distinct cc.charge_id)
  into v_total_penalty_assessed, v_penalty_charge_count
  from public.member_contribution_charges c
  join public.contribution_charge_components cc
    on cc.charge_id = c.id and cc.component_type = 'PENALTY'
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
    'total_base_assessed', v_total_base_assessed,
    'total_penalty_assessed', v_total_penalty_assessed,
    'penalty_charge_count', v_penalty_charge_count
  );
end;
$$;

revoke all on function public.rpc_get_contribution_period(uuid, uuid) from public;
grant execute on function public.rpc_get_contribution_period(uuid, uuid) to authenticated;
revoke execute on function public.rpc_get_contribution_period(uuid, uuid) from anon;

-- ---------------------------------------------------------------------
-- rpc_list_contribution_period_charges — add per-charge penalty totals.
-- ---------------------------------------------------------------------
--
-- Same function as 20260823140000's version, with penalty_amount,
-- penalty_count and total_amount (base + penalty) added per row.

create or replace function public.rpc_list_contribution_period_charges(
  p_group_id uuid,
  p_period_id uuid,
  p_search text default null,
  p_limit integer default 10,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_limit integer := greatest(1, least(coalesce(p_limit, 10), 100));
  v_offset integer := greatest(0, coalesce(p_offset, 0));
  v_period_group_id uuid;
  v_full_view boolean;
  v_self_membership_id uuid;
  v_total bigint;
  v_items jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  select group_id into v_period_group_id from public.contribution_periods where id = p_period_id;
  if v_period_group_id is null or v_period_group_id <> p_group_id then
    raise exception 'Contribution period not found in group' using errcode = '22023';
  end if;

  v_full_view := public.has_group_permission(p_group_id, 'contribution.view');

  if not v_full_view then
    if not public.has_group_permission(p_group_id, 'contribution.self_view') then
      raise exception 'Not authorized to view contribution charges in this group' using errcode = '42501';
    end if;

    select id into v_self_membership_id
    from public.group_memberships
    where group_id = p_group_id and user_id = v_uid
    limit 1;
  end if;

  select count(*) into v_total
  from public.member_contribution_charges c
  where c.period_id = p_period_id
    and (v_full_view or c.membership_id = v_self_membership_id)
    and (
      p_search is null or btrim(p_search) = ''
      or c.member_name_snapshot ilike '%' || btrim(p_search) || '%'
      or c.member_number_snapshot ilike '%' || btrim(p_search) || '%'
    );

  select coalesce(jsonb_agg(row_to_json(rows.*) order by rows.member_name_snapshot), '[]'::jsonb)
  into v_items
  from (
    select
      c.id as charge_id, c.membership_id, c.member_number_snapshot, c.member_name_snapshot,
      c.effective_at, c.due_date, c.created_at,
      (
        select cc.assessed_amount from public.contribution_charge_components cc
        where cc.charge_id = c.id and cc.component_type = 'BASE'
      ) as base_amount,
      (
        select coalesce(sum(cc.assessed_amount), 0) from public.contribution_charge_components cc
        where cc.charge_id = c.id and cc.component_type = 'PENALTY'
      ) as penalty_amount,
      (
        select count(*) from public.contribution_charge_components cc
        where cc.charge_id = c.id and cc.component_type = 'PENALTY'
      ) as penalty_count,
      (
        select coalesce(sum(cc.assessed_amount), 0) from public.contribution_charge_components cc
        where cc.charge_id = c.id
      ) as total_amount
    from public.member_contribution_charges c
    where c.period_id = p_period_id
      and (v_full_view or c.membership_id = v_self_membership_id)
      and (
        p_search is null or btrim(p_search) = ''
        or c.member_name_snapshot ilike '%' || btrim(p_search) || '%'
        or c.member_number_snapshot ilike '%' || btrim(p_search) || '%'
      )
    order by c.member_name_snapshot
    limit v_limit offset v_offset
  ) rows;

  return jsonb_build_object('items', v_items, 'total_count', v_total, 'limit', v_limit, 'offset', v_offset);
end;
$$;

revoke all on function public.rpc_list_contribution_period_charges(uuid, uuid, text, integer, integer) from public;
grant execute on function public.rpc_list_contribution_period_charges(uuid, uuid, text, integer, integer) to authenticated;
revoke execute on function public.rpc_list_contribution_period_charges(uuid, uuid, text, integer, integer) from anon;
