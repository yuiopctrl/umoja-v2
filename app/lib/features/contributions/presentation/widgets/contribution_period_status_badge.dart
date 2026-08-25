import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations_x.dart';
import '../../../../core/widgets/umoja_status_badge.dart';
import '../../../../l10n/app_localizations.dart';

/// Centralized mapping from a `contribution_periods.status` value to its
/// visual semantic — the only place this mapping is implemented, so
/// every period status badge across the app stays consistent. Mirrors
/// `memberStatusSemantic()`'s pattern.
UmojaStatusSemantic contributionPeriodStatusSemantic(String status) {
  return switch (status) {
    'DRAFT' => UmojaStatusSemantic.neutral,
    'SCHEDULED' => UmojaStatusSemantic.info,
    'OPEN' => UmojaStatusSemantic.success,
    'CLOSED' => UmojaStatusSemantic.neutral,
    'CANCELLED' => UmojaStatusSemantic.danger,
    _ => UmojaStatusSemantic.neutral,
  };
}

/// Centralized mapping from a `contribution_periods.status` value to its
/// localized display label — never the raw backend enum string.
String contributionPeriodStatusLabel(AppLocalizations l10n, String status) {
  return switch (status) {
    'DRAFT' => l10n.contributionPeriodStatusDraft,
    'SCHEDULED' => l10n.contributionPeriodStatusScheduled,
    'OPEN' => l10n.contributionPeriodStatusOpen,
    'CLOSED' => l10n.contributionPeriodStatusClosed,
    'CANCELLED' => l10n.contributionPeriodStatusCancelled,
    _ => status,
  };
}

/// A small status pill for a period's DRAFT/SCHEDULED/OPEN/CLOSED/
/// CANCELLED status.
class ContributionPeriodStatusBadge extends StatelessWidget {
  const ContributionPeriodStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return UmojaStatusBadge(
      label: contributionPeriodStatusLabel(context.l10n, status),
      semantic: contributionPeriodStatusSemantic(status),
    );
  }
}
