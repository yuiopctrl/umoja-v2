-- Prompt 06C: Contribution Adjustments, Waivers & Opening Balances.
--
-- Builds on 06A's obligation ledger and 06B's penalty engine. No new
-- parallel structure: a correction is exactly one more row in the
-- existing contribution_charge_components table (component_type
-- ADJUSTMENT/WAIVER/OPENING_BALANCE), and an opening balance is exactly
-- one more member_contribution_charges row — reusing 06A's own
-- "one charge per (period, membership)" uniqueness for duplicate-import
-- protection, rather than inventing a new mechanism.
--
-- Locked invariants preserved from 06A/06B, unchanged by this migration:
-- BASE and PENALTY components are never edited/deleted. No period is
-- reopened. No payment/wallet/cashbook concept is introduced.

-- ---------------------------------------------------------------------
-- contribution_period_purpose — distinguishes an ordinary period from
-- the system-managed "opening balance" construct (section 13/29: an
-- opening balance must never masquerade as, or pollute, a normal
-- monthly/one-time period list).
-- ---------------------------------------------------------------------

create type public.contribution_period_purpose as enum (
  'NORMAL',
  'OPENING_BALANCE'
);

alter table public.contribution_periods
  add column purpose public.contribution_period_purpose not null default 'NORMAL';

comment on column public.contribution_periods.purpose is
  'NORMAL for every ordinary period. OPENING_BALANCE marks a
  system-provisioned period that exists only to anchor imported
  pre-Umoja opening-balance charges for one (group, contribution_type,
  effective_at) combination — see
  rpc_import_contribution_opening_balances(). rpc_list_contribution_periods
  always excludes OPENING_BALANCE periods; use
  rpc_list_contribution_opening_balances() to see them.';

-- ---------------------------------------------------------------------
-- contribution_setups.is_system — marks the setup
-- rpc_import_contribution_opening_balances() auto-provisions per
-- (group, contribution_type) to carry OPENING_BALANCE periods. Hidden
-- from the normal setup list/picker so a treasurer never accidentally
-- creates a normal period under it.
-- ---------------------------------------------------------------------

alter table public.contribution_setups
  add column is_system boolean not null default false;

comment on column public.contribution_setups.is_system is
  'true only for the system-provisioned "Opening Balances" setup per
  (group, contribution_type) — see
  rpc_import_contribution_opening_balances(). Never created directly by
  a client RPC; excluded from rpc_list_contribution_setups and the
  setup picker by default.';

-- ---------------------------------------------------------------------
-- contribution_charge_components: sign convention + correction
-- metadata.
-- ---------------------------------------------------------------------
--
-- 06A's original constraint required assessed_amount > 0 for every
-- component (true for BASE/PENALTY). Section 3's locked sign convention
-- requires WAIVER to be stored negative and ADJUSTMENT to be either
-- sign — so that constraint is replaced with one that encodes the full
-- sign convention explicitly at the database level, per component type,
-- rather than trusting callers/Flutter to get the sign right.

alter table public.contribution_charge_components
  drop constraint contribution_charge_components_amount_positive;

alter table public.contribution_charge_components
  add constraint contribution_charge_components_amount_sign check (
    (component_type in ('BASE', 'PENALTY', 'OPENING_BALANCE') and assessed_amount > 0)
    or (component_type = 'ADJUSTMENT' and assessed_amount <> 0)
    or (component_type = 'WAIVER' and assessed_amount < 0)
  );

comment on constraint contribution_charge_components_amount_sign
  on public.contribution_charge_components is
  'Locked sign convention (Prompt 06C): BASE/PENALTY/OPENING_BALANCE are
  always positive obligations. ADJUSTMENT may be positive (increases
  obligation) or negative (reduces it), but never zero. WAIVER is always
  stored negative — never positive-with-Flutter-expected-to-subtract.';

alter table public.contribution_charge_components
  add column reason text;

comment on column public.contribution_charge_components.reason is
  'Required (enforced in the RPC, not here) for ADJUSTMENT and WAIVER.
  Always null for BASE/PENALTY/OPENING_BALANCE.';

alter table public.contribution_charge_components
  add column idempotency_key text;

comment on column public.contribution_charge_components.idempotency_key is
  'Optional client-supplied stable key so a retried
  adjustment/waiver submission is safe to resend — see
  rpc_create_contribution_adjustment()/rpc_waive_contribution_charge().
  Always null for BASE/PENALTY/OPENING_BALANCE, which have their own
  idempotency mechanisms (the (charge_id, sequence) unique index for
  PENALTY; one row per charge for BASE/OPENING_BALANCE).';

create unique index contribution_charge_components_idempotency_key_unique
  on public.contribution_charge_components (charge_id, component_type, idempotency_key)
  where idempotency_key is not null;

