-- Contribution Engine foundation — obligation ledger schema.
--
-- Implements Prompt 06A: Contribution Type -> Contribution Setup ->
-- Contribution Period -> Member Contribution Charge. Obligation side
-- only — no payments, allocations, wallet, or cashbook entities are
-- created here. Creating an obligation must never create cash
-- movement (docs/accounting/invariants.md).
--
-- There is intentionally NO contribution_series entity.
--
-- Eligibility/back-charge protection reuses
-- public.group_membership_status_history (see the Contribution Engine
-- note in 20260821090000_add_member_rejoin_workflow.sql): a member who
-- exited and later rejoined must never be automatically charged for a
-- period whose eligibility_date falls between the prior exit and the
-- rejoin's effective_at.

-- ---------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------

create type public.contribution_category as enum (
  'GENERAL',
  'SOCIAL',
  'SHARE'
);

comment on type public.contribution_category is
  'Business grouping of a contribution type. Schedule mode (recurring '
  'vs one-off) belongs to Contribution Setup, not category.';

create type public.contribution_accounting_treatment as enum (
  'GROUP_INCOME',
  'PASS_THROUGH',
  'SHARE_CAPITAL',
  'MEMBER_SAVINGS'
);

comment on type public.contribution_accounting_treatment is
  'How a settled contribution is ultimately recognised. MEMBER_SAVINGS '
  'is reserved/deferred: the schema understands the code but normal '
  'contribution type creation must reject it (enforced in '
  'rpc_create_contribution_type, not here, since the schema must still '
  'understand the value).';

create type public.contribution_schedule_mode as enum (
  'MONTHLY',
  'ON_DEMAND',
  'ONE_TIME'
);

create type public.contribution_amount_mode as enum (
  'FIXED',
  'CUSTOM_PER_MEMBER'
);

create type public.contribution_penalty_mode as enum (
  'NONE',
  'FIXED_ONCE',
  'FIXED_RECURRING',
  'PERCENTAGE_ONCE',
  'PERCENTAGE_RECURRING'
);

comment on type public.contribution_penalty_mode is
  'Penalty configuration foundation only. Prompt 06A stores and '
  'validates this configuration and snapshots it into OPEN periods but '
  'never posts a penalty component from it — penalty assessment is '
  'Prompt 06B.';

create type public.contribution_period_status as enum (
  'DRAFT',
  'SCHEDULED',
  'OPEN',
  'CLOSED',
  'CANCELLED'
);

comment on type public.contribution_period_status is
  'DRAFT and SCHEDULED create zero member charges. Only the OPEN '
  'transition posts member_contribution_charges rows. CLOSED and '
  'CANCELLED are terminal; OPEN cannot become CANCELLED.';

create type public.contribution_charge_component_type as enum (
  'BASE',
  'PENALTY'
);

-- ---------------------------------------------------------------------
-- Permissions
-- ---------------------------------------------------------------------

insert into public.permissions (code, name, description) values
  ('contribution.view', 'View contributions', 'View contribution types, setups, periods and charges.'),
  ('contribution.type.manage', 'Manage contribution types', 'Create/edit contribution types.'),
  ('contribution.setup.manage', 'Manage contribution setups', 'Create/edit contribution setups.'),
  ('contribution.period.manage', 'Manage contribution periods', 'Create/edit/cancel DRAFT and SCHEDULED periods.'),
  ('contribution.period.open', 'Open contribution periods', 'Post member charges by opening a period.'),
  ('contribution.period.close', 'Close contribution periods', 'Close an OPEN contribution period.'),
  ('contribution.member_amount.manage', 'Manage member contribution amounts', 'Set per-member amounts for CUSTOM_PER_MEMBER periods before OPEN.'),
  ('contribution.member_exclude', 'Exclude members from contribution periods', 'Exclude an eligible member from a DRAFT/SCHEDULED period.'),
  ('contribution.member_enroll', 'Enroll members into open contribution periods', 'Explicitly enroll a member into an OPEN period.'),
  ('contribution.self_view', 'View own contributions', 'View the caller''s own contribution charges.');

