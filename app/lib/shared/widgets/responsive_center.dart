import 'package:flutter/material.dart';

/// Centers [child] and constrains its width on large viewports (web,
/// desktop, tablet landscape) while letting it use the full width on
/// narrow/phone viewports.
///
/// This is a generic layout primitive, not a full application shell —
/// features can use it directly or build their own layout on top of it.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = 640,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
