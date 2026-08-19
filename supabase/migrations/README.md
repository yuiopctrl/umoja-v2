# Migrations

All schema changes are made through versioned migrations in this directory,
created with `supabase migration new <name>`. The identity + group tenancy +
authorization foundation (profiles, groups, group_memberships, roles/
permissions, RLS, RPCs) exists. No business/financial domain schema exists
yet.

See [docs/database/conventions.md](../../docs/database/conventions.md) for
the rules future migrations must follow, and
[docs/database/authorization.md](../../docs/database/authorization.md) for
how the identity/tenancy foundation works.
