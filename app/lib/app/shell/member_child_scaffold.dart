import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/umoja_spacing.dart';
import '../../core/widgets/umoja_responsive_content.dart';
import '../../features/auth/providers/selected_group_provider.dart';
import '../routing/app_routes.dart';
import 'member_avatar_button.dart';

/// The shared compact app bar for every member self-service child page
/// (My Profile, My Contributions, My Loans, My Financial Statement, and
/// future My Payments & Receipts — Prompt 09G-B5-C.2 §B/§D).
///
/// The shell's own persistent [AppTopBar] is suppressed on these routes
/// (see `app_shell.dart`), so this is the ONLY app bar shown — never a
/// second, oversized title stacked below the group header, which was
/// the exact defect UAT found on My Financial Statement. The page title
/// lives here, in the top app bar, at a compact size; the body never
/// repeats it as a second giant heading.
class MemberChildScaffold extends ConsumerWidget {
  const MemberChildScaffold({
    super.key,
    required this.title,
    required this.body,
    this.scrollable = true,
    this.actions = const [],
  });

  final String title;
  final Widget body;

  /// Set `false` when [body] manages its own scrolling (e.g. a list
  /// screen using `Expanded` + a scroll view internally).
  final bool scrollable;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedGroup = ref.watch(selectedGroupProvider);
    final membership = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership
        : null;
    final theme = Theme.of(context);

    final content = UmojaResponsiveContent(child: body);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        titleSpacing: 0,
        leading: BackButton(
          key: const Key('memberChildBackButton'),
          onPressed: () => Navigator.canPop(context)
              ? Navigator.pop(context)
              : context.go(AppRoutes.more),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            if (membership != null)
              Text(
                membership.group.groupName,
                key: const Key('memberChildGroupSubtitle'),
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12.5,
                ),
              ),
          ],
        ),
        actions: [
          ...actions,
          const Padding(
            padding: EdgeInsets.only(right: UmojaSpacing.md),
            child: MemberAvatarButton(),
          ),
        ],
      ),
      body: SafeArea(
        child: scrollable ? SingleChildScrollView(child: content) : content,
      ),
    );
  }
}
