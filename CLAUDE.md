# CLAUDE.md

Instructions for Claude Code (and any other agent) working in this
repository.

## Project

Umoja v2 is a new-from-scratch Flutter + Supabase group finance
application for community groups (vikundi). It is not a migration of any
previous Umoja codebase — do not reuse or copy old Umoja code.

## Client

One Flutter codebase (`app/`) targets Android, iOS, Web, Linux, Windows
and macOS. Do not create a separate React web frontend, React Native app,
or separate desktop frontend. See
[docs/decisions/0001-single-flutter-codebase.md](docs/decisions/0001-single-flutter-codebase.md).

## Source of truth

The backend/database (Supabase/PostgreSQL, `supabase/`) owns financial
calculations and state transitions. See
[docs/product/architecture.md](docs/product/architecture.md),
[docs/accounting/invariants.md](docs/accounting/invariants.md), and
[docs/database/conventions.md](docs/database/conventions.md).

## NEVER

- Invent accounting rules.
- Silently alter locked accounting behavior.
- Calculate authoritative money balances only in Flutter.
- Directly mutate posted financial records.
- Hard-delete posted financial transactions.
- Expose Supabase service-role keys to Flutter.
- Create duplicate cashbook entries for payment allocations.
- Use floating point for authoritative money.
- Bypass migrations for schema changes.
- Bypass RLS in normal client flows.
- Implement unrelated features during a scoped task.
- Treat an authenticated user and a domain group member as the same
  thing — `group_memberships.user_id` is nullable by design; a member
  may exist before (or without ever having) an app account.
- Automatically link a `group_memberships` row to an authenticated user
  by phone-number match or any other automatic mechanism. Account
  linking/claiming requires a controlled, explicit verification
  workflow that does not exist yet.
- Expose the Supabase service-role key to Flutter, or use it to create
  `auth.users` rows via SQL/scripts.
- Treat Flutter route guards as authorization. They are UX/navigation
  guidance only — RLS and the backend's `SECURITY DEFINER` RPCs are
  the actual security boundary.
- Let an inactive profile (`profiles.is_active = false`) retain
  effective group permissions through a still-valid session — this
  must be enforced in the backend (see
  `docs/database/authorization.md`), not only hidden in the UI.
- Auto-select or treat as normal operational context a membership that
  is not ACTIVE, or a membership whose group is not ACTIVE. Only an
  ACTIVE membership in an ACTIVE group is a normal selected-group
  context.

## ALWAYS

- Inspect the existing repository before making changes.
- Keep changes scoped to the prompt.
- Use migrations (`supabase/migrations/`) for schema changes.
- Use transactional backend/database commands for financial writes.
- Maintain `effective_at` and `created_at` separately.
- Maintain group/tenant isolation.
- Use the Supabase publishable client key (`SUPABASE_PUBLISHABLE_KEY`)
  for Flutter configuration — never a secret/service-role key.
- Make retryable financial mutations idempotent.
- Add tests for financial invariants when implementing financial logic.
- Run formatting/analyze/tests after changes (`dart format`,
  `flutter analyze`, `flutter test` from `app/`).
- Report exactly what changed.
- Report commands run.
- Report any failures honestly.
- Stop after completing the requested scope.

## Important

Do not automatically continue to another Umoja implementation phase.
Wait for the next explicit prompt.
