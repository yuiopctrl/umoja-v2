-- Prompt 09G-B4-B: My Contributions self-service backend.
--
-- Two new, additive, member-safe RPCs. No schema change, no new
-- permission (reuses the already-deployed, already-tested
-- `contribution.self_view`, granted to MEMBER per
-- 20260823120000_create_contribution_engine_schema.sql), no change to
-- any existing migration, RPC, or officer Contributions behavior.
--
-- Ownership is resolved exclusively via current_membership_id(p_group_id)
-- (the same B1/B2/B3 self-service primitive) — there is no
-- p_user_id/p_membership_id/p_phone/p_role_id parameter anywhere, and
-- no officer-permission fallback: an ADMIN calling these sees only
-- their own contribution obligations, exactly like a plain MEMBER
-- would (same posture as rpc_get_my_member_statement, B3).
--
-- CANONICAL STATE: every monetary figure is read from the
-- already-locked contribution_charge_component_states(charge_id)/
-- contribution_charge_net_assessed(charge_id) helpers — this migration
-- introduces NO new accounting formula, NO second netting algorithm,
-- and does not grant client access to those internal helpers (they
-- remain revoked from public/anon/authenticated; both RPCs below call
-- them only via their own SECURITY DEFINER execution context, exactly
-- like the existing officer rpc_get_contribution_charge_detail/
-- rpc_list_member_contribution_charges already do).
--
-- STATUS (09G-B4-B §C): there is no persisted contribution status
-- anywhere in this schema. SETTLED/OVERDUE/PARTIALLY_SETTLED/OPEN are
-- derived here, server-side, from canonical outstanding/allocated —
-- never a client-side guess, never "outstanding = 0 => PAID" (a
-- WAIVER or a negative ADJUSTMENT can fully settle a charge with zero
-- cash ever changing hands, so "SETTLED" — never "PAID" — is the only
-- honest label for that state).

-- =========================================================================
-- A. rpc_get_my_contributions — paginated, filterable list.
-- =========================================================================

