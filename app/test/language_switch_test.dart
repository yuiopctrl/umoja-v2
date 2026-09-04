import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:umoja/app/app.dart';
import 'package:umoja/features/auth/models/app_context.dart';
import 'package:umoja/features/auth/models/app_user_profile.dart';
import 'package:umoja/features/auth/models/group_context.dart';
import 'package:umoja/features/auth/models/membership_context.dart';
import 'package:umoja/features/auth/providers/app_context_provider.dart';
import 'package:umoja/features/auth/providers/auth_session_provider.dart';
import 'package:umoja/features/members/domain/group_member.dart';
import 'package:umoja/features/members/domain/group_member_page.dart';
import 'package:umoja/features/members/providers/member_repository_provider.dart';
import 'package:umoja/core/widgets/umoja_language_selector.dart';

import 'fakes/fake_member_repository.dart';
import 'fakes/pin_bypass_overrides.dart';

/// Prompt 05C §10: switching the language must update every part of
/// the already-visible UI live — sidebar/bottom nav, roles, statuses,
/// current page — with no logout/restart. Everything below pumps the
/// full app once, switches language mid-session, and re-checks the
/// same widgets rather than re-pumping.
Future<void> _pumpSignedInApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final fakeRepo = FakeMemberRepository()
    ..nextListResult = GroupMemberPage(
      items: [
        GroupMember(
          membershipId: 'm1',
          groupId: 'g1',
          displayName: 'Amina Juma',
          status: 'SUSPENDED',
          createdAt: DateTime.utc(2026, 1, 15),
          isLoginLinked: false,
          roleCodes: const ['TREASURER'],
        ),
      ],
      totalCount: 1,
      limit: 10,
      offset: 0,
    );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...pinBypassOverrides(),
        authSessionStatusProvider.overrideWithValue(AuthSessionStatus.signedIn),
        appContextProvider.overrideWith(
          (ref) async => AppContext(
            userId: 'u1',
            profile: const AppUserProfile(id: 'u1', fullName: 'Admin Caller'),
            memberships: [
              const MembershipContext(
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
              ),
            ],
          ),
        ),
        memberRepositoryProvider.overrideWithValue(fakeRepo),
      ],
      child: const UmojaApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapNavDestination(WidgetTester tester, String label) async {
  await tester.tap(
    find
        .descendant(of: find.byType(NavigationBar), matching: find.text(label))
        .first,
  );
  await tester.pumpAndSettle();
}

Future<void> _switchLanguage(WidgetTester tester, String segmentLabel) async {
  await tester.tap(find.text(segmentLabel).first);
  await tester.pumpAndSettle();
}

/// Opens the More sheet's "Akaunti" entry — where the account/current
/// group details and the language selector now live (see
/// `app_top_bar.dart`'s `_ProfileSheet`), grouped off the More sheet's
/// own top-level module list.
Future<void> _openAccountSheet(WidgetTester tester) async {
  await _tapNavDestination(tester, 'Zaidi');
  await tester.tap(find.byKey(const Key('moreSheetAccount')));
  await tester.pumpAndSettle();
}

/// Dismisses an open modal sheet by tapping its barrier, so a test can
/// go on to interact with the navigation underneath it.
Future<void> _closeModal(WidgetTester tester) async {
  await tester.tapAt(const Offset(200, 40));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('switching to English updates the bottom navigation labels live, '
      'with no logout/restart', (tester) async {
    await _pumpSignedInApp(tester);

    expect(find.text('Wanachama'), findsWidgets);
    expect(find.text('Zaidi'), findsWidgets);

    // The full-text Kiswahili|English selector lives in the More
    // sheet's Akaunti entry — prompt 05E-C §7/§8: the exact same
    // UmojaLanguageSelector widget as the login screen, never a
    // second, separately-styled implementation.
    await _openAccountSheet(tester);
    expect(find.byType(UmojaLanguageSelector), findsOneWidget);
    await _switchLanguage(tester, 'English');

    expect(find.text('Members'), findsWidgets);
    expect(find.text('More'), findsWidgets);
    expect(find.text('Wanachama'), findsNothing);
    expect(find.text('Zaidi'), findsNothing);
  });

  testWidgets(
    'switching to English updates role and status labels live — never '
    'the raw ADMIN/TREASURER/ACTIVE/SUSPENDED backend codes',
    (tester) async {
      await _pumpSignedInApp(tester);

      await _openAccountSheet(tester);

      // The modal sheet's entrance transition can briefly mount its
      // content twice in the same frame — findsWidgets (>=1) rather
      // than an exact count, matching the same artifact seen with the
      // profile/More sheets elsewhere.
      expect(find.textContaining('Msimamizi'), findsWidgets);
      expect(find.text('Hai'), findsWidgets);

      await _switchLanguage(tester, 'English');

      expect(find.textContaining('Administrator'), findsWidgets);
      expect(find.text('Active'), findsWidgets);
      // Never the raw backend codes/enum, in either language.
      expect(find.text('ADMIN'), findsNothing);
      expect(find.text('ACTIVE'), findsNothing);

      // Members list: a SUSPENDED Treasurer.
      await _closeModal(tester);
      await _tapNavDestination(tester, 'Members');

      expect(find.textContaining('Treasurer'), findsOneWidget);
      // Both the row's status badge and the "Suspended" filter chip
      // legitimately show this word at once.
      expect(find.text('Suspended'), findsWidgets);
      expect(find.text('TREASURER'), findsNothing);
      expect(find.text('SUSPENDED'), findsNothing);
    },
  );

  testWidgets('switching back to Swahili restores the Kiswahili labels, still '
      'without logout/restart', (tester) async {
    await _pumpSignedInApp(tester);

    await _openAccountSheet(tester);
    await _switchLanguage(tester, 'English');
    expect(find.text('More'), findsWidgets);

    await _switchLanguage(tester, 'Kiswahili');

    expect(find.text('More'), findsNothing);
    expect(find.textContaining('Msimamizi'), findsWidgets);
  });

  testWidgets('the compact SW|EN switcher is present and functional on the '
      'signed-out phone-entry (login) screen — by design it is not shown '
      'on OTP/PIN screens, where the language is already chosen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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

    // Swahili is the default (prompt 05E-B §19) — every returning-login
    // string is present and in Swahili before any language change.
    expect(find.text('Karibu Umoja'), findsOneWidget);
    expect(find.text('Namba ya simu'), findsOneWidget);
    expect(find.text('PIN'), findsOneWidget);
    expect(find.text('Ingia'), findsOneWidget);
    expect(find.text('Umesahau PIN?'), findsOneWidget);
    expect(
      find.text('Mara ya kwanza? Thibitisha namba kwa OTP'),
      findsOneWidget,
    );
    expect(find.byType(UmojaLanguageSelector), findsOneWidget);
    expect(find.text('SW'), findsOneWidget);
    expect(find.text('EN'), findsOneWidget);

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();

    expect(find.text('Karibu Umoja'), findsNothing);
    expect(find.text('Welcome to Umoja'), findsOneWidget);
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Forgot PIN?'), findsOneWidget);
    expect(find.text('First time? Verify by OTP'), findsOneWidget);
  });
}
