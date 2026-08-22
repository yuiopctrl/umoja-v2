import 'package:flutter/material.dart';

import '../theme/umoja_spacing.dart';

/// A titled group of content within a page — e.g. "Identity",
/// "Membership", "Roles", "Actions" on member detail. Deliberately
/// lighter-weight than [UmojaCard]: not every field needs its own card,
/// just a clear section heading and consistent spacing.
class UmojaSection extends StatelessWidget {
  const UmojaSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: UmojaSpacing.sm),
        child,
      ],
    );
  }
}
