import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/app/routing/route_guard.dart';
import 'package:umoja/features/auth/models/app_context.dart';
import 'package:umoja/features/auth/models/app_user_profile.dart';
import 'package:umoja/features/auth/models/group_context.dart';
import 'package:umoja/features/auth/models/membership_context.dart';
import 'package:umoja/features/auth/providers/auth_session_provider.dart';
import 'package:umoja/features/auth/providers/selected_group_provider.dart';
import 'package:umoja/features/security/providers/lock_state_provider.dart';

MembershipContext _membership({
  required String id,
  String membershipStatus = 'ACTIVE',
  String groupStatus = 'ACTIVE',
}) {
  return MembershipContext(
    membershipId: id,
    group: GroupContext(
      groupId: 'g-$id',
      groupName: 'Group $id',
      groupStatus: groupStatus,
    ),
    membershipStatus: membershipStatus,
    displayName: 'Member',
    roleCodes: const ['MEMBER'],
    permissionCodes: const ['group.view'],
  );
}

const _complete = AppUserProfile(id: 'u1', fullName: 'Amina');
const _incomplete = AppUserProfile(id: 'u1');
const _inactive = AppUserProfile(id: 'u1', fullName: 'Amina', isActive: false);

/// Wraps [computeRedirect] with PIN-gating defaults ("already configured
/// and unlocked") so every pre-existing test below continues to
/// exercise exactly the profile/group routing it did before the PIN
/// gate was introduced — only the dedicated 'PIN gating' group overrides
/// [hasPinConfigured]/[lockState].
String? _redirect({
  required AuthSessionStatus sessionStatus,
  required AsyncValue<AppContext?> appContext,
  required SelectedGroupState selectedGroup,
  required String currentLocation,
  AsyncValue<bool> hasPinConfigured = const AsyncValue.data(true),
  LockState lockState = LockState.unlocked,
}) {
  return computeRedirect(
    sessionStatus: sessionStatus,
    appContext: appContext,
    selectedGroup: selectedGroup,
    currentLocation: currentLocation,
    hasPinConfigured: hasPinConfigured,
    lockState: lockState,
  );
}

