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

const _fullPermissions = [
  'member.view',
  'contribution.view',
  'payment.view',
  'loan.view',
  'financial_account.view',
];

MembershipContext _membership(List<String> permissions) {
  return MembershipContext(
    membershipId: 'm-admin',
    group: const GroupContext(
      groupId: 'g1',
      groupName: 'Umoja Demo',
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
  List<String> permissions = _fullPermissions,
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
            memberships: [_membership(permissions)],
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
    'tapping More on mobile opens a modal listing the demoted modules '
    'and an Account entry, without navigating away or moving the '
    'bottom bar selection',
    (tester) async {
      _setViewport(tester, const Size(390, 844));
      await _pumpSignedInApp(tester);

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
      expect(find.byKey(const Key('moreSheetAccount')), findsOneWidget);

      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 0); // still on Home underneath.
    },
  );

  testWidgets('a member.view-only user sees no module links in the More sheet, '
      'only Account', (tester) async {
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
  });

  testWidgets(
    'tapping a module in the More sheet closes it and navigates there',
    (tester) async {
      _setViewport(tester, const Size(390, 844));
      await _pumpSignedInApp(tester);

      await tester.tap(find.text('Zaidi'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Mikopo'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Mikopo')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'tapping Account in the More sheet closes it and opens the profile '
    'sheet instead',
    (tester) async {
      _setViewport(tester, const Size(390, 844));
      await _pumpSignedInApp(tester);

      await tester.tap(find.text('Zaidi'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('moreSheetAccount')));
      await tester.pumpAndSettle();

      expect(find.text('Admin Caller'), findsOneWidget);
      expect(find.text('Toka'), findsOneWidget);
    },
  );
}
