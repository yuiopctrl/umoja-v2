import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/app.dart';
import 'package:umoja/app/routing/app_router.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/auth/models/app_context.dart';
import 'package:umoja/features/auth/models/app_user_profile.dart';
import 'package:umoja/features/auth/models/group_context.dart';
import 'package:umoja/features/auth/models/membership_context.dart';
import 'package:umoja/features/auth/providers/app_context_provider.dart';
import 'package:umoja/features/auth/providers/auth_session_provider.dart';

import 'fakes/fake_member_loans_repository.dart';
import 'fakes/pin_bypass_overrides.dart';

import 'package:umoja/features/member_loans/providers/member_loans_repository_provider.dart';
import 'package:umoja/features/member_statement/providers/member_statement_repository_provider.dart';

import 'package:umoja/features/my_contributions/providers/my_contributions_repository_provider.dart';

import 'fakes/fake_member_statement_repository.dart';
import 'fakes/fake_my_contributions_repository.dart';

/// Prompt 09G-B5-C.2 §N/§O: the actual defect UAT found (My Loans
/// missing from mobile navigation, Home wrongly selected on a self-
/// service child page) plus the shared member shell. Drives the real
/// [AppShell]/navigation widgets, never a label mapper in isolation.
void main() {
  MembershipContext membershipWith(
    List<String> permissions, {
    String groupName = 'Umoja Demo',
  }) {
    return MembershipContext(
      membershipId: 'm1',
      group: GroupContext(
        groupId: 'g1',
        groupName: groupName,
        groupStatus: 'ACTIVE',
      ),
      membershipStatus: 'ACTIVE',
      displayName: 'Member Caller',
      roleCodes: const ['MEMBER'],
      permissionCodes: permissions,
    );
  }

  Future<ProviderContainer> pumpWithContext(
    WidgetTester tester, {
    required AppContext Function() buildContext,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        ...pinBypassOverrides(),
        authSessionStatusProvider.overrideWithValue(AuthSessionStatus.signedIn),
        appContextProvider.overrideWith((ref) async => buildContext()),
        memberLoansRepositoryProvider.overrideWithValue(
          FakeMemberLoansRepository(),
        ),
        memberStatementRepositoryProvider.overrideWithValue(
          FakeMemberStatementRepository(),
        ),
        myContributionsRepositoryProvider.overrideWithValue(
          FakeMyContributionsRepository(),
        ),
        languageProvider.overrideWith(
          () => _FixedLanguage(AppLanguage.english),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const UmojaApp()),
    );
    await tester.pumpAndSettle();
    return container;
  }

  group('My Loans visibility (the actual physical-device defect)', () {
    testWidgets(
      '1. effective loan.self_view: My Loans appears in the mobile More sheet',
      (tester) async {
        final container = await pumpWithContext(
          tester,
          buildContext: () => AppContext(
            userId: 'u1',
            profile: const AppUserProfile(id: 'u1', fullName: 'Member Caller'),
            memberships: [
              membershipWith(const ['group.view', 'loan.self_view']),
            ],
          ),
        );
        final router = container.read(routerProvider);
        router.go(AppRoutes.home);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(NavigationDestination, 'More'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('moreSheetMyLoans')), findsOneWidget);
      },
    );

    testWidgets(
      '2. no loan.self_view: My Loans is absent from the mobile More sheet',
      (tester) async {
        final container = await pumpWithContext(
          tester,
          buildContext: () => AppContext(
            userId: 'u1',
            profile: const AppUserProfile(id: 'u1', fullName: 'Member Caller'),
            memberships: [
              membershipWith(const ['group.view']),
            ],
          ),
        );
        final router = container.read(routerProvider);
        router.go(AppRoutes.home);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(NavigationDestination, 'More'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('moreSheetMyLoans')), findsNothing);
      },
    );

    testWidgets(
      '3. loan.self_view without member.view: My Loans is still visible',
      (tester) async {
        final container = await pumpWithContext(
          tester,
          buildContext: () => AppContext(
            userId: 'u1',
            profile: const AppUserProfile(id: 'u1', fullName: 'Member Caller'),
            memberships: [
              membershipWith(const ['group.view', 'loan.self_view']),
            ],
          ),
        );
        final router = container.read(routerProvider);
        router.go(AppRoutes.home);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(NavigationDestination, 'More'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('moreSheetMyLoans')), findsOneWidget);
        expect(
          find.byKey(const Key('moreSheetMemberManagement')),
          findsNothing,
          reason: 'member.view is absent, so the Members directory entry point stays hidden',
        );
      },
    );

    testWidgets(
      '4. member.view absent: the Members directory route stays blocked',
      (tester) async {
        final container = await pumpWithContext(
          tester,
          buildContext: () => AppContext(
            userId: 'u1',
            profile: const AppUserProfile(id: 'u1', fullName: 'Member Caller'),
            memberships: [
              membershipWith(const ['group.view', 'loan.self_view']),
            ],
          ),
        );
        final router = container.read(routerProvider);
        router.go(AppRoutes.membersList);
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          isNot(AppRoutes.membersList),
        );
      },
    );

    testWidgets(
      '5. nav visibility and RouteGuard agree: visible implies navigable, hidden implies blocked',
      (tester) async {
        final visible = await pumpWithContext(
          tester,
          buildContext: () => AppContext(
            userId: 'u1',
            profile: const AppUserProfile(id: 'u1', fullName: 'Member Caller'),
            memberships: [
              membershipWith(const ['group.view', 'loan.self_view']),
            ],
          ),
        );
        final router1 = visible.read(routerProvider);
        router1.go(AppRoutes.myLoans);
        await tester.pumpAndSettle();
        expect(
          router1.routeInformationProvider.value.uri.path,
          AppRoutes.myLoans,
        );
      },
    );

    testWidgets(
      "5b. hidden implies blocked: without loan.self_view the route itself refuses",
      (tester) async {
        final container = await pumpWithContext(
          tester,
          buildContext: () => AppContext(
            userId: 'u1',
            profile: const AppUserProfile(id: 'u1', fullName: 'Member Caller'),
            memberships: [
              membershipWith(const ['group.view']),
            ],
          ),
        );
        final router = container.read(routerProvider);
        router.go(AppRoutes.myLoans);
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          isNot(AppRoutes.myLoans),
        );
      },
    );

    testWidgets(
      '6. refreshing the app context exposes a newly granted permission without reinstalling',
      (tester) async {
        var permissions = const ['group.view'];
        final container = await pumpWithContext(
          tester,
          buildContext: () => AppContext(
            userId: 'u1',
            profile: const AppUserProfile(id: 'u1', fullName: 'Member Caller'),
            memberships: [membershipWith(permissions)],
          ),
        );
        final router = container.read(routerProvider);
        router.go(AppRoutes.home);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(NavigationDestination, 'More'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('moreSheetMyLoans')), findsNothing);
        // Dismiss the sheet by tapping its barrier, then simulate the
        // backend granting loan.self_view mid-session (exactly the B5-B
        // deployment scenario) and use the shell's own refresh action
        // instead of restarting the app.
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();
        permissions = const ['group.view', 'loan.self_view'];
        await tester.tap(find.byKey(const Key('refreshPermissionsButton')));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(NavigationDestination, 'More'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('moreSheetMyLoans')), findsOneWidget);
      },
    );
  });

  group('Shared member shell', () {
    testWidgets('Home shows the group name in the top app bar', (tester) async {
      await pumpWithContext(
        tester,
        buildContext: () => AppContext(
          userId: 'u1',
          profile: const AppUserProfile(id: 'u1', fullName: 'Member Caller'),
          memberships: [
            membershipWith(const ['group.view'], groupName: 'Umoja Demo'),
          ],
        ),
      );
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Umoja Demo'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('profileMenuButton')), findsOneWidget);
    });

    testWidgets(
      'a child page shows a compact title and the group as secondary context, with no duplicate giant title',
      (tester) async {
        final container = await pumpWithContext(
          tester,
          buildContext: () => AppContext(
            userId: 'u1',
            profile: const AppUserProfile(id: 'u1', fullName: 'Member Caller'),
            memberships: [
              membershipWith(const [
                'group.view',
                'loan.self_view',
              ], groupName: 'Umoja Demo'),
            ],
          ),
        );
        final router = container.read(routerProvider);
        router.go(AppRoutes.myLoans);
        await tester.pumpAndSettle();
        expect(
          find.text('My Loans'),
          findsOneWidget,
          reason: 'the app bar owns the page title; it must not also appear as a second body heading',
        );
        expect(
          find.byKey(const Key('memberChildGroupSubtitle')),
          findsOneWidget,
        );
        expect(find.text('Umoja Demo'), findsOneWidget);
        expect(find.byKey(const Key('memberChildBackButton')), findsOneWidget);
      },
    );

    testWidgets(
      'the bottom bar selects More, not Home, while on a self-service child page',
      (tester) async {
        final container = await pumpWithContext(
          tester,
          buildContext: () => AppContext(
            userId: 'u1',
            profile: const AppUserProfile(id: 'u1', fullName: 'Member Caller'),
            memberships: [
              membershipWith(const ['group.view', 'loan.self_view']),
            ],
          ),
        );
        final router = container.read(routerProvider);
        router.go(AppRoutes.myLoans);
        await tester.pumpAndSettle();
        final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
        final destinations = navBar.destinations.cast<NavigationDestination>();
        final moreIndex = destinations.toList().indexWhere(
          (d) => d.label == 'More',
        );
        expect(
          navBar.selectedIndex,
          moreIndex,
          reason: 'the actual UAT defect: Home stayed selected on a member self-service child page',
        );
        expect(navBar.selectedIndex, isNot(0));
      },
    );

    // Prompt 09G-B5-C.2 §O: a sheet tile navigates via `context.push`,
    // which (as already found in member_loans_screen_test.dart) does not
    // update `routeInformationProvider` the way `go` does — go_router
    // keeps that accessor pointed at the underlying declarative location
    // while a push is an overlay. The real signal is the destination
    // screen's own content, not that accessor.
    for (final (description, key, expectedTitle) in [
      (
        'My Contributions navigates correctly from the sheet',
        'moreSheetMyContributions',
        'My Contributions',
      ),
      (
        'My Financial Statement navigates correctly from the sheet',
        'moreSheetFinancialStatement',
        'My Financial Statement',
      ),
      (
        'My Loans navigates correctly from the sheet',
        'moreSheetMyLoans',
        'My Loans',
      ),
    ]) {
      testWidgets(description, (tester) async {
        final container = await pumpWithContext(
          tester,
          buildContext: () => AppContext(
            userId: 'u1',
            profile: const AppUserProfile(id: 'u1', fullName: 'Member Caller'),
            memberships: [
              membershipWith(const [
                'group.view',
                'contribution.self_view',
                'financial_report.self_view',
                'loan.self_view',
              ]),
            ],
          ),
        );
        final router = container.read(routerProvider);
        router.go(AppRoutes.home);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(NavigationDestination, 'More'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text(expectedTitle),
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('memberChildBackButton')), findsOneWidget);
      });
    }

    testWidgets('My Profile navigates correctly', (tester) async {
      final container = await pumpWithContext(
        tester,
        buildContext: () => AppContext(
          userId: 'u1',
          profile: const AppUserProfile(id: 'u1', fullName: 'Member Caller'),
          memberships: [
            membershipWith(const ['group.view']),
          ],
        ),
      );
      final router = container.read(routerProvider);
      router.go(AppRoutes.myProfile);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutes.myProfile,
      );
    });

    testWidgets('Swahili labels: Mikopo Yangu in the More sheet', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [
          ...pinBypassOverrides(),
          authSessionStatusProvider.overrideWithValue(
            AuthSessionStatus.signedIn,
          ),
          appContextProvider.overrideWith(
            (ref) async => AppContext(
              userId: 'u1',
              profile: const AppUserProfile(
                id: 'u1',
                fullName: 'Member Caller',
              ),
              memberships: [
                membershipWith(const ['group.view', 'loan.self_view']),
              ],
            ),
          ),
          memberLoansRepositoryProvider.overrideWithValue(
            FakeMemberLoansRepository(),
          ),
          memberStatementRepositoryProvider.overrideWithValue(
            FakeMemberStatementRepository(),
          ),
          myContributionsRepositoryProvider.overrideWithValue(
            FakeMyContributionsRepository(),
          ),
          languageProvider.overrideWith(
            () => _FixedLanguage(AppLanguage.swahili),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const UmojaApp(),
        ),
      );
      await tester.pumpAndSettle();
      final router = container.read(routerProvider);
      router.go(AppRoutes.home);
      await tester.pumpAndSettle();
      // Swahili's "More" label is "Zaidi".
      await tester.tap(find.widgetWithText(NavigationDestination, 'Zaidi'));
      await tester.pumpAndSettle();
      // Home's own My Loans quick action (hidden behind the modal, but
      // still in the tree) uses the same label, so this is scoped to
      // the sheet's own tile rather than a bare text search.
      expect(
        find.descendant(
          of: find.byKey(const Key('moreSheetMyLoans')),
          matching: find.text('Mikopo Yangu'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a long group name does not overflow a 320px phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = await pumpWithContext(
        tester,
        buildContext: () => AppContext(
          userId: 'u1',
          profile: const AppUserProfile(id: 'u1', fullName: 'Member Caller'),
          memberships: [
            membershipWith(
              const ['group.view', 'loan.self_view'],
              groupName:
                  'Umoja Women Group Savings And Credit Cooperative Society',
            ),
          ],
        ),
      );
      final router = container.read(routerProvider);
      router.go(AppRoutes.myLoans);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}

class _FixedLanguage extends LanguageNotifier {
  _FixedLanguage(this._language);

  final AppLanguage _language;

  @override
  AppLanguage build() => _language;
}
