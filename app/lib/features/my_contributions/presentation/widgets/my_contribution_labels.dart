import 'package:intl/intl.dart';

import '../../../../core/widgets/umoja_status_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/my_contributions_failure.dart';
import '../../domain/my_contribution.dart';

final _dateFormat = DateFormat('d MMM yyyy');

String formatMyContributionDate(DateTime date) => _dateFormat.format(date);

/// Maps the backend status to its localized label. The status meaning
/// is never altered — SETTLED is shown as "Settled", never "Paid".
String myContributionStatusLabel(
  AppLocalizations l10n,
  MyContributionStatus status,
) {
  return switch (status) {
    MyContributionStatus.open => l10n.myContributionsStatusOpen,
    MyContributionStatus.partiallySettled =>
      l10n.myContributionsStatusPartiallySettled,
    MyContributionStatus.overdue => l10n.myContributionsStatusOverdue,
    MyContributionStatus.settled => l10n.myContributionsStatusSettled,
  };
}

/// Semantic tint for the status badge. Always paired with the text label
/// so status is never communicated by color alone.
UmojaStatusSemantic myContributionStatusSemantic(MyContributionStatus status) {
  return switch (status) {
    MyContributionStatus.open => UmojaStatusSemantic.info,
    MyContributionStatus.partiallySettled => UmojaStatusSemantic.warning,
    MyContributionStatus.overdue => UmojaStatusSemantic.danger,
    MyContributionStatus.settled => UmojaStatusSemantic.success,
  };
}

/// Charge-level name, or the neutral generic label when the backend has
/// none. A missing type name is never replaced by an invented one.
String myContributionTypeLabel(
  AppLocalizations l10n,
  String? contributionTypeName,
) {
  return (contributionTypeName == null || contributionTypeName.isEmpty)
      ? l10n.myContributionsFallbackTypeName
      : contributionTypeName;
}

/// The period context shown under a contribution: the opening-balance
/// label for OPENING_BALANCE obligations, otherwise the backend period
/// label. Returns null when there is nothing honest to show.
String? myContributionPeriodContext(
  AppLocalizations l10n, {
  required MyContributionPeriodPurpose purpose,
  required String? periodLabel,
}) {
  if (purpose == MyContributionPeriodPurpose.openingBalance) {
    return l10n.myContributionsOpeningBalanceLabel;
  }
  if (periodLabel == null || periodLabel.isEmpty) return null;
  return periodLabel;
}

/// Localized component label. Reuses the existing contribution component
/// keys so the member sees the same wording the officer screens use.
String myContributionComponentLabel(
  AppLocalizations l10n,
  MyContributionComponentType type,
) {
  return switch (type) {
    MyContributionComponentType.base => l10n.contributionComponentBase,
    MyContributionComponentType.penalty => l10n.contributionComponentPenalty,
    MyContributionComponentType.adjustment =>
      l10n.contributionComponentAdjustment,
    MyContributionComponentType.waiver => l10n.contributionComponentWaiver,
    MyContributionComponentType.openingBalance =>
      l10n.contributionComponentOpeningBalance,
  };
}

/// Safe, localized copy for a failure. Never includes the raw exception.
String myContributionsFailureMessage(
  AppLocalizations l10n,
  MyContributionsFailure failure, {
  bool isDetail = false,
}) {
  return switch (failure.type) {
    MyContributionsFailureType.notAuthorized =>
      l10n.myContributionsNotAuthorizedMessage,
    MyContributionsFailureType.notFound => l10n.myContributionsNotFoundMessage,
    MyContributionsFailureType.invalidDateRange =>
      l10n.myContributionsFromAfterToError,
    MyContributionsFailureType.invalidRequest =>
      l10n.myContributionsInvalidRequestMessage,
    MyContributionsFailureType.network => l10n.myContributionsNetworkMessage,
    MyContributionsFailureType.unexpected =>
      isDetail
          ? l10n.myContributionsDetailLoadFailedMessage
          : l10n.myContributionsLoadFailedMessage,
  };
}
