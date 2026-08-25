import '../../features/auth/data/auth_failure.dart';
import '../../features/contributions/data/contribution_failure.dart';
import '../../features/members/data/member_failure.dart';
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
    ContributionFailureType.permissionDenied =>
      l10n.contributionErrorPermissionDenied,
    ContributionFailureType.network => l10n.contributionErrorNetwork,
    ContributionFailureType.unexpected => l10n.contributionErrorUnexpected,
  };
}
