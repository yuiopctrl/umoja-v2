import 'package:flutter/material.dart';

import '../theme/umoja_colors.dart';
import '../theme/umoja_radius.dart';
import '../theme/umoja_spacing.dart';

/// The semantic meaning a status badge communicates. Deliberately
/// separate from any specific backend enum (e.g. membership status) —
/// each feature maps its own domain status to one of these, so this
/// widget stays reusable by future modules (contributions, loans, ...)
/// without new cases here.
enum UmojaStatusSemantic { success, warning, danger, info, neutral }

/// A small status pill. Status meaning is never carried by color alone
/// — the label text is always shown alongside the tint, so the badge
/// remains legible without relying on color perception.
class UmojaStatusBadge extends StatelessWidget {
  const UmojaStatusBadge({
    super.key,
    required this.label,
    required this.semantic,
  });

  final String label;
  final UmojaStatusSemantic semantic;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground) = switch (semantic) {
      UmojaStatusSemantic.success => (
        UmojaColors.successSoft,
        UmojaColors.success,
      ),
      UmojaStatusSemantic.warning => (
        UmojaColors.warningSoft,
        UmojaColors.warning,
      ),
      UmojaStatusSemantic.danger => (
        UmojaColors.dangerSoft,
        UmojaColors.danger,
      ),
      UmojaStatusSemantic.info => (UmojaColors.infoSoft, UmojaColors.info),
      UmojaStatusSemantic.neutral => (
        UmojaColors.surfaceSubtle,
        UmojaColors.textSecondary,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: UmojaSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: UmojaRadius.smallAll,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
      ),
    );
  }
}
