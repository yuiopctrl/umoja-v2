import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/access/presentation/account_disabled_screen.dart';
import '../../features/access/presentation/context_error_screen.dart';
import '../../features/access/presentation/group_closed_screen.dart';
import '../../features/access/presentation/group_suspended_screen.dart';
import '../../features/access/presentation/membership_restricted_screen.dart';
import '../../features/auth/presentation/otp_verify_screen.dart';
import '../../features/auth/presentation/phone_entry_screen.dart';
import '../../features/auth/providers/app_context_provider.dart';
import '../../features/auth/providers/auth_session_provider.dart';
import '../../features/auth/providers/selected_group_provider.dart';
import '../../features/groups/presentation/select_group_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/group_onboarding_screen.dart';
import '../../features/onboarding/presentation/profile_onboarding_screen.dart';
import '../../features/splash/splash_screen.dart';
import 'app_routes.dart';
import 'route_guard.dart';
import 'router_refresh_notifier.dart';

/// The app's single [GoRouter], reconstructed only when the provider
/// itself is recreated (e.g. in a fresh [ProviderScope] for tests) —
/// [RouterRefreshNotifier] is what makes it re-evaluate `redirect` on
/// state changes, not provider recreation.
///
/// See [computeRedirect] for the actual decision logic (kept separate
/// and pure so it is unit-testable without a router/widget tree). See
/// `docs/product/authentication.md` for the full state machine this
/// implements, and the reminder that these guards are UX only, not the
/// authorization boundary.
final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      return computeRedirect(
        sessionStatus: ref.read(authSessionStatusProvider),
        appContext: ref.read(appContextProvider),
        selectedGroup: ref.read(selectedGroupProvider),
        currentLocation: state.uri.path,
      );
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.authPhone,
        builder: (context, state) => const PhoneEntryScreen(),
      ),
      GoRoute(
        path: AppRoutes.authVerify,
        builder: (context, state) => const OtpVerifyScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingProfile,
        builder: (context, state) => const ProfileOnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingGroup,
        builder: (context, state) => const GroupOnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.selectGroup,
        builder: (context, state) => const SelectGroupScreen(),
      ),
      GoRoute(
        path: AppRoutes.accessAccountDisabled,
        builder: (context, state) => const AccountDisabledScreen(),
      ),
      GoRoute(
        path: AppRoutes.accessMembershipRestricted,
        builder: (context, state) => const MembershipRestrictedScreen(),
      ),
      GoRoute(
        path: AppRoutes.accessGroupSuspended,
        builder: (context, state) => const GroupSuspendedScreen(),
      ),
      GoRoute(
        path: AppRoutes.accessGroupClosed,
        builder: (context, state) => const GroupClosedScreen(),
      ),
      GoRoute(
        path: AppRoutes.contextError,
        builder: (context, state) => const ContextErrorScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
});
