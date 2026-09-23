import '../../features/auth/data/auth_failure.dart';
import '../../features/contributions/data/contribution_failure.dart';
import '../../features/financial_accounts/data/financial_account_failure.dart';
import '../../features/loans/data/loan_failure.dart';
import '../../features/members/data/member_failure.dart';
import '../../features/payments/data/payment_failure.dart';
import '../../l10n/app_localizations.dart';

/// Localizes an [AuthFailureType] for display — the single place this
/// mapping happens, so no screen pattern-matches [AuthFailure.message]
/// (which stays English-only, for logs).
String authFailureMessage(AppLocalizations l10n, AuthFailureType type) {
  return switch (type) {
    AuthFailureType.invalidPhone => l10n.authErrorInvalidPhone,
    AuthFailureType.invalidOtp => l10n.authErrorInvalidOtp,
    AuthFailureType.otpExpired => l10n.authErrorOtpExpired,
    AuthFailureType.tooManyRequests => l10n.authErrorTooManyRequests,
    AuthFailureType.network => l10n.authErrorNetwork,
    AuthFailureType.unexpected => l10n.authErrorUnexpected,
    AuthFailureType.invalidCredentials => l10n.authErrorInvalidCredentials,
    AuthFailureType.pinLocked => l10n.authErrorPinLocked,
  };
}

/// Localizes a [MemberFailureType] for display — the single place this
/// mapping happens, so no screen pattern-matches [MemberFailure.message].
String memberFailureMessage(AppLocalizations l10n, MemberFailureType type) {
  return switch (type) {
    MemberFailureType.accountDisabled => l10n.memberErrorAccountDisabled,
    MemberFailureType.lastAdminRequired => l10n.memberErrorLastAdminRequired,
    MemberFailureType.invalidStatusTransition =>
      l10n.memberErrorInvalidStatusTransition,
    MemberFailureType.duplicateMemberNumber =>
      l10n.memberErrorDuplicateMemberNumber,
    MemberFailureType.permissionDenied => l10n.memberErrorPermissionDenied,
    MemberFailureType.notFound => l10n.memberErrorNotFound,
    MemberFailureType.network => l10n.memberErrorNetwork,
    MemberFailureType.unexpected => l10n.memberErrorUnexpected,
    MemberFailureType.nameRequired => l10n.memberNameRequiredError,
    MemberFailureType.rejoinConflict => l10n.memberErrorRejoinConflict,
  };
}

/// Localizes a [ContributionFailureType] for display — the single place
/// this mapping happens, so no screen pattern-matches
/// [ContributionFailure.message].
String contributionFailureMessage(
  AppLocalizations l10n,
  ContributionFailureType type,
) {
  return switch (type) {
    ContributionFailureType.nameRequired => l10n.contributionErrorNameRequired,
    ContributionFailureType.memberSavingsNotAvailable =>
      l10n.contributionErrorMemberSavingsNotAvailable,
    ContributionFailureType.accountingLocked =>
      l10n.contributionErrorAccountingLocked,
    ContributionFailureType.setupConfigLocked =>
      l10n.contributionErrorSetupConfigLocked,
    ContributionFailureType.typeInactive => l10n.contributionErrorTypeInactive,
    ContributionFailureType.setupInactive =>
      l10n.contributionErrorSetupInactive,
    ContributionFailureType.duplicateName =>
      l10n.contributionErrorDuplicateName,
    ContributionFailureType.invalidDates => l10n.contributionErrorInvalidDates,
    ContributionFailureType.dueDateRequired =>
      l10n.contributionErrorDueDateRequired,
    ContributionFailureType.duplicateMonthlyPeriod =>
      l10n.contributionErrorDuplicateMonthlyPeriod,
    ContributionFailureType.periodNotEditable =>
      l10n.contributionErrorPeriodNotEditable,
    ContributionFailureType.setupNotCustomAmount =>
      l10n.contributionErrorSetupNotCustomAmount,
    ContributionFailureType.membershipNotFound =>
      l10n.contributionErrorMembershipNotFound,
    ContributionFailureType.invalidAmount =>
      l10n.contributionErrorInvalidAmount,
    ContributionFailureType.periodNotPreviewable =>
      l10n.contributionErrorPeriodNotPreviewable,
    ContributionFailureType.periodNotOpenable =>
      l10n.contributionErrorPeriodNotOpenable,
    ContributionFailureType.missingCustomAmounts =>
      l10n.contributionErrorMissingCustomAmounts,
    ContributionFailureType.periodNotOpen =>
      l10n.contributionErrorPeriodNotOpen,
    ContributionFailureType.memberAlreadyCharged =>
      l10n.contributionErrorMemberAlreadyCharged,
    ContributionFailureType.amountRequired =>
      l10n.contributionErrorAmountRequired,
    ContributionFailureType.periodNotCancellable =>
      l10n.contributionErrorPeriodNotCancellable,
    ContributionFailureType.notFound => l10n.contributionErrorNotFound,
    ContributionFailureType.noPenaltyPolicy =>
      l10n.contributionErrorNoPenaltyPolicy,
    ContributionFailureType.adjustmentAmountRequired =>
      l10n.contributionErrorAdjustmentAmountRequired,
    ContributionFailureType.adjustmentReasonRequired =>
      l10n.contributionErrorAdjustmentReasonRequired,
    ContributionFailureType.adjustmentWouldMakeObligationNegative =>
      l10n.contributionErrorAdjustmentWouldMakeObligationNegative,
    ContributionFailureType.waiverAmountMustBePositive =>
      l10n.contributionErrorWaiverAmountMustBePositive,
    ContributionFailureType.waiverReasonRequired =>
      l10n.contributionErrorWaiverReasonRequired,
    ContributionFailureType.waiverExceedsNetAssessed =>
      l10n.contributionErrorWaiverExceedsNetAssessed,
    ContributionFailureType.openingBalanceAmountMustBePositive =>
      l10n.contributionErrorOpeningBalanceAmountMustBePositive,
    ContributionFailureType.openingBalanceAlreadyImported =>
      l10n.contributionErrorOpeningBalanceAlreadyImported,
    ContributionFailureType.permissionDenied =>
      l10n.contributionErrorPermissionDenied,
    ContributionFailureType.network => l10n.contributionErrorNetwork,
    ContributionFailureType.unexpected => l10n.contributionErrorUnexpected,
  };
}

