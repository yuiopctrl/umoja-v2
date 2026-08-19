-- Group membership foundation: public.group_memberships
--
-- IMPORTANT: a "group member" (a person the group tracks, e.g. for future
-- financial obligations) and an authenticated "user" are related but
-- distinct concepts. A Treasurer/Secretary may register a member who has
-- not yet created (or may never create) a Umoja account. Therefore
-- user_id is nullable — see docs/product/member-identity-model.md.

create type public.membership_status as enum ('ACTIVE', 'SUSPENDED', 'EXITED');

create table public.group_memberships (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id),
  user_id uuid references auth.users (id),
  member_number text,
  display_name text not null,
  phone text,
  status public.membership_status not null default 'ACTIVE',
  joined_at date,
  exited_at date,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id),
  updated_at timestamptz not null default now(),
  constraint group_memberships_display_name_not_blank check (btrim(display_name) <> '')
);

comment on table public.group_memberships is
  'A person tracked by a group. user_id is nullable: membership can exist '
  'before the person ever has (or without ever having) an app account. '
  'Never hard-delete a membership that may carry financial history.';

create trigger group_memberships_set_updated_at
  before update on public.group_memberships
  for each row
  execute function public.set_updated_at();

-- user_id is immutable once a row exists (whether it was set at
-- creation or left null). Linking an existing membership to an
-- authenticated user is a controlled future workflow (see
-- docs/product/member-identity-model.md), not a plain UPDATE — without
-- this, an ordinary member.edit permission holder could repoint a
-- membership at an arbitrary user_id and hand them access to the group.
create or replace function public.prevent_membership_user_id_change()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.user_id is distinct from old.user_id then
    raise exception 'group_memberships.user_id cannot be changed by update' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger group_memberships_prevent_user_id_change
  before update on public.group_memberships
  for each row
  execute function public.prevent_membership_user_id_change();

-- member_number is unique within a group, but only when present, and
-- the same member_number may be reused across different groups.
create unique index group_memberships_member_number_unique
  on public.group_memberships (group_id, member_number)
  where member_number is not null;

-- One auth user must not hold more than one ACTIVE membership in the
-- same group.
create unique index group_memberships_user_active_unique
  on public.group_memberships (group_id, user_id)
  where user_id is not null and status = 'ACTIVE';

create index group_memberships_group_id_idx on public.group_memberships (group_id);
create index group_memberships_user_id_idx on public.group_memberships (user_id);
