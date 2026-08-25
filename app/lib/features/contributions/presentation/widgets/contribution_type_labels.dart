import '../../../../l10n/app_localizations.dart';

/// Centralized mapping from a `contribution_types.category` value to its
/// localized display label — the only place this mapping is
/// implemented, so it stays consistent everywhere a category is shown
/// and reacts to the active language. The backend enum value itself
/// never changes to fit the UI.
String contributionCategoryLabel(AppLocalizations l10n, String category) {
  return switch (category) {
    'GENERAL' => l10n.contributionCategoryGeneral,
    'SOCIAL' => l10n.contributionCategorySocial,
    'SHARE' => l10n.contributionCategoryShare,
    _ => category,
  };
}

/// Centralized mapping from a
/// `contribution_types.accounting_treatment` value to its localized
/// display label.
///
/// `MEMBER_SAVINGS` is reserved/deferred on the backend (see
/// `rpc_create_contribution_type`'s `MEMBER_SAVINGS_NOT_AVAILABLE`
/// guard) — its label makes that explicit so a disabled picker entry
/// still reads clearly, rather than looking like a plain, pickable
/// option.
String contributionAccountingTreatmentLabel(
  AppLocalizations l10n,
  String treatment,
) {
  return switch (treatment) {
    'GROUP_INCOME' => l10n.contributionTreatmentGroupIncome,
    'PASS_THROUGH' => l10n.contributionTreatmentPassThrough,
    'SHARE_CAPITAL' => l10n.contributionTreatmentShareCapital,
    'MEMBER_SAVINGS' => l10n.contributionTreatmentMemberSavingsUnavailable,
    _ => treatment,
  };
}

const contributionCategoryOptions = ['GENERAL', 'SOCIAL', 'SHARE'];

/// Every accounting treatment code the schema understands, including
/// `MEMBER_SAVINGS` — callers building a picker must render it as a
/// visibly disabled entry (see [contributionAccountingTreatmentLabel])
/// rather than omitting it outright, and must never submit it (the
/// create/edit forms validate this client-side before calling the
/// repository at all — see `ContributionTypeFormController`).
const contributionAccountingTreatmentOptions = [
  'GROUP_INCOME',
  'PASS_THROUGH',
  'SHARE_CAPITAL',
  'MEMBER_SAVINGS',
];

/// SHARE category requires SHARE_CAPITAL treatment
/// (`contribution_types_share_requires_share_capital` check constraint)
/// — used to filter the treatment picker's enabled options once a
/// category is chosen, so the form guides the user to a combination the
/// backend will actually accept.
List<String> contributionAllowedTreatmentsForCategory(String category) {
  if (category == 'SHARE') return const ['SHARE_CAPITAL'];
  return const ['GROUP_INCOME', 'PASS_THROUGH', 'SHARE_CAPITAL'];
}
