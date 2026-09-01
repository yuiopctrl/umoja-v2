/// Coarse, user-presentable classification of a Loans-module failure
/// (Prompt 09A). UI code should switch on [LoanFailure.type], never
/// pattern-match [LoanFailure.message] strings.
enum LoanFailureType {
  /// Loan product: blank code/name.
  nameRequired,

  /// A duplicate product code within the group (23505).
  duplicateCode,

  /// `LOAN_PRODUCT_MINIMUM_PRINCIPAL_MUST_BE_POSITIVE`.
  minimumPrincipalMustBePositive,

  /// `LOAN_PRODUCT_MAXIMUM_PRINCIPAL_BELOW_MINIMUM`.
  maximumPrincipalBelowMinimum,

  /// `LOAN_PRODUCT_MINIMUM_TERM_MUST_BE_POSITIVE`.
  minimumTermMustBePositive,

  /// `LOAN_PRODUCT_MAXIMUM_TERM_BELOW_MINIMUM`.
  maximumTermBelowMinimum,

  /// `LOAN_PRODUCT_INTEREST_RATE_INVALID`.
  interestRateInvalid,

  /// `LOAN_PRODUCT_INACTIVE`.
  productInactive,

  /// `LOAN_ACCOUNT_PRINCIPAL_MUST_BE_POSITIVE`.
  principalMustBePositive,

  /// `LOAN_ACCOUNT_PRINCIPAL_BELOW_PRODUCT_MINIMUM`.
  principalBelowProductMinimum,

  /// `LOAN_ACCOUNT_PRINCIPAL_ABOVE_PRODUCT_MAXIMUM`.
  principalAboveProductMaximum,

  /// `LOAN_ACCOUNT_TERM_OUT_OF_PRODUCT_RANGE`.
  termOutOfProductRange,

  /// `LOAN_ACCOUNT_BORROWER_NOT_ACTIVE`.
  borrowerNotActive,

  /// `LOAN_ACCOUNT_NOT_DRAFT`.
  notDraft,

  /// `LOAN_ACCOUNT_SCHEDULE_MISSING` / `LOAN_ACCOUNT_SCHEDULE_MISMATCH`
  /// (Prompt 09B submit/approve).
  scheduleMismatch,

  /// `LOAN_ACCOUNT_NOT_SUBMITTED` (Prompt 09B approve/reject).
  notSubmitted,

  /// `LOAN_ACCOUNT_REJECTION_REASON_REQUIRED` (Prompt 09B).
  rejectionReasonRequired,

  /// `LOAN_ACCOUNT_CANCELLATION_REASON_REQUIRED` (Prompt 09B).
  cancellationReasonRequired,

  /// `LOAN_ACCOUNT_NOT_CANCELLABLE` (Prompt 09B — already
  /// disbursed/active/closed/rejected/cancelled).
  notCancellable,

  /// `LOAN_ACCOUNT_NOT_APPROVED` (Prompt 09B disburse).
  notApproved,

  /// `LOAN_ACCOUNT_ALREADY_DISBURSED` (Prompt 09B).
  alreadyDisbursed,

  /// `FINANCIAL_ACCOUNT_INACTIVE` (Prompt 09B disburse).
  financialAccountInactive,

  /// `LOAN_DISBURSEMENT_INSUFFICIENT_BALANCE` (Prompt 09B).
  insufficientBalance,

  /// Not found (product, membership, or loan account not in group).
  notFound,

  /// 42501.
  permissionDenied,

  /// Network error. Check your connection and try again.
  network,

  /// Something went wrong. Please try again.
  unexpected,
}

class LoanFailure implements Exception {
  const LoanFailure(this.type, this.message);

  final LoanFailureType type;
  final String message;

  @override
  String toString() => message;
}
