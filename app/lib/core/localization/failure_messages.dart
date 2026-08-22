import '../../features/auth/data/auth_failure.dart';
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
