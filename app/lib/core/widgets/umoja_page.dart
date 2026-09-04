import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/umoja_breakpoints.dart';
import '../theme/umoja_spacing.dart';
import 'umoja_page_header.dart';
import 'umoja_responsive_content.dart';

/// Standard page scaffold for redesigned screens.
///
/// A shell-root screen (nothing to pop, no [backTo]) relies on the
/// shell's own persistent `AppTopBar` for its chrome, so its title is
/// always rendered inline via [UmojaPageHeader] instead of in a
/// second, redundant app bar — on every breakpoint, mobile included.
/// A nested/detail screen (reached via [backTo] or an ordinary
/// `Navigator` push) keeps its own [AppBar] with a back arrow and
/// title on mobile; desktop/tablet keeps its small "← [backLabel]"
/// link above the inline header instead, since that breakpoint never
/// shows a per-screen [AppBar] — see prompt 05 §12, "avoid duplicating
/// titles unnecessarily".
///
/// [backTo]/[backLabel] give a nested route (member detail, member
/// form) an explicit, deep-link-safe way back to its parent — rather
/// than relying on `Navigator.canPop`, which is false when the route
/// was reached directly (a deep link, a fresh web load) even though a
/// parent conceptually exists.
class UmojaPage extends StatelessWidget {
  const UmojaPage({
    super.key,
    required this.title,
    this.subtitle,
    this.appBarActions = const [],
    this.headerTrailing,
    this.floatingActionButton,
    required this.body,
    this.maxWidth = 1120,
    this.scrollable = true,
    this.automaticallyImplyLeading = true,
    this.backTo,
    this.backLabel,
  }) : assert(
         backTo == null || backLabel != null,
         'backLabel is required whenever backTo is set (used for the '
         'desktop/tablet "← [backLabel]" link) — a screen that sets '
         'backTo without it crashes at build time on desktop/tablet '
         'width. See the class doc.',
       );

  final String title;
  final String? subtitle;
  final List<Widget> appBarActions;
  final Widget? headerTrailing;
  final Widget? floatingActionButton;
  final Widget body;
  final double maxWidth;

  /// Whether [body] should be wrapped in a [SingleChildScrollView].
  /// Set `false` when [body] manages its own scrolling (e.g. a list
  /// screen using `Expanded` + `ListView`).
  final bool scrollable;
  final bool automaticallyImplyLeading;

  /// Route to navigate to for an explicit back action. See class doc.
  final String? backTo;

  /// Label shown next to the back arrow on desktop/tablet (e.g.
  /// "Wanachama"). Required when [backTo] is set.
  final String? backLabel;

  @override
  Widget build(BuildContext context) {
    final isMobile = UmojaBreakpoints.isMobile(
      MediaQuery.sizeOf(context).width,
    );
    final backTo = this.backTo;
    final canPop = Navigator.canPop(context);

    // A shell-root screen (Home/Members/More — nothing to pop, no
    // explicit back target) relies on the shell's persistent
    // AppTopBar for its chrome on every breakpoint, so it never grows
    // its own second app bar — its title always lives inline instead.
    final isShellRoot =
        backTo == null && !(automaticallyImplyLeading && canPop);
    final showInlineHeader = !isMobile || isShellRoot;

    // The FAB is a mobile affordance only — wide viewports get the
    // equivalent action via [headerTrailing] in the inline page header
    // instead, so the two are never shown at once. Now that a
    // shell-root screen's inline header also renders on mobile, the
    // same trailing action would otherwise duplicate that screen's own
    // FAB there — suppressed whenever both are present on mobile.
    final showHeaderTrailing =
        headerTrailing != null && !(isMobile && floatingActionButton != null);

    final inner = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
      children: [
        if (showInlineHeader) ...[
          if (backTo != null && !isMobile) ...[
            _DesktopBackLink(to: backTo, label: backLabel!),
            const SizedBox(height: UmojaSpacing.sm),
          ],
          UmojaPageHeader(
            title: title,
            subtitle: subtitle,
            trailing: showHeaderTrailing ? headerTrailing : null,
          ),
          const SizedBox(height: UmojaSpacing.lg),
        ],
        if (scrollable) body else Expanded(child: body),
      ],
    );

    final content = UmojaResponsiveContent(maxWidth: maxWidth, child: inner);

    // A shell-root page renders no per-screen AppBar at all — on
    // desktop/tablet the heading already lives inline above; on mobile
    // the shell's own AppTopBar now carries that chrome instead.
    final showAppBar =
        !isShellRoot &&
        (isMobile ||
            appBarActions.isNotEmpty ||
            (automaticallyImplyLeading && canPop));

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: isMobile ? Text(title) : null,
              actions: appBarActions,
              automaticallyImplyLeading:
                  backTo == null && automaticallyImplyLeading,
              leading: (isMobile && backTo != null)
                  ? BackButton(
                      key: const Key('umojaPageBackButton'),
                      onPressed: () => context.go(backTo),
                    )
                  : null,
            )
          : null,
      floatingActionButton: isMobile ? floatingActionButton : null,
      body: SafeArea(
        child: scrollable ? SingleChildScrollView(child: content) : content,
      ),
    );
  }
}

/// The desktop/tablet "← [label]" breadcrumb-style back link — see
/// [UmojaPage.backTo].
class _DesktopBackLink extends StatelessWidget {
  const _DesktopBackLink({required this.to, required this.label});

  final String to;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: UmojaSpacing.xs),
      child: InkWell(
        key: const Key('umojaPageDesktopBackLink'),
        onTap: () => context.go(to),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: UmojaSpacing.xs,
            vertical: UmojaSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_back,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: UmojaSpacing.xs),
              Text(label, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}
