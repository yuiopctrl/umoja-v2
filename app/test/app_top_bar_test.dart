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

import 'fakes/fake_member_repository.dart';
import 'fakes/pin_bypass_overrides.dart';

MembershipContext _membership() {
  return const MembershipContext(
    membershipId: 'm-admin',
    group: GroupContext(
      groupId: 'g1',
      groupName: 'Umoja Demo',
      groupStatus: 'ACTIVE',
    ),
    membershipStatus: 'ACTIVE',
    displayName: 'Admin Caller',
    roleCodes: ['ADMIN'],
    permissionCodes: ['member.view'],
  );
}

Future<void> _pumpSignedInApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...pinBypassOverrides(),
        authSessionStatusProvider.overrideWithValue(AuthSessionStatus.signedIn),
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
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('the top bar shows the current group name and a profile menu, on '
      'both mobile and desktop', (tester) async {
    for (final size in [const Size(390, 844), const Size(1400, 900)]) {
      _setViewport(tester, size);
      await _pumpSignedInApp(tester);

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Umoja Demo'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('profileMenuButton')), findsOneWidget);
    }
  });

  testWidgets('the profile avatar shows first+last name initials', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    await _pumpSignedInApp(tester);

    expect(find.text('AC'), findsOneWidget); // "Admin Caller"
  });

  testWidgets('tapping the profile avatar opens a modal sheet with the account '
      'name, current group, and Sign Out — Switch Group is hidden with '
      'only one eligible group', (tester) async {
    _setViewport(tester, const Size(390, 844));
    await _pumpSignedInApp(tester);

    await tester.tap(find.byKey(const Key('profileMenuButton')));
    await tester.pumpAndSettle();

    // Default language is Kiswahili — matches the app's own default.
    expect(find.text('Admin Caller'), findsOneWidget);
    // Also still in the top bar title behind the sheet.
    expect(find.text('Umoja Demo'), findsWidgets);
    expect(find.text('Badili Kikundi'), findsNothing);
    expect(find.text('Toka'), findsOneWidget);
    expect(find.text('Kiswahili'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });
}
