import 'package:flutter/material.dart';

import '../routing/app_routes.dart';
import 'umoja_feature_scaffold.dart';

/// The member self-service specialization of [UmojaFeatureScaffold]
/// (Prompt 09G-B6-C.2 §H) — every member self-service child page (My
/// Profile, My Contributions, My Loans, My Payments & Receipts, and My
/// Financial Statement) always shows a back arrow (member self-service
/// has no bottom-nav tab of its own; "back" falls through to More when
/// nothing is on the stack to pop) and never the shell-level refresh
/// action (that lives on a feature ROOT instead — see
/// `payments_home_screen.dart` for the officer equivalent).
///
/// The shell's own persistent `AppTopBar` is suppressed on these routes
/// (see `app_shell.dart`), so [UmojaFeatureScaffold]'s own header is the
/// ONLY one shown — never a second, oversized title stacked below the
/// group header, which was the exact defect UAT found on My Financial
/// Statement, and the exact class of defect officer Payments shared
/// before 09G-B6-C.2.
class MemberChildScaffold extends StatelessWidget {
  const MemberChildScaffold({
    super.key,
    required this.title,
    required this.body,
    this.scrollable = true,
    this.actions = const [],
  });

  final String title;
  final Widget body;
  final bool scrollable;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return UmojaFeatureScaffold(
      title: title,
      body: body,
      scrollable: scrollable,
      showBackButton: true,
      backFallbackRoute: AppRoutes.more,
      actions: actions,
      backButtonKey: const Key('memberChildBackButton'),
      groupSubtitleKey: const Key('memberChildGroupSubtitle'),
    );
  }
}
