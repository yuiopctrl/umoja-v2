import 'package:flutter/material.dart';

import 'responsive_center.dart';

/// A minimal, static informational screen: icon, title, message, and
/// optional action buttons. Used by the `/access/*` screens, which are
/// all structurally identical (see docs/product/authentication.md).
class SimpleMessageScreen extends StatelessWidget {
  const SimpleMessageScreen({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline,
    this.actions = const [],
  });

  final String title;
  final String message;
  final IconData icon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ResponsiveCenter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(message),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 24),
                Wrap(spacing: 12, runSpacing: 12, children: actions),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