void main() {
  group('signed out / config states', () {
    test('config missing never redirects', () {
      expect(
        _redirect(
          sessionStatus: AuthSessionStatus.configMissing,
          appContext: const AsyncValue.loading(),
          selectedGroup: const SelectedGroupLoading(),
          currentLocation: AppRoutes.splash,
        ),
        isNull,
      );
    });

    test('a signed-out user is sent to /auth/phone', () {
      expect(
        _redirect(
          sessionStatus: AuthSessionStatus.signedOut,
          appContext: const AsyncValue.loading(),
          selectedGroup: const SelectedGroupLoading(),
          currentLocation: AppRoutes.splash,
        ),
        AppRoutes.authPhone,
      );
    });

    test('a signed-out user already on /auth/verify is left alone', () {
      expect(
        _redirect(
          sessionStatus: AuthSessionStatus.signedOut,
          appContext: const AsyncValue.loading(),
          selectedGroup: const SelectedGroupLoading(),
          currentLocation: AppRoutes.authVerify,
        ),
        isNull,
      );
    });
  });

  group('PIN gating', () {
    test('signed in, PIN not yet configured, routes to PIN setup', () {
      expect(
        _redirect(
          sessionStatus: AuthSessionStatus.signedIn,
          appContext: const AsyncValue.loading(),
          selectedGroup: const SelectedGroupLoading(),
          currentLocation: AppRoutes.splash,
          hasPinConfigured: const AsyncValue.data(false),
          lockState: LockState.locked,
        ),
        AppRoutes.pinSetup,
      );
    });

    test('signed in, PIN configured but locked, routes to PIN unlock', () {
      expect(
        _redirect(
          sessionStatus: AuthSessionStatus.signedIn,
          appContext: const AsyncValue.loading(),
          selectedGroup: const SelectedGroupLoading(),
          currentLocation: AppRoutes.splash,
          hasPinConfigured: const AsyncValue.data(true),
          lockState: LockState.locked,
        ),
        AppRoutes.pinUnlock,
      );
    });

    test('signed in, on the PIN unlock route, PIN configured and unlocked, '
        'leaves the PIN flow (mirrors leaving /auth/* once signed in)', () {
      final context = AppContext(
        userId: 'u1',
        profile: _complete,
        memberships: const [],
      );
      expect(
        _redirect(
          sessionStatus: AuthSessionStatus.signedIn,
          appContext: AsyncValue.data(context),
          selectedGroup: const SelectedGroupNone(),
          currentLocation: AppRoutes.pinUnlock,
          hasPinConfigured: const AsyncValue.data(true),
          lockState: LockState.unlocked,
        ),
        AppRoutes.splash,
      );
    });

    test('signed in, PIN configured and unlocked, falls through to normal '
        'profile/group routing', () {
      final context = AppContext(
        userId: 'u1',
        profile: _complete,
        memberships: const [],
      );
      expect(
        _redirect(
          sessionStatus: AuthSessionStatus.signedIn,
          appContext: AsyncValue.data(context),
          selectedGroup: const SelectedGroupNone(),
          currentLocation: AppRoutes.splash,
          hasPinConfigured: const AsyncValue.data(true),
          lockState: LockState.unlocked,
        ),
        AppRoutes.onboardingGroup,
      );
    });

    test('while locked, the recovery verify/new-PIN routes are left alone '
        '(prompt 05C §18-21 — "Umesahau PIN?" must stay reachable without '
        'being bounced back to /auth/pin-unlock)', () {
      for (final recoveryRoute in [
        AppRoutes.pinForgotVerify,
        AppRoutes.pinForgotNewPin,
      ]) {
        expect(
          _redirect(
            sessionStatus: AuthSessionStatus.signedIn,
            appContext: const AsyncValue.loading(),
            selectedGroup: const SelectedGroupLoading(),
            currentLocation: recoveryRoute,
            hasPinConfigured: const AsyncValue.data(true),
            lockState: LockState.locked,
          ),
          isNull,
          reason: '$recoveryRoute should not redirect while locked',
        );
      }
    });

    test('a recovery route cannot expose operational screens without PIN — '
        'once unlocked, it falls through to normal routing rather than '
        'being treated as a resolved destination', () {
      final context = AppContext(
        userId: 'u1',
        profile: _complete,
        memberships: const [],
      );
      expect(
        _redirect(
          sessionStatus: AuthSessionStatus.signedIn,
          appContext: AsyncValue.data(context),
          selectedGroup: const SelectedGroupNone(),
          currentLocation: AppRoutes.pinForgotNewPin,
          hasPinConfigured: const AsyncValue.data(true),
          lockState: LockState.unlocked,
        ),
        AppRoutes.onboardingGroup,
      );
    });

    test('the PIN gate resolves before the appContext fetch', () {
      // appContext is still loading, but PIN setup is required first —
      // this must not wait on the network fetch to decide that.
      expect(
        _redirect(
          sessionStatus: AuthSessionStatus.signedIn,
          appContext: const AsyncValue.loading(),
          selectedGroup: const SelectedGroupLoading(),
          currentLocation: AppRoutes.home,
          hasPinConfigured: const AsyncValue.data(false),
          lockState: LockState.locked,
        ),
        AppRoutes.pinSetup,
      );
    });
  });

  group('signed in, context loading/error', () {
    test('leaves the auth flow once signed in', () {
      expect(
        _redirect(
          sessionStatus: AuthSessionStatus.signedIn,
          appContext: const AsyncValue.loading(),
          selectedGroup: const SelectedGroupLoading(),
          currentLocation: AppRoutes.authPhone,
        ),
        AppRoutes.splash,
      );
    });

    test(
      'a context load failure routes to the context-error screen, not sign-out',
      () {
        expect(
          _redirect(
            sessionStatus: AuthSessionStatus.signedIn,
            appContext: AsyncValue<AppContext?>.error(
              Exception('network'),
              StackTrace.empty,
            ),
            selectedGroup: const SelectedGroupLoading(),
            currentLocation: AppRoutes.splash,
          ),
          AppRoutes.contextError,
        );
      },
    );
  });

  group('profile state', () {
    test('an inactive profile routes to account-disabled', () {
      final context = AppContext(
        userId: 'u1',
        profile: _inactive,
        memberships: const [],
      );
      expect(
        _redirect(
          sessionStatus: AuthSessionStatus.signedIn,
          appContext: AsyncValue.data(context),
          selectedGroup: const SelectedGroupNone(),
          currentLocation: AppRoutes.splash,
        ),
        AppRoutes.accessAccountDisabled,
      );
    });

    test('a missing profile fails closed to account-disabled', () {
      const context = AppContext(userId: 'u1', profile: null, memberships: []);
      expect(
        _redirect(
          sessionStatus: AuthSessionStatus.signedIn,
          appContext: AsyncValue.data(context),
          selectedGroup: const SelectedGroupNone(),
          currentLocation: AppRoutes.splash,
        ),
        AppRoutes.accessAccountDisabled,
      );
    });

    test('an incomplete profile routes to /onboarding/profile', () {
      final context = AppContext(
        userId: 'u1',
        profile: _incomplete,
        memberships: const [],
      );
      expect(
        _redirect(
          sessionStatus: AuthSessionStatus.signedIn,
          appContext: AsyncValue.data(context),
          selectedGroup: const SelectedGroupNone(),
          currentLocation: AppRoutes.splash,
        ),
        AppRoutes.onboardingProfile,
      );
    });
  });

  group('group eligibility routing', () {
    test('a complete profile with no group routes to /onboarding/group', () {
      final context = AppContext(
        userId: 'u1',
        profile: _complete,
        memberships: const [],
      );
      expect(
        _redirect(
          sessionStatus: AuthSessionStatus.signedIn,
          appContext: AsyncValue.data(context),
          selectedGroup: const SelectedGroupNone(),
          currentLocation: AppRoutes.splash,
        ),
        AppRoutes.onboardingGroup,
      );
    });

    test('a resolved single group routes to /home', () {
      final membership = _membership(id: 'm1');
      final context = AppContext(
        userId: 'u1',
        profile: _complete,
        memberships: [membership],
      );
      expect(
        _redirect(
          sessionStatus: AuthSessionStatus.signedIn,
          appContext: AsyncValue.data(context),
          selectedGroup: SelectedGroupResolved(membership),
          currentLocation: AppRoutes.splash,
        ),
        AppRoutes.home,
      );
    });

    test('multiple eligible groups route to /select-group', () {
      final memberships = [_membership(id: 'm1'), _membership(id: 'm2')];
      final context = AppContext(
        userId: 'u1',
        profile: _complete,
        memberships: memberships,
      );
      expect(
        _redirect(
          sessionStatus: AuthSessionStatus.signedIn,
          appContext: AsyncValue.data(context),
          selectedGroup: SelectedGroupPending(memberships),
          currentLocation: AppRoutes.splash,
        ),
        AppRoutes.selectGroup,
      );
    });

    test('a SUSPENDED-only membership routes to membership-restricted, not onboarding', () {
      final membership = _membership(id: 'm1', membershipStatus: 'SUSPENDED');
      final context = AppContext(
        userId: 'u1',
        profile: _complete,
        memberships: [membership],
      );
      expect(
        _redirect(
          sessionStatus: AuthSessionStatus.signedIn,
          appContext: AsyncValue.data(context),
          selectedGroup: const SelectedGroupNone(),
          currentLocation: AppRoutes.splash,
        ),
        AppRoutes.accessMembershipRestricted,
      );
    });

    test('an EXITED-only membership routes to onboarding/group', () {
      final membership = _membership(id: 'm1', membershipStatus: 'EXITED');
      final context = AppContext(
        userId: 'u1',
        profile: _complete,
        memberships: [membership],
      );
      expect(
        _redirect(
          sessionStatus: AuthSessionStatus.signedIn,
          appContext: AsyncValue.data(context),
          selectedGroup: const SelectedGroupNone(),
          currentLocation: AppRoutes.splash,
        ),
        AppRoutes.onboardingGroup,
      );
    });

    test(
      'an ACTIVE membership in a SUSPENDED group routes to group-suspended',
      () {
        final membership = _membership(id: 'm1', groupStatus: 'SUSPENDED');
        final context = AppContext(
          userId: 'u1',
          profile: _complete,
          memberships: [membership],
        );
        expect(
          _redirect(
            sessionStatus: AuthSessionStatus.signedIn,
            appContext: AsyncValue.data(context),
            selectedGroup: const SelectedGroupNone(),
            currentLocation: AppRoutes.splash,
          ),
          AppRoutes.accessGroupSuspended,
        );
      },
    );

    test('an ACTIVE membership in a CLOSED group routes to group-closed', () {
      final membership = _membership(id: 'm1', groupStatus: 'CLOSED');
      final context = AppContext(
        userId: 'u1',
        profile: _complete,
        memberships: [membership],
      );
      expect(
        _redirect(
          sessionStatus: AuthSessionStatus.signedIn,
          appContext: AsyncValue.data(context),
          selectedGroup: const SelectedGroupNone(),
          currentLocation: AppRoutes.splash,
        ),
        AppRoutes.accessGroupClosed,
      );
    });
  });

  group('no-op when already at the correct location', () {
    test('does not redirect away from /home when already resolved', () {
      final membership = _membership(id: 'm1');
      final context = AppContext(
        userId: 'u1',
        profile: _complete,
        memberships: [membership],
      );
      expect(
        _redirect(
          sessionStatus: AuthSessionStatus.signedIn,
          appContext: AsyncValue.data(context),
          selectedGroup: SelectedGroupResolved(membership),
          currentLocation: AppRoutes.home,
        ),
        isNull,
      );
    });
  });
}
