/// Coarse, user-presentable classification of a Financial Accounts
/// failure (Prompt 08A). UI code should switch on
/// [FinancialAccountFailure.type], never pattern-match
/// [FinancialAccountFailure.message] strings.
enum FinancialAccountFailureType {
  /// Local + backend: a blank account name.
  nameRequired,

  /// A duplicate account name within the group (23505).
  duplicateName,

  /// `FINANCIAL_ACCOUNT_OPENING_BALANCE_MUST_BE_POSITIVE`.
  openingBalanceMustBePositive,

  /// An account id did not resolve in this group.
  notFound,

  /// `FINANCIAL_ACCOUNT_TRANSFER_SAME_ACCOUNT`.
  transferSameAccount,

  /// `FINANCIAL_ACCOUNT_TRANSFER_AMOUNT_MUST_BE_POSITIVE`.
  transferAmountMustBePositive,

  /// `FINANCIAL_ACCOUNT_INSUFFICIENT_BALANCE`.
  insufficientBalance,

  /// `FINANCIAL_ACCOUNT_INACTIVE`: one side of a transfer is inactive.
  accountInactive,

  /// "Effective date is required" (22023): the RPC's own
  /// `default current_date` never applies once an explicit JSON
  /// `null` is sent for the argument (see UAT-DIAG-02) — every caller
  /// must always supply an explicit date. Present here as a defensive
  /// mapping only; the transfer screen always sends one.
  effectiveDateRequired,

  /// `FINANCIAL_MANUAL_ENTRY_AMOUNT_MUST_BE_POSITIVE` /
  /// `FINANCIAL_ADJUSTMENT_AMOUNT_MUST_BE_POSITIVE` (Prompt 08B).
  amountMustBePositive,

  /// `FINANCIAL_CATEGORY_WRONG_TYPE` (Prompt 08B): an INCOME category
  /// used for an expense posting, or vice versa.
  categoryWrongType,

  /// `FINANCIAL_CATEGORY_INACTIVE` (Prompt 08B).
  categoryInactive,

  /// `FINANCIAL_MANUAL_ENTRY_IDEMPOTENCY_KEY_CONFLICT` /
  /// `FINANCIAL_ADJUSTMENT_IDEMPOTENCY_KEY_CONFLICT` (Prompt 08B).
  idempotencyKeyConflict,

  /// `FINANCIAL_ENTRY_REVERSAL_REASON_REQUIRED` (Prompt 08B).
  reversalReasonRequired,

  /// `FINANCIAL_MANUAL_ENTRY_ALREADY_REVERSED` (Prompt 08B).
  entryAlreadyReversed,

  /// `FINANCIAL_ADJUSTMENT_REASON_REQUIRED` (Prompt 08B).
  adjustmentReasonRequired,

  /// `FINANCIAL_RECONCILIATION_CANCELLATION_REASON_REQUIRED` (Prompt
  /// 08B).
  reconciliationCancellationReasonRequired,

  /// `FINANCIAL_RECONCILIATION_ALREADY_CANCELLED` (Prompt 08B).
  reconciliationAlreadyCancelled,

  permissionDenied,
  network,
  unexpected,
}

/// A safe-to-display Financial Accounts failure. Never wraps a raw
/// PostgREST/Postgres exception message or stack trace.
class FinancialAccountFailure implements Exception {
  const FinancialAccountFailure(this.type, this.message);

  final FinancialAccountFailureType type;
  final String message;

  @override
  String toString() => message;
}
