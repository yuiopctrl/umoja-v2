import 'package:flutter/material.dart';

import 'umoja_buttons.dart';

/// A friendly error state with a Retry action. Never renders raw
/// exception text, SQLSTATE codes, or stack traces — callers pass a
/// human message (already mapped upstream by the relevant repository).
class UmojaErrorState extends StatelessWidget {
  const UmojaErrorState({
    super.key,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: scheme.error),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            UmojaSecondaryButton(label: retryLabel, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
