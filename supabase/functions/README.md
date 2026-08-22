# Edge Functions

Supabase Edge Functions live here. Controlled financial mutations that
need logic beyond RLS/SQL are implemented as transactional database
functions/RPCs first (see
[docs/database/conventions.md](../../docs/database/conventions.md));
Edge Functions are added only when that is not sufficient — e.g. a
third-party HTTP integration that cannot be called from Postgres.

## `send-sms-hook`

Supabase Auth's Send SMS HTTP Hook, delivering phone-OTP SMS through
NextSMS. See
[docs/product/authentication.md](../../docs/product/authentication.md)
for the full architecture, required secrets, and deployment/dashboard
configuration steps. This hook is authentication-only — it is not the
general Umoja notification/messaging engine.

## `setup-pin` / `pin-login` (prompt 05E)

Server-verified phone + 4-digit PIN authentication — the normal
returning-login mechanism, replacing OTP for that case. See
[docs/product/authentication.md](../../docs/product/authentication.md)
for the full design (why a raw 4-digit PIN is never used as the actual
Supabase Auth password, the derived-password scheme, rate limiting,
and the no-enumeration guarantees).

- **`setup-pin`** (authenticated) — after a valid OTP verify, creates
  or replaces the caller's PIN credential.
- **`pin-login`** (public, no session yet) — the returning-login call:
  phone + PIN in, a genuine Supabase Auth session out.

Both depend on `_shared/` (phone normalization mirroring the Flutter
client's rules, PIN derivation, config/secret loading, safe logging)
and on `public.user_pin_credentials` plus its two SECURITY DEFINER
helper functions (see migration
`20260822090000_create_user_pin_credentials.sql`) — never a raw PIN or
the derived password anywhere in the database.

## Running the Edge Function test suite

```sh
deno test --allow-env --no-check supabase/functions/
```

`--no-check` is required: `@supabase/supabase-js`'s esm.sh type
declarations transitively reference `npm:@types/node`, which this
repo's bare Deno setup (no `deno.json`/`node_modules`) cannot resolve
for type-checking alone — the code still runs and is still fully type
correct at authoring time; only `tsc`'s resolution of that one
unrelated type dependency fails. This mirrors the existing
`send-sms-hook` precedent of Deno tooling being available locally but
not part of this repo's own toolchain/CI.
