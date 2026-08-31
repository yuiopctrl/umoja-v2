-- Prompt 07 UAT-FIX-03: a member-centric Charges/Madeni view — every
-- contribution charge for one membership across every period, without
-- opening each period individually.
--
-- `rpc_get_member_contribution_statement` (UAT-FIX-01) is intentionally
-- NOT extended for this: it is a small, unpaginated, always-
-- "outstanding-only" summary purpose-built for the pre-payment check,
-- and its own tests/callers depend on that exact contract. Overloading
-- it with filters (ALL/SETTLED/OVERDUE) and pagination would either
-- break that contract or force every caller to pass parameters
-- irrelevant to it. Matches the existing precedent of separate,
-- purpose-built LIST rpcs elsewhere (`rpc_list_member_payments`,
-- `rpc_list_member_wallet_entries`, `rpc_list_contribution_period_
-- charges`) rather than one overloaded "statement" endpoint.
--
-- This migration is purely additive: no contribution accounting
-- semantics, charge creation logic, payment allocation rule, or
-- historical component changes anywhere in it. It reuses three
-- already-locked helpers unchanged — `contribution_member_
-- allocatable_charges`, `contribution_charge_component_states`,
-- `contribution_charge_net_assessed` — and extends `rpc_get_member_
-- contribution_statement` with one new additive scalar field only.

-- ---------------------------------------------------------------------
-- rpc_get_member_contribution_statement — add `total_allocated`, a
-- global sum across EVERY charge (not just the outstanding-filtered
-- `charges` array, which excludes fully-settled charges entirely).
-- Everything else about this function — its signature, gating, the
-- `charges` array's own filtering/shape, `total_outstanding`,
-- `wallet_balance` — is completely unchanged.
-- ---------------------------------------------------------------------

create or replace function public.rpc_get_member_contribution_statement(
  p_group_id uuid,
  p_membership_id uuid
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_membership record;
  v_charges jsonb;
  v_total_outstanding numeric;
  v_total_allocated numeric;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not (
    public.has_group_permission(p_group_id, 'contribution.view')
    and public.has_group_permission(p_group_id, 'payment.view')
    and public.has_group_permission(p_group_id, 'wallet.view')
  ) then
    raise exception 'Not authorized to view this member''s contribution statement' using errcode = '42501';
  end if;

  select id, group_id, display_name, member_number, status into v_membership
  from public.group_memberships
  where id = p_membership_id;
  if v_membership.group_id is null or v_membership.group_id <> p_group_id then
    raise exception 'Membership not found in group' using errcode = '22023';
  end if;

  select
    coalesce(jsonb_agg(x.entry order by x.due_date), '[]'::jsonb),
    coalesce(sum(x.charge_outstanding), 0)
  into v_charges, v_total_outstanding
  from (
    select
      c.due_date,
      (select coalesce(sum(s.outstanding), 0) from public.contribution_charge_component_states(c.id) s)
        as charge_outstanding,
      jsonb_build_object(
        'charge_id', c.id,
        'period_id', c.period_id,
        'due_date', c.due_date,
        'contribution_type_name', ct.name,
        'period_label', p.label,
        'period_purpose', p.purpose::text,
        'components', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'component_type', s.component_type,
            'gross_after_corrections', s.gross_after_corrections,
            'allocated', s.allocated,
            'outstanding', s.outstanding
          ) order by s.priority, s.component_created_at), '[]'::jsonb)
          from public.contribution_charge_component_states(c.id) s
          where s.outstanding > 0
        )
      ) as entry
    from public.member_contribution_charges c
    join public.contribution_periods p on p.id = c.period_id
    join public.contribution_setups st on st.id = c.contribution_setup_id
    join public.contribution_types ct on ct.id = st.contribution_type_id
    where c.group_id = p_group_id and c.membership_id = p_membership_id
  ) x
  where x.charge_outstanding > 0;

  -- Global total across every charge for this membership, regardless
  -- of whether that charge is still outstanding — a fully-settled
  -- charge's allocations must still count toward "how much has this
  -- member paid/been allocated in total", even though it no longer
  -- appears in the `charges` array above.
  select coalesce(sum(s.allocated), 0)
  into v_total_allocated
  from public.member_contribution_charges c
  cross join lateral public.contribution_charge_component_states(c.id) s
  where c.group_id = p_group_id and c.membership_id = p_membership_id;

  return jsonb_build_object(
    'membership_id', p_membership_id,
    'member_display_name', v_membership.display_name,
    'member_number', v_membership.member_number,
    'membership_status', v_membership.status,
    'charges', v_charges,
    'total_outstanding', v_total_outstanding,
    'total_allocated', v_total_allocated,
    'wallet_balance', public.member_wallet_balance(p_membership_id)
  );
end;
$$;

revoke all on function public.rpc_get_member_contribution_statement(uuid, uuid) from public;
grant execute on function public.rpc_get_member_contribution_statement(uuid, uuid) to authenticated;
revoke execute on function public.rpc_get_member_contribution_statement(uuid, uuid) from anon;

-- ---------------------------------------------------------------------
-- rpc_list_member_contribution_charges — the new member-centric,
-- filterable, paginated charges list. Gated by contribution.view AND
-- payment.view (no wallet.view requirement — this RPC never exposes
-- wallet data). No status restriction on the membership itself:
-- SUSPENDED/EXITED members' historical charges remain fully visible,
-- matching section 13/the existing settleability rules.
-- ---------------------------------------------------------------------

