import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/branding/umoja_brand_mark.dart';
import '../../core/localization/app_localizations_x.dart';
import '../../core/theme/umoja_spacing.dart';
import '../../shared/widgets/responsive_center.dart';
import '../auth/providers/auth_session_provider.dart';

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
                const UmojaBrandMark.wordmark(wordmarkHeight: 28),
                const SizedBox(height: UmojaSpacing.lg),
                Row(
                  children: [
                    const Icon(Icons.warning_amber_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(context.l10n.supabaseConfigMissing)),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UmojaBrandMark.symbol(size: 48),
            SizedBox(height: UmojaSpacing.xxl),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