/// Localizes a [FinancialAccountFailureType] for display — the single
/// place this mapping happens, so no screen pattern-matches
/// [FinancialAccountFailure.message].
String financialAccountFailureMessage(
  AppLocalizations l10n,
  FinancialAccountFailureType type,
) {
  return switch (type) {
    FinancialAccountFailureType.nameRequired =>
      l10n.financialAccountErrorNameRequired,
    FinancialAccountFailureType.duplicateName =>
      l10n.financialAccountErrorDuplicateName,
    FinancialAccountFailureType.openingBalanceMustBePositive =>
      l10n.financialAccountErrorOpeningBalanceMustBePositive,
    FinancialAccountFailureType.notFound => l10n.financialAccountErrorNotFound,
    FinancialAccountFailureType.transferSameAccount =>
      l10n.financialAccountErrorTransferSameAccount,
    FinancialAccountFailureType.transferAmountMustBePositive =>
      l10n.financialAccountErrorTransferAmountMustBePositive,
    FinancialAccountFailureType.insufficientBalance =>
      l10n.financialAccountErrorInsufficientBalance,
    FinancialAccountFailureType.accountInactive =>
      l10n.financialAccountErrorAccountInactive,
    FinancialAccountFailureType.effectiveDateRequired =>
      l10n.financialAccountErrorEffectiveDateRequired,
    FinancialAccountFailureType.amountMustBePositive =>
      l10n.financialAccountErrorAmountMustBePositive,
    FinancialAccountFailureType.categoryWrongType =>
      l10n.financialAccountErrorCategoryWrongType,
    FinancialAccountFailureType.categoryInactive =>
      l10n.financialAccountErrorCategoryInactive,
    FinancialAccountFailureType.idempotencyKeyConflict =>
      l10n.financialAccountErrorIdempotencyKeyConflict,
    FinancialAccountFailureType.reversalReasonRequired =>
      l10n.financialAccountErrorReversalReasonRequired,
    FinancialAccountFailureType.entryAlreadyReversed =>
      l10n.financialAccountErrorEntryAlreadyReversed,
    FinancialAccountFailureType.adjustmentReasonRequired =>
      l10n.financialAccountErrorAdjustmentReasonRequired,
    FinancialAccountFailureType.reconciliationCancellationReasonRequired =>
      l10n.financialAccountErrorReconciliationCancellationReasonRequired,
    FinancialAccountFailureType.reconciliationAlreadyCancelled =>
      l10n.financialAccountErrorReconciliationAlreadyCancelled,
    FinancialAccountFailureType.permissionDenied =>
      l10n.financialAccountErrorPermissionDenied,
    FinancialAccountFailureType.network => l10n.financialAccountErrorNetwork,
    FinancialAccountFailureType.unexpected =>
      l10n.financialAccountErrorUnexpected,
  };
}

