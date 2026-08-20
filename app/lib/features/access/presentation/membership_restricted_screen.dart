import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../shared/widgets/simple_message_screen.dart';
import '../../auth/presentation/sign_out_button.dart';

/// `/access/membership-restricted`: shown when the user's only
/// membership(s) are SUSPENDED (not ACTIVE), so nothing is eligible for
/// normal operational selection. The suspended membership is not
/// hidden/pretended away — this screen names the restriction — but the
/// user may still create a separate new group.
class MembershipRestrictedScreen extends StatelessWidget {
  const MembershipRestrictedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SimpleMessageScreen(
      icon: Icons.pause_circle_outlined,
      title: 'Membership restricted',
      message:
          'Your membership in this group is currently suspended, so it '
          'is not available. You can still create a new group.',
      actions: [
        FilledButton(
          onPressed: () => context.go(AppRoutes.onboardingGroup),
          child: const Text('Create New Group'),
        ),
        const SignOutButton(),
      ],
    );
  }
}
