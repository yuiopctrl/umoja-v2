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

import 'fakes/pin_bypass_overrides.dart';
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
  testWidgets(
    'a mobile-width viewport shows the bottom navigation bar, not a rail',
    (tester) async {
      _setViewport(tester, const Size(390, 844));
      await _pumpSignedInApp(tester);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    },
  );

  testWidgets(
    'a wide viewport shows an extended NavigationRail, not the bottom bar',
    (tester) async {
      _setViewport(tester, const Size(1400, 900));
      await _pumpSignedInApp(tester);

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isTrue);
    },
  );

  testWidgets(
    'a tablet-width viewport shows a compact (non-extended) NavigationRail',
    (tester) async {
      _setViewport(tester, const Size(900, 800));
      await _pumpSignedInApp(tester);

      expect(find.byType(NavigationRail), findsOneWidget);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isFalse);
    },
  );

  testWidgets('auth routes do not show the operational bottom navigation', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...pinBypassOverrides(),
          authSessionStatusProvider.overrideWithValue(
            AuthSessionStatus.signedOut,
          ),
        ],
        child: const UmojaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets(
    'the current destination is selected correctly in the bottom nav',
    (tester) async {
      _setViewport(tester, const Size(390, 844));
      await _pumpSignedInApp(tester);

      // Starts on /home -> index 0.
      NavigationBar navBar = tester.widget(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 0);

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Wanachama'),
        ),
      );
      await tester.pumpAndSettle();

      navBar = tester.widget(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 1);

      await tester.tap(find.text('Zaidi'));
      await tester.pumpAndSettle();

      navBar = tester.widget(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 2);
    },
  );
}
