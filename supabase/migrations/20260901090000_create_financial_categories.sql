-- Prompt 08B: Financial Operations, Cashbook, Reconciliation & Financial
-- Position — financial_categories.
--
-- Audit of 08A/Prompt 07 before adding anything (see
-- docs/product/financial_operations.md for the full write-up):
--   - financial_accounts / financial_account_entries already exist
--     (CASH/BANK/MOBILE_MONEY; INFLOW/OUTFLOW/TRANSFER_IN/TRANSFER_OUT),
--     with a derived-only balance (financial_account_balance()) and a
--     reversal-safe, polymorphic source_type/source_id + reverses_entry_id
--     extension point already designed for exactly this phase.
--   - Prompt 07 already posts source_type = 'PAYMENT' / 'PAYMENT_REVERSAL'
--     / 'TRANSFER' / 'OPENING_BALANCE' through financial_account_post_entry
--     — this migration continues that SAME classification mechanism
--     (source_type) rather than inventing a parallel column: 08B adds
--     'MANUAL_INCOME', 'EXPENSE', 'MANUAL_INCOME_REVERSAL',
--     'EXPENSE_REVERSAL', 'FINANCIAL_ADJUSTMENT' as new source_type
--     values, each with a source_id pointing at the new tables below.
--   - contribution_types.accounting_treatment (GROUP_INCOME/PASS_THROUGH/
--     SHARE_CAPITAL/MEMBER_SAVINGS, 06A) is permanently locked by
--     rpc_update_contribution_type the moment any period reaches OPEN/
--     CLOSED (contribution_type_has_posted_period()) — so a live join
--     from payment_allocations -> member_contribution_charges ->
--     contribution_setups -> contribution_types is safe for financial
--     reporting: a contribution type's treatment can never retroactively
--     change once a payment could possibly have been allocated against
--     it. No new snapshot column is required for this (see
--     rpc_get_financial_position in a later migration).
--
-- financial_categories: group-scoped, INCOME|EXPENSE typed labels for
-- manual postings (section 6). Soft-deactivate only (is_active) — a
-- category is never hard-deleted, so a historical manual entry's
-- category_id reference never dangles.

create type public.financial_category_type as enum (
  'INCOME',
  'EXPENSE'
);

create table public.financial_categories (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id),
  name text not null,
  category_type public.financial_category_type not null,
  system_code text,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id),
  constraint financial_categories_name_not_blank check (btrim(name) <> '')
);

comment on table public.financial_categories is
  'Group-scoped INCOME/EXPENSE labels for manual cashbook postings
  (Prompt 08B). No hard delete — deactivate via is_active; a deactivated
  category cannot be used for new postings but historical
  financial_manual_entries.category_id references remain intact
  forever.';

create unique index financial_categories_group_type_name_unique
  on public.financial_categories (group_id, category_type, lower(name));
create index financial_categories_group_id_idx on public.financial_categories (group_id);

create trigger financial_categories_set_updated_at
  before update on public.financial_categories
  for each row execute function public.set_updated_at();

alter table public.financial_categories enable row level security;
revoke all on public.financial_categories from anon, authenticated;

grant select on public.financial_categories to authenticated;

create policy financial_categories_select
  on public.financial_categories
  for select
  to authenticated
  using (public.has_group_permission(group_id, 'financial_account.view'));

-- ---------------------------------------------------------------------
-- rpc_create_financial_category / rpc_update_financial_category /
-- rpc_list_financial_categories — gated by financial_account.manage,
-- the same permission that already governs financial-account setup
-- (creating accounts, renaming, activating/deactivating). Categories are
-- part of the same "how the treasury is organized" surface, not a new
-- operational concern deserving its own permission.
-- ---------------------------------------------------------------------

create or replace function public.rpc_create_financial_category(
  p_group_id uuid,
  p_name text,
  p_category_type public.financial_category_type,
  p_description text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'financial_account.manage') then
    raise exception 'Not authorized to manage financial categories in this group' using errcode = '42501';
  end if;

  if p_name is null or btrim(p_name) = '' then
    raise exception 'Financial category name is required' using errcode = '22023';
  end if;

  insert into public.financial_categories (group_id, name, category_type, description, created_by, updated_by)
  values (p_group_id, btrim(p_name), p_category_type, p_description, v_uid, v_uid)
  returning id into v_id;

  select jsonb_build_object(
    'id', id, 'group_id', group_id, 'name', name, 'category_type', category_type,
    'system_code', system_code, 'description', description, 'is_active', is_active,
    'created_at', created_at, 'updated_at', updated_at
  )
  into v_result
  from public.financial_categories
  where id = v_id;

  return v_result;
end;
$$;

revoke all on function public.rpc_create_financial_category(uuid, text, public.financial_category_type, text) from public;
grant execute on function public.rpc_create_financial_category(uuid, text, public.financial_category_type, text) to authenticated;
revoke execute on function public.rpc_create_financial_category(uuid, text, public.financial_category_type, text) from anon;

create or replace function public.rpc_update_financial_category(
  p_group_id uuid,
  p_category_id uuid,
  p_name text default null,
  p_description text default null,
  p_is_active boolean default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_category record;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'financial_account.manage') then
    raise exception 'Not authorized to manage financial categories in this group' using errcode = '42501';
  end if;

  select * into v_category from public.financial_categories where id = p_category_id for update;
  if v_category.group_id is null or v_category.group_id <> p_group_id then
    raise exception 'Financial category not found in group' using errcode = '22023';
  end if;

  if p_name is not null and btrim(p_name) = '' then
    raise exception 'Financial category name is required' using errcode = '22023';
  end if;

  update public.financial_categories
  set
    name = coalesce(nullif(btrim(p_name), ''), name),
    description = coalesce(p_description, description),
    is_active = coalesce(p_is_active, is_active),
    updated_by = v_uid
  where id = p_category_id;

  select jsonb_build_object(
    'id', id, 'group_id', group_id, 'name', name, 'category_type', category_type,
    'system_code', system_code, 'description', description, 'is_active', is_active,
    'created_at', created_at, 'updated_at', updated_at
  )
  into v_result
  from public.financial_categories
  where id = p_category_id;

  return v_result;
end;
$$;

revoke all on function public.rpc_update_financial_category(uuid, uuid, text, text, boolean) from public;
grant execute on function public.rpc_update_financial_category(uuid, uuid, text, text, boolean) to authenticated;
revoke execute on function public.rpc_update_financial_category(uuid, uuid, text, text, boolean) from anon;

create or replace function public.rpc_list_financial_categories(
  p_group_id uuid,
  p_category_type public.financial_category_type default null,
  p_is_active boolean default null
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_items jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'financial_account.view') then
    raise exception 'Not authorized to view financial categories in this group' using errcode = '42501';
  end if;

  select coalesce(jsonb_agg(row_to_json(rows.*) order by rows.category_type, rows.name), '[]'::jsonb)
  into v_items
  from (
    select id, group_id, name, category_type, system_code, description, is_active, created_at, updated_at
    from public.financial_categories
    where group_id = p_group_id
      and (p_category_type is null or category_type = p_category_type)
      and (p_is_active is null or is_active = p_is_active)
  ) rows;

  return jsonb_build_object('items', v_items);
end;
$$;

revoke all on function public.rpc_list_financial_categories(uuid, public.financial_category_type, boolean) from public;
grant execute on function public.rpc_list_financial_categories(uuid, public.financial_category_type, boolean) to authenticated;
revoke execute on function public.rpc_list_financial_categories(uuid, public.financial_category_type, boolean) from anon;
