import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations_x.dart';
import '../../../shared/widgets/simple_message_screen.dart';
import '../../auth/presentation/sign_out_button.dart';

/// `/access/account-disabled`: shown when `profile.is_active = false`
/// for an otherwise-valid Supabase session. No group operational UI is
/// reachable from here — only Sign Out.
class AccountDisabledScreen extends StatelessWidget {
  const AccountDisabledScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SimpleMessageScreen(
      icon: Icons.block,
      title: l10n.accountDisabledTitle,
      message: l10n.accountDisabledMessage,
      actions: const [SignOutButton()],
    );
  }
}
