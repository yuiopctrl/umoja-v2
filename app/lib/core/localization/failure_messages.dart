import '../../features/auth/data/auth_failure.dart';
import '../../features/contributions/data/contribution_failure.dart';
import '../../features/financial_accounts/data/financial_account_failure.dart';
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
    FinancialAccountFailureType.permissionDenied =>
      l10n.financialAccountErrorPermissionDenied,
    FinancialAccountFailureType.network => l10n.financialAccountErrorNetwork,
    FinancialAccountFailureType.unexpected =>
      l10n.financialAccountErrorUnexpected,
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
