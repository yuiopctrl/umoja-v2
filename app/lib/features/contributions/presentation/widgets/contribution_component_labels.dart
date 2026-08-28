import '../../../../l10n/app_localizations.dart';

/// Centralized mapping from a `contribution_charge_components
/// .component_type` value to its localized display label (Prompt 06C)
/// — the only place this mapping is implemented, so a charge/member
/// breakdown never shows a raw enum name.
String contributionComponentTypeLabel(AppLocalizations l10n, String type) {
  return switch (type) {
    'BASE' => l10n.contributionComponentBase,
    'PENALTY' => l10n.contributionComponentPenalty,
    'ADJUSTMENT' => l10n.contributionComponentAdjustment,
    'WAIVER' => l10n.contributionComponentWaiver,
    'OPENING_BALANCE' => l10n.contributionComponentOpeningBalance,
    _ => type,
  };
}
