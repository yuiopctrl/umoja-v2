# Authentication

Umoja v2's authentication is **phone number + Supabase Auth** — there
is no email/password or Google/Apple login. Since prompt 05E, there
are two distinct mechanisms, both verified entirely server-side
through genuine Supabase Auth (never a client-only/local check):

- **OTP** (Supabase Auth's SMS OTP flow) — used only for **initial
  verification** (first-time sign-in/self-service account creation)
  and **PIN recovery** ("Umesahau PIN?"). It is never the normal
  returning-login path.
- **Phone + 4-digit PIN** (`setup-pin`/`pin-login` Edge Functions) —
  the **normal returning-login path**. The PIN is never stored,
  never compared, and never used as a Supabase Auth password
  directly on the client or in the database; see [Server-side PIN
  authentication](#server-side-pin-authentication-prompt-05e) below.

A Supabase session is the only authoritative identity/authorization
signal — the client-side router (`route_guard.dart`) is UX/navigation
guidance only; RLS and `SECURITY DEFINER` RPCs remain what's actually
authoritative (see [Route guards vs.
authorization](#route-guards-vs-authorization)).

## Phone OTP

- Flutter never talks to the Supabase Auth SDK directly — `AuthRepository`
  (`lib/features/auth/data/`) is the only abstraction UI/controllers use,
  backed by `SupabaseAuthRepository` in production and a fake in tests.
- `sendOtp(phone)` calls `signInWithOtp(phone: ...)`. Self-service account
  creation is allowed: an unrecognized phone number creates a new
  Supabase-authenticated user (`shouldCreateUser` defaults to `true`).
  No `auth.users` row is ever created via SQL or a service-role key.
- `verifyOtp(phone, otp)` calls `verifyOTP(phone: ..., token: ..., type:
  OtpType.sms)`. On success, Supabase Auth persists the session itself;
  Flutter never stores `access_token`/`refresh_token` in
  `SharedPreferences` or anywhere else.
- Phone numbers are normalized client-side before ever reaching Supabase,
  by `TanzaniaPhoneNumber` (`lib/core/utils/tanzania_phone_number.dart`) —
  a small, purpose-built normalizer for Umoja's initial Tanzania market,
  not a general international phone library. It accepts `0712345678`,
  `712345678`, `255712345678`, and `+255712345678` (with benign
  spaces/hyphens/parentheses stripped) and normalizes all of them to
  E.164 (`+255712345678`). Non-mobile-range, wrong-length, or non-digit
  input is rejected with a clear message before any network call.
- Auth failures are mapped to a small `AuthFailureType` enum
  (`invalidPhone`, `invalidOtp`, `otpExpired`, `tooManyRequests`,
  `network`, `unexpected`) with a safe, user-presentable message —
  see `supabase_auth_repository.dart`. Raw exception text/stack traces
  are logged via the existing `AppLogger`, never shown to the user. The
  exact classification is heuristic (Supabase error codes/status where
  available, message-content fallback otherwise) since it could not be
  exhaustively verified without a live SMS provider in this environment
  — see [Local manual testing](#local-manual-testing-status) below.
- Resend has a client-side ~60s cooldown for UX only — it does not
  replace Supabase/the SMS provider's own rate limiting, which remains
  authoritative. The cooldown countdown is driven by a `Timer.periodic`
  owned by `OtpVerifyScreen`'s state and cancelled in `dispose()`, so it
  never outlives the screen.

## Send SMS Hook (NextSMS)

OTP delivery is: **Supabase Auth → Send SMS Hook → `send-sms-hook` Edge
Function → NextSMS**. Supabase Auth calls this hook synchronously
whenever it needs to deliver an OTP SMS, and the hook calls NextSMS's
single-SMS API synchronously in turn — no queueing, since Supabase's
HTTP Auth Hooks must complete quickly and Supabase itself is what
ultimately reports OTP delivery to the client.

- **Code**: `supabase/functions/send-sms-hook/`. `index.ts` is the
  HTTP entry point; provider-call logic (`nextsms.ts`), phone
  formatting (`phone.ts`), config loading (`config.ts`), the message
  body (`message.ts`), and safe logging (`logger.ts`) are separated
  into individually testable modules. `handleRequest()` is exported
  and takes an injectable `sendOtp` dependency specifically so tests
  never make a real network call to NextSMS.
- **Authentication of the caller**: this hook has no user JWT to check
  — Supabase Auth invokes it before any session exists — so
  `verify_jwt = false` is set for it in `supabase/config.toml`. The
  actual authentication mechanism is a
  [Standard Webhooks](https://www.standardwebhooks.com/) signature,
  verified via `https://esm.sh/standardwebhooks@1.0.0`'s `Webhook`
  class against the `webhook-id`/`webhook-timestamp`/`webhook-signature`
  headers and the *raw* request body (read via `req.text()` before any
  JSON parsing — Standard Webhooks signs exact bytes). An unverifiable
  signature is rejected with `401` and NextSMS is never called.
- **Phone format**: Supabase supplies `user.phone` in E.164
  (`+255713676401`); NextSMS expects the recipient without the leading
  `+` (`255713676401`). `phone.ts` converts this and rejects anything
  that is not well-formed E.164 before ever calling NextSMS.
- **Message**: a fixed, minimal Swahili OTP message
  (`"Umoja: Namba yako ya uthibitisho ni <OTP>. Usimpe mtu mwingine
  namba hii."`) — no user name or other identifying detail beyond the
  code itself.
- **Sender ID**: `NEXTSMS_DEFAULT_SENDER_ID` (`MICHANGO` for
  authentication OTP), validated at startup against the
  comma-separated `NEXTSMS_ALLOWED_SENDER_IDS` allowlist.
- **NextSMS request**: `POST {NEXTSMS_BASE_URL}{NEXTSMS_SINGLE_SMS_PATH}`
  with `{"from", "to", "text", "reference"}` and the `Authorization`
  header set to `NEXTSMS_AUTHORIZATION` **exactly as configured** — no
  `Basic `/`Bearer ` prefix is ever added, since NextSMS's own value
  already is the complete header. A ~4s request timeout keeps the hook
  fast; `reference` is a fresh `UMOJA-OTP-<uuid>` per attempt.
- **Response contract** (Supabase Auth Hook shape): NextSMS 2xx → hook
  returns `200 {}` (Supabase treats this as successful handoff).
  NextSMS non-2xx → hook returns `502
  {"error":{"http_code":502,"message":"Unable to send verification
  SMS"}}` — the provider's status/response body is logged server-side,
  never returned to the caller. Invalid signature/payload → `400`/`401`
  with the same safe-message shape. Any unexpected error → `500` with
  the same generic message; raw stack traces are never sent to the
  client.
- **Logging**: masked phone (last 4 digits only), NextSMS HTTP status,
  request duration, and the generated reference are safe to log. The
  OTP itself, `NEXTSMS_AUTHORIZATION`, and `SEND_SMS_HOOK_SECRETS` are
  never logged.
- **Scope**: this hook is authentication-OTP-only. It is not, and must
  not become, the general Umoja notification/messaging engine — a
  future notifications feature is a separate, explicit design.

### Required secrets (Edge Function environment variables)

Set via `supabase secrets set` (production) or a local `.env` for
`supabase functions serve` — **never committed**:

- `NEXTSMS_BASE_URL`, `NEXTSMS_SINGLE_SMS_PATH` — NextSMS API location.
- `NEXTSMS_AUTHORIZATION` — NextSMS's provider authorization value, used
  verbatim.
- `NEXTSMS_DEFAULT_SENDER_ID`, `NEXTSMS_ALLOWED_SENDER_IDS` — sender ID
  and its allowlist.
- `SEND_SMS_HOOK_SECRETS` — the Standard Webhooks secret Supabase
  Authentication → Hooks generates for this hook, in the form
  `v1,whsec_<base64>`. Only that literal `v1,whsec_` prefix is stripped
  before constructing `Webhook()` — the rest is the actual secret.

No actual secret values are recorded anywhere in this repository.

## Session lifecycle

- `authStateChangesProvider` (`auth_session_provider.dart`) is the single
  Supabase auth-state stream source — nothing else subscribes to
  `onAuthStateChange` directly.
- `currentSupabaseUserProvider` derives the current `User?` from that
  stream, falling back to `client.auth.currentUser` synchronously so the
  UI does not flash "signed out" before the first stream event arrives.
  This is how session restoration works on app restart: Supabase Auth's
  own persisted session is picked up automatically, with no custom
  session storage.
- `authUserIdProvider` derives just the user's `id` (or `null`). This
  exists specifically so `appContextProvider` refetches only on a real
  identity change (`String?` equality), not on every `TOKEN_REFRESHED`
  event for the same user.

## No user-state leakage across identities

This is a hard requirement: if User A signs in, selects a group, and
signs out, User B signing in afterward must never observe any fragment
of User A's state.

- `appContextProvider` watches `authUserIdProvider`, not the raw `User`
  object, and refetches from `rpc_get_my_context()` whenever the id
  changes (including transitioning to/from `null` on sign-out/in).
- `selectedGroupProvider` derives its state fully inside `build()` from
  the current `appContextProvider` value — it never carries state forward
  from a previous computation, so a rebuild triggered by an identity
  change produces entirely fresh state.
- `AuthController.signOut()` (`auth_controller_provider.dart`) is the
  single place sign-out happens — see [Toka](#toka-the-only-exit-action)
  below. Since prompt 05E this is always a **real** Supabase sign-out,
  full stop — there is no more separate local-only "lock" concept to
  distinguish it from. Beyond calling Supabase Auth's `signOut()`, it
  explicitly invalidates `appContextProvider`, `selectedGroupProvider`,
  `phoneAuthControllerProvider`, `hasPinCredentialProvider`, and
  `membersQueryProvider` (so a new sign-in never inherits a stale page
  count/search/filter from the previous identity, and never briefly
  reads the previous identity's PIN-credential state) — this makes the
  invalidation immediate and deterministic rather than depending purely
  on auth-stream event propagation timing.
- The router's redirect logic (`route_guard.dart`) never makes a routing
  decision from a stale value while `appContextProvider` is loading —
  `appContext.isLoading` is checked before `.value`, so a refetch in
  flight (e.g. right after an identity change) cannot route based on
  leftover data.
- See `app/test/user_switch_no_leak_test.dart` for a test that exercises
  this end-to-end at the provider level (User A's group selection is
  proven gone before User B's context ever loads).

## Profile completion

After authentication, `rpc_get_my_context()` returns the profile and
every membership. For **initial** onboarding, only `full_name` is
required (`AppUserProfile.isProfileComplete`) — no avatar, email,
address, or date of birth. `full_name` is saved via `ProfileRepository`
→ a direct `UPDATE public.profiles SET full_name = ...` scoped to the
caller's own row, which is exactly what the backend's RLS policy +
column-level grant already allow (see
`docs/database/authorization.md`) — no new backend surface was needed
for this.

`profiles.phone` is mirrored from the authenticated identity at account
creation time (the `handle_new_user()` trigger now also copies
`auth.users.phone`, added in migration
`20260819085905_enforce_active_profile_on_mutations.sql`). The profile
onboarding screen shows phone **read-only**, sourced directly from
`currentSupabaseUserProvider`'s `User.phone` — Flutter never offers a
way to edit `profiles.phone` as a way of changing the authentication
identity. Changing the authenticated phone number is a distinct future
workflow, not implemented here.

## Account-disabled behavior

`profiles.is_active = false` must disable a session even if the
Supabase JWT is still valid — see `docs/database/authorization.md` for
the backend enforcement (`assert_active_profile()`,
`caller_profile_is_active()`, and `is_group_member()`/
`has_group_permission()` now also require an active profile). On the
client, `route_guard.dart` treats a missing or inactive profile as
`/access/account-disabled` before any group-eligibility logic runs; that
screen offers only Sign Out, no group operational UI.

## Membership/group operational status

Existing statuses: `group_memberships.status` (ACTIVE / SUSPENDED /
EXITED) and `groups.status` (ACTIVE / SUSPENDED / CLOSED). Only a
membership that is **ACTIVE in an ACTIVE group** is a normal operational
selected-group context (`MembershipContext.isEligibleOperational`).
`selectedGroupProvider` filters on this before deciding
none/auto-select/require-selection — SUSPENDED/EXITED memberships and
memberships in a SUSPENDED/CLOSED group are never auto-selected, and
`rpc_get_my_context()` still reports their real status rather than
hiding or normalizing them (see the `12_operational_status_context`
pgTAP tests).

When a user has zero eligible memberships, `route_guard.dart`'s
`noEligibleGroupTarget()` picks the most specific relevant screen rather
than collapsing every case into onboarding:

1. Any SUSPENDED membership → `/access/membership-restricted` (which
   still offers "Create New Group" alongside the restriction notice).
2. Else any ACTIVE membership whose group is SUSPENDED →
   `/access/group-suspended`.
3. Else any ACTIVE membership whose group is CLOSED →
   `/access/group-closed`.
4. Otherwise (no memberships, or only EXITED ones) →
   `/onboarding/group`.

No group reactivation/closure workflow exists yet — these are read-only
notices.

## First-group onboarding

`/onboarding/group` is reachable once a signed-in, profile-complete
user has no eligible group. It always goes through the existing
`rpc_create_group()` RPC via `GroupRepository`/`GroupOnboardingController`
— never a direct insert into `groups`/`group_memberships`/
`group_membership_roles` (see `docs/database/authorization.md` for why
that matters: atomicity and the ADMIN-assignment invariant are owned by
the database function). On success, the controller invalidates
`appContextProvider`; the router then resolves the new membership as
selected and redirects to `/home` automatically — no logout/login
required. On failure, the screen stays put with entered values intact
(the `TextEditingController`s are owned by the screen, not the
controller) and shows a safe error message. The submit button is
disabled while a request is in flight, preventing duplicate-tap group
creation.

## Route guards vs. authorization

**`app/routing/route_guard.dart` is UX/navigation guidance only — it is
not the security boundary.** `computeRedirect()` is a pure function with
no `BuildContext` dependency, decided entirely from session/context/
selected-group state, so the full decision tree is unit-testable without
a widget tree. But a route reached by bypassing this logic entirely (a
stale deep link, browser back/forward, a modified client) still cannot
read or mutate data the backend would not otherwise allow — RLS policies
and the `SECURITY DEFINER` RPCs (`docs/database/authorization.md`) are
what's actually authoritative. Flutter must never introduce a
parallel, client-only authorization model.

## Account/member identity separation — linking remains deferred

Nothing in this prompt links an authenticated user to an existing
`group_memberships` row with `user_id IS NULL` by phone number or any
other automatic mechanism. See
[docs/product/member-identity-model.md](member-identity-model.md) for
the full rationale — an auth user and a domain "member" remain
intentionally separate concepts until a controlled, explicit
verification workflow is designed. A phone number matching an existing
unlinked membership does **not** cause any automatic claiming, joining,
or linking.

## Server-side PIN authentication (prompt 05E)

The 4-digit PIN is **not** local device-unlock UX — it is a
server-verified alternative credential for the normal returning-login
path, replacing the earlier (prompt 05B/05C/05D) local-device-lock
design entirely. Nothing about it is checked or stored client-side; the
client only ever sends the raw 4-digit PIN over TLS to one of two Edge
Functions and reacts to their result.

### Why server-side, not local

A local PIN check (a locally-stored hash compared client-side) can only
ever gate *UX* — it cannot be the actual authentication boundary, since
nothing stops a modified client from skipping the check. Prompt 05E's
design makes the PIN a real second way to authenticate with Supabase
Auth itself, so `pin-login` succeeding is exactly as strong a proof of
identity as a successful OTP verify — both end in a genuine Supabase
session installed through the official client APIs.

### Password derivation — the PIN never becomes a stored secret

A 4-digit PIN is far too low-entropy to use directly as a Supabase Auth
password. Instead, `setup-pin` derives a high-entropy password
deterministically and sets it as the user's Supabase Auth password via
the admin API:

```
derived = base64(HMAC-SHA256(PIN_PEPPER, "umoja-pin-v1:" + user_id + ":" + pin))
```

(`supabase/functions/_shared/pin_derivation.ts`). `PIN_PEPPER` is an
Edge Function secret, never present in Flutter, Git, or the database.
Because the derivation is deterministic, `pin-login` can recompute the
same password from `(user_id, pin)` and hand it to genuine
`signInWithPassword` — it never needs to store the derived password
anywhere. **Neither the raw PIN nor the derived password is ever
stored, logged, or returned to the client** — not in
`user_pin_credentials`, not in `profiles`, not in
`user_metadata`/`app_metadata`, not in `SharedPreferences`, not in any
log line.

### `public.user_pin_credentials`

The only PIN-related database table
(`20260822090000_create_user_pin_credentials.sql`). Holds phone→user
mapping and rate-limit metadata only — **never a PIN or password of any
form**: `user_id` (PK, FK to `auth.users`, cascade), `phone_e164`
(unique, `+255[67]\d{8}` format-checked), `credential_version`,
`failed_attempts`, `locked_until`, `last_failed_at`, `pin_set_at`,
`updated_at`/`created_at`. RLS is enabled with **zero policies**
(default-deny) and all grants are revoked from `anon`/`authenticated` —
every access goes through `SECURITY DEFINER` functions:

- `record_pin_login_failure(user_id, ...)` — atomic
  `UPDATE ... RETURNING` increment of `failed_attempts`; every 5th
  failure (configurable) sets an escalating `locked_until`
  (`least(base_minutes * cycle, max_minutes)`, default 5/60) — **never
  a permanent lock**.
- `reset_pin_login_failures(user_id)` — clears both fields on a
  successful login.
- `rpc_has_pin_credential()` — the **one** narrow client-facing read
  (`security definer`, `stable`, granted to `authenticated` only):
  whether the caller has a PIN credential configured. This is what
  `hasPinCredentialProvider` (`lib/features/security/providers/`)
  calls — there is no local/cached equivalent; it is refetched from the
  server whenever the authenticated identity changes.

### `setup-pin` (authenticated Edge Function)

Called by `AuthRepository.setupPin(pin)` right after a fresh OTP
sign-in with no PIN configured yet, and again at the end of a
successful PIN-recovery flow. Requires a valid Authorization header
(the caller's own JWT, resolved via an anon-client `auth.getUser`);
requires the caller's phone to already be verified. On success it
derives the password, sets it via the service-role admin API
(`admin.updateUserById`), and upserts `user_pin_credentials` (resetting
`failed_attempts`/`locked_until`, setting `pin_set_at`) — all inside
one Edge Function invocation, so a client never sees a partial state.
Errors: `UNAUTHORIZED` (401), `INVALID_PIN` (400), `PHONE_NOT_VERIFIED`
(403), `SERVER_ERROR` (500).

#### setup-pin consistency

Execution order is fixed and deliberate: **`setAuthPassword` (the Auth
admin password update) always runs before `upsertCredential` (the
`user_pin_credentials` write)** — never the reverse, and the two are
not (and cannot be, being two different systems — GoTrue and Postgres)
wrapped in one database transaction. `upsertCredential` is retried up
to 3 times in-request (150ms/300ms backoff) before giving up, since a
transient DB blip is far likelier to clear on an immediate second
attempt than to need a whole client retry round trip.

**If `setAuthPassword` fails**: nothing else runs. No DB write of any
kind happens. Whatever credential existed before (none, for first-time
setup; the old PIN, for recovery) is completely untouched and still
fully valid. Trivially safe.

**If `setAuthPassword` succeeds but `upsertCredential` still fails
after retries** (rare — this needs a DB-level failure occurring in the
narrow window right after a successful external Auth API call):

- **First-time setup** (no `user_pin_credentials` row existed yet): no
  row is ever written before the password change succeeds, so this
  leaves **no row at all**. `rpc_has_pin_credential()` correctly keeps
  reporting `false` — the client is never told a credential exists
  when it doesn't, and the router correctly keeps showing PIN setup.
  **No partial/broken credential is ever exposed as usable.**
- **Recovery** (a row already existed): the row is left completely
  unchanged — still pointing at the same `user_id`. Because
  `pin-login`'s sign-in step never reads `credential_version`/
  `pin_set_at` from that row (only `user_id`, for deriving the
  password, and `locked_until`, for the lockout check), and the Auth
  password *has* already changed above, **the new PIN the user just
  set already works** for `pin-login` even though `setup-pin` reported
  failure to the client. This is a harmless direction of surprise (more
  capability than promised, not less) — never a lockout, and the
  client's "failed, please retry" is what prompts the stale
  `failed_attempts`/`locked_until`/`pin_set_at` bookkeeping to
  self-correct on the next successful call.

**Either way, a user is never permanently unable to log in**: OTP
remains available unconditionally regardless of PIN state, and both
operations are individually idempotent (re-running `setAuthPassword`
with the same PIN is a no-op re-set; `upsertCredential` is keyed on
`user_id`), so a client retry with the same PIN always converges to a
fully consistent state.

**Why no explicit PENDING/ACTIVE schema state**: that design was
considered and is unnecessary given the ordering above — a
`user_pin_credentials` row is *only ever written* in the same step
where the Auth password change has already succeeded, so there is no
code path that creates a row *before* the password is set (which is
the actual scenario a PENDING/ACTIVE flag would exist to guard
against). Reversing the order to "write metadata first" was considered
and rejected: it would let a `rpc_has_pin_credential()` check briefly
observe a row for a credential whose password was never actually set,
which is precisely "exposing a partial credential as usable" — the
current order structurally cannot do that.

### `pin-login` (public Edge Function) — the actual login path

Called by `AuthRepository.pinLogin({e164Phone, pin})` from the
combined login screen. **This is a real login, not a service-role
shortcut**: the service-role client is used only to look up the
credential row and to record/reset the failure counter — the actual
authentication step is a genuine anon-client `signInWithPassword` call.
Flow:

1. Normalize the phone, validate the PIN is 4 digits — malformed input
   fails with the same generic error as everything else below (see
   [No account enumeration](#no-account-enumeration)).
2. Look up `user_pin_credentials` by phone (service role). Not found →
   generic failure.
3. Check `locked_until` — if still locked, `PIN_TEMPORARILY_LOCKED`
   (429) and **no attempt is recorded** (a locked account doesn't burn
   further attempts against itself).
4. Derive the password and call `signInWithPassword` (anon client). On
   success: reset the failure counter (RPC), return the session
   (`access_token`, `refresh_token`, `expires_in`, `expires_at`,
   `token_type`). On failure: record the failure (RPC), return the
   generic error.

`SupabaseAuthRepository.pinLogin` installs the returned session via
`client.auth.setSession(refreshToken, accessToken: accessToken)` —
deliberately passing a **fresh, non-expired access token together with
the refresh token**, which takes gotrue's "skip refresh" path and fires
a live `AuthChangeEvent.signedIn` (not `tokenRefreshed`), the same as a
real interactive sign-in. Flutter never manually writes tokens to
storage — Supabase Auth's own session persistence is what makes this
survive a restart, exactly as for OTP sign-in.

### No account enumeration

`pin-login` returns the **exact same** generic failure
(`AuthFailureType.invalidCredentials`, HTTP 401,
"Namba ya simu au PIN si sahihi.") whether the phone number doesn't
exist, has no PIN credential configured yet, or the PIN is simply
wrong — an attacker (or a curious user) cannot distinguish "no such
account" from "wrong PIN" from any response shape, status code, or
timing-observable branch. `PIN_TEMPORARILY_LOCKED` (429) is the only
distinct outcome, and it is only reachable *after* already knowing a
valid phone+PIN pair triggered enough failures to lock it — it does not
leak which phone numbers exist either, since a nonexistent phone number
can never reach the locked state.

### Rate limiting / lockout

Enforced entirely server-side via `record_pin_login_failure`/
`user_pin_credentials.locked_until` — never client-side, never
bypassable by a modified client. 5 consecutive failures locks for 5
minutes; each further cycle of 5 doubles the effective multiplier up to
a 60-minute cap (`least(base * cycle, max)`) — escalating, but **never
permanent**: waiting out the lock always eventually allows another
attempt. See `19_user_pin_credentials.test.sql` for the pgTAP coverage
of the escalation math and the reset-on-success behavior.

### Deployment — this is easy to leave half-done

`setup-pin` and `pin-login` are ordinary Supabase Edge Functions and
`PIN_PEPPER` is an ordinary Edge Function secret — **none of this
exists for real users until `supabase functions deploy setup-pin
pin-login` has been run and `PIN_PEPPER` has been set via `supabase
secrets set`, against the actual linked project.** Applying the
`user_pin_credentials` migration (`supabase db push`) is not
sufficient on its own. Prompt 05E-A's root cause was exactly this gap:
the migration had been pushed, but the two functions were never
deployed and `PIN_PEPPER` was never set, so `setup-pin` returned a 404
before any of its code ran (`supabase functions list` only showed
`send-sms-hook`) — every "Could not save your PIN" on a physical
device traced back to that, not application logic. Both functions also
guard `buildDefaultDeps()` in a `try`/`catch` now, specifically so a
missing/misconfigured secret returns a safe `SERVER_ERROR` (500)
instead of an unhandled crash — see the `"...server misconfigured"`
Deno tests in each function's `index.test.ts`. Confirm deployment
state with `supabase functions list` (expect `setup-pin` and
`pin-login` both `ACTIVE`) and `supabase secrets list` (expect
`PIN_PEPPER` present — names only, never values, are ever visible or
logged).

### Combined login screen (`/auth/phone`, `phone_entry_screen.dart`)

The normal returning-login screen: a phone field, a 4-digit
`UmojaCodeInput` PIN field (auto-submits on the 4th digit via
`AutoSubmitOnLength`, sharing the same `isSubmitting` guard as the
manual "Ingia" button so the two paths can never both be in flight),
and two links that reuse whatever phone number is already typed rather
than asking for it again:

- **"Mara ya kwanza? Thibitisha namba kwa OTP"** → `PhoneAuthController
  .submitPhone()` → `/auth/verify`. First-time verification/self-
  service account creation.
- **"Umesahau PIN?"** → `PinRecoveryController.start(phone)` → sends an
  OTP and navigates to `/auth/pin-recover/verify`. See [PIN
  recovery](#pin-recovery-forgot-pin) below.

### PIN setup (`pin_setup_screen.dart` / `pin_setup_controller.dart`)

Shown once, immediately after a fresh OTP sign-in with no PIN
credential configured yet (`hasPinCredentialProvider` resolves
`false`). Two steps — enter, then confirm — each auto-submitting at 4
digits. A mismatch on confirm restarts from the first step (never a
partial retry) and never calls `setup-pin`. On a successful match, the
raw PIN is sent to `AuthRepository.setupPin(pin)` and
`hasPinCredentialProvider` is invalidated; the router's redirect then
takes the user into the app once it refetches `true`. The same screen
is reused at `/auth/pin-recover/new-pin` for [PIN
recovery](#pin-recovery-forgot-pin) — see that section for why that
reuse navigates explicitly on success rather than relying purely on the
router (as every other auth screen does).

### PIN recovery ("Forgot PIN") — prompt 05E §17

"Umesahau PIN?" is reached from the **signed-out** login screen, using
whatever phone number is already typed there — there is no separate
"enter a phone number" step and no dependency on an existing session:

- `PinRecoveryController.start(rawPhone)` validates the phone, sends an
  OTP for it, and navigates to `/auth/pin-recover/verify`
  (`pin_recovery_verify_screen.dart`) — this OTP send happens once,
  from the login screen's tap; the verify screen itself never
  auto-sends on mount (unlike `OtpVerifyScreen`, which is reached
  differently and does auto-send there).
- On successful OTP verify, the user is now signed in (this is a real
  Supabase session, exactly as strong as first-time OTP verification)
  and navigates to `/auth/pin-recover/new-pin` — `PinSetupScreen`
  reused as-is. Its `PinSetupController.submitConfirm` only ever calls
  `setup-pin` (never a separate "clear" step first), so **the old PIN
  credential stays valid and unchanged server-side until the very
  moment a new one is successfully confirmed** — recovery can be
  abandoned at any point (even after the OTP verifies) without any
  effect on the existing PIN credential; the still-valid session and
  still-intact old credential simply land the user in the app rather
  than forcing a redundant re-login.
- **Safe Back everywhere**: both recovery routes set `onBack`/
  `cancelRoute` back to `/auth/phone`, which `AuthScreenLayout` turns
  into both a visible top-left back arrow AND a `PopScope` interception
  of the Android system Back gesture/button — both call the same
  callback, so hardware/gesture Back can never diverge from the visible
  affordance. `PinRecoveryController.reset()` clears in-flight state on
  the way out.
- `route_guard.dart`'s `_pinRecoveryRoutes` set keeps both routes
  reachable **unconditionally** while signed in (regardless of
  `hasPinCredential`) and reachable signed-out for `/auth/pin-recover/
  verify` (before its own OTP verify) — this is deliberate: the PIN
  gate must never bounce a user mid-recovery away in either direction,
  since the old credential existing server-side would otherwise read as
  "already configured, skip recovery." Because of this unconditional
  exemption, `PinSetupScreen`'s reuse at `/auth/pin-recover/new-pin` is
  the one auth screen that navigates explicitly (`context.go(AppRoutes
  .splash)`) on a successful `submitConfirm` — every other screen
  relies purely on the router's redirect recomputing once state
  changes, but the recovery-route exemption above would otherwise strand
  the user on this screen forever after a successful reset. See
  `route_guard_test.dart`'s "PIN gating" group and the full flow in
  `pin_recovery_navigation_test.dart`.

### "Toka" — the only exit action

Prompt 05E §13/§14: More screen's "Usalama" section exposes exactly one
action, "Toka", and it is always a real `AuthController.signOut()` —
there is no more "lock"/"switch account"/"use another number"
distinction, no confirmation dialog (nothing destructive beyond a
normal sign-out), and no PIN-unlock screen to land on. The next screen
is always the phone + PIN login screen — never an automatic OTP. See
`security_actions_test.dart`, `account_switch_pin_cycle_test.dart`.

### Startup/routing decision order (`route_guard.dart`)

Resolved in this exact order, before any profile/group decision:

1. No valid Supabase session → `/auth/phone` (the combined phone + PIN
   login screen) — except the recovery routes, which stay reachable
   signed-out too (see above).
2. Valid session, no PIN credential configured server-side
   (`hasPinCredentialProvider` → `false`) → `/auth/pin-setup`. Resolved
   before the `appContextProvider` fetch, so this never waits on a
   network round trip it doesn't need.
3. Valid session, PIN credential configured → falls through to the
   existing profile/group/operational routing described elsewhere in
   this document. There is no separate "locked" state to resolve — a
   valid session with a configured PIN credential *is* the unlocked
   app; the PIN's server-side check already happened at `pin-login`
   time (or the original OTP, for a session that hasn't signed out
   since).

### Auto-submit (OTP + PIN)

`AutoSubmitOnLength` (`lib/core/utils/auto_submit_on_length.dart`) is
shared by the OTP screen (6 digits — Supabase phone/SMS OTP is fixed
at 6, unlike email OTP, which is independently configurable in
`supabase/config.toml`), the login screen's PIN field, and both PIN
setup screens (4 digits). It fires `onComplete` once per *distinct*
value reached, so a failed attempt followed by re-entering the
identical value doesn't loop — except `reset()` re-arms it for the
exact same value on request, which PIN setup calls when moving from
"enter" to "confirm": confirming correctly means retyping the
*identical* PIN, and without this reset that legitimate case would
silently never auto-submit. Every screen using it keeps its manual
button as a fallback, and the controller's own `isSubmitting` guard is
what actually prevents the auto path and the manual button from ever
issuing two concurrent requests — see `pin_login_controller_test.dart`
for a dedicated regression covering exactly that race.

## OTP SMS autofill

Applies only to the 6-digit SMS OTP field (`OtpVerifyScreen`,
`PinRecoveryVerifyScreen`) — never the 4-digit login/setup PIN, which
is never eligible for any OS-level autofill.

- **Android**: `OtpAutofill` (`lib/core/utils/otp_autofill.dart`, via
  the `smart_auth` package) races **both** Android mechanisms and
  takes whichever resolves first:
  - **SMS Retriever API** — fully automatic, no dialog, no permission.
    Needs the SMS body to end with an 11-character app-signature hash.
  - **SMS User Consent API** — a one-tap system dialog for the next
    SMS received while listening. No message-format requirement.
  Neither needs `READ_SMS`/`RECEIVE_SMS` (`AndroidManifest.xml`
  declares no SMS permission; `smart_auth`'s own manifest declares
  none either). A look-behind matcher (`(?<=uthibitisho ni )\d{6}`) is
  anchored to the exact fixed NextSMS phrase for both, so an unrelated
  SMS arriving during the listening window is never mistaken for the
  OTP, and a trailing app-hash suffix never interferes with extracting
  the digits.
- **Today**, the production NextSMS message
  (`supabase/functions/send-sms-hook/message.ts`) does **not** contain
  the app hash, so the Retriever side of the race never actually wins
  — User Consent (the one-tap dialog) is what fills the code in
  practice right now. It remains the active, working fallback
  indefinitely, not just temporarily — the race means there is nothing
  to "switch off" later; the moment the message format changes (below),
  Retriever starts winning automatically and User Consent simply never
  gets a chance to, with **no further Flutter change needed**.
- **iOS**: `UmojaCodeInput.isOneTimeCode` (set only by the two OTP
  screens) applies `AutofillHints.oneTimeCode` to the field, the
  native, plugin-free iOS affordance that offers the received code
  above the keyboard. Unaffected by any of the above.
- Both screens read `otpAutofillProvider` (Riverpod, matching this
  codebase's DI convention) rather than constructing `OtpAutofill`
  directly, and cancel both listeners on successful verify, on
  dispose, and when backing out — see `otp_sms_autofill_test.dart`
  (screen integration) and `otp_autofill_race_test.dart` (the race
  logic itself, via injectable listener functions).
- PIN login (`pin-login`, `PinLoginController`) is entirely untouched
  by any of this — it has no SMS/autofill involvement at all.

### SMS Retriever API migration — not yet done, gated on the release hash

**The production NextSMS message has deliberately not been changed** —
doing so requires knowing the *release* app-signature hash first, which
this environment cannot produce (see below), and prompt "ADD OTP SMS
AUTOFILL" §12 explicitly required reporting this rather than guessing.

- **Debug app hash** (this machine's local `~/.android/debug.keystore`
  only — every developer's debug keystore differs, so this is not
  reusable elsewhere and **must never be used for production**):
  `rvM4AJc5H+Z`, package `org.umoja.umoja`.
- **Release app hash**: not obtainable in this environment — it is
  derived from your actual release signing certificate (your upload
  keystore, or Play App Signing's certificate if enrolled, which can
  differ from the upload key). Obtain it with either:
  1. Run `await SmartAuth.instance.getAppSignature()` from a
     **release-signed** build installed on a device (the authoritative
     method — it reads whatever certificate actually signed that exact
     build), or
  2. `keytool -exportcert -alias <release-key-alias> -keystore
     <release-keystore> | ` then SHA-256(`"<applicationId> " +
     <uppercase-hex-of-the-raw-DER-certificate-bytes>`), truncated to
     the first 9 bytes and base64-encoded to 11 characters — the same
     algorithm used to compute the debug hash above. Never share the
     release keystore itself to get this.
  If enrolled in Play App Signing, confirm which certificate actually
  signs the APKs served to users (Play Console → App integrity) before
  computing/trusting a hash from your local upload key alone.
- **Exact message template change required**, once the release hash is
  confirmed (replace `<HASH>`, keep it as the literal final 11
  characters, nothing after it):
  ```
  Umoja: Namba yako ya uthibitisho ni ${otp}. Usimpe mtu mwingine namba hii.
  <HASH>
  ```
  (a trailing newline then the hash — Android's own examples format it
  this way; the requirement is only that the hash is the exact last 11
  characters, not that it's on its own line, but a newline avoids any
  ambiguity). This is a one-line change to `buildOtpMessage()` in
  `supabase/functions/send-sms-hook/message.ts`, deliberately not made
  yet.

## Local manual testing status

Supabase's local dev stack (`supabase start`) does not include a real
SMS provider by default, and no Twilio/NextSMS credentials were added
to this repository (per instructions — no real SMS secrets, no
invented provider credentials, no hard-coded master OTP in production
code). `send-sms-hook`, `setup-pin`, and `pin-login` are all deployed
to the linked Supabase project (`supabase functions list`) and
`setup-pin`/`pin-login` were smoke-tested live post-deploy (prompt
05E-A) — but `send-sms-hook` has not been independently confirmed as
the *active* Send SMS Hook in Supabase Authentication → Hooks in this
session, so the phone-OTP send/receive round trip still could not be
exercised against a live SMS provider from this environment.

What *was* verified:

- All Flutter unit/widget tests (phone normalization, the OTP
  controller's send/verify/error states, and full router+screen
  navigation) run against a `FakeAuthRepository` and require no
  network, no real SMS, and no live Supabase project.
- The backend authorization changes (inactive-profile enforcement,
  operational-status representation) were verified against local
  Supabase via `supabase test db`.
- `send-sms-hook`'s Standard Webhooks signature verification and
  NextSMS request-building were verified with `deno check` and `deno
  test` (a locally installed Deno toolchain, not otherwise part of
  this repo's stack) — including a self-signed test webhook payload
  exercising the real `standardwebhooks` verification library, so the
  signature logic itself is confirmed correct without depending on
  live Supabase Auth to generate one. No real NextSMS call is made in
  these tests (`sendOtp` is dependency-injected).

If you do configure a real (or Supabase-supported test) SMS provider
locally, the manual flow is: run the app with `--dart-define-from-file`
pointed at your local Supabase instance (see the README's "Running
against local Supabase" section for host-address notes per platform),
enter a real phone number on `/auth/phone`, and enter the SMS code you
receive on `/auth/verify`.
