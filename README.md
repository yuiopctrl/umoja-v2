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

**Login/OTP UI is not implemented yet.** The Flutter app
(`lib/features/auth/`) understands Supabase auth session state
(signed-in/signed-out), fetches the current user's application context
via the `rpc_get_my_context()` RPC once signed in, and resolves which
group is "selected" (auto-selected if the user has exactly one
membership, otherwise a minimal selection list). There is no
sign-up/sign-in form; the foundation screen only reports session state
and lets you sign out.

To create a group during development (no New Group UI exists yet),
call the `rpc_create_group` RPC while authenticated — e.g. from the
Supabase Studio SQL editor's "run as user" mode, or any authenticated
Supabase client:

```sql
select rpc_create_group('My Test Group', 'optional description');
```

This atomically creates the group and makes the calling user its first
ACTIVE membership with the ADMIN role. To register a member who does
not (yet) have their own Umoja account, use
`rpc_create_group_member(group_id, display_name, ...)` while
authenticated as someone holding `member.create` in that group.

## Environment configuration

The app needs `SUPABASE_URL` and `SUPABASE_ANON_KEY` at build/run time,
supplied via `--dart-define-from-file` — never bundled as a runtime
`.env` file. `app/.env.example` documents the two values in plain
`KEY=value` form; `app/env.example.json` is the actual template to copy:

```bash
cd app
cp env.example.json env.json   # env.json is gitignored — fill in real values
flutter run -d chrome --dart-define-from-file=env.json
```

If configuration is missing, the app still starts and the foundation
screen reports "Supabase configuration missing" instead of crashing —
see `app/lib/core/config/env_config.dart`.

The Supabase anon/publishable key is a public client key by design and is
safe to embed this way. The service-role key must never be used in
Flutter — see `CLAUDE.md`.

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
