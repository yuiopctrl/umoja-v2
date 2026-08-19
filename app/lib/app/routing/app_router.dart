import 'package:go_router/go_router.dart';

import '../../features/foundation/foundation_screen.dart';

/// Root router configuration.
///
/// Only the foundation route exists today. This is the intended place to
/// later add, e.g., authentication routes and group/tenant-scoped
/// sub-routers — do not add feature routes until those features exist.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const FoundationScreen()),
  ],
);
