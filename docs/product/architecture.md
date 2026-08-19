# Architecture

## Data flow

```
Flutter
    ↓
Supabase API/Auth
    ↓
PostgreSQL
    ↓
Controlled financial commands / RPCs
    ↓
Authoritative ledgers
```

One Flutter codebase (`app/`) is the client for every platform: Android,
iOS, Web, Linux, Windows, macOS. Supabase (PostgreSQL + Auth + API) is the
backend. There is no separate web frontend, mobile app, or desktop
frontend stack — see
[docs/decisions/0001-single-flutter-codebase.md](../decisions/0001-single-flutter-codebase.md).

## Responsibility split

### Flutter (`app/`)

- Presentation and layout, responsive across form factors
- User interaction
- Input validation for UX (not authoritative validation)
- Invoking Supabase APIs / RPCs
- Displaying server-derived financial state

### Backend / PostgreSQL (`supabase/`)

- Authoritative validation
- Money calculations
- Accounting rules and invariants (see
  [docs/accounting/invariants.md](../accounting/invariants.md))
- Payment/contribution allocation
- Transaction posting
- Concurrency control
- Idempotency of financial commands
- Ledger consistency and auditability

Flutter never computes authoritative financial balances itself, and never
mutates posted financial records directly — it always goes through
controlled backend commands. See
[docs/database/conventions.md](../database/conventions.md) for the
concrete rules this implies for schema and query design.
