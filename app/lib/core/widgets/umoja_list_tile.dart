import 'package:flutter/material.dart';

import '../theme/umoja_spacing.dart';

/// A polished row: optional leading widget (e.g. an initials avatar),
/// title, optional subtitle, optional trailing widget, and a chevron
/// when tappable. Used for member rows and any future similarly-shaped
/// list content.
class UmojaListTile extends StatelessWidget {
  const UmojaListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final Widget? leading;
  final String title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: UmojaSpacing.lg,
          vertical: UmojaSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: UmojaSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: subtitle,
                    ),
                ],
              ),
            ),
            ?trailing,
            if (onTap != null) ...[
              const SizedBox(width: UmojaSpacing.xs),
              Icon(Icons.chevron_right, size: 18, color: scheme.outline),
            ],
          ],
        ),
      ),
    );
  }
}
