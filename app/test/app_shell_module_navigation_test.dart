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

/// Prompt 09E-UAT-BLOCKER-01 (section D/E/F): the shell navigation
/// registry (`shellDestinations`) had never been extended past Home/
/// Members/Contributions/More even though Payments, Loans, and Finance/
/// Cashbook were all fully implemented modules — so neither the mobile
/// bottom nav nor the desktop/tablet rail could ever reach them. This
/// covers the fix: each module destination is gated on the exact
/// permission its own home screen already requires (never hard-coded
/// visible), and the same fix applies to both mobile and desktop since
/// they share one `shellDestinations()` list.
MembershipContext _membershipWith(List<String> permissions) {
  return MembershipContext(
    membershipId: 'm-admin',
    group: const GroupContext(
      groupId: 'g1',
      groupName: 'Umoja Wamama',
      groupStatus: 'ACTIVE',
    ),
    membershipStatus: 'ACTIVE',
    displayName: 'Admin Caller',
    roleCodes: const ['ADMIN'],
    permissionCodes: permissions,
  );
}

Future<void> _pumpSignedInApp(
  WidgetTester tester, {
  required List<String> permissions,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...pinBypassOverrides(),
        authSessionStatusProvider.overrideWithValue(AuthSessionStatus.signedIn),
        appContextProvider.overrideWith(
          (ref) async => AppContext(
            userId: 'u1',
            profile: const AppUserProfile(id: 'u1', fullName: 'Admin Caller'),
            memberships: [_membershipWith(permissions)],
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

const _fullPermissions = [
  'member.view',
  'contribution.view',
  'payment.view',
  'loan.view',
  'financial_account.view',
];

void main() {
  group('Desktop/tablet sidebar', () {
    testWidgets(
      'a fully-permissioned user sees every eligible primary module, not '
      'just Members/Contributions/More',
      (tester) async {
        _setViewport(tester, const Size(1400, 900));
        await _pumpSignedInApp(tester, permissions: _fullPermissions);

        final rail = find.byType(NavigationRail);
        expect(rail, findsOneWidget);
        expect(
          find.descendant(of: rail, matching: find.text('Malipo')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: rail, matching: find.text('Mikopo')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: rail, matching: find.text('Fedha')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a user without payment/loan/financial permission never sees those '
      'destinations (nav stays permission-aware, never hard-coded)',
      (tester) async {
        _setViewport(tester, const Size(1400, 900));
        await _pumpSignedInApp(tester, permissions: const ['member.view']);

        final rail = find.byType(NavigationRail);
        expect(rail, findsOneWidget);
        expect(
          find.descendant(of: rail, matching: find.text('Malipo')),
          findsNothing,
        );
        expect(
          find.descendant(of: rail, matching: find.text('Mikopo')),
          findsNothing,
        );
        expect(
          find.descendant(of: rail, matching: find.text('Fedha')),
          findsNothing,
        );
      },
    );
  });

  group('Mobile bottom navigation', () {
    testWidgets('a fully-permissioned user sees only the curated Home/Members/'
        'Payments/More set on mobile — Contributions/Loans/Finance move '
        'into the More screen instead of congesting the bar', (tester) async {
      _setViewport(tester, const Size(390, 844));
      await _pumpSignedInApp(tester, permissions: _fullPermissions);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);

      final navBar = find.byType(NavigationBar);
      expect(tester.widget<NavigationBar>(navBar).destinations.length, 4);
      expect(
        find.descendant(of: navBar, matching: find.text('Malipo')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: navBar, matching: find.text('Mikopo')),
        findsNothing,
      );
      expect(
        find.descendant(of: navBar, matching: find.text('Michango')),
        findsNothing,
      );
      expect(
        find.descendant(of: navBar, matching: find.text('Fedha')),
        findsNothing,
      );
    });

    testWidgets(
      'a member.view-only user on mobile still sees exactly Home/Members/'
      'More, unaffected by the module additions',
      (tester) async {
        _setViewport(tester, const Size(390, 844));
        await _pumpSignedInApp(tester, permissions: const ['member.view']);

        final navBar = find.byType(NavigationBar);
        expect(navBar, findsOneWidget);
        expect(tester.widget<NavigationBar>(navBar).destinations.length, 3);
      },
    );

    testWidgets(
      'the demoted modules (Contributions/Loans/Finance) surface in the '
      'More sheet on mobile, and tapping one navigates to it',
      (tester) async {
        _setViewport(tester, const Size(390, 844));
        await _pumpSignedInApp(tester, permissions: _fullPermissions);

        await tester.tap(find.text('Zaidi'));
        await tester.pumpAndSettle();

        final sheet = find.byType(BottomSheet);
        expect(
          find.descendant(of: sheet, matching: find.text('Michango')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: sheet, matching: find.text('Mikopo')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: sheet, matching: find.text('Fedha')),
          findsOneWidget,
        );

        await tester.tap(
          find.descendant(of: sheet, matching: find.text('Mikopo')),
        );
        await tester.pumpAndSettle();

        // Opening the modal never moved the bar's own selection — it
        // stays on Home (index 0), where "Zaidi" was tapped from.
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byType(NavigationBar), findsOneWidget);
        final navBar = find.byType(NavigationBar);
        expect(tester.widget<NavigationBar>(navBar).selectedIndex, 0);
      },
    );

    testWidgets(
      'a member.view-only user sees no module links in the More sheet '
      '(nothing is demoted because nothing extra was ever shown)',
      (tester) async {
        _setViewport(tester, const Size(390, 844));
        await _pumpSignedInApp(tester, permissions: const ['member.view']);

        await tester.tap(find.text('Zaidi'));
        await tester.pumpAndSettle();

        final sheet = find.byType(BottomSheet);
        expect(
          find.descendant(of: sheet, matching: find.text('Michango')),
          findsNothing,
        );
        expect(
          find.descendant(of: sheet, matching: find.text('Mikopo')),
          findsNothing,
        );
        expect(
          find.descendant(of: sheet, matching: find.text('Fedha')),
          findsNothing,
        );
        expect(find.byKey(const Key('moreSheetAccount')), findsOneWidget);
      },
    );
  });
}
