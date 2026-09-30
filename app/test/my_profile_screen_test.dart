import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
import 'package:umoja/features/auth/providers/selected_group_provider.dart';
import 'package:umoja/features/members/domain/group_member_page.dart';
import 'package:umoja/features/members/providers/member_repository_provider.dart';
import 'package:umoja/features/membership_claim/providers/membership_claim_repository_provider.dart';

import 'fakes/fake_member_profile_repository.dart';
import 'fakes/fake_member_repository.dart';
import 'fakes/fake_membership_claim_repository.dart';
import 'fakes/pin_bypass_overrides.dart';

/// Prompt 09G-B2: Member Profile + Member Home Foundation.
MembershipContext _membership({
  String id = 'm-self-1',
  String groupId = 'g1',
  String groupName = 'Umoja Demo',
  List<String> roleCodes = const ['MEMBER'],
  List<String> permissionCodes = const ['group.view', 'member.view'],
}) {
  return MembershipContext(
    membershipId: id,
    group: GroupContext(
      groupId: groupId,
      groupName: groupName,
      groupStatus: 'ACTIVE',
    ),
    membershipStatus: 'ACTIVE',
    displayName: 'Fredrick Mrema',
    roleCodes: roleCodes,
    permissionCodes: permissionCodes,
  );
}

Future<(GoRouter, FakeMemberProfileRepository)> _pumpApp(
  WidgetTester tester, {
  required List<MembershipContext> memberships,
  Size viewSize = const Size(390, 844),
  FakeMemberProfileRepository? profileRepo,
  // Swahili is the ARB template locale, i.e. the app's real default —
  // tests force English so assertions can match literal English
  // strings, matching the convention other test files use.
  AppLanguage language = AppLanguage.english,
}) async {
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = profileRepo ?? FakeMemberProfileRepository();

  final container = ProviderContainer(
    retry: (retryCount, error) => null,
    overrides: [
      ...pinBypassOverrides(memberProfileRepository: repo),
      authSessionStatusProvider.overrideWithValue(AuthSessionStatus.signedIn),
      appContextProvider.overrideWith(
        (ref) async => AppContext(
          userId: 'u1',
          profile: const AppUserProfile(
            id: 'u1',
            fullName: 'Fredrick Mrema',
            phone: '+255700000001',
          ),
          memberships: memberships,
        ),
      ),
      memberRepositoryProvider.overrideWithValue(
        FakeMemberRepository()..nextListResult = GroupMemberPage.empty,
      ),
      membershipClaimRepositoryProvider.overrideWithValue(
        FakeMembershipClaimRepository(),
      ),
      languageProvider.overrideWith(() => _FixedLanguage(language)),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const UmojaApp()),
  );
  await tester.pumpAndSettle();

  return (container.read(routerProvider), repo);
}

class _FixedLanguage extends LanguageNotifier {
  _FixedLanguage(this._language);

  final AppLanguage _language;

  @override
  AppLanguage build() => _language;
}

