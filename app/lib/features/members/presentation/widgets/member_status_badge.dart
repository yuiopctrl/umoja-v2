import 'package:flutter/material.dart';

/// A small status pill for ACTIVE/SUSPENDED/EXITED — deliberately
/// minimal (text + tint), not a decorative badge.
class MemberStatusBadge extends StatelessWidget {
  const MemberStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color background, Color foreground) = switch (status) {
      'ACTIVE' => (scheme.primaryContainer, scheme.onPrimaryContainer),
      'SUSPENDED' => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      'EXITED' => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
      _ => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
      ),
    );
  }
}