-- ADMIN already receives every permission via the cross-join seeded in
-- 20260819080633_create_roles_and_permissions.sql, but that INSERT
-- already ran — it does not retroactively cover permissions added
-- here, so ADMIN is re-granted explicitly for the new codes.
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where r.code = 'ADMIN'
  and p.code in (
    'contribution.view',
    'contribution.type.manage',
    'contribution.setup.manage',
    'contribution.period.manage',
    'contribution.period.open',
    'contribution.period.close',
    'contribution.member_amount.manage',
    'contribution.member_exclude',
    'contribution.member_enroll',
    'contribution.self_view'
  )
on conflict do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p
  on p.code in (
    'contribution.view',
    'contribution.type.manage',
    'contribution.setup.manage',
    'contribution.period.manage',
    'contribution.period.open',
    'contribution.period.close',
    'contribution.member_amount.manage',
    'contribution.member_exclude',
    'contribution.member_enroll'
  )
where r.code = 'TREASURER';

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p
  on p.code in (
    'contribution.view',
    'contribution.period.open',
    'contribution.period.close'
  )
where r.code = 'CHAIRPERSON';

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p
  on p.code in ('contribution.view')
where r.code = 'SECRETARY';

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p
  on p.code in ('contribution.self_view')
where r.code = 'MEMBER';

-- ---------------------------------------------------------------------
-- contribution_types
-- ---------------------------------------------------------------------

create table public.contribution_types (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id),
  name text not null,
  description text,
  category public.contribution_category not null,
  accounting_treatment public.contribution_accounting_treatment not null,
  is_active boolean not null default true,
  display_order integer not null default 0,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id),
  updated_at timestamptz not null default now(),
  constraint contribution_types_name_not_blank check (btrim(name) <> ''),
  constraint contribution_types_share_requires_share_capital check (
    category <> 'SHARE' or accounting_treatment = 'SHARE_CAPITAL'
  )
);

comment on table public.contribution_types is
  'Business classification of a contribution ("what kind"). No hard '
  'delete — deactivate via is_active instead.';

create unique index contribution_types_group_name_unique
  on public.contribution_types (group_id, name);
create index contribution_types_group_id_idx on public.contribution_types (group_id);

create trigger contribution_types_set_updated_at
  before update on public.contribution_types
  for each row execute function public.set_updated_at();

alter table public.contribution_types enable row level security;
revoke all on public.contribution_types from anon, authenticated;

-- ---------------------------------------------------------------------
-- contribution_setups
-- ---------------------------------------------------------------------

create table public.contribution_setups (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id),
  contribution_type_id uuid not null references public.contribution_types (id),
  name text not null,
  description text,
  schedule_mode public.contribution_schedule_mode not null,
  amount_mode public.contribution_amount_mode not null,
  fixed_amount numeric(14, 2),
  default_due_day integer,
  default_due_month_offset integer,
  penalty_mode public.contribution_penalty_mode not null default 'NONE',
  penalty_grace_days integer,
  penalty_value numeric(14, 2),
  penalty_cap_amount numeric(14, 2),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id),
  updated_at timestamptz not null default now(),
  constraint contribution_setups_name_not_blank check (btrim(name) <> ''),
  constraint contribution_setups_fixed_amount_rule check (
    (amount_mode = 'FIXED' and fixed_amount is not null and fixed_amount > 0)
    or (amount_mode = 'CUSTOM_PER_MEMBER' and fixed_amount is null)
  ),
  constraint contribution_setups_due_day_range check (
    default_due_day is null or (default_due_day between 1 and 31)
  ),
  constraint contribution_setups_due_month_offset_range check (
    default_due_month_offset is null or default_due_month_offset >= 0
  ),
  constraint contribution_setups_penalty_config_rule check (
    (penalty_mode = 'NONE' and penalty_value is null)
    or (penalty_mode <> 'NONE' and penalty_value is not null and penalty_value > 0)
  ),
  constraint contribution_setups_penalty_grace_days_range check (
    penalty_grace_days is null or penalty_grace_days >= 0
  ),
  constraint contribution_setups_penalty_cap_positive check (
    penalty_cap_amount is null or penalty_cap_amount > 0
  )
);

