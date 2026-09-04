/// Coarse, user-presentable classification of a Payments/Wallet
/// failure (Prompt 07). UI code should switch on
/// [PaymentFailure.type], never pattern-match [PaymentFailure.message]
/// strings.
enum PaymentFailureType {
  amountMustBePositive,

  /// `FINANCIAL_ACCOUNT_INACTIVE`.
  financialAccountInactive,

  /// `PAYMENT_IDEMPOTENCY_KEY_CONFLICT`: a retried submission carried a
  /// different amount/member/account/date/method/reference than the
  /// original — never silently double-posted, never silently ignored.
  idempotencyKeyConflict,

  /// `PAYMENT_ALREADY_REVERSED`.
  paymentAlreadyReversed,

  /// `PAYMENT_REVERSAL_BLOCKED_WALLET_CREDIT_CONSUMED`: the wallet
  /// credit this payment created has already been spent elsewhere —
  /// never silently reverses unrelated wallet value.
  reversalBlockedWalletCreditConsumed,

  /// `LOAN_PREPAYMENT_REVERSAL_BLOCKED_SUBSEQUENT_ACTIVITY` (Prompt
  /// 09E-UAT-BLOCKER-04): reversing this principal prepayment would
  /// resurrect a schedule that a later prepayment, restructure, or
  /// early settlement has already superseded — an expected domain
  /// rejection, never an unexpected system failure.
  reversalBlockedSubsequentActivity,

  reversalReasonRequired,

  /// `WALLET_INSUFFICIENT_BALANCE`.
  walletInsufficientBalance,

  /// `WALLET_ALLOCATION_NOTHING_TO_ALLOCATE`: no outstanding obligation
  /// exists to apply the wallet balance against.
  walletAllocationNothingToAllocate,

  notFound,
  permissionDenied,
  network,
  unexpected,
}

/// A safe-to-display Payments/Wallet failure. Never wraps a raw
/// PostgREST/Postgres exception message or stack trace.
class PaymentFailure implements Exception {
  const PaymentFailure(this.type, this.message);

  final PaymentFailureType type;
  final String message;

  @override
  String toString() => message;
}
