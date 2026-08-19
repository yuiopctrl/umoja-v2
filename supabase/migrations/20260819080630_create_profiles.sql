-- Identity foundation: public.profiles
--
-- profiles.id is always equal to auth.users.id. This table holds
-- application-facing profile metadata only; it never stores passwords,
-- PINs, or other authentication secrets — those remain in Supabase Auth.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  phone text,
  email text,
  avatar_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is
  'Application-facing profile metadata for an authenticated user. '
  'profiles.id == auth.users.id. Does not store authentication secrets.';

-- Reusable updated_at maintenance trigger function, used by this and
-- later tables in this migration set.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row
  execute function public.set_updated_at();

-- Automatic profile creation for new auth.users rows.
--
-- SECURITY DEFINER is required because this trigger fires on auth.users,
-- which the invoking role does not own. The function only ever inserts a
-- row keyed on NEW.id (the just-created auth user), never on
-- caller-supplied input, so it cannot be used to create/overwrite an
-- arbitrary profile. It is idempotent (ON CONFLICT DO NOTHING) and never
-- raises on missing optional metadata, so it cannot fail signup.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.profiles (id, full_name, email)
  values (
    new.id,
    nullif(btrim(coalesce(new.raw_user_meta_data ->> 'full_name', '')), ''),
    new.email
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_user();
