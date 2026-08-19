# Database Conventions

These rules govern all future schema and database work in Umoja v2. They
apply regardless of which module (contributions, payments, loans, wallet,
etc.) is being implemented.

1. **Primary keys are PostgreSQL UUIDs** unless another key type is
   explicitly justified in the migration or an ADR.

2. **Tenant isolation.** Every group/tenant-owned business row must
   eventually include a `group_id` column where applicable, used to
   enforce isolation between vikundi.

3. **`created_at` is an audit timestamp.** It records when a row was
   written to the database. It is not a business/financial timestamp.

4. **`effective_at` is the financial/business effective timestamp.** It
   records when a transaction or event is effective for accounting
   purposes. `effective_at` and `created_at` must never be conflated —
   a record can be created on one date but be effective on another
   (e.g. backdated or corrected entries).

5. **No floating-point money.** Monetary values must never use `float` or
   `double precision`. Use PostgreSQL `numeric` with an explicit scale, or
   an integer-safe minor-unit representation (e.g. cents), decided
   per-schema and documented at the point of use.

6. **Posted financial records are immutable.** Once a financial record is
   posted, it is not updated or deleted in place. Corrections are made
   through one of:
   - adjustment
   - reversal
   - waiver
   - reallocation

   as appropriate to the situation.

7. **No hard delete of posted financial transactions.** Ever.

8. **Financial mutations go through controlled, transactional
   database/backend commands** (e.g. SQL functions/RPCs executed within a
   transaction), not ad hoc multi-statement writes from the client.

9. **Flutter must not directly mutate financial ledger tables.** All
   ledger-affecting writes happen through controlled backend commands.

10. **Idempotency.** Any financial command that could be retried or
    double-submitted (e.g. due to network retry or duplicate client
    action) must be safe to execute more than once with the same input.

11. **One cashbook.** All real cash movement must eventually flow into a
    single, unified cashbook architecture — no parallel/shadow cash
    ledgers per module.

12. **Row Level Security (RLS) must be enabled** for all tenant/group-owned
    tables once business schema is implemented. There is no business
    schema yet, so no RLS policies exist yet.

13. **Service-role secrets never reach Flutter.** The service role key is
    a backend-only credential and must never be embedded in, or
    accessible from, the Flutter client.

14. **All schema changes go through migrations** in `supabase/migrations/`.
    No manual/ad hoc schema edits against any environment.

See also [docs/accounting/invariants.md](../accounting/invariants.md) for
the accounting principles that constrain how these tables are eventually
designed and written to.
