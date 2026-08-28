-- Prompt 06C: Contribution Adjustments, Waivers & Opening Balances.
--
-- ALTER TYPE ... ADD VALUE cannot be used in the same transaction as any
-- statement that references the new value (e.g. a CHECK constraint or
-- RPC body naming it) — Postgres rejects "unsafe use of new value of
-- enum type" if both happen together. This migration therefore does
-- nothing except extend the enum; every constraint/RPC/permission that
-- references ADJUSTMENT/WAIVER/OPENING_BALANCE lives in the next
-- migration file instead.
--
-- 06A already created public.contribution_charge_component_type with
-- BASE/PENALTY. Extending it here — never modifying the 06A migration
-- that created it.

alter type public.contribution_charge_component_type add value 'ADJUSTMENT';
alter type public.contribution_charge_component_type add value 'WAIVER';
alter type public.contribution_charge_component_type add value 'OPENING_BALANCE';
