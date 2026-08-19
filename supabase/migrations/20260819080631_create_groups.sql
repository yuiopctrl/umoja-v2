-- Group/tenant foundation: public.groups
--
-- No financial/business/subscription fields belong here — this is only
-- the tenant identity record. See docs/accounting/invariants.md.

create type public.group_status as enum ('ACTIVE', 'SUSPENDED', 'CLOSED');

create table public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  code text,
  description text,
  status public.group_status not null default 'ACTIVE',
  currency text not null default 'TZS',
  timezone text not null default 'Africa/Dar_es_Salaam',
  accounting_cutover_date date,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id),
  updated_at timestamptz not null default now(),
  constraint groups_name_not_blank check (btrim(name) <> '')
);

comment on table public.groups is
  'A vikundi/tenant. Does not hold financial balances or subscription '
  'fields — those belong to authoritative ledgers/future modules.';

create trigger groups_set_updated_at
  before update on public.groups
  for each row
  execute function public.set_updated_at();

create index groups_status_idx on public.groups (status);
