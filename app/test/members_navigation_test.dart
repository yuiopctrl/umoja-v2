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
import 'package:umoja/features/members/providers/member_repository_provider.dart';

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
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
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

void main() {
  testWidgets('tapping Members from Home navigates to the members list', (
    tester,
  ) async {
    final fakeRepo = FakeMemberRepository()
      ..nextListResult = GroupMemberPage.empty;
    await _pumpSignedInApp(
      tester,
      membership: _membership(),
      memberRepository: fakeRepo,
    );

    expect(find.text('Group: Umoja Wamama'), findsOneWidget);

    await tester.tap(find.text('Members / Wanachama'));
    await tester.pumpAndSettle();

    expect(find.text('No members yet.'), findsOneWidget);
  });

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

    await tester.tap(find.text('Members / Wanachama'));
    await tester.pumpAndSettle();

    expect(find.text('Amina Juma'), findsOneWidget);
    expect(find.text('Baraka Msigwa'), findsOneWidget);
    expect(find.text('ACTIVE'), findsNWidgets(2));
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

    await tester.tap(find.text('Members / Wanachama'));
    await tester.pumpAndSettle();

    expect(find.text('Add Member'), findsNothing);
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

    await tester.tap(find.text('Members / Wanachama'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Amina Juma'));
    await tester.pumpAndSettle();

    expect(find.text('Account access: Not linked'), findsOneWidget);
    expect(find.text('Suspend'), findsOneWidget);
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

      await tester.tap(find.text('Members / Wanachama'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amina Juma'));
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsNothing);
      expect(find.text('Suspend'), findsNothing);
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

      await tester.tap(find.text('Members / Wanachama'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amina Juma'));
      await tester.pumpAndSettle();

      fakeRepo.failure = const MemberFailure(
        MemberFailureType.lastAdminRequired,
        'Kikundi lazima kibaki na angalau msimamizi mmoja aliye active.',
      );

      await tester.tap(find.text('Suspend'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Kikundi lazima kibaki na angalau msimamizi mmoja aliye active.',
        ),
        findsOneWidget,
      );
    },
  );
}
