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

/// Prompt 09G-B1-F-UAT-FIX-03: desktop/tablet no longer uses a stock
/// [NavigationRail] — the "Member Management" group needs an
/// expandable/collapsible entry interleaved with the flat
/// destinations, which [NavigationRail] cannot represent, so
/// `app_shell.dart` builds its own sidebar instead (keyed
/// `desktopSidebar`). Members is also no longer a mobile bottom-bar
/// destination — it moved under More → Member Management — so mobile
/// selection tests below use Payments instead.
MembershipContext _membership({
  List<String> permissionCodes = const ['member.view', 'payment.view'],
}) {
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
    permissionCodes: permissionCodes,
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
    'a mobile-width viewport shows the bottom navigation bar, not the '
    'desktop sidebar',
    (tester) async {
      _setViewport(tester, const Size(390, 844));
      await _pumpSignedInApp(tester);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byKey(const Key('desktopSidebar')), findsNothing);
    },
  );

  testWidgets(
    'a wide viewport shows the extended desktop sidebar (labels visible), '
    'not the bottom bar',
    (tester) async {
      _setViewport(tester, const Size(1400, 900));
      await _pumpSignedInApp(tester);

      expect(find.byKey(const Key('desktopSidebar')), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      // Extended: the flat Home destination shows its text label
      // alongside the icon.
      expect(
        find.descendant(
          of: find.byKey(const Key('desktopSidebar')),
          matching: find.text('Nyumbani'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a tablet-width viewport shows a compact desktop sidebar (narrower, '
    'label stacked below the icon — matching the stock NavigationRail '
    'labelType.all convention this replaced, never icon-only)',
    (tester) async {
      _setViewport(tester, const Size(900, 800));
      await _pumpSignedInApp(tester);

      expect(find.byKey(const Key('desktopSidebar')), findsOneWidget);
      expect(tester.getSize(find.byKey(const Key('desktopSidebar'))).width, 80);
      // Compact: the label is still rendered (stacked below the icon),
      // never icon-only.
      expect(
        find.descendant(
          of: find.byKey(const Key('desktopSidebar')),
          matching: find.text('Nyumbani'),
        ),
        findsOneWidget,
      );
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
    expect(find.byKey(const Key('desktopSidebar')), findsNothing);
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
          matching: find.text('Malipo'),
        ),
      );
      await tester.pumpAndSettle();

      navBar = tester.widget(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 1);

      // "Zaidi" (More) opens a modal instead of navigating — the bar's
      // own selection never moves off whatever screen was already
      // showing underneath (see more_sheet.dart).
      await tester.tap(find.text('Zaidi'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      navBar = tester.widget(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 1);
    },
  );
}
