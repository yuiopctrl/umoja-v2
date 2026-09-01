-- Prompt 09A: Loan Product + Loan Account + Schedule Foundation.
--
-- This migration creates the group-scoped Loan Product catalog only —
-- reusable lending policy/configuration. A Loan Product is never a
-- member's loan; see 20260902092000_create_loan_accounts_schema.sql
-- for the per-member Loan Account, which snapshots a product's terms
-- at creation time rather than referencing them live (section E).

-- ---------------------------------------------------------------------
-- Permissions (section S). Conservative mapping, matching the exact
-- posture already established for financial_account.*/financial_*
-- permissions in Prompt 08A/08B:
--   ADMIN / TREASURER: full loan-module access.
--   CHAIRPERSON / SECRETARY: view-only across products/loans/schedules.
--   MEMBER: none of the staff-facing loan-module permissions in 09A.
-- ---------------------------------------------------------------------

insert into public.permissions (code, name, description) values
  ('loan_product.view', 'View loan products', 'View the group''s reusable loan product catalog.'),
  ('loan_product.manage', 'Manage loan products', 'Create, edit, activate/deactivate loan products.'),
  ('loan.view', 'View loans', 'View member loan accounts and their terms.'),
  ('loan.create', 'Create loans', 'Create a draft loan account for a member.'),
  ('loan.edit', 'Edit loans', 'Edit a draft loan account''s terms.'),
  ('loan_schedule.view', 'View loan schedules', 'View a loan account''s repayment schedule.'),
  ('loan_schedule.generate', 'Generate loan schedules', 'Generate or regenerate a draft loan account''s repayment schedule.');

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where r.code = 'ADMIN'
  and p.code in (
    'loan_product.view', 'loan_product.manage', 'loan.view', 'loan.create',
    'loan.edit', 'loan_schedule.view', 'loan_schedule.generate'
  )
on conflict do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p
  on p.code in (
    'loan_product.view', 'loan_product.manage', 'loan.view', 'loan.create',
    'loan.edit', 'loan_schedule.view', 'loan_schedule.generate'
  )
where r.code = 'TREASURER';

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p
  on p.code in ('loan_product.view', 'loan.view', 'loan_schedule.view')
where r.code = 'CHAIRPERSON';

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p
  on p.code in ('loan_product.view', 'loan.view', 'loan_schedule.view')
where r.code = 'SECRETARY';

-- MEMBER intentionally gets none of the above — same posture as every
-- other staff-facing treasury permission in this project.

-- ---------------------------------------------------------------------
-- Loan product enums (section C). Deliberately small/closed for 09A —
-- widen only when a later phase genuinely needs it, never speculatively.
-- ---------------------------------------------------------------------

create type public.loan_term_unit as enum (
  'MONTH'
);

create type public.loan_interest_rate_basis as enum (
  'MONTHLY',
  'ANNUAL'
);

create type public.loan_interest_method as enum (
  'FLAT',
  'REDUCING_BALANCE'
);

create type public.loan_repayment_frequency as enum (
  'MONTHLY'
);

-- ---------------------------------------------------------------------
-- loan_products
-- ---------------------------------------------------------------------

create table public.loan_products (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id),
  code text not null,
  name text not null,
  description text,
  is_active boolean not null default true,

  minimum_principal numeric(14, 2) not null,
  maximum_principal numeric(14, 2),

  minimum_term integer not null,
  maximum_term integer not null,
  term_unit public.loan_term_unit not null default 'MONTH',

  interest_rate numeric(7, 4) not null,
  interest_rate_basis public.loan_interest_rate_basis not null,
  interest_method public.loan_interest_method not null,

  repayment_frequency public.loan_repayment_frequency not null default 'MONTHLY',

  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id),

  constraint loan_products_code_not_blank check (btrim(code) <> ''),
  constraint loan_products_name_not_blank check (btrim(name) <> ''),
  constraint loan_products_minimum_principal_positive check (minimum_principal > 0),
  constraint loan_products_maximum_principal_ge_minimum
    check (maximum_principal is null or maximum_principal >= minimum_principal),
  constraint loan_products_minimum_term_positive check (minimum_term > 0),
  constraint loan_products_maximum_term_ge_minimum check (maximum_term >= minimum_term),
  constraint loan_products_interest_rate_non_negative check (interest_rate >= 0)
);

comment on table public.loan_products is
  'Group-scoped reusable lending policy/configuration (Prompt 09A). '
  'Never a member loan itself — see loan_accounts, which snapshots '
  'these terms at creation time. Editing a product never recalculates '
  'or otherwise affects any loan account already created from it '
  '(section E).';

-- Product code is unique within a group, never globally (section D) —
-- case-insensitive, matching the established financial_categories
-- lower(name) convention.
create unique index loan_products_group_code_unique
  on public.loan_products (group_id, lower(code));
create index loan_products_group_id_idx on public.loan_products (group_id);

create trigger loan_products_set_updated_at
  before update on public.loan_products
  for each row execute function public.set_updated_at();

alter table public.loan_products enable row level security;
revoke all on public.loan_products from anon, authenticated;

grant select on public.loan_products to authenticated;

create policy loan_products_select
  on public.loan_products
  for select
  to authenticated
  using (public.has_group_permission(group_id, 'loan_product.view'));
