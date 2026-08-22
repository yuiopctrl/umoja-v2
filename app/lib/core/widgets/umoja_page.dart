import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/umoja_breakpoints.dart';
import '../theme/umoja_spacing.dart';
import 'umoja_page_header.dart';
import 'umoja_responsive_content.dart';

/// Standard page scaffold for redesigned screens.
///
/// Mobile: the title lives in the [AppBar] (with a back arrow where
/// there's somewhere to go back to). Desktop/tablet: the [AppBar]
/// title is omitted and the heading is rendered inline via
/// [UmojaPageHeader] instead — see prompt 05 §12, "avoid duplicating
/// titles unnecessarily".
///
/// [backTo]/[backLabel] give a nested route (member detail, member
/// form) an explicit, deep-link-safe way back to its parent — rather
/// than relying on `Navigator.canPop`, which is false when the route
/// was reached directly (a deep link, a fresh web load) even though a
/// parent conceptually exists. When set: mobile gets an explicit
/// back arrow in the `AppBar` (instead of the auto-implied one);
/// desktop/tablet gets a small "← [backLabel]" link above the inline
/// page header, since that breakpoint has no `AppBar` title at all to
/// carry a back arrow.
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
  });

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

    final inner = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
      children: [
        if (!isMobile) ...[
          if (backTo != null) ...[
            _DesktopBackLink(to: backTo, label: backLabel!),
            const SizedBox(height: UmojaSpacing.sm),
          ],
          UmojaPageHeader(
            title: title,
            subtitle: subtitle,
            trailing: headerTrailing,
          ),
          const SizedBox(height: UmojaSpacing.lg),
        ],
        if (scrollable) body else Expanded(child: body),
      ],
    );

    final content = UmojaResponsiveContent(maxWidth: maxWidth, child: inner);

    // On desktop/tablet, a shell-root page (Home/Members/More — nothing
    // to pop, no actions) renders no AppBar at all rather than an empty
    // strip: the heading already lives inline via UmojaPageHeader above.
    final canPop = Navigator.canPop(context);
    final showAppBar =
        isMobile ||
        appBarActions.isNotEmpty ||
        (automaticallyImplyLeading && canPop);

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
      // The FAB is a mobile affordance only — wide viewports get the
      // equivalent action via [headerTrailing] in the inline page
      // header instead, so the two are never shown at once.
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
