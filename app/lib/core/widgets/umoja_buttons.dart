import 'package:flutter/material.dart';

import '../theme/umoja_radius.dart';

/// Primary (filled) action. Disabled and shows an inline spinner while
/// [isLoading], without changing the button's size.
class UmojaPrimaryButton extends StatelessWidget {
  const UmojaPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = _ButtonContent(
      label: label,
      isLoading: isLoading,
      icon: icon,
      spinnerColor: Colors.white,
    );
    final button = FilledButton(
      onPressed: isLoading ? null : onPressed,
      child: child,
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Secondary (outlined) action.
class UmojaSecondaryButton extends StatelessWidget {
  const UmojaSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = _ButtonContent(
      label: label,
      isLoading: isLoading,
      icon: icon,
      spinnerColor: Theme.of(context).colorScheme.onSurface,
    );
    final button = OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      child: child,
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// A destructive action (e.g. remove a role), styled with danger
/// semantics rather than the primary brand color.
class UmojaDangerButton extends StatelessWidget {
  const UmojaDangerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.filled = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool filled;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    final child = _ButtonContent(
      label: label,
      isLoading: isLoading,
      spinnerColor: filled ? Colors.white : error,
    );

    final button = filled
        ? FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: error,
              foregroundColor: Colors.white,
              minimumSize: const Size(64, 48),
              shape: RoundedRectangleBorder(
                borderRadius: UmojaRadius.controlAll,
              ),
            ),
            onPressed: isLoading ? null : onPressed,
            child: child,
          )
        : OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: error,
              side: BorderSide(color: error),
              minimumSize: const Size(64, 48),
              shape: RoundedRectangleBorder(
                borderRadius: UmojaRadius.controlAll,
              ),
            ),
            onPressed: isLoading ? null : onPressed,
            child: child,
          );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.isLoading,
    required this.spinnerColor,
    this.icon,
  });

  final String label;
  final bool isLoading;
  final Color spinnerColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: spinnerColor,
            ),
          ),
          const SizedBox(width: 10),
          Text(label),
        ],
      );
    }
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
      );
    }
    return Text(label);
  }
}