/// Localizes a [LoanFailureType] for display — the single place this
/// mapping happens, so no screen pattern-matches [LoanFailure.message].
String loanFailureMessage(AppLocalizations l10n, LoanFailureType type) {
  return switch (type) {
    LoanFailureType.nameRequired => l10n.loanErrorNameRequired,
    LoanFailureType.duplicateCode => l10n.loanErrorDuplicateCode,
    LoanFailureType.minimumPrincipalMustBePositive =>
      l10n.loanErrorMinimumPrincipalMustBePositive,
    LoanFailureType.maximumPrincipalBelowMinimum =>
      l10n.loanErrorMaximumPrincipalBelowMinimum,
    LoanFailureType.minimumTermMustBePositive =>
      l10n.loanErrorMinimumTermMustBePositive,
    LoanFailureType.maximumTermBelowMinimum =>
      l10n.loanErrorMaximumTermBelowMinimum,
    LoanFailureType.interestRateInvalid => l10n.loanErrorInterestRateInvalid,
    LoanFailureType.productInactive => l10n.loanErrorProductInactive,
    LoanFailureType.principalMustBePositive =>
      l10n.loanErrorPrincipalMustBePositive,
    LoanFailureType.principalBelowProductMinimum =>
      l10n.loanErrorPrincipalBelowProductMinimum,
    LoanFailureType.principalAboveProductMaximum =>
      l10n.loanErrorPrincipalAboveProductMaximum,
    LoanFailureType.termOutOfProductRange =>
      l10n.loanErrorTermOutOfProductRange,
    LoanFailureType.borrowerNotActive => l10n.loanErrorBorrowerNotActive,
    LoanFailureType.notDraft => l10n.loanErrorNotDraft,
    LoanFailureType.scheduleMismatch => l10n.loanErrorScheduleMismatch,
    LoanFailureType.notSubmitted => l10n.loanErrorNotSubmitted,
    LoanFailureType.rejectionReasonRequired =>
      l10n.loanErrorRejectionReasonRequired,
    LoanFailureType.cancellationReasonRequired =>
      l10n.loanErrorCancellationReasonRequired,
    LoanFailureType.notCancellable => l10n.loanErrorNotCancellable,
    LoanFailureType.notApproved => l10n.loanErrorNotApproved,
    LoanFailureType.alreadyDisbursed => l10n.loanErrorAlreadyDisbursed,
    LoanFailureType.financialAccountInactive =>
      l10n.loanErrorFinancialAccountInactive,
    LoanFailureType.insufficientBalance => l10n.loanErrorInsufficientBalance,
    LoanFailureType.penaltyConfigInvalid => l10n.loanErrorPenaltyConfigInvalid,
    LoanFailureType.penaltyFixedAmountRequired =>
      l10n.loanErrorPenaltyFixedAmountRequired,
    LoanFailureType.penaltyRateRequired => l10n.loanErrorPenaltyRateRequired,
    LoanFailureType.openingOriginalPrincipalInvalid =>
      l10n.loanErrorOpeningOriginalPrincipalInvalid,
    LoanFailureType.openingPrincipalArrearsExceedsOutstanding =>
      l10n.loanErrorOpeningPrincipalArrearsExceedsOutstanding,
    LoanFailureType.openingArrearsDueDateInvalid =>
      l10n.loanErrorOpeningArrearsDueDateInvalid,
    LoanFailureType.openingArrearsInstallmentInvalid =>
      l10n.loanErrorOpeningArrearsInstallmentInvalid,
    LoanFailureType.openingArrearsDuplicateDueDate =>
      l10n.loanErrorOpeningArrearsDuplicateDueDate,
    LoanFailureType.openingSimpleArrearsBelowContractual =>
      l10n.loanErrorOpeningSimpleArrearsBelowContractual,
    LoanFailureType.openingSimpleInputInvalid =>
      l10n.loanErrorOpeningSimpleInputInvalid,
    LoanFailureType.openingRemainingScheduleInvalid =>
      l10n.loanErrorOpeningRemainingScheduleInvalid,
    LoanFailureType.openingNoOutstandingPosition =>
      l10n.loanErrorOpeningNoOutstandingPosition,
    LoanFailureType.loanNotActive => l10n.loanErrorLoanNotActive,
    LoanFailureType.alreadyFullySettled => l10n.loanErrorAlreadyFullySettled,
    LoanFailureType.prepaymentAmountInvalid =>
      l10n.loanErrorPrepaymentAmountInvalid,
    LoanFailureType.prepaymentBlockedOverduePenalty =>
      l10n.loanErrorPrepaymentBlockedOverduePenalty,
    LoanFailureType.prepaymentBlockedOverdueInterest =>
      l10n.loanErrorPrepaymentBlockedOverdueInterest,
    LoanFailureType.prepaymentReversalBlockedSubsequentActivity =>
      l10n.loanErrorPrepaymentReversalBlockedSubsequentActivity,
    LoanFailureType.restructureReasonRequired =>
      l10n.loanErrorRestructureReasonRequired,
    LoanFailureType.restructureInputInvalid =>
      l10n.loanErrorRestructureInputInvalid,
    LoanFailureType.restructureBlockedOverdueBalance =>
      l10n.loanErrorRestructureBlockedOverdueBalance,
    LoanFailureType.restructureNothingRemaining =>
      l10n.loanErrorRestructureNothingRemaining,
    LoanFailureType.waiverExceedsOutstanding =>
      l10n.loanErrorWaiverExceedsOutstanding,
    LoanFailureType.adjustmentTargetInvalid =>
      l10n.loanErrorAdjustmentTargetInvalid,
    LoanFailureType.futureInterestNotWaivable =>
      l10n.loanErrorFutureInterestNotWaivable,
    LoanFailureType.principalAdjustmentProhibited =>
      l10n.loanErrorPrincipalAdjustmentProhibited,
    LoanFailureType.correctionIncreaseNotAllowed =>
      l10n.loanErrorCorrectionIncreaseNotAllowed,
    LoanFailureType.correctionIncreaseExceedsBound =>
      l10n.loanErrorCorrectionIncreaseExceedsBound,
    LoanFailureType.correctionIncreasePolicyUnavailable =>
      l10n.loanErrorCorrectionIncreasePolicyUnavailable,
    LoanFailureType.correctionDecreaseExceedsOutstanding =>
      l10n.loanErrorCorrectionDecreaseExceedsOutstanding,
    LoanFailureType.futureInterestNotCorrectable =>
      l10n.loanErrorFutureInterestNotCorrectable,
    LoanFailureType.adjustmentEffectiveDateRequired =>
      l10n.loanErrorAdjustmentEffectiveDateRequired,
    LoanFailureType.adjustmentAmountInvalid =>
      l10n.loanErrorAdjustmentAmountInvalid,
    LoanFailureType.adjustmentReasonRequired =>
      l10n.loanErrorAdjustmentReasonRequired,
    LoanFailureType.adjustmentOtherNoteRequired =>
      l10n.loanErrorAdjustmentOtherNoteRequired,
    LoanFailureType.adjustmentAlreadyReversed =>
      l10n.loanErrorAdjustmentAlreadyReversed,
    LoanFailureType.adjustmentReversalBlockedSubsequentActivity =>
      l10n.loanErrorAdjustmentReversalBlockedSubsequentActivity,
    LoanFailureType.adjustmentReversalNotSupported =>
      l10n.loanErrorAdjustmentReversalNotSupported,
    LoanFailureType.notFound => l10n.loanErrorNotFound,
    LoanFailureType.permissionDenied => l10n.loanErrorPermissionDenied,
    LoanFailureType.network => l10n.loanErrorNetwork,
    LoanFailureType.unexpected => l10n.loanErrorUnexpected,
  };
}

