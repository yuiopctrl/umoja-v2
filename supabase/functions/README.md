# Edge Functions

Supabase Edge Functions live here. Controlled financial mutations that
need logic beyond RLS/SQL are implemented as transactional database
functions/RPCs first (see
[docs/database/conventions.md](../../docs/database/conventions.md));
Edge Functions are added only when that is not sufficient — e.g. a
third-party HTTP integration that cannot be called from Postgres.

## `send-sms-hook`

Supabase Auth's Send SMS HTTP Hook, delivering phone-OTP SMS through
NextSMS. See
[docs/product/authentication.md](../../docs/product/authentication.md)
for the full architecture, required secrets, and deployment/dashboard
configuration steps. This hook is authentication-only — it is not the
general Umoja notification/messaging engine.