comment on table public.contribution_setups is
  'Reusable rules for how a contribution behaves ("how does it '
  'charge"). Penalty columns are configuration only in Prompt 06A — no '
  'penalty component is ever posted from this table yet.';

create index contribution_setups_group_id_idx on public.contribution_setups (group_id);
create index contribution_setups_type_id_idx on public.contribution_setups (contribution_type_id);

create trigger contribution_setups_set_updated_at
  before update on public.contribution_setups
  for each row execute function public.set_updated_at();

create or replace function public.contribution_setups_check_type_group()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_type_group_id uuid;
begin
  select group_id into v_type_group_id
  from public.contribution_types
  where id = new.contribution_type_id;

  if v_type_group_id is null or v_type_group_id <> new.group_id then
    raise exception 'CONTRIBUTION_TYPE_GROUP_MISMATCH' using errcode = '22023';
  end if;

  return new;
end;
$$;

revoke all on function public.contribution_setups_check_type_group() from public, anon, authenticated;

create trigger contribution_setups_check_type_group
  before insert or update on public.contribution_setups
  for each row execute function public.contribution_setups_check_type_group();

alter table public.contribution_setups enable row level security;
revoke all on public.contribution_setups from anon, authenticated;

-- ---------------------------------------------------------------------
-- contribution_periods
-- ---------------------------------------------------------------------

create table public.contribution_periods (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id),
  contribution_setup_id uuid not null references public.contribution_setups (id),
  label text not null,
  period_start date not null,
  period_end date not null,
  obligation_date date not null,
  eligibility_date date not null,
  due_date date not null,
  status public.contribution_period_status not null default 'DRAFT',
  scheduled_open_date date,

  opened_at timestamptz,
  opened_by uuid references auth.users (id),
  closed_at timestamptz,
  closed_by uuid references auth.users (id),
  cancelled_at timestamptz,
  cancelled_by uuid references auth.users (id),

  -- Configuration snapshot, frozen at OPEN. Later edits to the type or
  -- setup must never rewrite an already-OPEN period's historical
  -- meaning. Null while DRAFT/SCHEDULED.
  snapshot_type_name text,
  snapshot_category public.contribution_category,
  snapshot_accounting_treatment public.contribution_accounting_treatment,
  snapshot_setup_name text,
  snapshot_schedule_mode public.contribution_schedule_mode,
  snapshot_amount_mode public.contribution_amount_mode,
  snapshot_fixed_amount numeric(14, 2),
  snapshot_penalty_mode public.contribution_penalty_mode,
  snapshot_penalty_grace_days integer,
  snapshot_penalty_value numeric(14, 2),
  snapshot_penalty_cap_amount numeric(14, 2),

  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id),
  updated_at timestamptz not null default now(),

  constraint contribution_periods_label_not_blank check (btrim(label) <> ''),
  constraint contribution_periods_dates_order check (period_start <= period_end)
);

comment on table public.contribution_periods is
  'One concrete obligation cycle/event. DRAFT and SCHEDULED create no '
  'charges — only the OPEN transition (rpc_open_contribution_period) '
  'posts member_contribution_charges, and it snapshots type/setup '
  'configuration into the snapshot_* columns so later edits cannot '
  'rewrite posted history.';

create index contribution_periods_group_id_idx on public.contribution_periods (group_id);
create index contribution_periods_setup_id_idx on public.contribution_periods (contribution_setup_id);
create index contribution_periods_status_idx on public.contribution_periods (status);

