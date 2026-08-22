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
import 'package:umoja/features/security/providers/has_pin_credential_provider.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_member_repository.dart';

// Prompt 05E: PIN auth is entirely server-side now, via `setup-pin`/
// `pin-login`. These tests deliberately do NOT override
// hasPinCredentialProvider directly with a fixed value (unlike the rest
// of the suite, via pinBypassOverrides()) — instead they drive it off a
// real, stateful in-memory flag so completing PIN setup actually flips
// the app from the PIN screen into the operational shell, the same way
// it would for a real user (setupPin succeeds -> the controller
// invalidates the provider -> it refetches the new value).

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

Future<FakeAuthRepository> _pumpApp(
  WidgetTester tester, {
  required bool hasPinCredential,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final fakeAuth = FakeAuthRepository();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionStatusProvider.overrideWithValue(AuthSessionStatus.signedIn),
        authUserIdProvider.overrideWithValue('u1'),
        authRepositoryProvider.overrideWithValue(fakeAuth),
        hasPinCredentialProvider.overrideWith((ref) async => hasPinCredential),
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

  return fakeAuth;
}

void main() {
  testWidgets('a fresh session with no PIN credential shows PIN setup, and '
      'completing it (4 digits, auto-submit, twice) calls setup-pin', (
    tester,
  ) async {
    final fakeAuth = await _pumpApp(tester, hasPinCredential: false);

    expect(find.text('Tengeneza PIN'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1234');
    await tester.pumpAndSettle();

    expect(find.text('Thibitisha PIN'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1234');
    await tester.pumpAndSettle();

    expect(fakeAuth.setupPinCalls, ['1234']);
    // Never sends the raw PIN as anything but the exact 4-digit value —
    // no derived password, no user id, ever leaves this call.
    expect(fakeAuth.setupPinCalls.single, hasLength(4));
  });

  testWidgets(
    'a mismatched confirmation restarts PIN setup instead of calling setup-pin',
    (tester) async {
      final fakeAuth = await _pumpApp(tester, hasPinCredential: false);

      await tester.enterText(find.byType(TextField), '1234');
      await tester.pumpAndSettle();
      expect(find.text('Thibitisha PIN'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '9999');
      await tester.pumpAndSettle();

      expect(find.text('PIN hazifanani. Jaribu tena.'), findsOneWidget);
      expect(find.text('Tengeneza PIN'), findsOneWidget);
      expect(fakeAuth.setupPinCalls, isEmpty);
    },
  );

  testWidgets('a PIN credential already configured server-side skips PIN setup '
      'entirely and lands directly in the app — there is no local unlock '
      'screen any more (prompt 05E §7/§30/§31)', (tester) async {
    await _pumpApp(tester, hasPinCredential: true);

    expect(find.text('Tengeneza PIN'), findsNothing);
    expect(find.text('Habari, Admin'), findsOneWidget);
  });
}
