# Umoja v2

Umoja v2 is a financial-management application for community groups
(vikundi). This is a new project, built from scratch — it does not reuse
any previous Umoja codebase.

See [docs/product/overview.md](docs/product/overview.md) for product
scope and [docs/product/architecture.md](docs/product/architecture.md)
for the architecture.

## Architecture summary

```
Flutter (app/)
    ↓
Supabase API/Auth
    ↓
PostgreSQL
    ↓
Controlled financial commands / RPCs
    ↓
Authoritative ledgers
```

One Flutter codebase targets Android, iOS, Web, Linux, Windows and
macOS. Supabase (PostgreSQL + Auth) is the backend and the source of
truth for financial state. See
[docs/decisions/0001-single-flutter-codebase.md](docs/decisions/0001-single-flutter-codebase.md).

## Directory structure

```
umoja-v2/
├── app/                  Flutter application (client for all platforms)
├── supabase/             Supabase project: config, migrations, functions
├── docs/
│   ├── product/           Product overview and architecture
│   ├── accounting/        Locked accounting invariants
│   ├── database/          Database conventions
│   └── decisions/         Architecture Decision Records
├── scripts/
├── .github/workflows/     CI
├── CLAUDE.md              Instructions for Claude Code in this repo
└── Makefile               Common development commands
```

## Requirements

- Flutter 3.47.0 (stable channel) or later — do not downgrade
- Dart 3.13.0 (bundled with Flutter)
- Supabase CLI (for local Supabase development)
- Platform SDKs as needed for the target you're building (Android SDK,
  Xcode for iOS/macOS, Visual Studio for Windows, Linux desktop build
  tools for Linux)

## Flutter setup

```bash
cd app
flutter pub get
```

## Supabase CLI setup

Install the Supabase CLI (see
https://supabase.com/docs/guides/cli/getting-started). This repository
already contains an initialized Supabase project at `supabase/`
(`project_id = umoja-v2`). To start it locally (requires Docker):

```bash
supabase start
```

Future schema changes must be added as versioned migrations:

```bash
supabase migration new <name>
```

See [docs/database/conventions.md](docs/database/conventions.md) for the
rules migrations must follow.

## Identity, tenancy, and session foundation

The identity + group tenancy + authorization foundation is implemented
(migrations in `supabase/migrations/`): `profiles`, `groups`,
`group_memberships`, `roles`/`permissions`/their mappings, RLS
policies, and RPCs. See
[docs/product/architecture.md](docs/product/architecture.md) and
[docs/database/authorization.md](docs/database/authorization.md) for
how tenant isolation and authorization actually work — in short, a
user's access to a group always flows through an explicit, RLS- and
permission-checked `group_memberships` row (`auth.uid()` scoped), never
through a permanent field on the user, since a user may belong to more
than one group.

## Authentication and onboarding

Phone number + OTP (via Supabase Auth) is the only authentication
method — no email/password, social login, or PIN. See
[docs/product/authentication.md](docs/product/authentication.md) for
the full flow: phone normalization, OTP send/verify, session
restoration, profile completion, first-group onboarding, the
account-disabled state, and route guards (`app/routing/`).

In short: `/auth/phone` → `/auth/verify` → (if needed)
`/onboarding/profile` → (if needed) `/onboarding/group` or
`/select-group` → `/home`. Group creation always goes through
`rpc_create_group()` — Flutter never inserts into
`groups`/`group_memberships`/`group_membership_roles` directly. From
`/home`, a signed-in member with `member.view` can open Members
(`/members`) to view, search, create, and edit group members and
manage their status/roles — see
[docs/product/members.md](docs/product/members.md). Member creation
always goes through `rpc_create_group_member(group_id, display_name,
...)`, callable by anyone holding `member.create` in that group; a
registered member does not need an Umoja account of their own
(`user_id` is nullable — see
[docs/product/member-identity-model.md](docs/product/member-identity-model.md)).
The operational UI (Home, Members, More) runs inside a responsive app
shell — bottom navigation on phone widths, a navigation rail on
tablet/desktop — built from a shared design system; see
[docs/product/design-system.md](docs/product/design-system.md), which
future modules (Contributions, Loans, Wallet, ...) are expected to
reuse rather than introducing their own visual system.

**Local phone-OTP testing note:** local Supabase does not include a
real SMS provider by default, and this repository does not configure
one (no Twilio/SMS credentials are committed). The phone-OTP flow could
not be end-to-end exercised against a live local Supabase instance in
this environment as a result — see
[docs/product/authentication.md](docs/product/authentication.md#local-manual-testing-status).
All Flutter tests for the auth flow use a fake `AuthRepository` and
require no network/SMS/live Supabase project.

## Running against local Supabase

`supabase start` prints local URLs (`http://127.0.0.1:54321`, etc.).
Which host address actually works from the Flutter app depends on the
platform you're running it on — use the right one for
`SUPABASE_URL` in your `env.json`:

- **Web (Chrome) / Linux desktop**, same host as Supabase:
  `http://127.0.0.1:54321` (or `http://localhost:54321`) works
  directly.
- **Android emulator**: the emulator's own loopback is not the host
  machine's — use `http://10.0.2.2:54321` instead.
- **A physical device** (Android/iOS) on the same network: use your
  host machine's LAN IP instead of `127.0.0.1`, e.g.
  `http://192.168.x.x:54321`.

Don't hard-code one address in the app — keep it in your local
(gitignored) `env.json` per platform/run target instead.

## Environment configuration

The app needs `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` at build/run
time, supplied via `--dart-define-from-file` — never bundled as a
runtime `.env` file. `app/.env.example` documents the two values in
plain `KEY=value` form; `app/env.example.json` is the actual template to
copy:

```bash
cd app
cp env.example.json env.json   # env.json is gitignored — fill in real values
flutter run -d chrome --dart-define-from-file=env.json
```

If configuration is missing, the app still starts and the foundation
screen reports "Supabase configuration missing" instead of crashing —
see `app/lib/core/config/env_config.dart`.

The Supabase publishable key (`sb_publishable_...`) is a public client
key by design and is safe to embed this way. The Supabase secret key
and the legacy service-role key must never be used in Flutter — see
`CLAUDE.md`.

## Running the app

Web:

```bash
cd app
flutter run -d chrome
```

Linux desktop:

```bash
cd app
flutter run -d linux
```

Android (requires a connected device or running emulator):

```bash
cd app
flutter run -d <device-id>   # see `flutter devices`
```

iOS, macOS, and Windows desktop builds require their respective host
platforms/toolchains (a macOS host with Xcode for iOS/macOS, a Windows
host with Visual Studio for Windows) and are not runnable from this
development machine (Linux). Platform support code has already been
generated under `app/ios/`, `app/macos/`, and `app/windows/`.

## Tests, analysis, formatting

```bash
cd app
flutter test
flutter analyze
dart format .
```

Or via the Makefile from the repository root:

```bash
make flutter-get
make flutter-analyze
make flutter-test
make flutter-format
make flutter-web
make flutter-linux
make check       # get + format + analyze + test
```

## CI

`.github/workflows/flutter-ci.yml` runs `flutter pub get`, format check,
`flutter analyze`, and `flutter test` on push/PR to `main`, with
`app/` as the working directory.