create trigger contribution_periods_set_updated_at
  before update on public.contribution_periods
  for each row execute function public.set_updated_at();

alter table public.contribution_periods enable row level security;
revoke all on public.contribution_periods from anon, authenticated;

-- ---------------------------------------------------------------------
-- contribution_period_member_amounts (CUSTOM_PER_MEMBER pre-open config)
-- ---------------------------------------------------------------------

create table public.contribution_period_member_amounts (
  id uuid primary key default gen_random_uuid(),
  period_id uuid not null references public.contribution_periods (id),
  group_id uuid not null references public.groups (id),
  membership_id uuid not null references public.group_memberships (id),
  amount numeric(14, 2) not null,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id),
  updated_at timestamptz not null default now(),
  constraint contribution_period_member_amounts_positive check (amount > 0),
  unique (period_id, membership_id)
);

comment on table public.contribution_period_member_amounts is
  'Per-member amount configuration for CUSTOM_PER_MEMBER periods. Only '
  'editable while the period is DRAFT or SCHEDULED (enforced in the '
  'managing RPC — there is no direct client grant on this table).';

create index contribution_period_member_amounts_period_idx
  on public.contribution_period_member_amounts (period_id);

create trigger contribution_period_member_amounts_set_updated_at
  before update on public.contribution_period_member_amounts
  for each row execute function public.set_updated_at();

alter table public.contribution_period_member_amounts enable row level security;
revoke all on public.contribution_period_member_amounts from anon, authenticated;

-- ---------------------------------------------------------------------
-- contribution_period_member_exclusions
-- ---------------------------------------------------------------------

create table public.contribution_period_member_exclusions (
  id uuid primary key default gen_random_uuid(),
  period_id uuid not null references public.contribution_periods (id),
  group_id uuid not null references public.groups (id),
  membership_id uuid not null references public.group_memberships (id),
  reason text,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id),
  unique (period_id, membership_id)
);

comment on table public.contribution_period_member_exclusions is
  'Pre-open exclusion: no obligation is ever posted for this member in '
  'this period. Distinct from a future waiver (obligation existed and '
  'was later forgiven) — waivers are not implemented in Prompt 06A. '
  'Only meaningful while the period is DRAFT/SCHEDULED; once OPEN the '
  'eligibility roster is historical fact and exclusions cannot change.';

create index contribution_period_member_exclusions_period_idx
  on public.contribution_period_member_exclusions (period_id);

alter table public.contribution_period_member_exclusions enable row level security;
revoke all on public.contribution_period_member_exclusions from anon, authenticated;

-- ---------------------------------------------------------------------
-- member_contribution_charges
-- ---------------------------------------------------------------------

create table public.member_contribution_charges (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id),
  period_id uuid not null references public.contribution_periods (id),
  contribution_setup_id uuid not null references public.contribution_setups (id),
  membership_id uuid not null references public.group_memberships (id),

  member_number_snapshot text not null,
  member_name_snapshot text not null,

  effective_at date not null,
  due_date date not null,

  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id),

  unique (period_id, membership_id)
);

comment on table public.member_contribution_charges is
  'The posted obligation for one member for one period. Immutable once '
  'created — no paid_amount, no cash/receipt reference, no financial '
  'account. Only rpc_open_contribution_period and '
  'rpc_enroll_member_in_contribution_period (both SECURITY DEFINER) '
  'ever write here; there is no client grant at all.';

create index member_contribution_charges_group_id_idx on public.member_contribution_charges (group_id);
create index member_contribution_charges_period_id_idx on public.member_contribution_charges (period_id);
create index member_contribution_charges_membership_id_idx on public.member_contribution_charges (membership_id);

alter table public.member_contribution_charges enable row level security;
revoke all on public.member_contribution_charges from anon, authenticated;

-- ---------------------------------------------------------------------
-- contribution_charge_components
-- ---------------------------------------------------------------------