create or replace function public.rpc_get_my_contributions(
  p_group_id uuid,
  p_status text default null,
  p_contribution_type_id uuid default null,
  p_from_date date default null,
  p_to_date date default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_membership_id uuid;
  v_limit integer;
  v_offset integer;
  v_member jsonb;
  v_group jsonb;
  v_total_outstanding numeric;
  v_items jsonb;
  v_total_count bigint;
  v_filter_options jsonb;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  if p_group_id is null then
    raise exception 'p_group_id is required' using errcode = '22023';
  end if;

  if p_status is not null and p_status not in ('SETTLED', 'OVERDUE', 'PARTIALLY_SETTLED', 'OPEN') then
    raise exception 'MY_CONTRIBUTIONS_INVALID_STATUS' using errcode = '22023';
  end if;

  if p_from_date is not null and p_to_date is not null and p_from_date > p_to_date then
    raise exception 'p_from_date must not be after p_to_date' using errcode = '22023';
  end if;

  v_membership_id := public.current_membership_id(p_group_id);

  if v_membership_id is null then
    raise exception 'No active membership in this group' using errcode = '42501';
  end if;

  -- No officer-permission fallback by design (09G-B4-B §D/§N): unlike
  -- rpc_get_contribution_charge_detail/rpc_list_member_contribution_
  -- charges (both gated on contribution.view, officer-wide), this is
  -- self-service only — an ADMIN with contribution.view but NOT
  -- contribution.self_view must be rejected here exactly like a
  -- member with no permission at all.
  if not public.has_group_permission(p_group_id, 'contribution.self_view') then
    raise exception 'Not authorized to view contributions' using errcode = '42501';
  end if;

  v_limit := least(greatest(coalesce(p_limit, 50), 1), 200);
  v_offset := greatest(coalesce(p_offset, 0), 0);

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

  -- summary.total_outstanding (09G-B4-B §Q): the canonical sum across
  -- EVERY own charge, deliberately computed BEFORE any status/type/
  -- date filter is applied below — matching rpc_get_my_member_
  -- statement's own summary.* convention (B3): a stable overall
  -- position that never shifts merely because the caller filtered or
  -- paged the list. No paid/overdue count — those would require a new
  -- aggregate derivation not established by any canonical source
  -- (09G-B4-A finding), so none is fabricated here.
  select coalesce(sum(s.outstanding), 0)
  into v_total_outstanding
  from public.member_contribution_charges c
  cross join lateral public.contribution_charge_component_states(c.id) s
  where c.membership_id = v_membership_id and c.group_id = p_group_id;

  -- filter_options.contribution_types (09G-B4-B.1): the caller's OWN
  -- contribution-type universe, derived from every own charge —
  -- deliberately independent of p_limit/p_offset/p_status/
  -- p_contribution_type_id/p_from_date/p_to_date so an applied filter
  -- never makes its own option disappear, and never from the paged
  -- items (which would omit types beyond the current page).
  --
  -- id: contribution_setups.contribution_type_id via the charge's own
  --     immutable contribution_setup_id (no frozen type-id snapshot
  --     exists; periods freeze display text only).
  -- name / category: the frozen period snapshot of the caller's MOST
  --     RECENT own obligation of that type (effective_at DESC, then
  --     period_start DESC, then charge id DESC) — historically honest.
  -- name_variants / category_variants: every distinct frozen value the
  --     caller's own obligations of this type actually carry, so a
  --     contradiction is surfaced rather than silently collapsed.
  -- Ordered by primary display name ASC, then type id ASC.
  with own_type_rows as (
    select
      st.contribution_type_id as type_id,
      coalesce(p.snapshot_type_name, ct.name) as type_name,
      coalesce(p.snapshot_category, ct.category)::text as type_category,
      c.effective_at,
      p.period_start,
      c.id as charge_id
    from public.member_contribution_charges c
    join public.contribution_periods p on p.id = c.period_id
    join public.contribution_setups st on st.id = c.contribution_setup_id
    join public.contribution_types ct on ct.id = st.contribution_type_id
    where c.membership_id = v_membership_id and c.group_id = p_group_id
  ),
  latest_per_type as (
    select distinct on (type_id) type_id, type_name, type_category
    from own_type_rows
    order by type_id, effective_at desc, period_start desc, charge_id desc
  ),
  variants_per_type as (
    select
      type_id,
      array_agg(distinct type_name order by type_name) as name_variants,
      array_agg(distinct type_category order by type_category) as category_variants
    from own_type_rows
    group by type_id
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', l.type_id,
    'name', l.type_name,
    'category', l.type_category,
    'name_variants', to_jsonb(v.name_variants),
    'category_variants', to_jsonb(v.category_variants)
  ) order by l.type_name, l.type_id), '[]'::jsonb)
  into v_filter_options
  from latest_per_type l
  join variants_per_type v on v.type_id = l.type_id;

  with my_charges as (
    select
      c.id as charge_id,
      c.period_id,
      c.effective_at,
      c.due_date,
      c.created_at,
      st.contribution_type_id,
      -- Frozen period snapshot (09G-B4-B §E/§F): the authoritative
      -- historical display source — a later edit to contribution_
      -- types.name/category must never retroactively change how an
      -- already-posted charge is labeled. contribution_type_id itself
      -- has no snapshot column (periods only freeze display text), so
      -- it comes from the charge's own immutable contribution_setup_id
      -- -> contribution_setups.contribution_type_id chain — stable for
      -- a given charge, used for filtering only, never for display
      -- text.
      p.label as period_label,
      p.purpose::text as period_purpose,
      coalesce(p.snapshot_type_name, ct.name) as contribution_type_name,
      coalesce(p.snapshot_category, ct.category)::text as contribution_category,
      public.contribution_charge_net_assessed(c.id) as net_assessed,
      (select coalesce(sum(s.allocated), 0) from public.contribution_charge_component_states(c.id) s) as allocated_amount,
      (select coalesce(sum(s.outstanding), 0) from public.contribution_charge_component_states(c.id) s) as outstanding
    from public.member_contribution_charges c
    join public.contribution_periods p on p.id = c.period_id
    join public.contribution_setups st on st.id = c.contribution_setup_id
    join public.contribution_types ct on ct.id = st.contribution_type_id
    where c.membership_id = v_membership_id and c.group_id = p_group_id
  ),
  classified as (
    select
      my_charges.*,
      -- Status derivation (09G-B4-B §C, locked):
      --   SETTLED            outstanding = 0 (WAIVER/negative
      --                       ADJUSTMENT can reach this with zero cash
      --                       — never called "PAID").
      --   OVERDUE             outstanding > 0 and due_date < today.
      --   PARTIALLY_SETTLED   outstanding > 0, allocated_amount > 0,
      --                       not overdue.
      --   OPEN                otherwise (outstanding > 0, nothing
      --                       allocated yet, not overdue).
      (case
        when my_charges.outstanding = 0 then 'SETTLED'
        when my_charges.outstanding > 0 and my_charges.due_date is not null and my_charges.due_date < current_date then 'OVERDUE'
        when my_charges.outstanding > 0 and my_charges.allocated_amount > 0 then 'PARTIALLY_SETTLED'
        else 'OPEN'
      end) as status
    from my_charges
  ),
  filtered as (
    select *
    from classified
    where (p_status is null or status = p_status)
      and (p_contribution_type_id is null or contribution_type_id = p_contribution_type_id)
      and (p_from_date is null or effective_at >= p_from_date)
      and (p_to_date is null or effective_at <= p_to_date)
  ),
  total as (
    select count(*) as total_count from filtered
  ),
  paged as (
    select *
    from filtered
    order by effective_at desc, created_at desc, charge_id desc
    limit v_limit offset v_offset
  )
  select
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'charge_id', paged.charge_id,
          'contribution_type_id', paged.contribution_type_id,
          'contribution_type_name', paged.contribution_type_name,
          'contribution_category', paged.contribution_category,
          'period_id', paged.period_id,
          'period_label', paged.period_label,
          'period_purpose', paged.period_purpose,
          'effective_at', paged.effective_at,
          'due_date', paged.due_date,
          'net_assessed', paged.net_assessed,
          'allocated_amount', paged.allocated_amount,
          'outstanding', paged.outstanding,
          'status', paged.status
        )
        order by paged.effective_at desc, paged.created_at desc, paged.charge_id desc
      )
      from paged
    ), '[]'::jsonb),
    (select total_count from total)
  into v_items, v_total_count;

  return jsonb_build_object(
    'member', v_member,
    'group', v_group,
    'summary', jsonb_build_object(
      'total_outstanding', v_total_outstanding
    ),
    'filter_options', jsonb_build_object(
      'contribution_types', v_filter_options
    ),
    'items', v_items,
    'pagination', jsonb_build_object(
      'limit', v_limit,
      'offset', v_offset,
      'total_count', v_total_count,
      'has_more', (v_offset + v_limit) < v_total_count
    )
  );
