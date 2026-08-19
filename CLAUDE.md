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

## ALWAYS

- Inspect the existing repository before making changes.
- Keep changes scoped to the prompt.
- Use migrations (`supabase/migrations/`) for schema changes.
- Use transactional backend/database commands for financial writes.
- Maintain `effective_at` and `created_at` separately.
- Maintain group/tenant isolation.
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