/// Localizes a [PaymentFailureType] for display — the single place
/// this mapping happens, so no screen pattern-matches
/// [PaymentFailure.message].
String paymentFailureMessage(AppLocalizations l10n, PaymentFailureType type) {
  return switch (type) {
    PaymentFailureType.amountMustBePositive =>
      l10n.paymentErrorAmountMustBePositive,
    PaymentFailureType.financialAccountInactive =>
      l10n.paymentErrorFinancialAccountInactive,
    PaymentFailureType.idempotencyKeyConflict =>
      l10n.paymentErrorIdempotencyKeyConflict,
    PaymentFailureType.paymentAlreadyReversed =>
      l10n.paymentErrorAlreadyReversed,
    PaymentFailureType.reversalBlockedWalletCreditConsumed =>
      l10n.paymentErrorReversalBlockedWalletCreditConsumed,
    PaymentFailureType.reversalBlockedSubsequentActivity =>
      l10n.paymentErrorReversalBlockedSubsequentActivity,
    PaymentFailureType.reversalReasonRequired =>
      l10n.paymentErrorReversalReasonRequired,
    PaymentFailureType.walletInsufficientBalance =>
      l10n.paymentErrorWalletInsufficientBalance,
    PaymentFailureType.walletAllocationNothingToAllocate =>
      l10n.paymentErrorWalletNothingToAllocate,
    PaymentFailureType.notFound => l10n.paymentErrorNotFound,
    PaymentFailureType.permissionDenied => l10n.paymentErrorPermissionDenied,
    PaymentFailureType.network => l10n.paymentErrorNetwork,
    PaymentFailureType.unexpected => l10n.paymentErrorUnexpected,
  };
}
