import '../../../../l10n/app_localizations.dart';

/// Localizes one excluded/ineligible member's reason code from
/// `rpc_preview_contribution_period_open()` — either one of the
/// server's automatic-ineligibility codes, or an explicit exclusion
/// reason (free text, or the `'EXCLUDED'` default when none was given).
/// Free text reasons are shown as-is (they are the group's own words,
/// not a backend enum).
String contributionExclusionReasonLabel(AppLocalizations l10n, String reason) {
  return switch (reason) {
    'SUSPENDED' => l10n.contributionExclusionReasonSuspended,
    'EXITED' => l10n.contributionExclusionReasonExited,
    'JOINED_AFTER_ELIGIBILITY_DATE' =>
      l10n.contributionExclusionReasonJoinedAfterEligibility,
    'EXITED_DURING_PERIOD' =>
      l10n.contributionExclusionReasonExitedDuringPeriod,
    'EXCLUDED' => l10n.contributionExclusionReasonExcludedDefault,
    _ => reason,
  };
}
