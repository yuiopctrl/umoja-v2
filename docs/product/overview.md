# Umoja v2 — Product Overview

Umoja v2 is a financial-management application for community groups
(vikundi). It is a new, from-scratch project — not a migration of any
previous Umoja codebase.

## Scope (future, incremental)

Umoja v2 will eventually support:

- Members
- Contributions
- Contribution periods and member charges
- Penalties and arrears
- Pass-through collections such as Mzunguko / Rambirambi
- Member payments
- Payment allocation
- Member wallet / advance credit
- Hisa / share capital
- Loans
- Financial accounts
- Cashbook
- Income and expenses
- Reconciliation
- Financial reports

None of these are implemented yet. This repository currently contains
only the application foundation: project structure, client/backend
bootstrap, architecture conventions, and documentation.

Detailed accounting and business rules are implemented incrementally,
from locked specifications, in later scoped tasks — see
[docs/accounting/invariants.md](../accounting/invariants.md) for the
architectural principles that already constrain that future work.
