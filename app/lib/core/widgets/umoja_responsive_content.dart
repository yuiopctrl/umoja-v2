import 'package:flutter/material.dart';

import '../theme/umoja_breakpoints.dart';

/// Centers [child] and constrains its width on wide viewports, using
/// responsive horizontal padding (16 on mobile, 24 on tablet/desktop —
/// see [UmojaBreakpoints]) rather than a single fixed inset.
///
/// This is the standard content wrapper for redesigned screens. Prefer
/// [maxWidth] presets suited to the content: ~640 for forms, ~900 for
/// detail views, ~1100–1200 for general list/content pages (the
/// default).
class UmojaResponsiveContent extends StatelessWidget {
  const UmojaResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = 1120,
    this.verticalPadding = 24,
  });

  final Widget child;
  final double maxWidth;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = UmojaBreakpoints.horizontalPadding(width);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontal,
            vertical: verticalPadding,
          ),
          child: child,
        ),
      ),
    );
  }
}
