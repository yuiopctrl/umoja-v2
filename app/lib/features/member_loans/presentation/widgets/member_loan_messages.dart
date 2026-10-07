import '../../../../l10n/app_localizations.dart';
import '../../data/member_loans_failure.dart';

/// Safe, localized message for a My Loans failure. Raw PostgREST text,
/// SQLSTATEs and RPC names are never shown. A not-found result is the same
/// text whether the loan is missing, foreign, or in another group.
String memberLoansFailureMessage(
  AppLocalizations l10n,
  Object error, {
  required bool isLoanScoped,
}) {
  if (error is MemberLoansFailure) {
    return switch (error.type) {
      MemberLoansFailureType.notAuthorized => l10n.myLoansNotAuthorizedMessage,
      MemberLoansFailureType.notFound => l10n.myLoansNotFoundMessage,
      MemberLoansFailureType.network => l10n.myLoansNetworkMessage,
      MemberLoansFailureType.invalidRequest ||
      MemberLoansFailureType.unexpected =>
        isLoanScoped
            ? l10n.myLoansLoadFailedMessage
            : l10n.myLoansUnexpectedMessage,
    };
  }
  return isLoanScoped
      ? l10n.myLoansLoadFailedMessage
      : l10n.myLoansUnexpectedMessage;
}
