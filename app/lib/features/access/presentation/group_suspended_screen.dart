import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations_x.dart';
import '../../../shared/widgets/simple_message_screen.dart';
import '../../auth/presentation/sign_out_button.dart';

/// `/access/group-suspended`: shown when the user's ACTIVE membership
/// belongs to a group whose status is SUSPENDED. No group reactivation
/// workflow exists yet (Prompt 03) — this is a read-only notice.
class GroupSuspendedScreen extends StatelessWidget {
  const GroupSuspendedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SimpleMessageScreen(
      icon: Icons.pause_circle_outlined,
      title: l10n.groupSuspendedTitle,
      message: l10n.groupSuspendedMessage,
      actions: const [SignOutButton()],
    );
  }
}
