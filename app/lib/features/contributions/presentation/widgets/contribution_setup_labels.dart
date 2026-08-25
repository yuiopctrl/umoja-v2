import '../../../../l10n/app_localizations.dart';

/// Centralized mapping from a `contribution_setups.schedule_mode` value
/// to its localized display label.
String contributionScheduleModeLabel(AppLocalizations l10n, String mode) {
  return switch (mode) {
    'MONTHLY' => l10n.contributionScheduleMonthly,
    'ON_DEMAND' => l10n.contributionScheduleOnDemand,
    'ONE_TIME' => l10n.contributionScheduleOneTime,
    _ => mode,
  };
}

/// Centralized mapping from a `contribution_setups.amount_mode` value to
/// its localized display label.
String contributionAmountModeLabel(AppLocalizations l10n, String mode) {
  return switch (mode) {
    'FIXED' => l10n.contributionAmountFixed,
    'CUSTOM_PER_MEMBER' => l10n.contributionAmountCustomPerMember,
    _ => mode,
  };
}

/// Centralized mapping from a `contribution_setups.penalty_mode` value
/// to its localized display label. Penalty configuration is stored and
/// validated in this Contribution Engine foundation, but never posted
/// as a charge component yet — see the schema migration's comment on
/// `contribution_penalty_mode`.
String contributionPenaltyModeLabel(AppLocalizations l10n, String mode) {
  return switch (mode) {
    'NONE' => l10n.contributionPenaltyNone,
    'FIXED_ONCE' => l10n.contributionPenaltyFixedOnce,
    'FIXED_RECURRING' => l10n.contributionPenaltyFixedRecurring,
    'PERCENTAGE_ONCE' => l10n.contributionPenaltyPercentageOnce,
    'PERCENTAGE_RECURRING' => l10n.contributionPenaltyPercentageRecurring,
    _ => mode,
  };
}

const contributionScheduleModeOptions = ['MONTHLY', 'ON_DEMAND', 'ONE_TIME'];
const contributionAmountModeOptions = ['FIXED', 'CUSTOM_PER_MEMBER'];
const contributionPenaltyModeOptions = [
  'NONE',
  'FIXED_ONCE',
  'FIXED_RECURRING',
  'PERCENTAGE_ONCE',
  'PERCENTAGE_RECURRING',
];

/// Percentage-based penalty modes — used by the setup form to decide
/// whether the penalty value field should show a "%" affordance.
bool isPercentagePenaltyMode(String mode) =>
    mode == 'PERCENTAGE_ONCE' || mode == 'PERCENTAGE_RECURRING';