-- ---------------------------------------------------------------------
-- Permissions.
-- ---------------------------------------------------------------------
--
-- Financially-sensitive corrections — deliberately narrower than plain
-- contribution.view. Mapped per section 21: ADMIN/TREASURER get all
-- three; CHAIRPERSON gets waiver visibility only (via contribution.view,
-- already held — no new grant needed for "view"); SECRETARY/MEMBER get
-- none of these three (SECRETARY already has contribution.view for
-- read-only visibility; MEMBER already has contribution.self_view).

insert into public.permissions (code, name, description) values
  ('contribution.adjustment.create', 'Create contribution adjustments', 'Post a signed adjustment component against an existing contribution charge.'),
  ('contribution.waiver.create', 'Waive contribution obligations', 'Post a waiver component reducing an existing contribution charge''s net obligation.'),
  ('contribution.opening_balance.manage', 'Manage contribution opening balances', 'Import pre-Umoja opening-balance obligations for group members.');

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where r.code = 'ADMIN'
  and p.code in (
    'contribution.adjustment.create',
    'contribution.waiver.create',
    'contribution.opening_balance.manage'
  )
on conflict do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p
  on p.code in (
    'contribution.adjustment.create',
    'contribution.waiver.create',
    'contribution.opening_balance.manage'
  )
where r.code = 'TREASURER';

-- ---------------------------------------------------------------------
-- Shared helper: net assessed / component sums for one charge.
-- ---------------------------------------------------------------------

create or replace function public.contribution_charge_net_assessed(p_charge_id uuid)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(sum(assessed_amount), 0)
  from public.contribution_charge_components
  where charge_id = p_charge_id;
$$;

comment on function public.contribution_charge_net_assessed(uuid) is
  'Sum of every component (BASE + PENALTY + OPENING_BALANCE +
  ADJUSTMENT + WAIVER, WAIVER already stored negative) for one charge —
  the authoritative "net assessed" figure. Never negative by
  construction: every RPC that inserts a component validates this stays
  >= 0 before inserting.';

