-- Prompt 05E: server-verified phone + 4-digit PIN authentication.
--
-- The user-facing credential stays a 4-digit PIN, but a raw 4-digit
-- PIN (10,000 possible values) is far too weak to use directly as a
-- Supabase Auth password. The actual Supabase Auth password is a
-- high-entropy value deterministically DERIVED from the PIN
-- (HMAC-SHA256, keyed by a server-only "pepper" secret that never
-- leaves the Edge Function runtime — see `supabase/functions/_shared/
-- pin_derivation.ts` and `setup-pin`/`pin-login`). This migration adds
-- only the narrow, private metadata this scheme needs — never the PIN
-- itself, never a hash of it, and never the derived password:
--
--   - Supabase Auth already stores its own secure hash of the derived
--     password (via `auth.admin.updateUserById`) — this schema does
--     not duplicate that.
--   - `public.user_pin_credentials` exists only to map a phone number
--     to a user id (so `pin-login` has something to look up before any
--     session exists) and to track rate-limit/lockout state. No
--     column in this table can reconstruct the PIN or the password.
--
-- No RLS policies are created — the table is enabled for RLS with zero
-- policies, which is default-deny for every role subject to RLS
-- (anon, authenticated). The only reader/writer is trusted Edge
-- Function code running with the service-role key, which bypasses RLS
-- entirely; the two SECURITY DEFINER functions below exist purely for
-- atomicity (race-free increment-and-maybe-lock) and are themselves
-- revoked from anon/authenticated the same way, as defense in depth
-- with the same "service-role only" intent.

create table public.user_pin_credentials (
  user_id uuid primary key references auth.users (id) on delete cascade,
  phone_e164 text not null unique,
  credential_version integer not null default 1,
  failed_attempts integer not null default 0,
  locked_until timestamptz,
  last_failed_at timestamptz,
  pin_set_at timestamptz not null,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint user_pin_credentials_phone_format check (phone_e164 ~ '^\+255[67]\d{8}$'),
  constraint user_pin_credentials_failed_attempts_non_negative check (failed_attempts >= 0)
);

comment on table public.user_pin_credentials is
  'Private metadata for server-verified phone+PIN login (prompt 05E). '
  'Never stores the PIN, a PIN hash, or the derived internal Supabase '
  'Auth password — only phone->user_id lookup and rate-limit/lockout '
  'state. RLS-enabled with zero policies (default-deny); only '
  'service-role Edge Function code and the SECURITY DEFINER functions '
  'below ever read or write it.';

alter table public.user_pin_credentials enable row level security;
revoke all on public.user_pin_credentials from anon, authenticated;

create trigger user_pin_credentials_set_updated_at
  before update on public.user_pin_credentials
  for each row
  execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- record_pin_login_failure(): atomically increments failed_attempts
-- and, on crossing a multiple of p_lock_threshold, sets locked_until
-- with an escalating duration for repeated lock cycles ("further
-- repeated lock cycles: increase delay reasonably" — capped, so an
-- account is never permanently locked). A single UPDATE ... RETURNING
-- is what makes the increment race-free under concurrent brute-force
-- attempts against the same account — never a read-then-write from
-- the calling Edge Function.
--
-- pin-login only ever calls this for an account that is NOT currently
-- locked (it checks locked_until itself before attempting password
-- verification), so failed_attempts only climbs during a period the
-- caller is actively allowed to keep trying — each additional
-- threshold crossing represents a genuinely new lock cycle, not a
-- retry against an already-locked account.
-- ---------------------------------------------------------------------
create or replace function public.record_pin_login_failure(
  p_user_id uuid,
  p_lock_threshold integer default 5,
  p_base_lock_minutes integer default 5,
  p_max_lock_minutes integer default 60
)
returns table (failed_attempts integer, locked_until timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_failed integer;
  v_cycle integer;
  v_minutes integer;
  v_locked timestamptz;
begin
  update public.user_pin_credentials
  set failed_attempts = public.user_pin_credentials.failed_attempts + 1,
      last_failed_at = now()
  where user_id = p_user_id
  returning public.user_pin_credentials.failed_attempts into v_failed;

  if v_failed is null then
    return;
  end if;

  if p_lock_threshold > 0 and v_failed % p_lock_threshold = 0 then
    v_cycle := v_failed / p_lock_threshold;
    v_minutes := least(p_base_lock_minutes * v_cycle, p_max_lock_minutes);

    update public.user_pin_credentials
    set locked_until = now() + make_interval(mins => v_minutes)
    where user_id = p_user_id
    returning public.user_pin_credentials.locked_until into v_locked;
  else
    select u.locked_until into v_locked
    from public.user_pin_credentials u
    where u.user_id = p_user_id;
  end if;

  failed_attempts := v_failed;
  locked_until := v_locked;
  return next;
end;
$$;

revoke all on function public.record_pin_login_failure(uuid, integer, integer, integer)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- reset_pin_login_failures(): called on a successful pin-login, and
-- from setup-pin (fresh PIN set/reset — both a first-time PIN and a
-- "Forgot PIN" reset must clear any prior lockout, per prompt 05E
-- §20/§38).
-- ---------------------------------------------------------------------
create or replace function public.reset_pin_login_failures(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.user_pin_credentials
  set failed_attempts = 0,
      locked_until = null
  where user_id = p_user_id;
end;
$$;

revoke all on function public.reset_pin_login_failures(uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- rpc_has_pin_credential(): the one narrow read the *client* itself is
-- allowed, and only about the caller's own row — needed so the
-- first-time flow (prompt 05E §7) can decide, right after a fresh OTP
-- verify, whether to show "Create PIN" or continue straight into the
-- app. This does not weaken §4's "no direct client access" — it never
-- exposes a row, only a boolean derived from the caller's own
-- auth.uid(), which reveals nothing about any other account.
-- ---------------------------------------------------------------------
create or replace function public.rpc_has_pin_credential()
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.user_pin_credentials where user_id = auth.uid()
  );
$$;

revoke all on function public.rpc_has_pin_credential() from public;
revoke execute on function public.rpc_has_pin_credential() from anon;
grant execute on function public.rpc_has_pin_credential() to authenticated;
