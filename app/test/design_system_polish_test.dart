import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/app.dart';
import 'package:umoja/core/branding/umoja_brand_mark.dart';
import 'package:umoja/core/theme/umoja_theme.dart';
import 'package:umoja/features/auth/models/app_context.dart';
import 'package:umoja/features/auth/models/app_user_profile.dart';
import 'package:umoja/features/auth/models/group_context.dart';
import 'package:umoja/features/auth/models/membership_context.dart';
import 'package:umoja/features/auth/providers/app_context_provider.dart';
import 'package:umoja/features/auth/providers/auth_session_provider.dart';
import 'package:umoja/features/members/domain/group_member.dart';
import 'package:umoja/features/members/domain/group_member_page.dart';
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
    permissionCodes: [
      'member.view',
      'member.create',
      'member.edit',
      'member.change_status',
      'role.view',
      'role.assign',
    ],
  );
}

GroupMember _member({String id = 'mem-1', String name = 'Amina Juma'}) {
  return GroupMember(
    membershipId: id,
    groupId: 'g1',
    displayName: name,
    status: 'ACTIVE',
    createdAt: DateTime.utc(2026, 1, 15),
    joinedAt: DateTime.utc(2026, 1, 15),
    isLoginLinked: false,
    roleCodes: const ['ADMIN'],
  );
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _pumpSignedInApp(
  WidgetTester tester, {
  required FakeMemberRepository memberRepository,
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
            memberships: [_membership()],
          ),
        ),
        memberRepositoryProvider.overrideWithValue(memberRepository),
      ],
      child: const UmojaApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _goToMembersList(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('homeMembersShortcut')));
  await tester.pumpAndSettle();
}

void main() {
  test('Ubuntu is applied as the application UI font', () {
    // ThemeData(fontFamily: 'Ubuntu') fills in every TextStyle in
    // textTheme that doesn't set its own fontFamily (see
    // ThemeData._().textTheme = defaultTextTheme.merge(textTheme) in
    // the Flutter SDK) — this is true for every style UmojaTypography
    // defines, so this single check covers the whole hierarchy.
    for (final style in [
      UmojaTheme.light.textTheme.titleLarge,
      UmojaTheme.light.textTheme.bodyLarge,
      UmojaTheme.light.textTheme.bodyMedium,
      UmojaTheme.light.textTheme.labelLarge,
    ]) {
      expect(style?.fontFamily, 'Ubuntu');
    }
  });

  testWidgets(
    'login shows the Umoja brand artwork, not the "Umoja v2" project label',
    (tester) async {
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

      expect(
        find.byType(UmojaBrandMark),
        findsOneWidget,
      ); // the unified symbol+wordmark lockup (prompt 05E)
      expect(find.text('Umoja v2'), findsNothing);
      expect(find.text('Karibu Umoja'), findsOneWidget);
    },
  );

  testWidgets('mobile member detail has an explicit back control', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    final fakeRepo = FakeMemberRepository()
      ..nextListResult = GroupMemberPage(
        items: [_member()],
        totalCount: 1,
        limit: 25,
        offset: 0,
      )
      ..nextMemberResult = _member();
    await _pumpSignedInApp(tester, memberRepository: fakeRepo);

    await _goToMembersList(tester);
    await tester.tap(find.text('Amina Juma'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('umojaPageBackButton')), findsOneWidget);
  });

  testWidgets(
    'desktop member detail shows a "← Wanachama" breadcrumb back link',
    (tester) async {
      _setViewport(tester, const Size(1400, 900));
      final fakeRepo = FakeMemberRepository()
        ..nextListResult = GroupMemberPage(
          items: [_member()],
          totalCount: 1,
          limit: 25,
          offset: 0,
        )
        ..nextMemberResult = _member();
      await _pumpSignedInApp(tester, memberRepository: fakeRepo);

      await _goToMembersList(tester);
      await tester.tap(find.text('Amina Juma'));
      await tester.pumpAndSettle();

      final backLink = find.byKey(const Key('umojaPageDesktopBackLink'));
      expect(backLink, findsOneWidget);
      expect(
        find.descendant(of: backLink, matching: find.text('Wanachama')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'the mobile Add Member FAB never permanently hides the last member row',
    (tester) async {
      _setViewport(tester, const Size(390, 844));
      final fakeRepo = FakeMemberRepository()
        ..nextListResult = GroupMemberPage(
          items: [
            for (var i = 0; i < 15; i++) _member(id: 'm$i', name: 'Member $i'),
          ],
          totalCount: 15,
          limit: 25,
          offset: 0,
        );
      await _pumpSignedInApp(tester, memberRepository: fakeRepo);

      await _goToMembersList(tester);
      expect(find.byType(FloatingActionButton), findsOneWidget);

      // Scroll the list fully to the bottom, then confirm the last row
      // is still tappable (not permanently obscured behind the FAB).
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      final lastRow = find.text('Member 14');
      expect(lastRow, findsOneWidget);
      await tester.tap(lastRow, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Landed on that member's detail screen (proves the tap actually
      // reached the row, not the FAB sitting on top of it — a tap
      // swallowed by the FAB instead would have opened the "Ongeza
      // Mwanachama" create form).
      expect(tester.takeException(), isNull);
      expect(find.text('Ongeza Mwanachama'), findsNothing);
      expect(find.text('Simamia Majukumu'), findsOneWidget);
    },
  );

  testWidgets('Zaidi (More) uses Kiswahili section titles', (tester) async {
    _setViewport(tester, const Size(390, 844));
    await _pumpSignedInApp(
      tester,
      memberRepository: FakeMemberRepository()
        ..nextListResult = GroupMemberPage.empty,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Zaidi'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Akaunti'), findsOneWidget);
    expect(find.text('Kikundi cha Sasa'), findsOneWidget);
    expect(find.text('Usalama'), findsOneWidget);
  });
}