revoke all on function public.contribution_charge_net_assessed(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- rpc_create_contribution_adjustment
-- ---------------------------------------------------------------------

create or replace function public.rpc_create_contribution_adjustment(
  p_group_id uuid,
  p_charge_id uuid,
  p_amount numeric,
  p_reason text,
  p_effective_at date default current_date,
  p_idempotency_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_charge record;
  v_existing record;
  v_current_net numeric;
  v_component_id uuid;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'contribution.adjustment.create') then
    raise exception 'Not authorized to create contribution adjustments in this group' using errcode = '42501';
  end if;

  if p_amount is null or p_amount = 0 then
    raise exception 'ADJUSTMENT_AMOUNT_REQUIRED' using errcode = '22023';
  end if;

  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'ADJUSTMENT_REASON_REQUIRED' using errcode = '22023';
  end if;

  if p_effective_at is null then
    raise exception 'Effective date is required' using errcode = '22023';
  end if;

  select c.id, c.group_id into v_charge
  from public.member_contribution_charges c
  where c.id = p_charge_id
  for update;

  if v_charge.group_id is null or v_charge.group_id <> p_group_id then
    raise exception 'Contribution charge not found in group' using errcode = '22023';
  end if;

  -- Idempotent retry: an identical (charge_id, component_type, key)
  -- request returns the existing component instead of posting again.
  if p_idempotency_key is not null then
    select id, assessed_amount into v_existing
    from public.contribution_charge_components
    where charge_id = p_charge_id
      and component_type = 'ADJUSTMENT'
      and idempotency_key = p_idempotency_key;

    if v_existing.id is not null then
      return jsonb_build_object(
        'component_id', v_existing.id,
        'charge_id', p_charge_id,
        'amount', v_existing.assessed_amount,
        'already_posted', true,
        'net_assessed', public.contribution_charge_net_assessed(p_charge_id)
      );
    end if;
  end if;

  v_current_net := public.contribution_charge_net_assessed(p_charge_id);

  if v_current_net + p_amount < 0 then
    raise exception 'ADJUSTMENT_WOULD_MAKE_OBLIGATION_NEGATIVE' using errcode = 'P0001';
  end if;

  insert into public.contribution_charge_components (
    group_id, charge_id, component_type, assessed_amount, effective_at, sequence, reason, idempotency_key, created_by
  ) values (
    p_group_id, p_charge_id, 'ADJUSTMENT', p_amount, p_effective_at, 1, btrim(p_reason), p_idempotency_key, v_uid
  )
  returning id into v_component_id;

  select jsonb_build_object(
    'component_id', v_component_id,
    'charge_id', p_charge_id,
    'amount', p_amount,
    'already_posted', false,
    'net_assessed', public.contribution_charge_net_assessed(p_charge_id)
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.rpc_create_contribution_adjustment(uuid, uuid, numeric, text, date, text) from public;
grant execute on function public.rpc_create_contribution_adjustment(uuid, uuid, numeric, text, date, text) to authenticated;
revoke execute on function public.rpc_create_contribution_adjustment(uuid, uuid, numeric, text, date, text) from anon;

comment on function public.rpc_create_contribution_adjustment(uuid, uuid, numeric, text, date, text) is
  'Posts a signed ADJUSTMENT component (positive increases obligation,
  negative reduces it, never zero) against an existing charge. Never
  edits BASE/PENALTY. Rejects if the resulting net_assessed would go
  negative. Applies to a charge under an OPEN or CLOSED period alike —
  never reopens the period. Idempotent when p_idempotency_key is
  supplied and reused on retry.';

-- ---------------------------------------------------------------------
-- rpc_waive_contribution_charge
-- ---------------------------------------------------------------------

create or replace function public.rpc_waive_contribution_charge(
  p_group_id uuid,
  p_charge_id uuid,
  p_amount numeric,
  p_reason text,
  p_effective_at date default current_date,
  p_idempotency_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_charge record;
  v_existing record;
  v_current_net numeric;
  v_component_id uuid;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'contribution.waiver.create') then
    raise exception 'Not authorized to waive contribution obligations in this group' using errcode = '42501';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'WAIVER_AMOUNT_MUST_BE_POSITIVE' using errcode = '22023';
  end if;

  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'WAIVER_REASON_REQUIRED' using errcode = '22023';
  end if;

  if p_effective_at is null then
    raise exception 'Effective date is required' using errcode = '22023';
  end if;

  select c.id, c.group_id into v_charge
  from public.member_contribution_charges c
  where c.id = p_charge_id
  for update;

  if v_charge.group_id is null or v_charge.group_id <> p_group_id then
    raise exception 'Contribution charge not found in group' using errcode = '22023';
  end if;

  if p_idempotency_key is not null then
    select id, assessed_amount into v_existing
    from public.contribution_charge_components
    where charge_id = p_charge_id
      and component_type = 'WAIVER'
      and idempotency_key = p_idempotency_key;

    if v_existing.id is not null then
      return jsonb_build_object(
        'component_id', v_existing.id,
        'charge_id', p_charge_id,
        'amount', abs(v_existing.assessed_amount),
        'already_posted', true,
        'net_assessed', public.contribution_charge_net_assessed(p_charge_id)
      );
    end if;
  end if;

  v_current_net := public.contribution_charge_net_assessed(p_charge_id);

  if v_current_net - p_amount < 0 then
    raise exception 'WAIVER_EXCEEDS_NET_ASSESSED' using errcode = 'P0001';
  end if;

  -- Locked sign convention: WAIVER is always stored negative — the
  -- caller supplies a positive magnitude, never a signed value.
  insert into public.contribution_charge_components (
    group_id, charge_id, component_type, assessed_amount, effective_at, sequence, reason, idempotency_key, created_by
  ) values (
    p_group_id, p_charge_id, 'WAIVER', -p_amount, p_effective_at, 1, btrim(p_reason), p_idempotency_key, v_uid
  )
  returning id into v_component_id;

  select jsonb_build_object(
    'component_id', v_component_id,
    'charge_id', p_charge_id,
    'amount', p_amount,
    'already_posted', false,
    'net_assessed', public.contribution_charge_net_assessed(p_charge_id)
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.rpc_waive_contribution_charge(uuid, uuid, numeric, text, date, text) from public;
grant execute on function public.rpc_waive_contribution_charge(uuid, uuid, numeric, text, date, text) to authenticated;
revoke execute on function public.rpc_waive_contribution_charge(uuid, uuid, numeric, text, date, text) from anon;

comment on function public.rpc_waive_contribution_charge(uuid, uuid, numeric, text, date, text) is
  'p_amount is always a positive magnitude to waive; the stored
  component is always negative (locked sign convention). Rejects if the
  waiver would exceed the charge''s current net_assessed (never
  produces negative obligation). Never deletes/rewrites BASE/PENALTY —
  a waiver against a penalized charge leaves the PENALTY component
  historically intact. Applies to OPEN or CLOSED charges; never reopens
  the period. Idempotent when p_idempotency_key is supplied.';

-- ---------------------------------------------------------------------
-- Opening balances: get-or-create the system setup/period, preview, and
-- atomic batch import.
-- ---------------------------------------------------------------------

create or replace function public.contribution_get_or_create_opening_balance_period(
  p_group_id uuid,
  p_contribution_type_id uuid,
  p_effective_at date,
  p_uid uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_type record;
  v_setup_id uuid;
  v_period_id uuid;
begin
  select id, group_id, name, category, accounting_treatment, is_active
  into v_type
  from public.contribution_types
  where id = p_contribution_type_id;

  if v_type.group_id is null or v_type.group_id <> p_group_id then
    raise exception 'Contribution type not found in group' using errcode = '22023';
  end if;

  if not v_type.is_active then
    raise exception 'CONTRIBUTION_TYPE_INACTIVE' using errcode = 'P0001';
  end if;

  select id into v_setup_id
  from public.contribution_setups
  where group_id = p_group_id
    and contribution_type_id = p_contribution_type_id
    and is_system = true
  limit 1;

  if v_setup_id is null then
    insert into public.contribution_setups (
      group_id, contribution_type_id, name, schedule_mode, amount_mode,
      penalty_mode, is_system, created_by
    ) values (
      p_group_id, p_contribution_type_id,
      v_type.name || ' — Opening Balances', 'ONE_TIME', 'CUSTOM_PER_MEMBER',
      'NONE', true, p_uid
    )
    returning id into v_setup_id;
  end if;

  select id into v_period_id
  from public.contribution_periods
  where contribution_setup_id = v_setup_id
    and purpose = 'OPENING_BALANCE'
    and period_start = p_effective_at
  limit 1;

  if v_period_id is null then
    insert into public.contribution_periods (
      group_id, contribution_setup_id, label, period_start, period_end,
      obligation_date, eligibility_date, due_date, status, purpose,
      opened_at, opened_by,
      snapshot_type_name, snapshot_category, snapshot_accounting_treatment,
      snapshot_setup_name, snapshot_schedule_mode, snapshot_amount_mode,
      snapshot_penalty_mode,
      created_by
    ) values (
      p_group_id, v_setup_id, v_type.name || ' Opening Balances — ' || p_effective_at::text,
      p_effective_at, p_effective_at, p_effective_at, p_effective_at, p_effective_at,
      'OPEN', 'OPENING_BALANCE',
      now(), p_uid,
      v_type.name, v_type.category, v_type.accounting_treatment,
      v_type.name || ' — Opening Balances', 'ONE_TIME', 'CUSTOM_PER_MEMBER',
      'NONE',
      p_uid
    )
    returning id into v_period_id;
  end if;

  return v_period_id;
end;
$$;

comment on function public.contribution_get_or_create_opening_balance_period(uuid, uuid, date, uuid) is
  'Idempotently returns the one system-managed OPENING_BALANCE period
  for (group, contribution_type, effective_at), auto-provisioning its
  backing system setup/period on first use. This period is created
  directly in OPEN status — none of the eligibility/exclusion/preview
  machinery applies, since an opening balance is not derived from
  automatic membership eligibility. penalty_mode is always NONE: an
  opening balance never automatically accrues a NEW 06B penalty.
  Excluded from rpc_list_contribution_periods (purpose <> NORMAL); see
  rpc_list_contribution_opening_balances() for its own reporting path.';

revoke all on function public.contribution_get_or_create_opening_balance_period(uuid, uuid, date, uuid) from public, anon, authenticated;

create or replace function public.rpc_preview_contribution_opening_balance_import(
  p_group_id uuid,
  p_contribution_type_id uuid,
  p_effective_at date,
  p_entries jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_type_group_id uuid;
  v_item jsonb;
  v_membership_id uuid;
  v_amount numeric;
  v_membership record;
  v_existing_charge_id uuid;
  v_setup_id uuid;
  v_rows jsonb := '[]'::jsonb;
  v_total numeric := 0;
  v_count integer := 0;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'contribution.opening_balance.manage') then
    raise exception 'Not authorized to manage contribution opening balances in this group' using errcode = '42501';
  end if;

  select group_id into v_type_group_id from public.contribution_types where id = p_contribution_type_id;
  if v_type_group_id is null or v_type_group_id <> p_group_id then
    raise exception 'Contribution type not found in group' using errcode = '22023';
  end if;

  if p_effective_at is null then
    raise exception 'Effective date is required' using errcode = '22023';
  end if;

  select id into v_setup_id
  from public.contribution_setups
  where group_id = p_group_id and contribution_type_id = p_contribution_type_id and is_system = true
  limit 1;

  if p_entries is null or jsonb_typeof(p_entries) <> 'array' then
    raise exception 'Entries payload must be a JSON array' using errcode = '22023';
  end if;

  for v_item in select * from jsonb_array_elements(p_entries)
  loop
    v_membership_id := (v_item ->> 'membership_id')::uuid;
    v_amount := nullif(v_item ->> 'amount', '')::numeric;

    if v_amount is null or v_amount <= 0 then
      continue;
    end if;

    select id, group_id, member_number, display_name into v_membership
    from public.group_memberships
    where id = v_membership_id;

    if v_membership.group_id is null or v_membership.group_id <> p_group_id then
      raise exception 'Membership not found in group' using errcode = '22023';
    end if;

    v_existing_charge_id := null;
    if v_setup_id is not null then
      select c.id into v_existing_charge_id
      from public.member_contribution_charges c
      join public.contribution_periods p on p.id = c.period_id
      where p.contribution_setup_id = v_setup_id
        and p.purpose = 'OPENING_BALANCE'
        and p.period_start = p_effective_at
        and c.membership_id = v_membership_id;
    end if;

    v_rows := v_rows || jsonb_build_object(
      'membership_id', v_membership_id,
      'member_number', v_membership.member_number,
      'display_name', v_membership.display_name,
      'amount', v_amount,
      'already_imported', v_existing_charge_id is not null
    );
    v_total := v_total + v_amount;
    v_count := v_count + 1;
  end loop;

  return jsonb_build_object(
    'contribution_type_id', p_contribution_type_id,
    'effective_at', p_effective_at,
    'member_count', v_count,
    'total_opening_obligation', v_total,
    'entries', v_rows,
    'can_import', not exists (
      select 1 from jsonb_array_elements(v_rows) e
      where (e -> 'already_imported')::boolean
    )
  );
end;
$$;

revoke all on function public.rpc_preview_contribution_opening_balance_import(uuid, uuid, date, jsonb) from public;
grant execute on function public.rpc_preview_contribution_opening_balance_import(uuid, uuid, date, jsonb) to authenticated;
revoke execute on function public.rpc_preview_contribution_opening_balance_import(uuid, uuid, date, jsonb) from anon;

comment on function public.rpc_preview_contribution_opening_balance_import(uuid, uuid, date, jsonb) is
  'Read-only, server-authoritative preview of
  rpc_import_contribution_opening_balances() — member count, total, and
  per-member already_imported flags, so the batch UI never guesses the
  total or silently double-imports. Blank/zero amounts are simply
  omitted (no opening balance for that member), never rejected.';

create or replace function public.rpc_import_contribution_opening_balances(
  p_group_id uuid,
  p_contribution_type_id uuid,
  p_effective_at date,
  p_entries jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_period_id uuid;
  v_item jsonb;
  v_membership_id uuid;
  v_membership_group_id uuid;
  v_amount numeric;
  v_membership record;
  v_charge_id uuid;
  v_imported_count integer := 0;
  v_total numeric := 0;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'contribution.opening_balance.manage') then
    raise exception 'Not authorized to manage contribution opening balances in this group' using errcode = '42501';
  end if;

  if p_effective_at is null then
    raise exception 'Effective date is required' using errcode = '22023';
  end if;

  if p_entries is null or jsonb_typeof(p_entries) <> 'array' then
    raise exception 'Entries payload must be a JSON array' using errcode = '22023';
  end if;

  v_period_id := public.contribution_get_or_create_opening_balance_period(
    p_group_id, p_contribution_type_id, p_effective_at, v_uid
  );

  -- Validate every row first (membership in group, positive amount,
  -- not already imported for this exact group/type/effective_at) —
  -- atomic all-or-nothing: any failure here raises and rolls back the
  -- whole batch before anything is inserted.
  for v_item in select * from jsonb_array_elements(p_entries)
  loop
    v_membership_id := (v_item ->> 'membership_id')::uuid;
    v_amount := nullif(v_item ->> 'amount', '')::numeric;

    -- Blank or zero means "no opening balance for this member" — simply
    -- skip the entry, same as the preview RPC. Only a negative amount
    -- is an actual validation error.
    if v_amount is null or v_amount = 0 then
      continue;
    end if;

    if v_amount < 0 then
      raise exception 'OPENING_BALANCE_AMOUNT_MUST_BE_POSITIVE' using errcode = 'P0001';
    end if;

    select group_id into v_membership_group_id
    from public.group_memberships
    where id = v_membership_id;

    if v_membership_group_id is null or v_membership_group_id <> p_group_id then
      raise exception 'Membership not found in group' using errcode = '22023';
    end if;

    if exists (
      select 1 from public.member_contribution_charges
      where period_id = v_period_id and membership_id = v_membership_id
    ) then
      raise exception 'OPENING_BALANCE_ALREADY_IMPORTED' using errcode = 'P0001';
    end if;
  end loop;

  for v_item in select * from jsonb_array_elements(p_entries)
  loop
    v_membership_id := (v_item ->> 'membership_id')::uuid;
    v_amount := nullif(v_item ->> 'amount', '')::numeric;

    if v_amount is null or v_amount = 0 then
      continue;
    end if;

    select id, member_number, display_name into v_membership
    from public.group_memberships
    where id = v_membership_id;

    insert into public.member_contribution_charges (
      group_id, period_id, contribution_setup_id, membership_id,
      member_number_snapshot, member_name_snapshot, effective_at, due_date, created_by
    )
    select
      p_group_id, v_period_id, contribution_setup_id, v_membership_id,
      v_membership.member_number, v_membership.display_name, p_effective_at, p_effective_at, v_uid
    from public.contribution_periods where id = v_period_id
    returning id into v_charge_id;

    insert into public.contribution_charge_components (
      group_id, charge_id, component_type, assessed_amount, effective_at, sequence, created_by
    ) values (
      p_group_id, v_charge_id, 'OPENING_BALANCE', v_amount, p_effective_at, 1, v_uid
    );

    v_imported_count := v_imported_count + 1;
    v_total := v_total + v_amount;
  end loop;

  return jsonb_build_object(
    'period_id', v_period_id,
    'contribution_type_id', p_contribution_type_id,
    'effective_at', p_effective_at,
    'imported_count', v_imported_count,
    'total_opening_obligation', v_total
  );
end;
$$;

revoke all on function public.rpc_import_contribution_opening_balances(uuid, uuid, date, jsonb) from public;
grant execute on function public.rpc_import_contribution_opening_balances(uuid, uuid, date, jsonb) to authenticated;
revoke execute on function public.rpc_import_contribution_opening_balances(uuid, uuid, date, jsonb) from anon;

comment on function public.rpc_import_contribution_opening_balances(uuid, uuid, date, jsonb) is
  'Atomic batch import: either every valid (non-blank) entry posts, or
  none do — a single already-imported or invalid entry rejects the
  whole call (P0001 OPENING_BALANCE_ALREADY_IMPORTED /
  OPENING_BALANCE_AMOUNT_MUST_BE_POSITIVE) rather than silently
  skipping it or partially posting. Creates no payment/cash/receipt row
  of any kind — only member_contribution_charges +
  one OPENING_BALANCE contribution_charge_components row per member.';

-- ---------------------------------------------------------------------
-- rpc_list_contribution_opening_balances — dedicated reporting path
-- (never mixed into rpc_list_contribution_periods).
-- ---------------------------------------------------------------------

create or replace function public.rpc_list_contribution_opening_balances(
  p_group_id uuid,
  p_contribution_type_id uuid default null,
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
  v_total bigint;
  v_items jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'contribution.view') then
    raise exception 'Not authorized to view contributions in this group' using errcode = '42501';
  end if;

  select count(*) into v_total
  from public.member_contribution_charges c
  join public.contribution_periods p on p.id = c.period_id
  where p.group_id = p_group_id
    and p.purpose = 'OPENING_BALANCE'
    and (p_contribution_type_id is null or p.snapshot_type_name = (
      select name from public.contribution_types where id = p_contribution_type_id
    ));

  select coalesce(jsonb_agg(row_to_json(rows.*) order by rows.member_name_snapshot), '[]'::jsonb)
  into v_items
  from (
    select
      c.id as charge_id, c.membership_id, c.member_number_snapshot, c.member_name_snapshot,
      c.effective_at, p.snapshot_type_name as contribution_type_name,
      p.snapshot_category as category, p.snapshot_accounting_treatment as accounting_treatment,
      (
        select cc.assessed_amount from public.contribution_charge_components cc
        where cc.charge_id = c.id and cc.component_type = 'OPENING_BALANCE'
      ) as opening_balance_amount,
      public.contribution_charge_net_assessed(c.id) as net_assessed
    from public.member_contribution_charges c
    join public.contribution_periods p on p.id = c.period_id
    where p.group_id = p_group_id
      and p.purpose = 'OPENING_BALANCE'
      and (p_contribution_type_id is null or p.snapshot_type_name = (
        select name from public.contribution_types where id = p_contribution_type_id
      ))
    order by c.member_name_snapshot
    limit v_limit offset v_offset
  ) rows;

  return jsonb_build_object('items', v_items, 'total_count', v_total, 'limit', v_limit, 'offset', v_offset);
end;
$$;

revoke all on function public.rpc_list_contribution_opening_balances(uuid, uuid, integer, integer) from public;
grant execute on function public.rpc_list_contribution_opening_balances(uuid, uuid, integer, integer) to authenticated;
revoke execute on function public.rpc_list_contribution_opening_balances(uuid, uuid, integer, integer) from anon;

-- ---------------------------------------------------------------------
-- rpc_get_contribution_charge_detail — full per-component breakdown for
-- one charge (Flutter's charge/member detail screen, section 30).
-- ---------------------------------------------------------------------

create or replace function public.rpc_get_contribution_charge_detail(
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
  v_uid uuid := auth.uid();
  v_charge record;
  v_full_view boolean;
  v_components jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  select c.*, gm.user_id as membership_user_id into v_charge
  from public.member_contribution_charges c
  join public.group_memberships gm on gm.id = c.membership_id
  where c.id = p_charge_id;

  if v_charge.group_id is null or v_charge.group_id <> p_group_id then
    raise exception 'Contribution charge not found in group' using errcode = '22023';
  end if;

  v_full_view := public.has_group_permission(p_group_id, 'contribution.view');
  if not v_full_view then
    if not (
      public.has_group_permission(p_group_id, 'contribution.self_view')
      and v_charge.membership_user_id = v_uid
    ) then
      raise exception 'Not authorized to view this contribution charge' using errcode = '42501';
    end if;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'component_id', cc.id,
    'component_type', cc.component_type,
    'amount', cc.assessed_amount,
    'reason', cc.reason,
    'effective_at', cc.effective_at,
    'sequence', cc.sequence,
    'created_at', cc.created_at,
    'created_by', cc.created_by
  ) order by cc.effective_at, cc.created_at), '[]'::jsonb)
  into v_components
  from public.contribution_charge_components cc
  where cc.charge_id = p_charge_id;

  return jsonb_build_object(
    'charge_id', v_charge.id,
    'group_id', v_charge.group_id,
    'period_id', v_charge.period_id,
    'membership_id', v_charge.membership_id,
    'member_number_snapshot', v_charge.member_number_snapshot,
    'member_name_snapshot', v_charge.member_name_snapshot,
    'effective_at', v_charge.effective_at,
    'due_date', v_charge.due_date,
    'components', v_components,
    'net_assessed', public.contribution_charge_net_assessed(p_charge_id)
  );
end;
$$;

revoke all on function public.rpc_get_contribution_charge_detail(uuid, uuid) from public;
grant execute on function public.rpc_get_contribution_charge_detail(uuid, uuid) to authenticated;
revoke execute on function public.rpc_get_contribution_charge_detail(uuid, uuid) from anon;

-- ---------------------------------------------------------------------
-- rpc_get_member_contribution_summary — per-member obligation summary
-- across all their charges in the group (section 27). No "paid"/
-- "outstanding after payment" concept — payments don't exist yet.
-- ---------------------------------------------------------------------

create or replace function public.rpc_get_member_contribution_summary(
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
  v_full_view boolean;
  v_base numeric;
  v_penalty numeric;
  v_adjustment numeric;
  v_waiver numeric;
  v_opening_balance numeric;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  select id, group_id, user_id into v_membership
  from public.group_memberships
  where id = p_membership_id;

  if v_membership.group_id is null or v_membership.group_id <> p_group_id then
    raise exception 'Membership not found in group' using errcode = '22023';
  end if;

  v_full_view := public.has_group_permission(p_group_id, 'contribution.view');
  if not v_full_view then
    if not (
      public.has_group_permission(p_group_id, 'contribution.self_view')
      and v_membership.user_id = v_uid
    ) then
      raise exception 'Not authorized to view this member''s contribution summary' using errcode = '42501';
    end if;
  end if;

  select
    coalesce(sum(cc.assessed_amount) filter (where cc.component_type = 'BASE'), 0),
    coalesce(sum(cc.assessed_amount) filter (where cc.component_type = 'PENALTY'), 0),
    coalesce(sum(cc.assessed_amount) filter (where cc.component_type = 'ADJUSTMENT'), 0),
    coalesce(sum(cc.assessed_amount) filter (where cc.component_type = 'WAIVER'), 0),
    coalesce(sum(cc.assessed_amount) filter (where cc.component_type = 'OPENING_BALANCE'), 0)
  into v_base, v_penalty, v_adjustment, v_waiver, v_opening_balance
  from public.member_contribution_charges c
  join public.contribution_charge_components cc on cc.charge_id = c.id
  where c.membership_id = p_membership_id and c.group_id = p_group_id;

  return jsonb_build_object(
    'membership_id', p_membership_id,
    'base_assessed', v_base,
    'penalties_assessed', v_penalty,
    'adjustments_assessed', v_adjustment,
    'waivers_assessed', v_waiver,
    'opening_balances_assessed', v_opening_balance,
    'net_assessed', v_base + v_penalty + v_adjustment + v_waiver + v_opening_balance
  );
end;
$$;

revoke all on function public.rpc_get_member_contribution_summary(uuid, uuid) from public;
grant execute on function public.rpc_get_member_contribution_summary(uuid, uuid) to authenticated;
revoke execute on function public.rpc_get_member_contribution_summary(uuid, uuid) from anon;

-- ---------------------------------------------------------------------
-- rpc_list_contribution_periods — always excludes OPENING_BALANCE
-- periods (section 13/29: never pollute the normal period list).
-- ---------------------------------------------------------------------

create or replace function public.rpc_list_contribution_periods(
  p_group_id uuid,
  p_contribution_setup_id uuid default null,
  p_status public.contribution_period_status default null,
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
  v_total bigint;
  v_items jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'contribution.view') then
    raise exception 'Not authorized to view contributions in this group' using errcode = '42501';
  end if;

  select count(*) into v_total
  from public.contribution_periods p
  where p.group_id = p_group_id
    and p.purpose = 'NORMAL'
    and (p_contribution_setup_id is null or p.contribution_setup_id = p_contribution_setup_id)
    and (p_status is null or p.status = p_status);

  select coalesce(jsonb_agg(row_to_json(rows.*) order by rows.period_start desc), '[]'::jsonb)
  into v_items
  from (
    select id, group_id, contribution_setup_id, label, period_start, period_end,
           obligation_date, eligibility_date, due_date, status, scheduled_open_date,
           opened_at, closed_at, cancelled_at, created_at, updated_at
    from public.contribution_periods p
    where p.group_id = p_group_id
      and p.purpose = 'NORMAL'
      and (p_contribution_setup_id is null or p.contribution_setup_id = p_contribution_setup_id)
      and (p_status is null or p.status = p_status)
    order by period_start desc
    limit v_limit offset v_offset
  ) rows;

  return jsonb_build_object('items', v_items, 'total_count', v_total, 'limit', v_limit, 'offset', v_offset);
end;
$$;

revoke all on function public.rpc_list_contribution_periods(uuid, uuid, public.contribution_period_status, integer, integer) from public;
grant execute on function public.rpc_list_contribution_periods(uuid, uuid, public.contribution_period_status, integer, integer) to authenticated;
revoke execute on function public.rpc_list_contribution_periods(uuid, uuid, public.contribution_period_status, integer, integer) from anon;

-- ---------------------------------------------------------------------
-- rpc_list_contribution_setups — always excludes system (is_system)
-- setups from the normal list/picker.
-- ---------------------------------------------------------------------

create or replace function public.rpc_list_contribution_setups(
  p_group_id uuid,
  p_contribution_type_id uuid default null,
  p_is_active boolean default null,
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
  v_total bigint;
  v_items jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'contribution.view') then
    raise exception 'Not authorized to view contributions in this group' using errcode = '42501';
  end if;

  select count(*) into v_total
  from public.contribution_setups s
  where s.group_id = p_group_id
    and s.is_system = false
    and (p_contribution_type_id is null or s.contribution_type_id = p_contribution_type_id)
    and (p_is_active is null or s.is_active = p_is_active);

  select coalesce(jsonb_agg(row_to_json(rows.*) order by rows.name), '[]'::jsonb)
  into v_items
  from (
    select id, group_id, contribution_type_id, name, description, schedule_mode, amount_mode,
           fixed_amount, default_due_day, default_due_month_offset,
           penalty_mode, penalty_grace_days, penalty_value, penalty_cap_amount,
           is_active, created_at, updated_at
    from public.contribution_setups s
    where s.group_id = p_group_id
      and s.is_system = false
      and (p_contribution_type_id is null or s.contribution_type_id = p_contribution_type_id)
      and (p_is_active is null or s.is_active = p_is_active)
    order by name
    limit v_limit offset v_offset
  ) rows;

  return jsonb_build_object('items', v_items, 'total_count', v_total, 'limit', v_limit, 'offset', v_offset);
end;
$$;

revoke all on function public.rpc_list_contribution_setups(uuid, uuid, boolean, integer, integer) from public;
grant execute on function public.rpc_list_contribution_setups(uuid, uuid, boolean, integer, integer) to authenticated;
revoke execute on function public.rpc_list_contribution_setups(uuid, uuid, boolean, integer, integer) from anon;

-- ---------------------------------------------------------------------
-- rpc_get_contribution_period — add correction/net totals to the period
-- summary (section 28), on top of 06B's penalty totals.
-- ---------------------------------------------------------------------

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
  v_total_adjustments numeric;
  v_total_waivers numeric;
  v_net_assessed numeric;
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

  select coalesce(sum(cc.assessed_amount) filter (where cc.component_type = 'ADJUSTMENT'), 0),
         coalesce(sum(cc.assessed_amount) filter (where cc.component_type = 'WAIVER'), 0),
         coalesce(sum(cc.assessed_amount), 0)
  into v_total_adjustments, v_total_waivers, v_net_assessed
  from public.member_contribution_charges c
  join public.contribution_charge_components cc on cc.charge_id = c.id
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
    'penalty_charge_count', v_penalty_charge_count,
    'total_adjustments_assessed', v_total_adjustments,
    'total_waivers_assessed', v_total_waivers,
    'net_assessed_total', v_net_assessed
  );
end;
$$;

revoke all on function public.rpc_get_contribution_period(uuid, uuid) from public;
grant execute on function public.rpc_get_contribution_period(uuid, uuid) to authenticated;
revoke execute on function public.rpc_get_contribution_period(uuid, uuid) from anon;

-- ---------------------------------------------------------------------
-- rpc_list_contribution_period_charges — add per-charge
-- adjustment/waiver/opening_balance/net breakdown on top of 06B's
-- penalty fields.
-- ---------------------------------------------------------------------

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
        where cc.charge_id = c.id and cc.component_type = 'ADJUSTMENT'
      ) as adjustment_amount,
      (
        select coalesce(sum(cc.assessed_amount), 0) from public.contribution_charge_components cc
        where cc.charge_id = c.id and cc.component_type = 'WAIVER'
      ) as waiver_amount,
      (
        select coalesce(sum(cc.assessed_amount), 0) from public.contribution_charge_components cc
        where cc.charge_id = c.id and cc.component_type = 'OPENING_BALANCE'
      ) as opening_balance_amount,
      public.contribution_charge_net_assessed(c.id) as total_amount
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