end;
$$;

comment on function public.rpc_get_my_contributions(uuid, text, uuid, date, date, integer, integer) is
  'The caller''s own contribution obligations for p_group_id —
  resolved exclusively via current_membership_id(), never a
  client-supplied membership_id/user_id/phone. Requires
  contribution.self_view, no officer-permission fallback. Every
  monetary field (net_assessed/allocated_amount/outstanding) is read
  from the existing locked contribution_charge_net_assessed()/
  contribution_charge_component_states() helpers — no new accounting
  formula. status is server-derived (SETTLED/OVERDUE/
  PARTIALLY_SETTLED/OPEN) — never "PAID" (a WAIVER/negative ADJUSTMENT
  can reach zero outstanding with no payment involved).
  summary.total_outstanding is the unfiltered total across every own
  charge (matches rpc_get_my_member_statement''s own summary.*
  convention); pagination.total_count reflects the applied filters.';

revoke all on function public.rpc_get_my_contributions(uuid, text, uuid, date, date, integer, integer) from public;
revoke execute on function public.rpc_get_my_contributions(uuid, text, uuid, date, date, integer, integer) from anon;
grant execute on function public.rpc_get_my_contributions(uuid, text, uuid, date, date, integer, integer) to authenticated;

-- =========================================================================
-- B. rpc_get_my_contribution_charge_detail
--
-- 09G-B4-B §J (required justification for a new RPC rather than
-- reusing rpc_get_contribution_charge_detail(p_group_id, p_charge_id),
-- 20260828095000_create_payment_read_rpcs.sql:607):
--
-- 1. OWNERSHIP MECHANISM DIFFERS from the B4-A-locked architecture.
--    The existing RPC authorizes self-view access via
--    `v_charge.membership_user_id = auth.uid()` — a direct comparison
--    against whichever membership row owns the charge, computed via a
--    raw join, with no requirement that this is the caller's current
--    ACTIVE membership (it does not route through current_membership_id()
--    at all). B4-A §L explicitly locks current_membership_id(p_group_id)
--    as the ownership primitive precisely so an inactive/exited
--    membership or a non-ACTIVE group can never retain effective
--    access (see docs/database/authorization.md; CLAUDE.md "Let an
--    inactive profile retain effective group permissions" rule).
--    Changing the existing officer-facing RPC''s authorization
--    mechanism to fix this would risk regressing its own officer
--    callers/tests (`contribution.view` path) for a problem that only
--    matters for the NEW self-service caller — so a new RPC with the
--    correct ownership primitive is the safer change.
-- 2. MATERIALLY DIFFERENT RESPONSE SHAPE. The existing RPC returns
--    component breakdown + net_assessed + total_outstanding ONLY — it
--    has no settlement/payment/wallet-allocation history whatsoever
--    (09G-B4-A §21 finding). 09G-B4-B §L requires a member-
--    understandable settlement history (payments AND wallet-sourced
--    allocations, reversed payments visible). Retrofitting that onto
--    the existing RPC would change its contract for every existing
--    officer caller.
--
-- Conclusion: a new RPC is justified on both grounds. It intentionally
-- reuses the SAME component-breakdown query shape (LEFT JOIN from
-- every raw component to contribution_charge_component_states(), so
-- WAIVER/negative-ADJUSTMENT rows still appear with outstanding=null,
-- exactly like the existing RPC already does) — this is architectural
-- reuse of a proven pattern, not an independent reimplementation of
-- contribution accounting.
-- =========================================================================

create or replace function public.rpc_get_my_contribution_charge_detail(
  p_group_id uuid,
  p_charge_id uuid
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_membership_id uuid;
  v_charge record;
  v_context record;
  v_components jsonb;
  v_settlement jsonb;
  v_net_assessed numeric;
  v_allocated numeric;
  v_outstanding numeric;
  v_status text;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  if p_group_id is null or p_charge_id is null then
    raise exception 'p_group_id and p_charge_id are required' using errcode = '22023';
  end if;

  v_membership_id := public.current_membership_id(p_group_id);

  if v_membership_id is null then
    raise exception 'No active membership in this group' using errcode = '42501';
  end if;

  if not public.has_group_permission(p_group_id, 'contribution.self_view') then
    raise exception 'Not authorized to view contributions' using errcode = '42501';
  end if;

  -- Ownership by resolved membership_id, never by charge_id alone
  -- (09G-B4-B §K): the charge must belong to v_membership_id (already
  -- proven to be the caller''s own ACTIVE membership in this exact
  -- group) AND to this exact group_id. A charge belonging to any other
  -- membership — including another membership the SAME user might
  -- hold in a different group — is reported as not found, never as
  -- "forbidden" (no existence oracle).
  select c.id, c.group_id, c.period_id, c.membership_id, c.effective_at, c.due_date
  into v_charge
  from public.member_contribution_charges c
  where c.id = p_charge_id
    and c.group_id = p_group_id
    and c.membership_id = v_membership_id;

  if v_charge.id is null then
    raise exception 'Contribution charge not found' using errcode = '22023';
  end if;

  -- Type/period context resolved once, via the charge's immutable
  -- contribution_setup_id chain — same frozen-snapshot-first rule as
  -- the list RPC (09G-B4-B §E/§F).
  select
    st.contribution_type_id,
    coalesce(p.snapshot_type_name, ct.name) as contribution_type_name,
    coalesce(p.snapshot_category, ct.category)::text as contribution_category,
    p.label as period_label,
    p.purpose::text as period_purpose
  into v_context
  from public.member_contribution_charges c
  join public.contribution_periods p on p.id = c.period_id
  join public.contribution_setups st on st.id = c.contribution_setup_id
  join public.contribution_types ct on ct.id = st.contribution_type_id
  where c.id = v_charge.id;

  v_net_assessed := public.contribution_charge_net_assessed(v_charge.id);

  select coalesce(sum(s.allocated), 0), coalesce(sum(s.outstanding), 0)
  into v_allocated, v_outstanding
  from public.contribution_charge_component_states(v_charge.id) s;

  v_status := case
    when v_outstanding = 0 then 'SETTLED'
    when v_outstanding > 0 and v_charge.due_date is not null and v_charge.due_date < current_date then 'OVERDUE'
    when v_outstanding > 0 and v_allocated > 0 then 'PARTIALLY_SETTLED'
    else 'OPEN'
  end;

  -- Component breakdown: every real component row, left-joined to the
  -- canonical states helper so WAIVER/negative-ADJUSTMENT (which never
  -- appear in that helper''s own output — they are netted off, not
  -- independently payable) still show their real assessed_amount with
  -- allocated/outstanding/net_effect honestly null, never fabricated.
  select coalesce(jsonb_agg(jsonb_build_object(
    'component_id', cc.id,
    'component_type', cc.component_type,
    'assessed_amount', cc.assessed_amount,
    'net_effect', s.gross_after_corrections,
    'allocated', s.allocated,
    'outstanding', s.outstanding,
    'effective_at', cc.effective_at,
    'reason', cc.reason
  ) order by cc.effective_at, cc.created_at), '[]'::jsonb)
  into v_components
  from public.contribution_charge_components cc
  left join public.contribution_charge_component_states(v_charge.id) s on s.component_id = cc.id
  where cc.charge_id = v_charge.id;

  -- Settlement history (09G-B4-B §L): both payment-sourced and
  -- wallet-sourced allocations against this charge's components, in
  -- deterministic effective-date order. A reversed payment''s
  -- allocation remains visible here (status='REVERSED') even though
  -- contribution_charge_component_states() already excludes it from
  -- allocated/outstanding above — exactly the same "never mutate the
  -- row, just stop counting it" pattern as B3''s own activity feed.
  -- No synthetic payment/allocation row is created; this is a read of
  -- real persisted payment_allocations rows only.
  select coalesce(jsonb_agg(jsonb_build_object(
    'allocation_id', pa.id,
    'component_id', pa.charge_component_id,
    'component_type', cc.component_type,
    'amount', pa.amount,
    'source', case when pa.wallet_entry_id is not null then 'WALLET' else 'PAYMENT' end,
    'effective_at', coalesce(pay.effective_at, we.effective_at),
    'payment_status', pay.status,
    'receipt_number', pay.receipt_number,
    'is_reversed', pay.status = 'REVERSED'
  ) order by coalesce(pay.effective_at, we.effective_at), pa.created_at), '[]'::jsonb)
  into v_settlement
  from public.payment_allocations pa
  join public.contribution_charge_components cc on cc.id = pa.charge_component_id
  left join public.payments pay on pay.id = pa.payment_id
  left join public.member_wallet_entries we on we.id = pa.wallet_entry_id
  where cc.charge_id = v_charge.id;

  return jsonb_build_object(
    'charge_id', v_charge.id,
    'contribution_type_id', v_context.contribution_type_id,
    'contribution_type_name', v_context.contribution_type_name,
    'contribution_category', v_context.contribution_category,
    'period_id', v_charge.period_id,
    'period_label', v_context.period_label,
    'period_purpose', v_context.period_purpose,
    'effective_at', v_charge.effective_at,
    'due_date', v_charge.due_date,
    'net_assessed', v_net_assessed,
    'allocated_amount', v_allocated,
    'outstanding', v_outstanding,
    'status', v_status,
    'components', v_components,
    'settlement_history', v_settlement
  );
end;
$$;

comment on function public.rpc_get_my_contribution_charge_detail(uuid, uuid) is
  'The caller''s own single contribution charge in full detail —
  component breakdown (BASE/PENALTY/ADJUSTMENT/WAIVER/OPENING_BALANCE,
  all from contribution_charge_components, outstanding/allocated/
  net_effect from the locked contribution_charge_component_states()
  helper) plus settlement_history (every payment_allocations row
  against this charge, both payment- and wallet-sourced, reversed
  payments visible but already excluded from outstanding by the
  canonical helper). Ownership: the charge must belong to
  current_membership_id(p_group_id) exactly — never charge_id alone,
  never a caller-supplied membership_id. Requires
  contribution.self_view, no officer fallback. See this migration''s
  own comment for why this is a new RPC rather than a reuse of
  rpc_get_contribution_charge_detail.';

revoke all on function public.rpc_get_my_contribution_charge_detail(uuid, uuid) from public;
revoke execute on function public.rpc_get_my_contribution_charge_detail(uuid, uuid) from anon;
grant execute on function public.rpc_get_my_contribution_charge_detail(uuid, uuid) to authenticated;
