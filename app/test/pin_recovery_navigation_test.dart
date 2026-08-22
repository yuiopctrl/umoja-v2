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
import 'package:umoja/features/security/providers/has_pin_credential_provider.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_member_repository.dart';

MembershipContext _membership() {
  return const MembershipContext(
    membershipId: 'm-admin',
    group: GroupContext(
      groupId: 'g1',
      groupName: 'Umoja Wamama',
      groupStatus: 'ACTIVE',
    ),
    membershipStatus: 'ACTIVE',
    displayName: 'Admin Caller',
    roleCodes: ['ADMIN'],
    permissionCodes: ['member.view'],
  );
}

final _fakeUser = User(
  id: 'u1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
  phone: '255712345678',
);

class _FakeUserNotifier extends Notifier<User?> {
  @override
  User? build() => null;
  void set(User? user) => state = user;
}

final _fakeUserProvider = NotifierProvider<_FakeUserNotifier, User?>(
  _FakeUserNotifier.new,
);

/// Pumps the app signed out on `/auth/phone` (the combined phone+PIN
/// login screen), types a phone number, then taps "Umesahau PIN?" to
/// land on the recovery verify screen — the shared entry point for
/// every test below (prompt 05E §17: recovery starts signed-out, before
/// its own OTP verify, reusing whatever phone number is already typed
/// on the login screen).
Future<({FakeAuthRepository auth, ProviderContainer container})>
_pumpOnRecoveryVerify(WidgetTester tester) async {
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
            profile: const AppUserProfile(id: 'u1', fullName: 'Admin Caller'),
            memberships: [_membership()],
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

  expect(find.text('Karibu Umoja'), findsOneWidget);
  await tester.enterText(find.byType(TextField).first, '0712345678');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Umesahau PIN?'));
  await tester.pumpAndSettle();
  expect(find.text('Thibitisha Namba Yako'), findsOneWidget);

  return (auth: fakeAuth, container: container);
}

