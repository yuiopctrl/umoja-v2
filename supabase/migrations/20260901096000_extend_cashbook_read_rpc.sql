-- Prompt 08B: cashbook read model (sections 20-21).
--
-- Extends the existing rpc_list_financial_account_entries (08A) — same
-- function name, new filter params appended at the end with defaults,
-- so every existing caller keeps working unchanged. Adds:
--   - date range / direction / source_type / category_id filters
--   - enough joined context for a UI row to explain itself without any
--     raw enum: payment receipt_number, manual-entry category_name +
--     entry status, adjustment reason, transfer counterparty (already
--     existed from 08A-UAT-FIX-03).
--
-- source_type is the authoritative classification key (section 3) —
-- no new classification column was added; this migration reuses the
-- polymorphic source_type/source_id architecture 08A already shipped
-- and Prompt 07 already populated ('PAYMENT', 'PAYMENT_REVERSAL',
-- 'TRANSFER', 'OPENING_BALANCE'), now joined outward per source_type
-- to resolve display context instead of inventing a duplicate column.

-- Adding new parameters changes the function's argument-type signature
-- — CREATE OR REPLACE only replaces a function whose argument list is
-- byte-for-byte identical, so without this DROP the old 4-argument
-- overload would remain callable side-by-side with the new 9-argument
-- one, making every existing 2/3/4-arg call site ambiguous (Postgres
-- cannot choose a "best candidate" between them).
drop function if exists public.rpc_list_financial_account_entries(uuid, uuid, integer, integer);

create or replace function public.rpc_list_financial_account_entries(
  p_group_id uuid,
  p_account_id uuid,
  p_limit integer default 10,
  p_offset integer default 0,
  p_date_from date default null,
  p_date_to date default null,
  p_entry_type public.financial_account_entry_type default null,
  p_source_type text default null,
  p_category_id uuid default null
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
  v_account_group_id uuid;
  v_total bigint;
  v_items jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'financial_account.view') then
    raise exception 'Not authorized to view financial accounts in this group' using errcode = '42501';
  end if;

  select group_id into v_account_group_id from public.financial_accounts where id = p_account_id;
  if v_account_group_id is null or v_account_group_id <> p_group_id then
    raise exception 'Financial account not found in group' using errcode = '22023';
  end if;

  select count(*) into v_total
  from public.financial_account_entries e
  where e.financial_account_id = p_account_id
    and (p_date_from is null or e.effective_at >= p_date_from)
    and (p_date_to is null or e.effective_at <= p_date_to)
    and (p_entry_type is null or e.entry_type = p_entry_type)
    and (p_source_type is null or e.source_type = p_source_type)
    and (
      p_category_id is null
      or exists (
        select 1 from public.financial_manual_entries me
        where me.id = e.source_id and me.category_id = p_category_id
      )
    );

  select coalesce(jsonb_agg(row_to_json(rows.*) order by rows.effective_at desc, rows.created_at desc), '[]'::jsonb)
  into v_items
  from (
    select
      e.id as entry_id, e.entry_type, e.amount, e.effective_at, e.description,
      e.reference, e.transfer_reference, e.source_type, e.source_id,
      e.reverses_entry_id, e.created_at, e.created_by,
      counterparty.id as counterparty_account_id,
      counterparty.name as counterparty_account_name,
      pay.receipt_number as payment_receipt_number,
      me.category_id as manual_entry_category_id,
      cat.name as manual_entry_category_name,
      me.status::text as manual_entry_status,
      adj.reason as adjustment_reason
    from public.financial_account_entries e
    left join public.financial_account_entries pair
      on pair.transfer_reference = e.transfer_reference
      and pair.financial_account_id <> e.financial_account_id
      and e.transfer_reference is not null
    left join public.financial_accounts counterparty
      on counterparty.id = pair.financial_account_id
    left join public.payments pay
      on e.source_type in ('PAYMENT', 'PAYMENT_REVERSAL') and pay.id = e.source_id
    left join public.financial_manual_entries me
      on e.source_type in ('MANUAL_INCOME', 'EXPENSE', 'MANUAL_INCOME_REVERSAL', 'EXPENSE_REVERSAL')
      and me.id = e.source_id
    left join public.financial_categories cat on cat.id = me.category_id
    left join public.financial_adjustments adj
      on e.source_type = 'FINANCIAL_ADJUSTMENT' and adj.id = e.source_id
    where e.financial_account_id = p_account_id
      and (p_date_from is null or e.effective_at >= p_date_from)
      and (p_date_to is null or e.effective_at <= p_date_to)
      and (p_entry_type is null or e.entry_type = p_entry_type)
      and (p_source_type is null or e.source_type = p_source_type)
      and (p_category_id is null or me.category_id = p_category_id)
    order by e.effective_at desc, e.created_at desc
    limit v_limit offset v_offset
  ) rows;

  return jsonb_build_object('items', v_items, 'total_count', v_total, 'limit', v_limit, 'offset', v_offset);
end;
$$;

comment on function public.rpc_list_financial_account_entries(uuid, uuid, integer, integer, date, date, public.financial_account_entry_type, text, uuid) is
  'Paginated, filterable cashbook for one account (Prompt 08A, extended
  08B). source_type is the authoritative economic classification
  (PAYMENT/PAYMENT_REVERSAL/MANUAL_INCOME/EXPENSE/
  MANUAL_INCOME_REVERSAL/EXPENSE_REVERSAL/TRANSFER/OPENING_BALANCE/
  FINANCIAL_ADJUSTMENT) — direction (entry_type) and classification
  (source_type) are deliberately separate columns, never overloaded
  into one. payment_receipt_number/manual_entry_category_name/
  manual_entry_status/adjustment_reason/counterparty_account_* are all
  resolved server-side so a UI row never shows a raw enum or needs a
  second round-trip.';

revoke all on function public.rpc_list_financial_account_entries(uuid, uuid, integer, integer, date, date, public.financial_account_entry_type, text, uuid) from public;
grant execute on function public.rpc_list_financial_account_entries(uuid, uuid, integer, integer, date, date, public.financial_account_entry_type, text, uuid) to authenticated;
revoke execute on function public.rpc_list_financial_account_entries(uuid, uuid, integer, integer, date, date, public.financial_account_entry_type, text, uuid) from anon;
