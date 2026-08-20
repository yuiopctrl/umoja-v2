import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/sign_out_button.dart';
import '../../auth/providers/app_context_provider.dart';
import '../../../shared/widgets/simple_message_screen.dart';

/// Shown when `rpc_get_my_context()` fails for a signed-in user
/// (network/server failure) — distinct from an authentication failure.
/// The user is not signed out automatically; they can retry or sign
/// out themselves.
class ContextErrorScreen extends ConsumerWidget {
  const ContextErrorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SimpleMessageScreen(
      icon: Icons.cloud_off,
      title: 'Unable to load account',
      message: 'We could not load your account. Check your connection and try again.',
      actions: [
        FilledButton(
          onPressed: () => ref.invalidate(appContextProvider),
          child: const Text('Retry'),
        ),
        const SignOutButton(),
      ],
    );
  }
}