create table public.contribution_charge_components (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id),
  charge_id uuid not null references public.member_contribution_charges (id),
  component_type public.contribution_charge_component_type not null,
  assessed_amount numeric(14, 2) not null,
  effective_at date not null,
  sequence integer not null default 1,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id),
  constraint contribution_charge_components_amount_positive check (assessed_amount > 0)
);

comment on table public.contribution_charge_components is
  'Monetary components of a charge. Prompt 06A OPEN creates exactly '
  'one BASE component per charge. PENALTY components are posted by '
  'Prompt 06B only. No allocations exist yet.';

create unique index contribution_charge_components_one_base_per_charge
  on public.contribution_charge_components (charge_id)
  where component_type = 'BASE';
create index contribution_charge_components_charge_id_idx
  on public.contribution_charge_components (charge_id);

alter table public.contribution_charge_components enable row level security;
revoke all on public.contribution_charge_components from anon, authenticated;

-- ---------------------------------------------------------------------
-- Shared helper functions
-- ---------------------------------------------------------------------

create or replace function public.contribution_compute_due_date(
  p_period_start date,
  p_month_offset integer,
  p_day integer
)
returns date
language sql
immutable
set search_path = ''
as $$
  select (
    (date_trunc('month', p_period_start) + make_interval(months => coalesce(p_month_offset, 0)))::date
    + (
        least(
          coalesce(p_day, 1),
          extract(
            day from (
              (date_trunc('month', p_period_start) + make_interval(months => coalesce(p_month_offset, 0) + 1))::date
              - 1
            )
          )::integer
        ) - 1
      )
  );
$$;

comment on function public.contribution_compute_due_date(date, integer, integer) is
  'Derives a due date from a period start date, a month offset and a '
  'target day-of-month, capping the day at the last valid day of the '
  'resulting month (e.g. day 31 in February -> the 28th/29th).';

revoke all on function public.contribution_compute_due_date(date, integer, integer) from public;
grant execute on function public.contribution_compute_due_date(date, integer, integer) to authenticated;
revoke execute on function public.contribution_compute_due_date(date, integer, integer) from anon;

create or replace function public.contribution_period_eligible_memberships(p_period_id uuid)
returns table (
  membership_id uuid,
  group_id uuid,
  member_number text,
  display_name text
)
language sql
stable
security definer
set search_path = ''
as $$
  select gm.id, gm.group_id, gm.member_number, gm.display_name
  from public.contribution_periods cp
  join public.group_memberships gm on gm.group_id = cp.group_id
  where cp.id = p_period_id
    and gm.status = 'ACTIVE'
    and (gm.joined_at is null or gm.joined_at <= cp.eligibility_date)
    and not exists (
      select 1
      from public.contribution_period_member_exclusions ex
      where ex.period_id = cp.id
        and ex.membership_id = gm.id
    )
    and not exists (
      -- A member who was EXITED and later rejoined must not be
      -- automatically back-charged for a period whose eligibility
      -- falls inside the window they were exited. See the
      -- Contribution Engine note in
      -- 20260821090000_add_member_rejoin_workflow.sql.
      select 1
      from public.group_membership_status_history h
      where h.group_membership_id = gm.id
        and h.action = 'REJOIN'
        and h.previous_exited_at is not null
        and h.previous_exited_at <= cp.eligibility_date
        and h.effective_at > cp.eligibility_date
    );
$$;

comment on function public.contribution_period_eligible_memberships(uuid) is
  'Server-authoritative eligibility roster for a period: ACTIVE '
  'members who had joined by eligibility_date, minus explicit pre-open '
  'exclusions, minus members who were EXITED for a window covering '
  'eligibility_date and later rejoined. SECURITY DEFINER because it is '
  'used by preview/open RPCs regardless of the caller''s own row-level '
  'visibility into group_memberships.';

revoke all on function public.contribution_period_eligible_memberships(uuid) from public, anon, authenticated;
