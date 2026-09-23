-- Prompt 09F-A-05 (security hardening): revoke client access to the
-- identity sequence backing loan_obligation_adjustments.entry_no.
--
-- Root cause: `entry_no bigint generated always as identity`
-- (20260916090000) implicitly creates its own backing sequence, which
-- was never explicitly referenced by any 09F-A migration — it silently
-- inherited this project's pre-existing
-- `ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT
-- ALL ON SEQUENCES TO anon/authenticated/service_role` baseline. Live
-- inspection confirmed anon and authenticated both held USAGE, SELECT
-- (currval), and UPDATE (nextval/setval) on it — the only per-object
-- sequence grant to anon/authenticated found anywhere in this schema;
-- every other identity/serial-backed object in the codebase's history
-- already has this explicitly revoked.
--
-- entry_no is not merely cosmetic: it is the monotonic ordering signal
-- rpc_reverse_loan_obligation_adjustment uses to decide "was a later
-- adjustment posted on this same target" (see
-- 20260916095000_create_loan_obligation_adjustment_reversal_rpc.sql).
-- Client-callable nextval()/setval() on the sequence is therefore a
-- genuine integrity concern for that guard, even though the table
-- itself already structurally denies direct client
-- INSERT/UPDATE/DELETE.
--
-- Scope (locked, section 3): this migration touches ONLY this one
-- object. It does not alter the project's ALTER DEFAULT PRIVILEGES
-- policy (which would affect every future sequence in the schema) and
-- does not touch any other sequence. `postgres` (table/sequence owner)
-- and `service_role` (Supabase's trusted backend role) are left
-- untouched — the SECURITY DEFINER posting RPCs insert under the
-- function owner's privileges, never the calling client's, so this
-- revoke has zero effect on normal, authorized adjustment posting.

revoke all on sequence public.loan_obligation_adjustments_entry_no_seq from anon, authenticated;

comment on sequence public.loan_obligation_adjustments_entry_no_seq is
  'Backing sequence for loan_obligation_adjustments.entry_no (Prompt
  09F-A) — the monotonic ordering signal used by
  rpc_reverse_loan_obligation_adjustment''s dependency guard. USAGE/
  SELECT/UPDATE deliberately revoked from anon/authenticated (Prompt
  09F-A-05): normal adjustment posting happens entirely inside
  SECURITY DEFINER RPCs under the function owner''s privileges, so no
  client role ever needs direct sequence access.';
