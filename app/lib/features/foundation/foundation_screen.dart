import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_client_provider.dart';
import '../../shared/widgets/responsive_center.dart';

/// Minimal bootstrap screen. This is not the product dashboard — it only
/// confirms the application foundation (routing, theme, config, Supabase
/// wiring) starts correctly.
class FoundationScreen extends ConsumerWidget {
  const FoundationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSupabaseConfigured = ref.watch(isSupabaseConfiguredProvider);

    return Scaffold(
      body: SafeArea(
        child: ResponsiveCenter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Umoja', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text('Umoja v2', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              const Text('Application foundation is ready.'),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(
                    isSupabaseConfigured
                        ? Icons.check_circle_outline
                        : Icons.warning_amber_outlined,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isSupabaseConfigured
                          ? 'Supabase configuration detected.'
                          : 'Supabase configuration missing '
                                '(SUPABASE_URL / SUPABASE_ANON_KEY not set).',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
