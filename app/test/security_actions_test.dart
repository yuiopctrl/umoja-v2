import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/app.dart';
import 'package:umoja/features/auth/models/app_context.dart';
import 'package:umoja/features/auth/models/app_user_profile.dart';
import 'package:umoja/features/auth/models/group_context.dart';
import 'package:umoja/features/auth/models/membership_context.dart';
import 'package:umoja/features/auth/providers/app_context_provider.dart';
import 'package:umoja/features/auth/providers/auth_repository_provider.dart';
import 'package:umoja/features/auth/providers/auth_session_provider.dart';
import 'package:umoja/features/members/providers/member_repository_provider.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_member_repository.dart';
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

Future<FakeAuthRepository> _pumpMoreScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final fakeAuth = FakeAuthRepository();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...pinBypassOverrides(),
        authSessionStatusProvider.overrideWithValue(AuthSessionStatus.signedIn),
        authRepositoryProvider.overrideWithValue(fakeAuth),
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

  return fakeAuth;
}

/// Pumps More, taps "Toka" to lock, and lands on the PIN unlock screen
/// — the entry point for the "Umesahau PIN?"/"Tumia namba nyingine"
/// tests below, since both actions only exist on that screen (prompt
/// 05C §3 — deliberately not in normal operational navigation).
Future<FakeAuthRepository> _pumpLockedOnPinUnlock(WidgetTester tester) async {
  final fakeAuth = await _pumpMoreScreen(tester);

  await tester.tap(find.text('Toka'));
  await tester.pumpAndSettle();

  expect(find.text('Ingiza PIN'), findsOneWidget);
  return fakeAuth;
}

void main() {
  testWidgets('normal Toka locks the app without calling Supabase signOut, and '
      'without requiring OTP', (tester) async {
    final fakeAuth = await _pumpMoreScreen(tester);

    await tester.tap(find.text('Toka'));
    await tester.pumpAndSettle();

    expect(fakeAuth.signOutCallCount, 0);
    // Routes to the PIN unlock screen, never back to phone/OTP.
    expect(find.text('Ingiza PIN'), findsOneWidget);
    expect(find.text('Karibu Umoja'), findsNothing);
    expect(find.text('Thibitisha Namba'), findsNothing);
  });

  testWidgets('Umesahau PIN? navigates straight to recovery verify, without '
      'calling Supabase signOut (prompt 05C §18-19 — see '
      'pin_recovery_navigation_test.dart for the full recovery flow)', (
    tester,
  ) async {
    final fakeAuth = await _pumpLockedOnPinUnlock(tester);

    await tester.tap(find.text('Umesahau PIN?'));
    await tester.pumpAndSettle();

    expect(fakeAuth.signOutCallCount, 0);
    expect(find.text('Thibitisha Namba Yako'), findsOneWidget);
  });

  testWidgets('Tumia namba nyingine, after confirming, calls Supabase signOut '
      '(clearing the session so the next sign-in requires phone + OTP)', (
    tester,
  ) async {
    // See the note on the "Umesahau PIN?" test above — same fixture
    // limitation applies here.
    final fakeAuth = await _pumpLockedOnPinUnlock(tester);

    await tester.tap(find.text('Tumia namba nyingine'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tumia Namba Nyingine'));
    await tester.pumpAndSettle();

    expect(fakeAuth.signOutCallCount, 1);
  });

  testWidgets(
    'Tumia namba nyingine requires confirmation — cancelling stays put',
    (tester) async {
      final fakeAuth = await _pumpLockedOnPinUnlock(tester);

      await tester.tap(find.text('Tumia namba nyingine'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ghairi'));
      await tester.pumpAndSettle();

      expect(fakeAuth.signOutCallCount, 0);
      expect(find.text('Ingiza PIN'), findsOneWidget);
    },
  );
}