void main() {
  testWidgets('login screen -> Umesahau PIN works', (tester) async {
    await _pumpOnRecoveryVerify(tester);
    // _pumpOnRecoveryVerify's own assertion already proves this; kept
    // as an explicit, separately-named test per prompt 05C §23 item 1.
  });

  testWidgets('the recovery verify screen has a visible Back/Cancel', (
    tester,
  ) async {
    await _pumpOnRecoveryVerify(tester);

    expect(find.byKey(const Key('authScreenBackButton')), findsOneWidget);
    expect(find.text('Ghairi'), findsOneWidget);
  });

  testWidgets('tapping Back from recovery verify returns to the login screen', (
    tester,
  ) async {
    await _pumpOnRecoveryVerify(tester);

    await tester.tap(find.byKey(const Key('authScreenBackButton')));
    await tester.pumpAndSettle();

    expect(find.text('Karibu Umoja'), findsOneWidget);
    expect(find.text('Thibitisha Namba Yako'), findsNothing);
  });

  testWidgets(
    'tapping the Cancel text button from recovery verify also returns to '
    'the login screen (same destination as the visible Back arrow)',
    (tester) async {
      await _pumpOnRecoveryVerify(tester);

      await tester.tap(find.text('Ghairi'));
      await tester.pumpAndSettle();

      expect(find.text('Karibu Umoja'), findsOneWidget);
    },
  );

  testWidgets('cancelling recovery does not call Supabase signOut', (
    tester,
  ) async {
    final fakes = await _pumpOnRecoveryVerify(tester);

    await tester.tap(find.byKey(const Key('authScreenBackButton')));
    await tester.pumpAndSettle();

    expect(fakes.auth.signOutCallCount, 0);
  });

  testWidgets('cancelling recovery never calls setup-pin — the existing PIN '
      'credential is only ever replaced by a *successful* recovery', (
    tester,
  ) async {
    final fakes = await _pumpOnRecoveryVerify(tester);

    await tester.tap(find.byKey(const Key('authScreenBackButton')));
    await tester.pumpAndSettle();

    expect(fakes.auth.setupPinCalls, isEmpty);
  });

  testWidgets('the Android system Back button/gesture behaves exactly like the '
      'visible Back arrow (returns to the login screen, no signOut)', (
    tester,
  ) async {
    final fakes = await _pumpOnRecoveryVerify(tester);

    // `PopScope` is generic (`PopScope<T>`) in this Flutter version,
    // so `find.byType(PopScope)` (unparameterized) never matches a
    // concrete instantiation — a predicate using `is PopScope` does.
    final popScope =
        tester.widget(find.byWidgetPredicate((w) => w is PopScope)) as PopScope;
    // canPop is false: the system back gesture/button always reaches
    // onPopInvokedWithResult(false, ...) rather than actually
    // popping, which is exactly what this simulates.
    expect(popScope.canPop, isFalse);
    popScope.onPopInvokedWithResult!(false, null);
    await tester.pumpAndSettle();

    expect(find.text('Karibu Umoja'), findsOneWidget);
    expect(fakes.auth.signOutCallCount, 0);
  });

  testWidgets('a successful OTP verify proceeds to the New PIN screen', (
    tester,
  ) async {
    final fakes = await _pumpOnRecoveryVerify(tester);

    await tester.enterText(find.byType(TextField).first, '000000');
    await tester.pumpAndSettle();
    // Verifying the OTP establishes a real Supabase session — simulate
    // that side effect the same way the rest of the suite does (the
    // fake repository itself never drives auth state, matching how the
    // real `AuthRepository` abstraction doesn't either).
    fakes.container.read(_fakeUserProvider.notifier).set(_fakeUser);
    await tester.pumpAndSettle();

    expect(find.text('Tengeneza PIN'), findsOneWidget);
  });

  testWidgets(
    'a new PIN is only sent to setup-pin once both entry steps complete — '
    'not merely after OTP verification — and then lands in the app',
    (tester) async {
      final fakes = await _pumpOnRecoveryVerify(tester);

      await tester.enterText(find.byType(TextField).first, '000000');
      await tester.pumpAndSettle();
      fakes.container.read(_fakeUserProvider.notifier).set(_fakeUser);
      await tester.pumpAndSettle();
      expect(find.text('Tengeneza PIN'), findsOneWidget);

      // Reaching the New PIN screen alone must not have called
      // setup-pin yet.
      expect(fakes.auth.setupPinCalls, isEmpty);

      await tester.enterText(find.byType(TextField).first, '5678');
      await tester.pumpAndSettle();
      expect(find.text('Thibitisha PIN'), findsOneWidget);
      expect(fakes.auth.setupPinCalls, isEmpty);

      await tester.enterText(find.byType(TextField).first, '5678');
      await tester.pumpAndSettle();

      expect(fakes.auth.setupPinCalls, ['5678']);
      // A successful recovery lands in the operational app, not stuck
      // on the New PIN screen (see PinSetupScreen's explicit navigate-
      // on-success for the recovery reuse).
      expect(find.textContaining('Habari'), findsWidgets);
    },
  );

  testWidgets(
    'backing out of the New PIN screen before completing it never calls '
    'setup-pin or signs the user out — the fresh OTP session and the '
    'still-intact old PIN credential land the user in the app rather than '
    'being force-walked through a redundant login',
    (tester) async {
      final fakes = await _pumpOnRecoveryVerify(tester);

      await tester.enterText(find.byType(TextField).first, '000000');
      await tester.pumpAndSettle();
      fakes.container.read(_fakeUserProvider.notifier).set(_fakeUser);
      await tester.pumpAndSettle();
      expect(find.text('Tengeneza PIN'), findsOneWidget);

      await tester.tap(find.byKey(const Key('authScreenBackButton')));
      await tester.pumpAndSettle();

      expect(fakes.auth.setupPinCalls, isEmpty);
      expect(fakes.auth.signOutCallCount, 0);
      expect(find.textContaining('Habari'), findsWidgets);
    },
  );
}
