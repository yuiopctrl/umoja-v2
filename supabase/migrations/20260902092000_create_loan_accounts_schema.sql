-- Prompt 09A: Loan Account schema — one specific member's loan
-- instance (section F). Borrower is `membership_id`, never `user_id`
-- directly (section H) — membership is the group-specific financial
-- identity, exactly as group_memberships.user_id already being
-- nullable-by-design established elsewhere in this project.
--
-- Section E (product snapshot rule): every financial term below is a
-- frozen copy taken from the Loan Product at creation time.
-- loan_product_id is kept for provenance only — schedule calculation
-- and every other financial computation must use these columns, never
-- a live join back to loan_products.

create type public.loan_account_status as enum (
  'DRAFT',
  'SUBMITTED',
  'APPROVED',
  'REJECTED',
  'CANCELLED',
  'DISBURSED',
  'ACTIVE',
  'CLOSED'
);

comment on type public.loan_account_status is
  'Prompt 09A only implements DRAFT (create/edit/cancel) plus the
  terminal CANCELLED state. SUBMITTED/APPROVED/REJECTED/DISBURSED/
  ACTIVE/CLOSED are reserved for later phases (09B approval +
  disbursement, 09C repayment, 09D penalties) — the enum is defined
  now so those phases extend an already-agreed lifecycle rather than
  requiring a later type change.';

-- ---------------------------------------------------------------------
-- Server-generated, tenant-aware loan numbering (section I) — the
-- exact same backing-counter + INSERT ... ON CONFLICT ... DO UPDATE
-- pattern already proven concurrency-safe for member numbers
-- (group_member_number_counters / next_group_member_number).
-- ---------------------------------------------------------------------

create table public.loan_number_counters (
  group_id uuid not null references public.groups (id),
  year integer not null,
  last_number integer not null default 0,
  primary key (group_id, year)
);

comment on table public.loan_number_counters is
  'Backing counter for server-generated loan numbers '
  '(<groups.code>-LN-<year>-<sequence>). Never read/written directly '
  'by clients — only via next_loan_number(), itself only called from '
  'rpc_create_draft_loan_account.';

alter table public.loan_number_counters enable row level security;
revoke all on public.loan_number_counters from anon, authenticated;

create function public.next_loan_number(
  p_group_id uuid,
  p_year integer
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_next integer;
begin
  insert into public.loan_number_counters (group_id, year, last_number)
  values (p_group_id, p_year, 1)
  on conflict (group_id, year)
  do update set last_number = public.loan_number_counters.last_number + 1
  returning last_number into v_next;

  return v_next;
end;
$$;

create function public.generate_loan_number(
  p_group_id uuid,
  p_year integer
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text;
  v_seq integer;
begin
  select code into v_code from public.groups where id = p_group_id;
  if v_code is null then
    raise exception 'Group has no code configured' using errcode = 'P0001';
  end if;

  v_seq := public.next_loan_number(p_group_id, p_year);

  return v_code || '-LN-' || p_year::text || '-' || lpad(v_seq::text, 4, '0');
end;
$$;

revoke all on function public.next_loan_number(uuid, integer) from public, anon, authenticated;
revoke all on function public.generate_loan_number(uuid, integer) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- loan_accounts
-- ---------------------------------------------------------------------

create table public.loan_accounts (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id),
  membership_id uuid not null references public.group_memberships (id),
  loan_product_id uuid not null references public.loan_products (id),

  loan_number text not null,

  -- Frozen terms snapshot (section E) — authoritative for this loan
  -- regardless of any later loan_products edit.
  principal_amount numeric(14, 2) not null,
  interest_rate numeric(7, 4) not null,
  interest_rate_basis public.loan_interest_rate_basis not null,
  interest_method public.loan_interest_method not null,
  term integer not null,
  term_unit public.loan_term_unit not null,
  repayment_frequency public.loan_repayment_frequency not null,

  application_date date not null default current_date,
  proposed_disbursement_date date,
  first_repayment_date date not null,

  status public.loan_account_status not null default 'DRAFT',

  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id),

  constraint loan_accounts_principal_positive check (principal_amount > 0),
  constraint loan_accounts_term_positive check (term > 0),
  constraint loan_accounts_interest_rate_non_negative check (interest_rate >= 0)
);

comment on table public.loan_accounts is
  'One specific member''s loan instance (Prompt 09A). NOT a cash
  transaction and NOT yet a funded receivable — see section A/C/D/Z:
  no cashbook entry, no group-income recognition, and no Financial
  Position impact exists for a loan account until Phase 09B actually
  disburses it. Terms are a frozen snapshot; loan_product_id is
  provenance only.';

create unique index loan_accounts_group_loan_number_unique
  on public.loan_accounts (group_id, loan_number);
create index loan_accounts_group_id_idx on public.loan_accounts (group_id);
create index loan_accounts_membership_id_idx on public.loan_accounts (membership_id);
create index loan_accounts_loan_product_id_idx on public.loan_accounts (loan_product_id);

create trigger loan_accounts_set_updated_at
  before update on public.loan_accounts
  for each row execute function public.set_updated_at();

alter table public.loan_accounts enable row level security;
revoke all on public.loan_accounts from anon, authenticated;

grant select on public.loan_accounts to authenticated;

create policy loan_accounts_select
  on public.loan_accounts
  for select
  to authenticated
  using (public.has_group_permission(group_id, 'loan.view'));
