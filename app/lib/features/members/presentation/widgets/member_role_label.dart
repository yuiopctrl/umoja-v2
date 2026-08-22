import '../../../../l10n/app_localizations.dart';

/// Centralized mapping from a `group_memberships` role code to its
/// localized display label — the only place this mapping is
/// implemented, so every role chip/summary across the app stays
/// consistent and reacts to the active language. Backend role codes
/// are never changed to fit the UI, and authorization always checks
/// the backend code, never this label.
String memberRoleLabel(AppLocalizations l10n, String code) {
  return switch (code) {
    'ADMIN' => l10n.roleAdmin,
    'TREASURER' => l10n.roleTreasurer,
    'SECRETARY' => l10n.roleSecretary,
    'CHAIRPERSON' => l10n.roleChairperson,
    'MEMBER' => l10n.roleMember,
    _ => code,
  };
}
