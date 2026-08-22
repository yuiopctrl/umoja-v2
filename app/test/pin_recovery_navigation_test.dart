import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umoja/app/app.dart';
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
import 'fakes/pin_bypass_overrides.dart';

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

/// Pumps the app locked on `/auth/pin-unlock`, then taps "Umesahau
/// PIN?" to land on the recovery verify screen — the shared entry point
/// for every test below. [pinRepository] pre-seeds an existing PIN
/// (`'1234'`) so tests can assert it survives cancellation.
Future<({FakeAuthRepository auth, FakePinRepository pin})>
_pumpOnRecoveryVerify(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final fakeAuth = FakeAuthRepository();
  final fakePin = FakePinRepository();
  await fakePin.setPin(userId: 'u1', pin: '1234');
  // The seed call above is not a "the app saved a new PIN" event —
  // clear it so `setPinCalls` in the tests below only reflects PIN
  // saves that happen *during* the test itself.
  fakePin.setPinCalls.clear();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...pinBypassOverrides(),
        authSessionStatusProvider.overrideWithValue(AuthSessionStatus.signedIn),
        authRepositoryProvider.overrideWithValue(fakeAuth),
        pinRepositoryProvider.overrideWithValue(fakePin),
        currentSupabaseUserProvider.overrideWithValue(_fakeUser),
        appContextProvider.overrideWith(
          (ref) async => AppContext(
            userId: 'u1',
            profile: const AppUserProfile(id: 'u1', fullName: 'Admin Caller'),
            memberships: [_membership()],
          ),
        ),
        memberRepositoryProvider.overrideWithValue(FakeMemberRepository()),
      ],
      child: const UmojaApp(),
    ),
  );
  await tester.pumpAndSettle();

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

  await tester.tap(find.text('Umesahau PIN?'));
  await tester.pumpAndSettle();
  expect(find.text('Thibitisha Namba Yako'), findsOneWidget);

  return (auth: fakeAuth, pin: fakePin);
}

void main() {
  testWidgets('PIN screen -> Forgot PIN works', (tester) async {
    await _pumpOnRecoveryVerify(tester);
    // _pumpOnRecoveryVerify's own assertion already proves this; kept
    // as an explicit, separately-named test per prompt 05C §23 item 1.
  });

  testWidgets('the Forgot PIN screen has a visible Back/Cancel', (
    tester,
  ) async {
    await _pumpOnRecoveryVerify(tester);

    expect(find.byKey(const Key('authScreenBackButton')), findsOneWidget);
    expect(find.text('Ghairi'), findsOneWidget);
  });

  testWidgets('tapping Back from Forgot PIN returns to PIN login', (
    tester,
  ) async {
    await _pumpOnRecoveryVerify(tester);

    await tester.tap(find.byKey(const Key('authScreenBackButton')));
    await tester.pumpAndSettle();

    expect(find.text('Ingiza PIN'), findsOneWidget);
    expect(find.text('Thibitisha Namba Yako'), findsNothing);
  });

  testWidgets(
    'tapping the Cancel text button from Forgot PIN also returns to PIN '
    'login (same destination as the visible Back arrow)',
    (tester) async {
      await _pumpOnRecoveryVerify(tester);

      await tester.tap(find.text('Ghairi'));
      await tester.pumpAndSettle();

      expect(find.text('Ingiza PIN'), findsOneWidget);
    },
  );

  testWidgets('cancelling Forgot PIN does not call Supabase signOut', (
    tester,
  ) async {
    final fakes = await _pumpOnRecoveryVerify(tester);

    await tester.tap(find.byKey(const Key('authScreenBackButton')));
    await tester.pumpAndSettle();

    expect(fakes.auth.signOutCallCount, 0);
  });

  testWidgets('cancelling Forgot PIN does not clear the existing PIN — the old '
      'PIN still unlocks the app afterward', (tester) async {
    final fakes = await _pumpOnRecoveryVerify(tester);

    await tester.tap(find.byKey(const Key('authScreenBackButton')));
    await tester.pumpAndSettle();

    expect(fakes.pin.clearPinCalls, isEmpty);
    expect(await fakes.pin.hasPin('u1'), isTrue);
    expect(
      await fakes.pin.verifyPin(userId: 'u1', pin: '1234'),
      isTrue,
      reason: 'the pre-existing PIN must still be valid',
    );

    // And it actually still unlocks the app from PIN login.
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pumpAndSettle();
    expect(find.textContaining('Habari'), findsWidgets);
  });

  testWidgets('the Android system Back button/gesture behaves exactly like the '
      'visible Back arrow (returns to PIN login, no signOut)', (tester) async {
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

    expect(find.text('Ingiza PIN'), findsOneWidget);
    expect(fakes.auth.signOutCallCount, 0);
  });

  testWidgets('a successful OTP verify proceeds to the New PIN screen', (
    tester,
  ) async {
    await _pumpOnRecoveryVerify(tester);

    // Auto-sent on entry; auto-submits at 6 digits.
    await tester.enterText(find.byType(TextField), '000000');
    await tester.pumpAndSettle();

    expect(find.text('Tengeneza PIN'), findsOneWidget);
  });

  testWidgets('a successful new PIN replaces the old PIN only after both entry '
      'steps complete — not merely after OTP verification', (tester) async {
    final fakes = await _pumpOnRecoveryVerify(tester);

    await tester.enterText(find.byType(TextField), '000000');
    await tester.pumpAndSettle();
    expect(find.text('Tengeneza PIN'), findsOneWidget);

    // Reaching the New PIN screen alone must not have touched the
    // stored PIN yet.
    expect(fakes.pin.setPinCalls, isEmpty);
    expect(
      await fakes.pin.verifyPin(userId: 'u1', pin: '1234'),
      isTrue,
      reason: 'old PIN must still be intact mid-recovery',
    );

    await tester.enterText(find.byType(TextField), '5678');
    await tester.pumpAndSettle();
    expect(find.text('Thibitisha PIN'), findsOneWidget);
    // Old PIN still untouched between "enter" and "confirm".
    expect(fakes.pin.setPinCalls, isEmpty);

    await tester.enterText(find.byType(TextField), '5678');
    await tester.pumpAndSettle();

    expect(fakes.pin.setPinCalls, ['u1']);
    expect(await fakes.pin.verifyPin(userId: 'u1', pin: '5678'), isTrue);
    expect(
      await fakes.pin.verifyPin(userId: 'u1', pin: '1234'),
      isFalse,
      reason: 'the old PIN is replaced once the new one is confirmed',
    );
  });

  testWidgets(
    'backing out of the New PIN screen before completing it routes to a '
    'safe, still-locked PIN entry state rather than unlocking the app',
    (tester) async {
      final fakes = await _pumpOnRecoveryVerify(tester);

      await tester.enterText(find.byType(TextField), '000000');
      await tester.pumpAndSettle();
      expect(find.text('Tengeneza PIN'), findsOneWidget);

      await tester.tap(find.byKey(const Key('authScreenBackButton')));
      await tester.pumpAndSettle();

      expect(find.text('Ingiza PIN'), findsOneWidget);
      expect(fakes.pin.setPinCalls, isEmpty);
      expect(fakes.pin.clearPinCalls, isEmpty);
      expect(fakes.auth.signOutCallCount, 0);
    },
  );
}
