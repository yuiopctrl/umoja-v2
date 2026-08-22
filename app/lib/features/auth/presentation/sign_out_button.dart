import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations_x.dart';
import '../providers/auth_controller_provider.dart';

/// Shared "Sign Out" action. Always goes through [AuthController], so
/// user-scoped state is cleared consistently everywhere this appears.
/// Used only in pre-operational flows (onboarding) where there is
/// nothing to "lock" yet — always a full sign out, not a PIN lock.
class SignOutButton extends ConsumerWidget {
  const SignOutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton(
      onPressed: () => ref.read(authControllerProvider).signOut(),
      child: Text(context.l10n.signOutButtonLabel),
    );
  }
}
