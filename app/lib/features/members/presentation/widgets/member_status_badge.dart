import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations_x.dart';
import '../../../../core/widgets/umoja_status_badge.dart';
import '../../../../l10n/app_localizations.dart';

/// Centralized mapping from a `group_memberships.status` value to its
/// visual semantic — the only place this mapping is implemented, so
/// every member status badge across the app stays consistent. Backend
/// enum values are never changed to fit the UI; only the visual
/// treatment is chosen here.
UmojaStatusSemantic memberStatusSemantic(String status) {
  return switch (status) {
    'ACTIVE' => UmojaStatusSemantic.success,
    'SUSPENDED' => UmojaStatusSemantic.warning,
    'EXITED' => UmojaStatusSemantic.neutral,
    _ => UmojaStatusSemantic.neutral,
  };
}

/// Centralized mapping from a `group_memberships.status` value to its
/// localized display label — polished UI never shows the raw backend
/// enum string. The backend value itself never changes.
String memberStatusLabel(AppLocalizations l10n, String status) {
  return switch (status) {
    'ACTIVE' => l10n.statusActive,
    'SUSPENDED' => l10n.statusSuspended,
    'EXITED' => l10n.statusExited,
    _ => status,
  };
}

/// A small status pill for a member's ACTIVE/SUSPENDED/EXITED status.
class MemberStatusBadge extends StatelessWidget {
  const MemberStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return UmojaStatusBadge(
      label: memberStatusLabel(context.l10n, status),
      semantic: memberStatusSemantic(status),
    );
  }
}
