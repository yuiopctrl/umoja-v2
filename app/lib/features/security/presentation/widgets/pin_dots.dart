import 'package:flutter/material.dart';

import '../../../../core/theme/umoja_colors.dart';

/// 4 filled/empty dots reflecting how many PIN digits have been
/// entered so far — the "4 PIN slots" visual, layered above a plain
/// obscured numeric field rather than a bespoke keypad.
class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.filled, this.length = 4});

  final int filled;
  final int length;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < length; i++)
          Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled
                  ? UmojaColors.primary
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
      ],
    );
  }
}
