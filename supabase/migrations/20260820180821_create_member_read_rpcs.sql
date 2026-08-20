-- Prompt 04: Members Management — read APIs.
--
-- The existing schema (public.group_memberships, group_membership_roles,
-- roles) already carries everything a usable member registry needs —
-- id, display_name, member_number, phone, status, joined_at, exited_at,
-- user_id (login-linked indicator), plus roles via
-- group_membership_roles. No new columns/tables are introduced.
--
-- The existing group_memberships_select RLS policy (member.view OR own
-- row) already scopes direct reads correctly, but this feature needs:
-- search across multiple columns, a status filter, deterministic
-- pagination with a total count, a bounded page size, and a per-row
-- roles summary without one round trip per row. Rather than build that
-- client-side against raw PostgREST, this follows the project's
-- established convention (rpc_get_my_context, rpc_create_group, ...)
-- of a controlled read RPC — consistent with "Preferred API shape:
-- rpc_list_group_members / rpc_get_group_member" and with how every
-- other read/write in this schema already goes through an explicit
-- function. No additional index is added for search: ILIKE with a
-- leading wildcard cannot use a plain btree index anyway (would need
-- pg_trgm + GIN to meaningfully accelerate), and at the expected scale
-- of a single vikundi's membership list this is not yet justified —
-- revisit if group sizes grow much larger.
--
-- Role visibility is deliberately gated by `role.view`, separate from
-- `member.view` — a caller with member.view but not role.view (e.g.
-- TREASURER, SECRETARY under the seeded mappings) can see the member
-- list/detail but not role assignments: `roles` is `null` (meaning
-- "not visible to you"), never `[]` (which would misleadingly read as
-- "this member holds no roles"). This mirrors Step 12's "If caller has
-- role.view: show member roles" rule precisely, rather than piggy-
-- backing role visibility on member.view.

-- ---------------------------------------------------------------------
-- rpc_list_group_members(): paginated, searchable, status-filterable
-- member list for one group. Requires member.view. Group isolation is
-- enforced the same way every other mutation RPC in this schema
-- enforces it: has_group_permission(p_group_id, ...) is keyed on
-- auth.uid()'s own membership, so a caller cannot pass an arbitrary
-- group_id they do not belong to and see results — and the row query
-- itself is additionally scoped to gm.group_id = p_group_id.
-- ---------------------------------------------------------------------
create or replace function public.rpc_list_group_members(
  p_group_id uuid,
  p_search text default null,
  p_status public.membership_status default null,
  p_limit integer default 25,
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
  v_limit integer;
  v_offset integer;
  v_search text;
  v_can_view_roles boolean;
  v_total bigint;
  v_items jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'member.view') then
    raise exception 'Not authorized to view members in this group' using errcode = '42501';
  end if;

  v_can_view_roles := public.has_group_permission(p_group_id, 'role.view');

  -- Bounded page size (max 100) and non-negative offset, regardless of
  -- what the client requests.
  v_limit := greatest(1, least(coalesce(p_limit, 25), 100));
  v_offset := greatest(0, coalesce(p_offset, 0));
  v_search := nullif(btrim(coalesce(p_search, '')), '');

  if v_search is not null and char_length(v_search) > 100 then
    raise exception 'Search term too long' using errcode = '22023';
  end if;

  select count(*)
  into v_total
  from public.group_memberships gm
  where gm.group_id = p_group_id
    and (p_status is null or gm.status = p_status)
    and (
      v_search is null
      or gm.display_name ilike '%' || v_search || '%'
      or gm.member_number ilike '%' || v_search || '%'
      or gm.phone ilike '%' || v_search || '%'
    );

  with page as (
    select gm.*
    from public.group_memberships gm
    where gm.group_id = p_group_id
      and (p_status is null or gm.status = p_status)
      and (
        v_search is null
        or gm.display_name ilike '%' || v_search || '%'
        or gm.member_number ilike '%' || v_search || '%'
        or gm.phone ilike '%' || v_search || '%'
      )
    order by gm.display_name asc, gm.id asc
    limit v_limit
    offset v_offset
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'membership_id', page.id,
        'group_id', page.group_id,
        'display_name', page.display_name,
        'member_number', page.member_number,
        'phone', page.phone,
        'status', page.status,
        'joined_at', page.joined_at,
        'exited_at', page.exited_at,
        'created_at', page.created_at,
        'is_login_linked', page.user_id is not null,
        'roles', case
          when v_can_view_roles then coalesce((
            select jsonb_agg(distinct r.code order by r.code)
            from public.group_membership_roles gmr
            join public.roles r on r.id = gmr.role_id
            where gmr.group_membership_id = page.id
          ), '[]'::jsonb)
          else null
        end
      )
      order by page.display_name asc, page.id asc
    ),
    '[]'::jsonb
  )
  into v_items
  from page;

  return jsonb_build_object(
    'items', v_items,
    'total_count', v_total,
    'limit', v_limit,
    'offset', v_offset
  );
