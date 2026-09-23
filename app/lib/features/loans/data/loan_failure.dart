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

  /// `LOAN_NOT_ACTIVE` (Prompt 09E) — early settlement/prepayment/
  /// restructure all require an ACTIVE loan.
  loanNotActive,

  /// `LOAN_ALREADY_FULLY_SETTLED` (Prompt 09E).
  alreadyFullySettled,

  /// `LOAN_PREPAYMENT_AMOUNT_MUST_BE_POSITIVE` /
  /// `LOAN_PREPAYMENT_EXCEEDS_FUTURE_PRINCIPAL` (Prompt 09E).
  prepaymentAmountInvalid,

  /// `LOAN_PREPAYMENT_BLOCKED_OVERDUE_PENALTY` (Prompt 09E section 3
  /// v1 lock).
  prepaymentBlockedOverduePenalty,

  /// `LOAN_PREPAYMENT_BLOCKED_OVERDUE_INTEREST` (Prompt 09E section 3
  /// v1 lock).
  prepaymentBlockedOverdueInterest,

  /// `LOAN_PREPAYMENT_REVERSAL_BLOCKED_SUBSEQUENT_ACTIVITY` (Prompt
  /// 09E section 9).
  prepaymentReversalBlockedSubsequentActivity,

  /// `LOAN_RESTRUCTURE_REASON_REQUIRED` (Prompt 09E).
  restructureReasonRequired,

  /// `LOAN_RESTRUCTURE_TERM_MUST_BE_POSITIVE` /
  /// `LOAN_RESTRUCTURE_FIRST_INSTALLMENT_DATE_MUST_BE_AFTER_EFFECTIVE_DATE`
  /// / `LOAN_RESTRUCTURE_INTEREST_RATE_MUST_BE_NON_NEGATIVE` (Prompt
  /// 09E).
  restructureInputInvalid,

  /// `LOAN_RESTRUCTURE_BLOCKED_OVERDUE_BALANCE` (Prompt 09E section 6
  /// v1 lock).
  restructureBlockedOverdueBalance,

  /// `LOAN_RESTRUCTURE_NOTHING_REMAINING` (Prompt 09E).
  restructureNothingRemaining,

  /// `LOAN_WAIVER_EXCEEDS_OUTSTANDING` (Prompt 09F-A).
  waiverExceedsOutstanding,

  /// `LOAN_ADJUSTMENT_TARGET_INVALID` (Prompt 09F-A).
  adjustmentTargetInvalid,

  /// `LOAN_FUTURE_INTEREST_NOT_WAIVABLE` (Prompt 09F-A).
  futureInterestNotWaivable,

  /// `LOAN_PRINCIPAL_ADJUSTMENT_PROHIBITED` (Prompt 09F-A).
  principalAdjustmentProhibited,

  /// `LOAN_CORRECTION_INCREASE_NOT_ALLOWED` (Prompt 09F-A) — interest
  /// correction increases are always rejected.
  correctionIncreaseNotAllowed,

  /// `LOAN_CORRECTION_INCREASE_EXCEEDS_BOUND` (Prompt 09F-A) — the
  /// corrected gross would exceed the charge's frozen-policy expected
  /// amount (09F-A-BLOCKER-01: no multiplier/tolerance/override).
  correctionIncreaseExceedsBound,

  /// `LOAN_CORRECTION_INCREASE_POLICY_UNAVAILABLE` (Prompt
  /// 09F-A-BLOCKER-01) — the target (e.g. a MIGRATED loan's OPENING
  /// penalty charge) has no frozen policy snapshot to reconcile a
  /// correction increase against.
  correctionIncreasePolicyUnavailable,

  /// `LOAN_CORRECTION_DECREASE_EXCEEDS_OUTSTANDING` (Prompt 09F-A).
  correctionDecreaseExceedsOutstanding,

  /// `LOAN_FUTURE_INTEREST_NOT_CORRECTABLE` (Prompt 09F-A-09, Defect C)
  /// — only earned/payable interest (due_date <= effective_date) may be
  /// CORRECTION_DECREASE-d; a not-yet-due installment is rejected. A
  /// dedicated code, distinct from [futureInterestNotWaivable], because
  /// that name is specific to waiver semantics.
  futureInterestNotCorrectable,

  /// The backend rejected a request for lacking an effective date
  /// (Prompt 09F-A-09, Defect B) — defense in depth: after Defect A's
  /// fix the client never sends an explicit null for this, but an
  /// explicit backend rejection must never degrade to a generic
  /// "unexpected" failure.
  adjustmentEffectiveDateRequired,

  /// `LOAN_ADJUSTMENT_AMOUNT_MUST_BE_POSITIVE` (Prompt 09F-A).
  adjustmentAmountInvalid,

  /// `LOAN_ADJUSTMENT_REASON_REQUIRED` (Prompt 09F-A).
  adjustmentReasonRequired,

  /// `LOAN_ADJUSTMENT_OTHER_NOTE_REQUIRED` (Prompt 09F-A).
  adjustmentOtherNoteRequired,

  /// `LOAN_ADJUSTMENT_ALREADY_REVERSED` (Prompt 09F-A).
  adjustmentAlreadyReversed,

  /// `LOAN_ADJUSTMENT_REVERSAL_BLOCKED_SUBSEQUENT_ACTIVITY` (Prompt
  /// 09F-A).
  adjustmentReversalBlockedSubsequentActivity,

  /// `LOAN_ADJUSTMENT_REVERSAL_NOT_SUPPORTED` (Prompt 09F-A) — a
  /// reversal of a reversal is not supported.
  adjustmentReversalNotSupported,

  /// `LOAN_WRITE_OFF_NOTHING_OUTSTANDING` (Prompt 09F-B) — an ACTIVE
  /// loan with nothing outstanding to write off. In practice
  /// unreachable through normal flows (a zero-outstanding ACTIVE loan
  /// auto-closes first via `loan_account_recheck_closure`), but kept as
  /// a defensive server-side guard.
  writeOffNothingOutstanding,

  /// `LOAN_RECOVERY_TARGET_NOT_WRITTEN_OFF` (Prompt 09F-B) — a recovery
  /// was attempted against a loan that is not (or no longer) WRITTEN_OFF.
  recoveryTargetNotWrittenOff,

  /// `LOAN_RECOVERY_EXCEEDS_REMAINING_BALANCE` (Prompt 09F-B) — the
  /// proposed recovery amount exceeds the write-off's remaining
  /// recoverable balance; never a partial silent clamp.
  recoveryExceedsRemainingBalance,

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
