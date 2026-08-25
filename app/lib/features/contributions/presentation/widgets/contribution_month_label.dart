import '../../../../l10n/app_localizations.dart';

/// Localized full month name for [month] (1-12) — used by the
/// Contribution Period create form's MONTHLY month picker. A small
/// direct ARB mapping (matching this app's existing localization
/// approach) rather than `intl`'s CLDR `DateFormat`, since the app
/// never calls `initializeDateFormatting` for non-`en` locales.
String contributionMonthLabel(AppLocalizations l10n, int month) {
  return switch (month) {
    1 => l10n.contributionMonthJanuary,
    2 => l10n.contributionMonthFebruary,
    3 => l10n.contributionMonthMarch,
    4 => l10n.contributionMonthApril,
    5 => l10n.contributionMonthMay,
    6 => l10n.contributionMonthJune,
    7 => l10n.contributionMonthJuly,
    8 => l10n.contributionMonthAugust,
    9 => l10n.contributionMonthSeptember,
    10 => l10n.contributionMonthOctober,
    11 => l10n.contributionMonthNovember,
    12 => l10n.contributionMonthDecember,
    _ => month.toString(),
  };
}