end;
$$;

comment on function public.rpc_list_group_members(uuid, text, public.membership_status, integer, integer) is
  'Paginated, searchable member list for one group. Requires '
  'member.view. Search matches display_name/member_number/phone. Page '
  'size is capped at 100. `roles` is null (not []) per row unless the '
  'caller also holds role.view.';

revoke all on function public.rpc_list_group_members(uuid, text, public.membership_status, integer, integer) from public;
revoke execute on function public.rpc_list_group_members(uuid, text, public.membership_status, integer, integer) from anon;
grant execute on function public.rpc_list_group_members(uuid, text, public.membership_status, integer, integer) to authenticated;

-- ---------------------------------------------------------------------
-- rpc_get_group_member(): single member detail, scoped to the target
-- group. Requires member.view. The WHERE clause requires BOTH the
-- membership id and the caller-authorized group_id to match, so a
-- membership belonging to a different group is indistinguishable from
-- a nonexistent one — no existence/data leakage across groups.
-- ---------------------------------------------------------------------
create or replace function public.rpc_get_group_member(
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
  v_can_view_roles boolean;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  perform public.assert_active_profile();

  if not public.has_group_permission(p_group_id, 'member.view') then
    raise exception 'Not authorized to view members in this group' using errcode = '42501';
  end if;

  v_can_view_roles := public.has_group_permission(p_group_id, 'role.view');

  select jsonb_build_object(
    'membership_id', gm.id,
    'group_id', gm.group_id,
    'display_name', gm.display_name,
    'member_number', gm.member_number,
    'phone', gm.phone,
    'status', gm.status,
    'joined_at', gm.joined_at,
    'exited_at', gm.exited_at,
    'created_at', gm.created_at,
    'updated_at', gm.updated_at,
    'is_login_linked', gm.user_id is not null,
    'roles', case
      when v_can_view_roles then coalesce((
        select jsonb_agg(distinct r.code order by r.code)
        from public.group_membership_roles gmr
        join public.roles r on r.id = gmr.role_id
        where gmr.group_membership_id = gm.id
      ), '[]'::jsonb)
      else null
    end
  )
  into v_result
  from public.group_memberships gm
  where gm.id = p_membership_id
    and gm.group_id = p_group_id;

  if v_result is null then
    raise exception 'Member not found in group' using errcode = '22023';
  end if;

  return v_result;
end;
$$;

comment on function public.rpc_get_group_member(uuid, uuid) is
  'Single member detail, scoped to p_group_id. Requires member.view. '
  'A membership belonging to a different group is treated as not '
  'found, never as a permission error that would confirm its '
  'existence. `roles` is null unless the caller also holds role.view.';

revoke all on function public.rpc_get_group_member(uuid, uuid) from public;
revoke execute on function public.rpc_get_group_member(uuid, uuid) from anon;
grant execute on function public.rpc_get_group_member(uuid, uuid) to authenticated;