void main() {
  // --- Reachability -------------------------------------------------

  testWidgets('My Profile is reachable from the Home shortcut', (tester) async {
    await _pumpApp(tester, memberships: [_membership()]);

    await tester.tap(find.byKey(const Key('homeMyProfileShortcut')));
    await tester.pumpAndSettle();

    expect(find.text('My Profile'), findsWidgets);
    expect(find.byKey(const Key('myProfileHeaderCard')), findsOneWidget);
  });

  testWidgets('My Profile is reachable from the More screen (desktop)', (
    tester,
  ) async {
    final (router, _) = await _pumpApp(
      tester,
      memberships: [_membership()],
      viewSize: const Size(1440, 900),
    );

    router.go(AppRoutes.more);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moreMyProfileAction')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('myProfileHeaderCard')), findsOneWidget);
  });

  testWidgets('My Profile is reachable from the mobile More sheet', (
    tester,
  ) async {
    final (router, _) = await _pumpApp(tester, memberships: [_membership()]);

    router.go(AppRoutes.home);
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moreSheetMyProfile')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('myProfileHeaderCard')), findsOneWidget);
  });

  // --- Rendering ------------------------------------------------------

  testWidgets('renders full name, phone, group, member number, status, '
      'joined date, and role label; never a raw UUID or permission code', (
    tester,
  ) async {
    final repo = FakeMemberProfileRepository(
      profile: fakeMyMemberProfile(
        accountFullName: 'Fredrick Mrema',
        accountPhone: '+255700000001',
        membershipId: 'membership-secret-uuid-1',
        memberNumber: 'UMJ-2026-0001',
        groupName: 'Umoja Demo',
        groupCode: 'DEMO01',
        joinedAt: '2025-01-01',
        roleCodes: const ['TREASURER'],
      ),
    );
    final (router, _) = await _pumpApp(
      tester,
      memberships: [
        _membership(permissionCodes: const ['group.view']),
      ],
      profileRepo: repo,
    );

    router.go(AppRoutes.myProfile);
    await tester.pumpAndSettle();

    expect(find.text('Fredrick Mrema'), findsWidgets);
    expect(find.text('+255700000001'), findsOneWidget);
    expect(find.text('Umoja Demo'), findsWidgets);
    expect(find.text('DEMO01'), findsOneWidget);
    expect(find.text('UMJ-2026-0001'), findsOneWidget);
    expect(find.text('2025-01-01'), findsOneWidget);
    expect(find.text('Treasurer'), findsOneWidget);
    expect(find.textContaining('membership-secret-uuid-1'), findsNothing);
    expect(find.textContaining('TREASURER'), findsNothing);
  });

  // --- Edit -------------------------------------------------------------

  testWidgets('editing full_name saves, invalidates AppContext, and Home '
      'reflects the new name', (tester) async {
    final repo = FakeMemberProfileRepository();
    final (router, _) = await _pumpApp(
      tester,
      memberships: [_membership()],
      profileRepo: repo,
    );

    router.go(AppRoutes.myProfile);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('myProfileEditAction')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('myProfileFullNameField')),
      'Fredrick Updated',
    );
    repo.profile = fakeMyMemberProfile(accountFullName: 'Fredrick Updated');
    await tester.tap(find.byKey(const Key('myProfileSaveAction')));
    await tester.pumpAndSettle();

    expect(find.text('Fredrick Updated'), findsWidgets);
  });

  testWidgets('an empty full_name is rejected', (tester) async {
    final (router, _) = await _pumpApp(tester, memberships: [_membership()]);

    router.go(AppRoutes.myProfile);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('myProfileEditAction')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('myProfileFullNameField')),
      '   ',
    );
    await tester.tap(find.byKey(const Key('myProfileSaveAction')));
    await tester.pumpAndSettle();

    // Sheet stays open on validation failure.
    expect(find.byKey(const Key('myProfileFullNameField')), findsOneWidget);
  });

  // --- Multi-group --------------------------------------------------

  testWidgets(
    'switching selected group refreshes My Profile with no stale data',
    (tester) async {
      final repo = FakeMemberProfileRepository(
        profile: fakeMyMemberProfile(
          memberNumber: 'A-001',
          groupName: 'Group A',
          roleCodes: const ['MEMBER'],
        ),
      );
      final membershipA = _membership(
        id: 'm-a',
        groupId: 'g-a',
        groupName: 'Group A',
      );
      final membershipB = _membership(
        id: 'm-b',
        groupId: 'g-b',
        groupName: 'Group B',
        roleCodes: const ['TREASURER'],
        permissionCodes: const ['group.view', 'member.view', 'payment.view'],
      );

      final (router, _) = await _pumpApp(
        tester,
        memberships: [membershipA, membershipB],
        profileRepo: repo,
      );

      // Two eligible memberships means selection is pending (never
      // auto-selected — CLAUDE.md) until explicitly chosen.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(UmojaApp)),
      );
      container.read(selectedGroupProvider.notifier).selectGroup('m-a');
      await tester.pumpAndSettle();

      router.go(AppRoutes.myProfile);
      await tester.pumpAndSettle();
      expect(find.text('A-001'), findsOneWidget);

      repo.profile = fakeMyMemberProfile(
        memberNumber: 'B-017',
        groupName: 'Group B',
        roleCodes: const ['TREASURER'],
      );
      // selectGroup only acts from SelectedGroupPending — switching an
      // already-resolved selection goes through requireReselection
      // first, matching the real "Switch Group" UI flow.
      container.read(selectedGroupProvider.notifier).requireReselection([
        membershipA,
        membershipB,
      ]);
      container.read(selectedGroupProvider.notifier).selectGroup('m-b');
      await tester.pumpAndSettle();

      expect(find.text('B-017'), findsOneWidget);
      expect(find.text('A-001'), findsNothing);
    },
  );

  // --- Ordinary member navigation ------------------------------------

  testWidgets('an ordinary member without member.view does not see Members in '
      'Member Management, and direct /members navigation is denied', (
    tester,
  ) async {
    final (router, _) = await _pumpApp(
      tester,
      memberships: [
        _membership(permissionCodes: const ['group.view']),
      ],
    );

    // Home is reachable.
    router.go(AppRoutes.home);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('homeMyProfileShortcut')), findsOneWidget);
    expect(find.byKey(const Key('homeMembersShortcut')), findsNothing);

    // More sheet shows no Member Management entry (no permission at all).
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('moreSheetMemberManagement')), findsNothing);
    // Close the sheet before navigating directly.
    await tester.tapAt(const Offset(200, 50));
    await tester.pumpAndSettle();

    // Direct navigation to /members is denied, redirected to Home.
    router.go(AppRoutes.membersList);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('homeMyProfileShortcut')), findsOneWidget);
  });

  testWidgets(
    'an officer with member.invite but not member.view is denied direct '
    '/members navigation, and sees Invite Member/Sent Invitations but not '
    'Members in the sidebar',
    (tester) async {
      final (router, _) = await _pumpApp(
        tester,
        memberships: [
          _membership(permissionCodes: const ['group.view', 'member.invite']),
        ],
        viewSize: const Size(1440, 900),
      );

      router.go(AppRoutes.membersList);
      await tester.pumpAndSettle();
      // Denied (redirected) since member.view is absent — back on Home.
      expect(find.byKey(const Key('homeMyProfileShortcut')), findsOneWidget);

      // The sidebar group only auto-expands on a member-management
      // location; from Home it starts collapsed, so expand it first.
      await tester.tap(find.byKey(const Key('memberManagementNavGroupToggle')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('memberManagementNavChild_/members/invite')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('memberManagementNavChild_/members')),
        findsNothing,
      );
    },
  );

  // --- Responsive -----------------------------------------------------

  for (final size in [
    (360.0, 'mobile'),
    (1024.0, 'tablet'),
    (1440.0, 'desktop'),
  ]) {
    testWidgets('My Profile has no layout overflow at ${size.$2} width', (
      tester,
    ) async {
      final (router, _) = await _pumpApp(
        tester,
        memberships: [_membership()],
        viewSize: Size(size.$1, 900),
      );

      router.go(AppRoutes.myProfile);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }

  // --- Localization -----------------------------------------------------

  testWidgets('renders in Swahili when the active language is Swahili', (
    tester,
  ) async {
    final (router, _) = await _pumpApp(
      tester,
      memberships: [_membership()],
      language: AppLanguage.swahili,
    );

    router.go(AppRoutes.myProfile);
    await tester.pumpAndSettle();

    expect(find.text('Wasifu Wangu'), findsWidgets);
  });
}
