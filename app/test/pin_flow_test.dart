import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/app.dart';
import 'package:umoja/features/auth/models/app_context.dart';
import 'package:umoja/features/auth/models/app_user_profile.dart';
import 'package:umoja/features/auth/models/group_context.dart';
import 'package:umoja/features/auth/models/membership_context.dart';
import 'package:umoja/features/auth/providers/app_context_provider.dart';
import 'package:umoja/features/auth/providers/auth_session_provider.dart';
import 'package:umoja/features/members/providers/member_repository_provider.dart';
import 'package:umoja/features/security/providers/pin_repository_provider.dart';

import 'fakes/fake_member_repository.dart';
import 'fakes/fake_pin_repository.dart';

// These tests deliberately do NOT override hasPinConfiguredProvider or
// lockStateProvider (unlike the rest of the suite, via
// pinBypassOverrides()) — the whole point here is to exercise the real
// PIN gate reactively: pinRepositoryProvider is a real, stateful
// FakePinRepository, so completing PIN setup / entering the correct
// PIN actually flips the app from the PIN screen into the operational
// shell, the same way it would for a real user.

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

Future<void> _pumpApp(
  WidgetTester tester, {
  required FakePinRepository pinRepository,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionStatusProvider.overrideWithValue(AuthSessionStatus.signedIn),
        authUserIdProvider.overrideWithValue('u1'),
        appContextProvider.overrideWith(
          (ref) async => AppContext(
            userId: 'u1',
            profile: const AppUserProfile(id: 'u1', fullName: 'Admin Caller'),
            memberships: [_membership()],
          ),
        ),
        pinRepositoryProvider.overrideWithValue(pinRepository),
        memberRepositoryProvider.overrideWithValue(FakeMemberRepository()),
      ],
      child: const UmojaApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a fresh session with no PIN configured shows PIN setup, and '
      'completing it (4 digits, auto-submit, twice) unlocks into Home', (
    tester,
  ) async {
    final pinRepository = FakePinRepository();
    await _pumpApp(tester, pinRepository: pinRepository);

    expect(find.text('Tengeneza PIN'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1234');
    await tester.pumpAndSettle();

    expect(find.text('Thibitisha PIN'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1234');
    await tester.pumpAndSettle();

    expect(await pinRepository.hasPin('u1'), isTrue);
    expect(find.text('Tengeneza PIN'), findsNothing);
    expect(find.text('Thibitisha PIN'), findsNothing);
    // Lands on the operational shell (Home).
    expect(find.text('Habari, Admin'), findsOneWidget);
  });

  testWidgets(
    'a mismatched confirmation restarts PIN setup instead of unlocking',
    (tester) async {
      final pinRepository = FakePinRepository();
      await _pumpApp(tester, pinRepository: pinRepository);

      await tester.enterText(find.byType(TextField), '1234');
      await tester.pumpAndSettle();
      expect(find.text('Thibitisha PIN'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '9999');
      await tester.pumpAndSettle();

      expect(find.text('PIN hazifanani. Jaribu tena.'), findsOneWidget);
      expect(find.text('Tengeneza PIN'), findsOneWidget);
      expect(await pinRepository.hasPin('u1'), isFalse);
    },
  );

  testWidgets(
    'a PIN already configured shows the unlock screen; wrong PIN shows a '
    'friendly error, correct PIN unlocks into Home',
    (tester) async {
      final pinRepository = FakePinRepository();
      await pinRepository.setPin(userId: 'u1', pin: '1234');
      await _pumpApp(tester, pinRepository: pinRepository);

      expect(find.text('Ingiza PIN'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '0000');
      await tester.pumpAndSettle();

      expect(find.text('PIN si sahihi.'), findsOneWidget);
      expect(find.text('Ingiza PIN'), findsOneWidget); // still locked

      await tester.enterText(find.byType(TextField), '1234');
      await tester.pumpAndSettle();

      expect(find.text('Ingiza PIN'), findsNothing);
      expect(find.text('Habari, Admin'), findsOneWidget);
    },
  );
}
