import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations_x.dart';
import '../../../shared/widgets/simple_message_screen.dart';
import '../../auth/presentation/sign_out_button.dart';

/// `/access/group-closed`: shown when the user's ACTIVE membership
/// belongs to a group whose status is CLOSED. No group closure/
/// reopening workflow exists yet (Prompt 03) — this is a read-only
/// notice.
class GroupClosedScreen extends StatelessWidget {
  const GroupClosedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SimpleMessageScreen(
      icon: Icons.lock_outline,
      title: l10n.groupClosedTitle,
      message: l10n.groupClosedMessage,
      actions: const [SignOutButton()],
    );
  }
}
