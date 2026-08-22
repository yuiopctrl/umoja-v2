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
    // Prompt 05E-C §17: theme-aware rather than always the light
    // palette — a light "soft" background (e.g. `successSoft`, a pale
    // mint) rendered on a dark screen showed up as a jarring bright
    // patch, and its paired dark-toned foreground text lost contrast
    // against dark surfaces generally.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (Color background, Color foreground) = switch (semantic) {
      UmojaStatusSemantic.success =>
        isDark
            ? (UmojaColors.successSoftDark, UmojaColors.successDark)
            : (UmojaColors.successSoft, UmojaColors.success),
      UmojaStatusSemantic.warning =>
        isDark
            ? (UmojaColors.warningSoftDark, UmojaColors.warningDark)
            : (UmojaColors.warningSoft, UmojaColors.warning),
      UmojaStatusSemantic.danger =>
        isDark
            ? (UmojaColors.dangerSoftDark, UmojaColors.dangerDark)
            : (UmojaColors.dangerSoft, UmojaColors.danger),
      UmojaStatusSemantic.info =>
        isDark
            ? (UmojaColors.infoSoftDark, UmojaColors.infoDark)
            : (UmojaColors.infoSoft, UmojaColors.info),
      UmojaStatusSemantic.neutral =>
        isDark
            ? (UmojaColors.surfaceSubtleDark, UmojaColors.textSecondaryDark)
            : (UmojaColors.surfaceSubtle, UmojaColors.textSecondary),
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
