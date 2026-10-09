import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_localizations_x.dart';
import '../../core/theme/umoja_spacing.dart';
import '../../core/widgets/umoja_responsive_content.dart';
import '../../features/auth/providers/app_context_provider.dart';
import '../../features/auth/providers/selected_group_provider.dart';
import '../routing/navigation_history_provider.dart';
import 'member_avatar_button.dart';

/// Prompt 09G-B6-C.2 §H, back semantics revised by 09G-B6-C.5 §B/§P:
/// the ONE shared compact top-navigation primitive for every
/// authenticated feature screen — member self-service
/// ([member_child_scaffold.dart] composes this) and officer/admin
/// feature roots and children alike. Neither depends on the other's
/// specific semantics; this widget has no notion of "member" at all.
///
/// Produces exactly one header: title + (when a group is selected) the
/// group name as a compact subtitle, a back arrow per the rule below,
/// an optional refresh action (the shell-level permission-refresh
/// affordance previously only on the persistent `AppTopBar`), any
/// caller-supplied [actions], and the shared account avatar. A screen
/// using this never also shows the shell's persistent `AppTopBar` —
/// see `app_shell.dart`'s route-based suppression — so there is never
/// a second, independent header level stacked above it.
///
/// Back-arrow visibility (09G-B6-C.5 §D/§E/§P — supersedes the old
/// "feature ROOT ⇒ never" rule):
///  - [showBackButton] `true` (every CHILD screen — [UmojaPage]'s
///    unified path and [MemberChildScaffold] both always set this,
///    since a CHILD always has either real in-session history or a
///    declared [backFallbackRoute]): the arrow is always shown.
///  - [showBackButton] `false` but [isFeatureRoot] `true` (the five
///    officer feature roots): the arrow shows ONLY when
///    [canPerformAppBack] reports a real previous meaningful location
///    — i.e. this root was reached FROM somewhere, not restored/
///    launched directly. No declared [backFallbackRoute] of its own:
///    a root never invents a misleading previous screen.
///  - Neither: no arrow (used only by the few remaining screens that
///    genuinely have nothing to go back to and are not roots either).
///
/// Pressing the arrow always calls [performAppBack] — the exact same
/// function the global system-Back handler uses
/// (`app_exit_guard.dart`), so the header button and the hardware/
/// gesture back button are always coherent (09G-B6-C.5 §L).
class UmojaFeatureScaffold extends ConsumerWidget {
  const UmojaFeatureScaffold({
    super.key,
    required this.title,
    required this.body,
    this.scrollable = true,
    this.showBackButton = false,
    this.isFeatureRoot = false,
    this.backFallbackRoute,
    this.showRefreshAction = false,
    this.actions = const [],
    this.floatingActionButton,
    this.maxWidth = 1120,
    this.backButtonKey = const Key('umojaFeatureBackButton'),
    this.groupSubtitleKey = const Key('umojaFeatureGroupSubtitle'),
  });

  final String title;
  final Widget body;

  /// Set `false` when [body] manages its own scrolling (e.g. a list
  /// screen using `Expanded` + a scroll view internally).
  final bool scrollable;

  /// A CHILD screen always sets this `true`. See the class doc.
  final bool showBackButton;

  /// `true` only for the five officer feature roots (Payments/Members/
  /// Contributions/Finance/Loans) — makes the back arrow conditionally
  /// visible based on in-session history alone (09G-B6-C.5 §D/§E),
  /// never on a declared fallback (roots have none).
  final bool isFeatureRoot;

  /// A CHILD's declared static fallback for when neither in-session
  /// history nor an actual `Navigator` pop applies (a direct deep
  /// link). Ignored when [showBackButton] is false.
  final String? backFallbackRoute;

  /// The shell-level "refresh effective permissions" affordance
  /// (`appContextProvider` invalidation) — normally only a feature
  /// ROOT needs it; a child screen relies on its root for this.
  final bool showRefreshAction;

  /// Extra actions between [showRefreshAction]'s button (if any) and
  /// the shared avatar — e.g. a root's "Add" action on wide layouts.
  final List<Widget> actions;

  final Widget? floatingActionButton;
  final double maxWidth;

  /// Lets a composing widget (e.g. [MemberChildScaffold]) keep its own
  /// established `Key` so existing tests/automation continue to match
  /// exactly the same key they were written against.
  final Key backButtonKey;
  final Key groupSubtitleKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedGroup = ref.watch(selectedGroupProvider);
    final membership = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership
        : null;
    final theme = Theme.of(context);
    final l10n = context.l10n;

    // Prompt 09G-B6-C.5 §D/§E: a feature ROOT shows a back arrow only
    // when real in-session history exists to go back TO — read here
    // (not watched) since visibility must not itself consume history;
    // the actual consumption happens only inside `performAppBack` when
    // the button is pressed.
    final effectiveShowBack =
        showBackButton ||
        (isFeatureRoot &&
            canPerformAppBack(context, ref, fallbackRoute: backFallbackRoute));

    final content = UmojaResponsiveContent(maxWidth: maxWidth, child: body);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        // Prompt 09G-B6-C.5 §E: `0` only when a leading back arrow is
        // actually present — otherwise the default toolbar spacing
        // applies, so the title never hugs the screen's left edge (the
        // exact physical defect this phase found on Payments).
        titleSpacing: effectiveShowBack ? 0 : null,
        automaticallyImplyLeading: false,
        leading: effectiveShowBack
            ? BackButton(
                key: backButtonKey,
                onPressed: () => performAppBack(
                  context,
                  ref,
                  fallbackRoute: backFallbackRoute,
                ),
              )
            : null,
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
                key: groupSubtitleKey,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12.5,
                ),
              ),
          ],
        ),
        actions: [
          // Prompt 09G-B5-C.2 §A/§N.6 (carried into B6-C.2): the same
          // explicit, discoverable way to pick up a newly effective
          // permission without reinstalling or signing out, now on a
          // feature root's own header instead of only the persistent
          // AppTopBar.
          if (showRefreshAction)
            IconButton(
              key: const Key('refreshPermissionsButton'),
              tooltip: l10n.refreshAction,
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(appContextProvider),
            ),
          ...actions,
          const Padding(
            padding: EdgeInsets.only(right: UmojaSpacing.md),
            child: MemberAvatarButton(),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: scrollable ? SingleChildScrollView(child: content) : content,
      ),
    );
  }
}
