import 'package:flutter/material.dart';

import '../theme/umoja_radius.dart';
import '../theme/umoja_spacing.dart';

/// A restrained list-shaped loading placeholder — a handful of muted
/// skeleton rows, rather than a lonely spinner floating in the middle
/// of an otherwise-empty page. Intentionally static (no shimmer/looping
/// animation dependency) to keep this cheap to render.
class UmojaLoadingState extends StatelessWidget {
  const UmojaLoadingState({super.key, this.rows = 6});

  final int rows;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: UmojaSpacing.sm),
      itemCount: rows,
      separatorBuilder: (context, _) => const SizedBox(height: UmojaSpacing.md),
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: UmojaSpacing.lg),
        child: Row(
          children: [
            _bar(base, width: 40, height: 40, radius: UmojaRadius.largeAll),
            const SizedBox(width: UmojaSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(base, width: 160, height: 14),
                  const SizedBox(height: UmojaSpacing.sm),
                  _bar(base, width: 100, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(
    Color color, {
    required double width,
    required double height,
    BorderRadius? radius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius ?? UmojaRadius.smallAll,
      ),
    );
  }
}
