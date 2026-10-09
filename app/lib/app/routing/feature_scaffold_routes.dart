import 'app_routes.dart';

/// Prompt 09G-B6-C.3 §M: a maintainable, feature-family-based
/// replacement for the hand-written per-route list 09G-B6-C.2
/// introduced. Every authenticated screen in the route tree now builds
/// its own header via the shared `UmojaFeatureScaffold` (directly, or
/// through `UmojaPage`/`MemberChildScaffold`, which both compose it) —
/// EXCEPT [AppRoutes.home] and [AppRoutes.more], the two deliberate
/// dashboard/hub screens that keep relying on the shell's persistent
/// `AppTopBar` instead (`UmojaPage(useAppTopBar: true)` — see its own
/// doc comment).
///
/// [app_shell.dart] suppresses its own persistent `AppTopBar` on every
/// route for which this returns `true`, so a migrated screen's own
/// compact header is never stacked under a second, independent one.
/// Because this is the complement of an exhaustive, explicitly-named
/// two-route exception list — rather than an enumerated allowlist of
/// every migrated route — a new feature screen added later can never
/// silently fall through to "legacy AppTopBar with no header of its
/// own": it is correctly suppressed by default, and the one invariant
/// that actually matters (a suppressed route truly supplies its own
/// header) is covered by `navigation_shell_consistency_test.dart`'s
/// dedicated invariant test instead of by keeping this list exhaustive.
bool usesLegacyAppTopBar(String location) =>
    location == AppRoutes.home || location == AppRoutes.more;
