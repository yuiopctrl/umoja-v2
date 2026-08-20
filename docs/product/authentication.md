# Authentication

Umoja v2's initial (and, for this prompt, only) authentication method is
**phone number + OTP**, via Supabase Auth's SMS OTP flow. There is no
email/password, Google/Apple, or PIN login. PIN is intentionally
deferred — see [PIN is not implemented](#pin-is-not-implemented) below.

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
  single place sign-out happens. Beyond calling Supabase Auth's
  `signOut()`, it explicitly invalidates `appContextProvider`,
  `selectedGroupProvider`, and `phoneAuthControllerProvider` — this makes
  the clear immediate and deterministic rather than depending purely on
  auth-stream event propagation timing.
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

## PIN is not implemented

No PIN authentication, PIN storage, or PIN-related columns exist in this
prompt (nor should they — see `CLAUDE.md`). If a device-friendly PIN
unlock is added later, it will be a separate, explicit design decision
layered on top of the Supabase phone-OTP session, not a replacement for
it.

## Local manual testing status

Supabase's local dev stack (`supabase start`) does not include a real
SMS provider by default, and no Twilio/SMS credentials were added to
this repository (per instructions — no real SMS secrets, no invented
provider credentials, no hard-coded master OTP in production code).
This means the phone-OTP flow **could not be end-to-end exercised
against a live/local Supabase instance** in this environment — sending
a real OTP requires configuring an SMS provider in `supabase/config.toml`
under `[auth.sms]`, which is a deployment-time decision outside this
prompt's scope.

What *was* verified:

- All Flutter unit/widget tests (phone normalization, the OTP
  controller's send/verify/error states, and full router+screen
  navigation) run against a `FakeAuthRepository` and require no
  network, no real SMS, and no live Supabase project.
- The backend authorization changes (inactive-profile enforcement,
  operational-status representation) were verified against local
  Supabase via `supabase test db`.

If you do configure a real (or Supabase-supported test) SMS provider
locally, the manual flow is: run the app with `--dart-define-from-file`
pointed at your local Supabase instance (see the README's "Running
against local Supabase" section for host-address notes per platform),
enter a real phone number on `/auth/phone`, and enter the SMS code you
receive on `/auth/verify`.
