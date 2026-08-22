import 'package:flutter/material.dart';

import '../theme/umoja_spacing.dart';

/// A titled group of form fields (e.g. "Member information", "Contact")
/// with consistent spacing between fields.
class UmojaFormSection extends StatelessWidget {
  const UmojaFormSection({
    super.key,
    required this.title,
    required this.fields,
  });

  final String title;
  final List<Widget> fields;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: UmojaSpacing.md),
        for (final field in fields) ...[
          field,
          const SizedBox(height: UmojaSpacing.lg),
        ],
      ],
    );
  }
}
