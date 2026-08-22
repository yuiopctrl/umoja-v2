import 'package:flutter/material.dart';

import '../theme/umoja_spacing.dart';
import 'umoja_buttons.dart';

/// Shows a modal bottom sheet asking the user to confirm (or cancel) an
/// action — the standard confirmation surface for potentially
/// destructive member actions (suspend, mark as exited, remove role),
/// so no more than one such action is ever mid-flight from a single
/// screen. Sizes to its content (never a full-height sheet) and
/// respects the safe area, so it fits short displays.
///
/// [title] and [confirmLabel] are deliberately separate parameters —
/// giving them the same literal text (e.g. both "Confirm") produces two
/// visually identical strings on screen at once, which is confusing and
/// makes automated/accessibility lookups by text ambiguous.
Future<bool> showUmojaConfirmationSheet(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool danger = false,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            UmojaSpacing.xxl,
            UmojaSpacing.sm,
            UmojaSpacing.xxl,
            UmojaSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(sheetContext).textTheme.titleMedium),
              const SizedBox(height: UmojaSpacing.sm),
              Text(message, style: Theme.of(sheetContext).textTheme.bodyLarge),
              const SizedBox(height: UmojaSpacing.xxl),
              Row(
                children: [
                  Expanded(
                    child: UmojaSecondaryButton(
                      label: cancelLabel,
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                    ),
                  ),
                  const SizedBox(width: UmojaSpacing.md),
                  Expanded(
                    child: danger
                        ? UmojaDangerButton(
                            label: confirmLabel,
                            filled: true,
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(true),
                          )
                        : UmojaPrimaryButton(
                            label: confirmLabel,
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(true),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}
