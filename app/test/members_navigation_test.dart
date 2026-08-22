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
import 'package:umoja/features/members/data/member_failure.dart';
import 'package:umoja/features/members/domain/group_member.dart';
import 'package:umoja/features/members/domain/group_member_page.dart';
import 'package:umoja/features/members/presentation/widgets/member_status_badge.dart';
import 'package:umoja/features/members/providers/member_repository_provider.dart';

import 'fakes/pin_bypass_overrides.dart';
import 'fakes/fake_member_repository.dart';

MembershipContext _membership({
  List<String> roles = const ['ADMIN'],
  List<String> permissions = const [
    'group.view',
    'member.view',
    'member.create',
    'member.edit',
    'member.change_status',
    'role.view',
    'role.assign',
  ],
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
    roleCodes: roles,
    permissionCodes: permissions,
  );
}

GroupMember _member({
  String id = 'mem-1',
  String name = 'Amina Juma',
  String status = 'ACTIVE',
  List<String>? roles = const [],
}) {
  return GroupMember(
    membershipId: id,
    groupId: 'g1',
    displayName: name,
    memberNumber: 'M-001',
    status: status,
    createdAt: DateTime.utc(2026, 1, 15),
    isLoginLinked: false,
    roleCodes: roles,
  );
}

Future<void> _pumpSignedInApp(
  WidgetTester tester, {
  required MembershipContext membership,
  required FakeMemberRepository memberRepository,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...pinBypassOverrides(),
        authSessionStatusProvider.overrideWithValue(AuthSessionStatus.signedIn),
        appContextProvider.overrideWith(
          (ref) async => AppContext(
            userId: 'u1',
            profile: const AppUserProfile(id: 'u1', fullName: 'Admin Caller'),
            memberships: [membership],
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
  testWidgets(
    'tapping the Members shortcut from Home navigates to the members list',
    (tester) async {
      final fakeRepo = FakeMemberRepository()
        ..nextListResult = GroupMemberPage.empty;
      await _pumpSignedInApp(
        tester,
        membership: _membership(),
        memberRepository: fakeRepo,
      );

      await _goToMembersList(tester);

      expect(find.text('Jaza Orodha ya Wanachama'), findsOneWidget);
    },
  );

  testWidgets('members list shows populated members with a status badge', (
    tester,
  ) async {
    final fakeRepo = FakeMemberRepository()
      ..nextListResult = GroupMemberPage(
        items: [
          _member(name: 'Amina Juma'),
          _member(id: 'mem-2', name: 'Baraka Msigwa'),
        ],
        totalCount: 2,
        limit: 25,
        offset: 0,
      );
    await _pumpSignedInApp(
      tester,
      membership: _membership(),
      memberRepository: fakeRepo,
    );

    await _goToMembersList(tester);

    expect(find.text('Amina Juma'), findsOneWidget);
    expect(find.text('Baraka Msigwa'), findsOneWidget);
    // Two row status badges — not text-matched directly, since the
    // "Hai" status filter chip legitimately shows the same Kiswahili
    // word and would otherwise be an unrelated third match.
    expect(find.byType(MemberStatusBadge), findsNWidgets(2));
  });

  testWidgets('Add Member is hidden without member.create permission', (
    tester,
  ) async {
    final fakeRepo = FakeMemberRepository()
      ..nextListResult = GroupMemberPage.empty;
    await _pumpSignedInApp(
      tester,
      membership: _membership(
        roles: const ['TREASURER'],
        permissions: const ['group.view', 'member.view'],
      ),
      memberRepository: fakeRepo,
    );

    await _goToMembersList(tester);

    expect(find.text('Ongeza Mwanachama'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('tapping a member row navigates to member detail', (
    tester,
  ) async {
    final fakeRepo = FakeMemberRepository()
      ..nextListResult = GroupMemberPage(
        items: [
          _member(roles: const ['MEMBER']),
        ],
        totalCount: 1,
        limit: 25,
        offset: 0,
      )
      ..nextMemberResult = _member(roles: const ['MEMBER']);
    await _pumpSignedInApp(
      tester,
      membership: _membership(),
      memberRepository: fakeRepo,
    );

    await _goToMembersList(tester);

    await tester.tap(find.text('Amina Juma'));
    await tester.pumpAndSettle();

    expect(find.text('Akaunti ya kuingia: Haijaunganishwa'), findsOneWidget);
    expect(find.text('Sitisha'), findsOneWidget);
  });

  testWidgets(
    'member detail hides Edit and status actions without the relevant permissions',
    (tester) async {
      final fakeRepo = FakeMemberRepository()
        ..nextListResult = GroupMemberPage(
          items: [_member()],
          totalCount: 1,
          limit: 25,
          offset: 0,
        )
        ..nextMemberResult = _member();
      await _pumpSignedInApp(
        tester,
        membership: _membership(
          roles: const ['TREASURER'],
          permissions: const ['group.view', 'member.view'],
        ),
        memberRepository: fakeRepo,
      );

      await _goToMembersList(tester);
      await tester.tap(find.text('Amina Juma'));
      await tester.pumpAndSettle();

      expect(find.text('Hariri'), findsNothing);
      expect(find.text('Sitisha'), findsNothing);
    },
  );

  testWidgets(
    'LAST_ADMIN_REQUIRED shows the friendly Swahili message on a failed suspend',
    (tester) async {
      final fakeRepo = FakeMemberRepository()
        ..nextListResult = GroupMemberPage(
          items: [_member()],
          totalCount: 1,
          limit: 25,
          offset: 0,
        )
        ..nextMemberResult = _member();
      await _pumpSignedInApp(
        tester,
        membership: _membership(),
        memberRepository: fakeRepo,
      );

      await _goToMembersList(tester);
      await tester.tap(find.text('Amina Juma'));
      await tester.pumpAndSettle();

      fakeRepo.failure = const MemberFailure(
        MemberFailureType.lastAdminRequired,
        'Kikundi lazima kibaki na angalau msimamizi mmoja aliye active.',
      );

      // Triggers a confirmation bottom sheet whose own confirm button also
      // reads "Sitisha" (matching the action) — the trigger button behind
      // the modal barrier is still technically in the tree, so `.last`
      // reliably reaches the sheet's own button, the only one a user can
      // actually see/tap once the sheet is open.
      await tester.tap(find.text('Sitisha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sitisha').last);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Kikundi lazima kibaki na angalau msimamizi mmoja aliye active.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'ACTIVE/SUSPENDED/EXITED members render their Kiswahili status label, '
    'never the raw backend enum',
    (tester) async {
      final fakeRepo = FakeMemberRepository()
        ..nextListResult = GroupMemberPage(
          items: [
            _member(id: 'mem-1', name: 'Amina Juma', status: 'ACTIVE'),
            _member(id: 'mem-2', name: 'Baraka Msigwa', status: 'SUSPENDED'),
            _member(id: 'mem-3', name: 'Chiku Ally', status: 'EXITED'),
          ],
          totalCount: 3,
          limit: 25,
          offset: 0,
        );
      await _pumpSignedInApp(
        tester,
        membership: _membership(),
        memberRepository: fakeRepo,
      );

      await _goToMembersList(tester);

      // "Hai" is checked via the badge widget type, not raw text — the
      // "Hai" status filter chip legitimately shows the same word.
      expect(
        find.descendant(
          of: find.byType(MemberStatusBadge),
          matching: find.text('Hai'),
        ),
        findsOneWidget,
      );
      expect(find.text('Amesitishwa'), findsOneWidget);
      expect(find.text('Ametoka'), findsOneWidget);
      expect(find.text('ACTIVE'), findsNothing);
      expect(find.text('SUSPENDED'), findsNothing);
      expect(find.text('EXITED'), findsNothing);
    },
  );

  testWidgets('creating a member from the mobile Add action works end to end', (
    tester,
  ) async {
    final fakeRepo = FakeMemberRepository()
      ..nextListResult = GroupMemberPage.empty
      ..nextMemberResult = _member(id: 'mem-new', name: 'Fresh Member');
    await _pumpSignedInApp(
      tester,
      membership: _membership(),
      memberRepository: fakeRepo,
    );

    await _goToMembersList(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Fresh Member');
    await tester.tap(find.text('Hifadhi'));
    await tester.pumpAndSettle();

    expect(fakeRepo.createMemberCalls, hasLength(1));
    expect(fakeRepo.createMemberCalls.single.displayName, 'Fresh Member');
  });
}
