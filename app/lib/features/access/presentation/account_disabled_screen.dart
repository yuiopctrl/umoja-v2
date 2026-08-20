import 'package:flutter/material.dart';

import '../../../shared/widgets/simple_message_screen.dart';
import '../../auth/presentation/sign_out_button.dart';

/// `/access/account-disabled`: shown when `profile.is_active = false`
/// for an otherwise-valid Supabase session. No group operational UI is
/// reachable from here — only Sign Out.
class AccountDisabledScreen extends StatelessWidget {
  const AccountDisabledScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SimpleMessageScreen(
      icon: Icons.block,
      title: 'Account access disabled',
      message:
          'Your account access has been disabled. Contact your group '
          'administrator if you believe this is a mistake.',
      actions: [SignOutButton()],
    );
  }
}
