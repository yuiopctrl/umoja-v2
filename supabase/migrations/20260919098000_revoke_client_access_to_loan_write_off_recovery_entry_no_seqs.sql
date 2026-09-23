-- Prompt 09F-B-03 (pre-deploy security audit): revoke client access to
-- the identity sequences backing loan_write_off_events.entry_no and
-- loan_recovery_events.entry_no.
--
-- Root cause: identical to 09F-A-05
-- (20260917090000_revoke_client_access_to_loan_obligation_adjustment_entry_no_seq.sql).
-- `entry_no bigint generated always as identity` (20260919090000)
-- implicitly creates its own backing sequence, which was never
-- explicitly referenced by any 09F-B migration — it silently inherited
-- this project's pre-existing `ALTER DEFAULT PRIVILEGES FOR ROLE
-- "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO
-- anon/authenticated/service_role` baseline. Live inspection (local)
-- confirmed anon and authenticated both held UPDATE (nextval/setval) on
-- both loan_write_off_events_entry_no_seq and
-- loan_recovery_events_entry_no_seq — the exact same exposure class
-- 09F-A-05 already fixed for loan_obligation_adjustments_entry_no_seq,
-- just not yet applied to these two new 09F-B sequences.
--
-- entry_no is not merely cosmetic: it is the monotonic ordering signal
-- rpc_reverse_loan_write_off's dependency guard and
-- rpc_post_loan_write_off/rpc_post_loan_recovery's "most recent
-- write-off for this loan" resolution rely on (see
-- 20260919094000_create_loan_write_off_rpcs.sql and
-- 20260919095000_create_loan_recovery_rpcs.sql). Client-callable
-- nextval()/setval() on either sequence is therefore a genuine
-- integrity concern for those guards, even though both tables already
-- structurally deny direct client INSERT/UPDATE/DELETE.
--
-- Scope (locked, matching 09F-A-05's precedent): this migration touches
-- ONLY these two objects. It does not alter the project's ALTER
-- DEFAULT PRIVILEGES policy (which would affect every future sequence
-- in the schema) and does not touch any other sequence. `postgres`
-- (table/sequence owner) and `service_role` (Supabase's trusted backend
-- role) are left untouched — the SECURITY DEFINER posting RPCs insert
-- under the function owner's privileges, never the calling client's, so
-- this revoke has zero effect on normal, authorized write-off/recovery
-- posting.

revoke all on sequence public.loan_write_off_events_entry_no_seq from anon, authenticated;
revoke all on sequence public.loan_recovery_events_entry_no_seq from anon, authenticated;

comment on sequence public.loan_write_off_events_entry_no_seq is
  'Backing sequence for loan_write_off_events.entry_no (Prompt 09F-B) —
  the monotonic ordering signal used by rpc_reverse_loan_write_off''s
  dependency guard and the "most recent write-off" resolution in
  rpc_post_loan_write_off/rpc_preview_loan_recovery/
  rpc_post_loan_recovery/rpc_get_loan_write_off_summary. USAGE/SELECT/
  UPDATE deliberately revoked from anon/authenticated (Prompt 09F-B-03):
  normal write-off posting happens entirely inside SECURITY DEFINER
  RPCs under the function owner''s privileges, so no client role ever
  needs direct sequence access.';

comment on sequence public.loan_recovery_events_entry_no_seq is
  'Backing sequence for loan_recovery_events.entry_no (Prompt 09F-B) —
  the monotonic ordering signal used by the recovery history ordering
  in rpc_get_loan_write_off_summary. USAGE/SELECT/UPDATE deliberately
  revoked from anon/authenticated (Prompt 09F-B-03): normal recovery
  posting happens entirely inside SECURITY DEFINER RPCs under the
  function owner''s privileges, so no client role ever needs direct
  sequence access.';
