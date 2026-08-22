import 'package:flutter/material.dart';

import '../theme/umoja_spacing.dart';

/// A content card with consistent internal padding, using the app's
/// [CardTheme] (border + flat surface, no heavy shadow) for the outer
/// shape.
class UmojaCard extends StatelessWidget {
  const UmojaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(UmojaSpacing.lg),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) {
      return Card(
        child: Padding(padding: padding, child: child),
      );
    }

    final shape = Theme.of(context).cardTheme.shape;
    return Card(
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
