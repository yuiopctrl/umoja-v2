import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umoja/app/app.dart';
import 'package:umoja/core/supabase/supabase_client_provider.dart';
import 'package:umoja/features/auth/models/app_context.dart';
import 'package:umoja/features/auth/models/app_user_profile.dart';
import 'package:umoja/features/auth/models/group_context.dart';
import 'package:umoja/features/auth/models/membership_context.dart';
import 'package:umoja/features/auth/data/auth_failure.dart';
import 'package:umoja/features/auth/providers/app_context_provider.dart';
import 'package:umoja/features/auth/providers/auth_repository_provider.dart';
import 'package:umoja/features/auth/providers/auth_session_provider.dart';
import 'package:umoja/features/members/providers/member_repository_provider.dart';
import 'package:umoja/features/security/providers/has_pin_credential_provider.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_member_repository.dart';

/// Prompt 05E: end-to-end regression for the full server-side phone +
/// PIN login cycle — returning login never shows OTP, a wrong PIN never
/// signs anyone in, and "Toka" always returns to the same phone + PIN
/// login screen (never a cached/local unlock, never an automatic OTP).
///
/// Like the rest of this suite that exercises real auth-state
/// transitions (see pin_recovery_navigation_test.dart), this drives the
/// real [currentSupabaseUserProvider]/`authUserIdProvider`/
/// `hasPinCredentialProvider` chain — [FakeAuthRepository] itself never
/// touches auth state (matching how the real `AuthRepository`
/// abstraction doesn't either; only Supabase Auth's own state stream
/// does), so a successful `pinLogin`/`signOut` call is followed by the
/// test manually flipping the fake user provider, standing in for what
/// that stream would emit.
User _fakeUser(String id) => User(
  id: id,
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
);

class _FakeUserNotifier extends Notifier<User?> {
  @override
  User? build() => null;
  void set(User? user) => state = user;
}

final _fakeUserProvider = NotifierProvider<_FakeUserNotifier, User?>(
  _FakeUserNotifier.new,
);

MembershipContext _membership(String uid) => MembershipContext(
  membershipId: 'm-$uid',
  group: const GroupContext(
    groupId: 'g1',
    groupName: 'Umoja Wamama',
    groupStatus: 'ACTIVE',
  ),
  membershipStatus: 'ACTIVE',
  displayName: 'Member $uid',
  roleCodes: const ['ADMIN'],
  permissionCodes: const ['member.view'],
);

void main() {
  testWidgets(
    'returning login is always phone + PIN, never OTP; a wrong PIN never '
    'signs in; a correct PIN signs in; and "Toka" always returns to the '
    'same phone + PIN login screen',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final fakeAuth = FakeAuthRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isSupabaseConfiguredProvider.overrideWithValue(true),
            currentSupabaseUserProvider.overrideWith(
              (ref) => ref.watch(_fakeUserProvider),
            ),
            authRepositoryProvider.overrideWithValue(fakeAuth),
            hasPinCredentialProvider.overrideWith((ref) async => true),
            appContextProvider.overrideWith((ref) async {
              final user = ref.watch(_fakeUserProvider);
              if (user == null) {
                throw StateError('appContextProvider read while signed out');
              }
              return AppContext(
                userId: user.id,
                profile: AppUserProfile(id: user.id, fullName: 'Test User'),
                memberships: [_membership(user.id)],
              );
            }),
            memberRepositoryProvider.overrideWithValue(FakeMemberRepository()),
          ],
          child: const UmojaApp(),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(UmojaApp)),
      );

      // ---------------------------------------------------------------
      // 1. Signed out: the phone + PIN login screen, never OTP, never
      // an auto-sent code.
      // ---------------------------------------------------------------
      expect(find.text('Karibu Umoja'), findsOneWidget);
      expect(find.text('Thibitisha Namba'), findsNothing);
      expect(fakeAuth.sentOtpTo, isEmpty);

      // ---------------------------------------------------------------
      // 2. A wrong PIN never signs in — the login screen shows a
      // generic error and stays put.
      // ---------------------------------------------------------------
      fakeAuth.pinLoginFailure = const AuthFailure(
        AuthFailureType.invalidCredentials,
        'Phone number or PIN is incorrect.',
      );
      await tester.enterText(find.byType(TextField).at(0), '0712345678');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '0000');
      await tester.pumpAndSettle();

      expect(fakeAuth.pinLoginCalls, [('+255712345678', '0000')]);
      expect(find.text('Namba ya simu au PIN si sahihi.'), findsOneWidget);
      expect(find.text('Karibu Umoja'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      // ---------------------------------------------------------------
      // 3. The correct PIN signs in — never a fake/service-role
      // shortcut; this only happens because pin-login itself succeeded
      // and the resulting session was installed for real.
      // ---------------------------------------------------------------
      fakeAuth.pinLoginFailure = null;
      await tester.enterText(find.byType(TextField).at(1), '1234');
      await tester.pumpAndSettle();

      expect(fakeAuth.pinLoginCalls.last, ('+255712345678', '1234'));
      container.read(_fakeUserProvider.notifier).set(_fakeUser('userA'));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);

      // ---------------------------------------------------------------
      // 4. "Toka" always calls the real Supabase sign-out and returns
      // to the same phone + PIN login screen — never an automatic OTP,
      // never a local unlock screen.
      // ---------------------------------------------------------------
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Zaidi'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toka'));
      await tester.pumpAndSettle();

      expect(fakeAuth.signOutCallCount, 1);
      container.read(_fakeUserProvider.notifier).set(null);
      await tester.pumpAndSettle();

      expect(find.text('Karibu Umoja'), findsOneWidget);
      expect(find.text('Thibitisha Namba'), findsNothing);
      expect(fakeAuth.sentOtpTo, isEmpty);
    },
  );
}
