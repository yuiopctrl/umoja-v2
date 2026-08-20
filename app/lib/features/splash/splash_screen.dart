import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/providers/auth_session_provider.dart';
import '../../shared/widgets/responsive_center.dart';

/// Rendered at `/` while application state is still resolving, and as
/// the terminal state when Supabase configuration is missing (there is
/// nowhere else useful to route to in that case). Every other state
/// redirects away from here — see `app/routing/route_guard.dart`.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionStatus = ref.watch(authSessionStatusProvider);

    if (sessionStatus == AuthSessionStatus.configMissing) {
      return Scaffold(
        body: SafeArea(
          child: ResponsiveCenter(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Umoja',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.warning_amber_outlined, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Supabase configuration missing '
                        '(SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY not set).',
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

    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
