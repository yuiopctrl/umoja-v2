-- Prompt 08B: sensible default financial categories (section 6),
-- provided as an explicit, idempotent RPC rather than a hook into
-- rpc_create_group — that RPC is foundational identity/tenancy plumbing
-- from an earlier, already-locked phase, and category seeding is not
-- essential to group creation succeeding. A treasurer/admin can call
-- this once (Flutter surfaces it as an explicit action when a group has
-- no categories yet of a given type) to populate a standard starting
-- set; it never overwrites/duplicates categories that already exist
-- (on conflict do nothing against the same unique index every other
-- category insert is subject to), so it is always safe to call again.

create or replace function public.rpc_seed_default_financial_categories(
  p_group_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_inserted integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'financial_account.manage') then
    raise exception 'Not authorized to manage financial categories in this group' using errcode = '42501';
  end if;

  with defaults (name, category_type, system_code) as (
    values
      ('Riba ya Benki', 'INCOME'::public.financial_category_type, 'BANK_INTEREST'),
      ('Mchango wa Hisani', 'INCOME'::public.financial_category_type, 'DONATION'),
      ('Mapato Mengineyo', 'INCOME'::public.financial_category_type, 'MISC_INCOME'),
      ('Usafiri', 'EXPENSE'::public.financial_category_type, 'TRANSPORT'),
      ('Ada za Benki', 'EXPENSE'::public.financial_category_type, 'BANK_CHARGES'),
      ('Vifaa vya Ofisi', 'EXPENSE'::public.financial_category_type, 'STATIONERY'),
      ('Matumizi Mengineyo', 'EXPENSE'::public.financial_category_type, 'MISC_EXPENSE')
  ),
  inserted as (
    insert into public.financial_categories (group_id, name, category_type, system_code, created_by, updated_by)
    select p_group_id, d.name, d.category_type, d.system_code, v_uid, v_uid
    from defaults d
    on conflict (group_id, category_type, lower(name)) do nothing
    returning 1
  )
  select count(*) into v_inserted from inserted;

  return jsonb_build_object('inserted_count', v_inserted);
end;
$$;

comment on function public.rpc_seed_default_financial_categories(uuid) is
  'Idempotently populates a group''s financial_categories with a
  standard starting set (bank interest, donation, misc income;
  transport, bank charges, stationery, misc expense) — never
  duplicates or overwrites existing categories (on conflict do
  nothing). Safe to call more than once; only ever inserts what is
  still missing.';

revoke all on function public.rpc_seed_default_financial_categories(uuid) from public;
grant execute on function public.rpc_seed_default_financial_categories(uuid) to authenticated;
revoke execute on function public.rpc_seed_default_financial_categories(uuid) from anon;
