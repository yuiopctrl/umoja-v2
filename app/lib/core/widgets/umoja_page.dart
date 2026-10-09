import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/shell/umoja_feature_scaffold.dart';
import '../theme/umoja_breakpoints.dart';
import '../theme/umoja_spacing.dart';

/// Standard page scaffold for authenticated feature screens.
///
/// Prompt 09G-B6-C.3: every screen using [UmojaPage] now composes the
/// single shared [UmojaFeatureScaffold] header — title, selected-group
/// subtitle, refresh/avatar, and (for a child screen) a back arrow, all
/// in ONE coherent top navigation region. [AppShell] suppresses its own
/// persistent `AppTopBar` on every such route, so a screen built with
/// [UmojaPage] never also shows that second, independent header level
/// (the exact physical-UAT defect 09G-B6-C.1/.2/.3 progressively fixed).
///
/// A screen is treated as a feature ROOT (no back arrow) when it has
/// nothing to pop and no explicit [backTo] — exactly [Home]/[More],
/// which opt out via [useAppTopBar] instead (see below), and every
/// shell-root officer screen (Members, Contributions, Payments,
/// Finance, Loans, ...). Any other screen (reached via [backTo] or an
/// ordinary `Navigator`/`GoRouter` push) is a feature CHILD and always
/// shows a back arrow, on every breakpoint — the old desktop-only
/// "← [backLabel]" breadcrumb link and the old mobile-only child
/// [AppBar] are both retired in favor of this one universal treatment.
///
/// [useAppTopBar] is the sole, deliberate exception: [HomeScreen] and
/// [MoreScreen] are hub/dashboard screens that keep relying on the
/// shell's persistent `AppTopBar` instead of their own header (prompt
/// 09G-B6-C.3 §J/§K — "Home/More are allowed to be structurally
/// different... do not force a title into the new feature header... do
/// not change More merely for symmetry"). No other screen in the route
/// tree sets this.
///
/// [backTo] gives a nested route (member detail, member form) an
/// explicit, deep-link-safe way back to its parent — rather than
/// relying solely on `Navigator.canPop`, which is false when the route
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
    this.showTitleOnMobile = true,
    this.useAppTopBar = false,
  }) : assert(
         backTo == null || backLabel != null,
         'backLabel is required whenever backTo is set. See the class '
         'doc.',
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

  /// Unused in the [UmojaFeatureScaffold] path (its back arrow carries
  /// no adjacent text label on any breakpoint); kept only so the
  /// [useAppTopBar] legacy path (Home/More) still has it available, and
  /// so existing call sites that pass it alongside [backTo] keep
  /// compiling unchanged.
  final String? backLabel;

  /// [useAppTopBar]-only: suppresses just the mobile copy of a
  /// shell-root screen's inline title when its body already opens with
  /// an equivalent heading (e.g. Home's greeting).
  final bool showTitleOnMobile;

  /// Prompt 09G-B6-C.3 §C/§J/§K: `true` only for [HomeScreen] and
  /// [MoreScreen] — every other screen uses the shared
  /// [UmojaFeatureScaffold] header instead. See the class doc.
  final bool useAppTopBar;

  @override
  Widget build(BuildContext context) {
    if (useAppTopBar) {
      return _LegacyAppTopBarPage(
        title: title,
        subtitle: subtitle,
        appBarActions: appBarActions,
        headerTrailing: headerTrailing,
        floatingActionButton: floatingActionButton,
        body: body,
        maxWidth: maxWidth,
        scrollable: scrollable,
        automaticallyImplyLeading: automaticallyImplyLeading,
        backTo: backTo,
        backLabel: backLabel,
        showTitleOnMobile: showTitleOnMobile,
      );
    }

    final isMobile = UmojaBreakpoints.isMobile(
      MediaQuery.sizeOf(context).width,
    );
    final canPop = Navigator.canPop(context);
    final showBackButton =
        backTo != null || (automaticallyImplyLeading && canPop);

    // The FAB is a mobile affordance only — wide viewports get the
    // equivalent action via [headerTrailing] in the header's own
    // actions instead, so the two are never shown at once.
    final showHeaderTrailing =
        headerTrailing != null && !(isMobile && floatingActionButton != null);

    final effectiveBody = subtitle == null
        ? body
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: UmojaSpacing.lg),
              if (scrollable) body else Expanded(child: body),
            ],
          );

    return UmojaFeatureScaffold(
      title: title,
      body: effectiveBody,
      scrollable: scrollable,
      maxWidth: maxWidth,
      showBackButton: showBackButton,
      backFallbackRoute: backTo,
      backButtonKey: const Key('umojaPageBackButton'),
      actions: [...appBarActions, if (showHeaderTrailing) headerTrailing!],
      floatingActionButton: isMobile ? floatingActionButton : null,
    );
  }
}

/// The exact pre-09G-B6-C.3 implementation, preserved verbatim for
/// [UmojaPage.useAppTopBar]'s two call sites (Home, More).
class _LegacyAppTopBarPage extends StatelessWidget {
  const _LegacyAppTopBarPage({
    required this.title,
    required this.subtitle,
    required this.appBarActions,
    required this.headerTrailing,
    required this.floatingActionButton,
    required this.body,
    required this.maxWidth,
    required this.scrollable,
    required this.automaticallyImplyLeading,
    required this.backTo,
    required this.backLabel,
    required this.showTitleOnMobile,
  });

  final String title;
  final String? subtitle;
  final List<Widget> appBarActions;
  final Widget? headerTrailing;
  final Widget? floatingActionButton;
  final Widget body;
  final double maxWidth;
  final bool scrollable;
  final bool automaticallyImplyLeading;
  final String? backTo;
  final String? backLabel;
  final bool showTitleOnMobile;

  @override
  Widget build(BuildContext context) {
    final isMobile = UmojaBreakpoints.isMobile(
      MediaQuery.sizeOf(context).width,
    );
    final backTo = this.backTo;
    final canPop = Navigator.canPop(context);

    final isShellRoot =
        backTo == null && !(automaticallyImplyLeading && canPop);
    final showInlineHeader = !isMobile || (isShellRoot && showTitleOnMobile);

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
          _UmojaPageHeader(
            title: title,
            subtitle: subtitle,
            trailing: showHeaderTrailing ? headerTrailing : null,
          ),
          const SizedBox(height: UmojaSpacing.lg),
        ],
        if (scrollable) body else Expanded(child: body),
      ],
    );

    final content = _ResponsiveContent(maxWidth: maxWidth, child: inner);

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

class _ResponsiveContent extends StatelessWidget {
  const _ResponsiveContent({required this.child, required this.maxWidth});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = UmojaBreakpoints.horizontalPadding(width);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: 24),
          child: child,
        ),
      ),
    );
  }
}

class _UmojaPageHeader extends StatelessWidget {
  const _UmojaPageHeader({required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// The desktop/tablet "← [label]" breadcrumb-style back link — legacy
/// path only.
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
