# Member Identity Model

## Auth user ≠ group member

Umoja v2 deliberately keeps two related but distinct concepts:

- An **auth user**: a row in Supabase `auth.users`, created when someone
  signs up/signs in to the app. Identified by `auth.uid()`.
- A **group member**: a row in `public.group_memberships`, representing
  a person a group tracks (for future obligations such as contributions,
  loans, etc.). Identified by its own `id`.

A group member is not required to ever have an auth user. In practice:

- A Treasurer or Secretary commonly registers members from a physical
  register before those members ever install the app or create an
  account — sometimes they never do.
- `group_memberships.user_id` is therefore **nullable**. A membership
  with `user_id = null` is a fully valid, first-class row: it can be
  edited, assigned a `member_number`, and (in later modules) carry
  financial history.
- When a person does create/sign in to a Umoja account, and that
  account should be recognized as an existing member, the membership's
  `user_id` is the field that gets set — see "Future: linking" below.

This is why the tenancy chain is:

```
auth.users
    ↓
profiles
    ↓
group_memberships
    ↓
groups
```

and not a direct `auth.users → groups` relationship: a user's access to
a group's data always flows through an explicit `group_memberships` row
with `user_id = auth.uid()`, never through a permanent field on the
user itself (a person may belong to more than one group over time).

## Future requirement: linking an auth user to an existing member

Not implemented yet. Documented here so the eventual design has a
place to start from.

An existing `group_memberships` row with `user_id is null` will, in a
later prompt, need to become linkable to an authenticated Supabase user
— e.g. a member who registered by phone at a group meeting later
installs the app and wants their contribution/loan history to show up
under their own login.

This must go through a **controlled verification workflow** — it is
not implemented in this prompt, and must not be implemented as
unsafe phone-number-only auto-linking (matching on phone number alone
is not proof of identity: phone numbers are reassigned, shared, or
mistyped). Whatever the eventual mechanism (e.g. a group-admin-approved
claim, an OTP-verified match, or similar), it must ensure:

- the claiming user actually is the person the membership represents
- a membership can only ever be linked to one `user_id`
- an auth user cannot silently take over a membership's financial
  history without an explicit, auditable authorization step
- group/tenant isolation is preserved (a member of Group A cannot use
  this mechanism to attach themselves to a membership in Group B)

Until this workflow exists, members without an auth account remain
fully usable via `rpc_create_group_member` (see
[docs/database/authorization.md](../database/authorization.md)), and a
signed-in user's own memberships are always the ones where
`group_memberships.user_id = auth.uid()`.
