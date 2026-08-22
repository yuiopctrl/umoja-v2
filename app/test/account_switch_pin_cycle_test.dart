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
import 'package:umoja/features/auth/providers/app_context_provider.dart';
import 'package:umoja/features/auth/providers/auth_repository_provider.dart';
import 'package:umoja/features/auth/providers/auth_session_provider.dart';
import 'package:umoja/features/members/providers/member_repository_provider.dart';
import 'package:umoja/features/security/providers/pin_repository_provider.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_member_repository.dart';
import 'fakes/fake_pin_repository.dart';

/// Prompt 05D §9-15: end-to-end regression for the live OTP/PIN-setup
/// cycle bug — reproduced by switching between two accounts ("Tumia
/// namba nyingine") and verifying neither account is ever asked to
/// create a PIN a second time, and neither is ever bounced back through
/// OTP after already having one.
///
/// Unlike the rest of the widget suite (which bypasses PIN gating via
/// `pinBypassOverrides()`), this test drives the *real*
/// [currentSupabaseUserProvider]/[latestAuthChangeEventProvider]/
/// `authUserIdProvider`/`LockNotifier`/`hasPinConfiguredProvider` chain
/// — only the two raw signal providers are overridden with fakes this
/// test controls directly, standing in for what the real Supabase
/// auth-state stream would emit at each step (`FakeAuthRepository`
/// itself never touches them, matching how the real `AuthRepository`
/// abstraction never drives auth state directly either — see
/// docs/product/authentication.md).
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

class _FakeEventNotifier extends Notifier<AuthChangeEvent?> {
  @override
  AuthChangeEvent? build() => null;
  void set(AuthChangeEvent? event) => state = event;
}

final _fakeUserProvider = NotifierProvider<_FakeUserNotifier, User?>(
  _FakeUserNotifier.new,
);
final _fakeEventProvider =
    NotifierProvider<_FakeEventNotifier, AuthChangeEvent?>(
      _FakeEventNotifier.new,
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
    'switching between two accounts never re-triggers PIN setup for an '
    'account that already has one, and never leaves the app cycling '
    'between OTP and PIN setup',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final fakePins = FakePinRepository();
      final fakeAuth = FakeAuthRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isSupabaseConfiguredProvider.overrideWithValue(true),
            currentSupabaseUserProvider.overrideWith(
              (ref) => ref.watch(_fakeUserProvider),
            ),
            latestAuthChangeEventProvider.overrideWith(
              (ref) => ref.watch(_fakeEventProvider),
            ),
            authRepositoryProvider.overrideWithValue(fakeAuth),
            pinRepositoryProvider.overrideWithValue(fakePins),
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

      // Starts signed out.
      expect(find.text('Karibu Umoja'), findsOneWidget);

      // ---------------------------------------------------------------
      // 1-2. Account A's OTP verifies -> unlocks immediately -> no PIN
      // yet for A -> PIN setup -> completing it lands in the app.
      // ---------------------------------------------------------------
      container.read(_fakeUserProvider.notifier).set(_fakeUser('userA'));
      container.read(_fakeEventProvider.notifier).set(AuthChangeEvent.signedIn);
      await tester.pumpAndSettle();

      expect(find.text('Tengeneza PIN'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '1234');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1234');
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(await fakePins.hasPin('userA'), isTrue);

      // ---------------------------------------------------------------
      // 3. Normal "Toka" locks without touching Supabase; the correct
      // PIN unlocks straight back into the app.
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

      expect(find.text('Ingiza PIN'), findsOneWidget);
      expect(fakeAuth.signOutCallCount, 0);

      await tester.enterText(find.byType(TextField), '1234');
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);

      // ---------------------------------------------------------------
      // 4. "Tumia namba nyingine": deliberate account switch. Signs out
      // (simulated the same way a real Supabase signedOut event would
      // arrive) and must NOT clear A's stored PIN.
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
      await tester.tap(find.text('Tumia namba nyingine'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tumia Namba Nyingine'));
      await tester.pump();

      container.read(_fakeUserProvider.notifier).set(null);
      container
          .read(_fakeEventProvider.notifier)
          .set(AuthChangeEvent.signedOut);
      await tester.pumpAndSettle();

      expect(fakeAuth.signOutCallCount, 1);
      expect(find.text('Karibu Umoja'), findsOneWidget);
      expect(
        await fakePins.hasPin('userA'),
        isTrue,
        reason:
            'account switch must not clear the outgoing user\'s PIN '
            '(prompt 05D §12)',
      );

      // ---------------------------------------------------------------
      // 5-6. Phone B's OTP verifies -> unlocks immediately -> no PIN
      // yet for B -> PIN setup exactly once -> lands in the app
      // directly, never bounced back to OTP.
      // ---------------------------------------------------------------
      container.read(_fakeUserProvider.notifier).set(_fakeUser('userB'));
      container.read(_fakeEventProvider.notifier).set(AuthChangeEvent.signedIn);
      await tester.pumpAndSettle();

      expect(find.text('Tengeneza PIN'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '5678');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '5678');
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Thibitisha'), findsNothing);
      expect(await fakePins.hasPin('userB'), isTrue);

      // ---------------------------------------------------------------
      // 7-11. Switch back to A. A's OTP verifies again — since A's PIN
      // was never cleared and the fresh signedIn event unlocks
      // immediately, this must land directly in the app: no PIN setup,
      // no PIN unlock, no bounce back to OTP.
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
      await tester.tap(find.text('Tumia namba nyingine'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tumia Namba Nyingine'));
      await tester.pump();

      container.read(_fakeUserProvider.notifier).set(null);
      container
          .read(_fakeEventProvider.notifier)
          .set(AuthChangeEvent.signedOut);
      await tester.pumpAndSettle();

      container.read(_fakeUserProvider.notifier).set(_fakeUser('userA'));
      container.read(_fakeEventProvider.notifier).set(AuthChangeEvent.signedIn);
      await tester.pumpAndSettle();

      expect(
        find.byType(NavigationBar),
        findsOneWidget,
        reason:
            'A\'s existing PIN must be recognized and the session '
            'unlocked immediately on its fresh OTP verify',
      );
      expect(find.text('Tengeneza PIN'), findsNothing);
      expect(find.text('Ingiza PIN'), findsNothing);
      expect(find.text('Karibu Umoja'), findsNothing);
      expect(find.text('Thibitisha'), findsNothing);
    },
  );
}
