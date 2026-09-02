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

  /// `LOAN_PRODUCT_PENALTY_TYPE_REQUIRED` /
  /// `LOAN_PRODUCT_PENALTY_FREQUENCY_REQUIRED` /
  /// `LOAN_PRODUCT_PENALTY_GRACE_DAYS_INVALID` (Prompt 09D).
  penaltyConfigInvalid,

  /// `LOAN_PRODUCT_PENALTY_FIXED_AMOUNT_REQUIRED` (Prompt 09D).
  penaltyFixedAmountRequired,

  /// `LOAN_PRODUCT_PENALTY_RATE_REQUIRED` (Prompt 09D).
  penaltyRateRequired,

  /// `LOAN_OPENING_ORIGINAL_PRINCIPAL_MUST_BE_POSITIVE`
  /// (Prompt 09D-UAT-BLOCKER-01).
  openingOriginalPrincipalInvalid,

  /// `LOAN_OPENING_PRINCIPAL_ARREARS_EXCEEDS_OUTSTANDING`
  /// (Prompt 09D-UAT-BLOCKER-01).
  openingPrincipalArrearsExceedsOutstanding,

  /// `LOAN_OPENING_ARREARS_DUE_DATE_REQUIRED` /
  /// `LOAN_OPENING_ARREARS_DUE_DATE_AFTER_AS_OF`
  /// (Prompt 09D-UAT-BLOCKER-01).
  openingArrearsDueDateInvalid,

  /// `LOAN_OPENING_ARREARS_INSTALLMENTS_INVALID` /
  /// `LOAN_OPENING_ARREARS_COMPONENT_NEGATIVE` /
  /// `LOAN_OPENING_ARREARS_ROW_EMPTY` (Prompt 09D-UAT-BLOCKER-02).
  openingArrearsInstallmentInvalid,

  /// `LOAN_OPENING_ARREARS_DUPLICATE_DUE_DATE` (Prompt
  /// 09D-UAT-BLOCKER-02).
  openingArrearsDuplicateDueDate,

  /// `LOAN_OPENING_SIMPLE_ARREARS_BELOW_CONTRACTUAL` (Prompt
  /// 09D-UAT-BLOCKER-03) — the entered total historical arrears is less
  /// than the derived contractual arrears; suggest Detailed Import.
  openingSimpleArrearsBelowContractual,

  /// `LOAN_OPENING_SIMPLE_CONTRACTED_INTEREST_INVALID` /
  /// `LOAN_OPENING_SIMPLE_INSTALLMENT_AMOUNT_INVALID` /
  /// `LOAN_OPENING_SIMPLE_HISTORICAL_COUNT_INVALID` /
  /// `LOAN_OPENING_SIMPLE_TOTAL_ARREARS_INVALID` /
  /// `LOAN_OPENING_SIMPLE_RECONSTRUCTION_INCONSISTENT` /
  /// `LOAN_OPENING_MODE_INVALID` (Prompt 09D-UAT-BLOCKER-03).
  openingSimpleInputInvalid,

  /// `LOAN_OPENING_REMAINING_SCHEDULE_INCONSISTENT` /
  /// `LOAN_OPENING_NEXT_DUE_DATE_REQUIRED` (Prompt 09D-UAT-BLOCKER-01).
  openingRemainingScheduleInvalid,

  /// `LOAN_OPENING_NO_OUTSTANDING_POSITION` (Prompt
  /// 09D-UAT-BLOCKER-01) — nothing left to migrate.
  openingNoOutstandingPosition,

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
