import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_controller_provider.dart';

/// Shared "Sign Out" action. Always goes through [AuthController], so
/// user-scoped state is cleared consistently everywhere this appears.
class SignOutButton extends ConsumerWidget {
  const SignOutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton(
      onPressed: () => ref.read(authControllerProvider).signOut(),
      child: const Text('Sign Out'),
    );
  }
}
