import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/app_context_provider.dart';
import 'app_top_bar.dart';

/// The caller's own initials avatar, opening the same account sheet as
/// the persistent [AppTopBar] — shared so every member-facing app bar
/// (shell-level and the compact child app bar) uses one consistent
/// control. ~38dp diameter (Prompt 09G-B5-C.2 §C).
class MemberAvatarButton extends ConsumerWidget {
  const MemberAvatarButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appContextAsync = ref.watch(appContextProvider);
    final displayName = appContextAsync.value?.profile?.displayName;

    return InkWell(
      key: const Key('profileMenuButton'),
      customBorder: const CircleBorder(),
      onTap: () => showProfileSheet(context),
      child: CircleAvatar(
        radius: 19,
        child: Text(memberInitials(displayName ?? 'Umoja')),
      ),
    );
  }
}

/// First + last name initials (e.g. "Fred Mwangi" -> "FM"); a single
/// name falls back to just its own first letter.
String memberInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}