create or replace function public.rpc_list_member_contribution_charges(
  p_group_id uuid,
  p_membership_id uuid,
  p_filter text default 'OUTSTANDING',
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
  v_membership record;
  v_filter text;
  v_limit integer;
  v_offset integer;
  v_total bigint;
  v_items jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not (
    public.has_group_permission(p_group_id, 'contribution.view')
    and public.has_group_permission(p_group_id, 'payment.view')
  ) then
    raise exception 'Not authorized to view this member''s contribution charges' using errcode = '42501';
  end if;

  select id, group_id, display_name, member_number, status into v_membership
  from public.group_memberships
  where id = p_membership_id;
  if v_membership.group_id is null or v_membership.group_id <> p_group_id then
    raise exception 'Membership not found in group' using errcode = '22023';
  end if;

  v_filter := upper(coalesce(p_filter, 'OUTSTANDING'));
  if v_filter not in ('ALL', 'OUTSTANDING', 'SETTLED', 'OVERDUE') then
    raise exception 'MEMBER_CHARGES_INVALID_FILTER' using errcode = '22023';
  end if;

  v_limit := greatest(1, least(coalesce(p_limit, 10), 100));
  v_offset := greatest(0, coalesce(p_offset, 0));

  with base as (
    select
      c.charge_id,
      c.due_date,
      c.contribution_type_name,
      c.period_id,
      c.period_label,
      c.period_purpose,
      p.status::text as period_status,
      public.contribution_charge_net_assessed(c.charge_id) as net_assessed,
      (select coalesce(sum(s.allocated), 0) from public.contribution_charge_component_states(c.charge_id) s)
        as allocated,
      (select coalesce(sum(s.outstanding), 0) from public.contribution_charge_component_states(c.charge_id) s)
        as outstanding
    from public.contribution_member_allocatable_charges(p_group_id, p_membership_id) c
    join public.contribution_periods p on p.id = c.period_id
  ),
  filtered as (
    select
      base.*,
      (base.due_date < current_date and base.outstanding > 0) as is_overdue
    from base
    where case v_filter
      when 'ALL' then true
      when 'OUTSTANDING' then base.outstanding > 0
      when 'SETTLED' then base.outstanding <= 0
      when 'OVERDUE' then base.due_date < current_date and base.outstanding > 0
    end
  )
  select count(*) into v_total from filtered;

  with base as (
    select
      c.charge_id,
      c.due_date,
      c.contribution_type_name,
      c.period_id,
      c.period_label,
      c.period_purpose,
      p.status::text as period_status,
      public.contribution_charge_net_assessed(c.charge_id) as net_assessed,
      (select coalesce(sum(s.allocated), 0) from public.contribution_charge_component_states(c.charge_id) s)
        as allocated,
      (select coalesce(sum(s.outstanding), 0) from public.contribution_charge_component_states(c.charge_id) s)
        as outstanding
    from public.contribution_member_allocatable_charges(p_group_id, p_membership_id) c
    join public.contribution_periods p on p.id = c.period_id
  ),
  filtered as (
    select
      base.*,
      (base.due_date < current_date and base.outstanding > 0) as is_overdue
    from base
    where case v_filter
      when 'ALL' then true
      when 'OUTSTANDING' then base.outstanding > 0
      when 'SETTLED' then base.outstanding <= 0
      when 'OVERDUE' then base.due_date < current_date and base.outstanding > 0
    end
    order by base.due_date desc
    limit v_limit
    offset v_offset
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'charge_id', filtered.charge_id,
    'period_id', filtered.period_id,
    'due_date', filtered.due_date,
    'contribution_type_name', filtered.contribution_type_name,
    'period_label', filtered.period_label,
    'period_purpose', filtered.period_purpose,
    'period_status', filtered.period_status,
    'is_overdue', filtered.is_overdue,
    'net_assessed', filtered.net_assessed,
    'allocated', filtered.allocated,
    'outstanding', filtered.outstanding,
    'components', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'component_type', cc.component_type,
        'amount', cc.assessed_amount,
        'effective_at', cc.effective_at
      ) order by cc.effective_at, cc.created_at), '[]'::jsonb)
      from public.contribution_charge_components cc
      where cc.charge_id = filtered.charge_id
    )
  ) order by filtered.due_date desc), '[]'::jsonb)
  into v_items
  from filtered;

  return jsonb_build_object(
    'membership_id', p_membership_id,
    'member_display_name', v_membership.display_name,
    'member_number', v_membership.member_number,
    'membership_status', v_membership.status,
    'filter', v_filter,
    'items', v_items,
    'total_count', v_total,
    'limit', v_limit,
    'offset', v_offset
  );
end;
$$;

revoke all on function public.rpc_list_member_contribution_charges(uuid, uuid, text, integer, integer) from public;
grant execute on function public.rpc_list_member_contribution_charges(uuid, uuid, text, integer, integer) to authenticated;
revoke execute on function public.rpc_list_member_contribution_charges(uuid, uuid, text, integer, integer) from anon;

comment on function public.rpc_list_member_contribution_charges(uuid, uuid, text, integer, integer) is
  'Prompt 07 UAT-FIX-03: every contribution charge for one membership
  across every period, filterable (ALL/OUTSTANDING/SETTLED/OVERDUE,
  default OUTSTANDING) and paginated (default 10, max 100), ordered
  newest-due-date-first. `components` carries every raw component
  (including WAIVER/negative ADJUSTMENT at their original signed
  amount) — never netted for display, so a correction is shown as its
  own reducing line rather than silently absorbed into BASE. No
  membership-status restriction: a SUSPENDED/EXITED member''s
  historical charges remain fully listed. Never used for payment
  allocation — that remains contribution_compute_payment_allocation_
  plan''s exclusive responsibility.';
