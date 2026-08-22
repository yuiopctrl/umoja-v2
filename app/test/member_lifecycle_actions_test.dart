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
import 'package:umoja/features/members/domain/group_member.dart';
import 'package:umoja/features/members/domain/group_member_page.dart';
import 'package:umoja/features/members/providers/member_repository_provider.dart';

import 'fakes/fake_member_repository.dart';
import 'fakes/pin_bypass_overrides.dart';

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
      'group.view',
      'member.view',
      'member.create',
      'member.edit',
      'member.change_status',
      'role.view',
      'role.assign',
    ],
  );
}

GroupMember _member({
  String id = 'mem-1',
  String name = 'amina juma',
  String status = 'ACTIVE',
}) {
  return GroupMember(
    membershipId: id,
    groupId: 'g1',
    displayName: name,
    status: status,
    createdAt: DateTime.utc(2026, 1, 15),
    joinedAt: DateTime.utc(2026, 1, 15),
    isLoginLinked: false,
    roleCodes: const [],
  );
}

Future<void> _pumpSignedInApp(
  WidgetTester tester, {
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
  testWidgets(
    'a lower-case stored display name renders in Title Case in the members list',
    (tester) async {
      final fakeRepo = FakeMemberRepository()
        ..nextListResult = GroupMemberPage(
          items: [_member(name: 'enock godfrey mrema')],
          totalCount: 1,
          limit: 10,
          offset: 0,
        );
      await _pumpSignedInApp(tester, memberRepository: fakeRepo);

      await _goToMembersList(tester);

      expect(find.text('Enock Godfrey Mrema'), findsOneWidget);
      expect(find.text('enock godfrey mrema'), findsNothing);
    },
  );

  testWidgets(
    'a lower-case stored display name renders in Title Case in member detail',
    (tester) async {
      final fakeRepo = FakeMemberRepository()
        ..nextListResult = GroupMemberPage(
          items: [_member(name: 'fredrick mrema')],
          totalCount: 1,
          limit: 10,
          offset: 0,
        )
        ..nextMemberResult = _member(name: 'fredrick mrema');
      await _pumpSignedInApp(tester, memberRepository: fakeRepo);

      await _goToMembersList(tester);
      await tester.tap(find.text('Fredrick Mrema'));
      await tester.pumpAndSettle();

      expect(find.text('Fredrick Mrema'), findsWidgets);
    },
  );

  testWidgets(
    'a SUSPENDED member can be reactivated via the existing Rudisha action',
    (tester) async {
      final fakeRepo = FakeMemberRepository()
        ..nextListResult = GroupMemberPage(
          items: [_member(status: 'SUSPENDED')],
          totalCount: 1,
          limit: 10,
          offset: 0,
        )
        ..nextMemberResult = _member(status: 'SUSPENDED');
      await _pumpSignedInApp(tester, memberRepository: fakeRepo);

      await _goToMembersList(tester);
      await tester.tap(find.text('Amina Juma'));
      await tester.pumpAndSettle();

      expect(find.text('Rudisha'), findsOneWidget);
      await tester.tap(find.text('Rudisha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rudisha').last);
      await tester.pumpAndSettle();

      expect(fakeRepo.changeStatusCalls, hasLength(1));
      expect(fakeRepo.changeStatusCalls.single.status, 'ACTIVE');
      expect(find.text('Mwanachama amerudishwa.'), findsOneWidget);
    },
  );

  testWidgets(
    'an EXITED member shows the explicit Rudisha kwenye Kikundi rejoin '
    'action instead of the generic Rudisha reactivate action',
    (tester) async {
      final fakeRepo = FakeMemberRepository()
        ..nextListResult = GroupMemberPage(
          items: [_member(status: 'EXITED')],
          totalCount: 1,
          limit: 10,
          offset: 0,
        )
        ..nextMemberResult = _member(status: 'EXITED');
      await _pumpSignedInApp(tester, memberRepository: fakeRepo);

      await _goToMembersList(tester);
      await tester.tap(find.text('Amina Juma'));
      await tester.pumpAndSettle();

      expect(find.text('Rudisha kwenye Kikundi'), findsOneWidget);
      // The generic single-word "Rudisha" reactivate action must not
      // appear for an EXITED member — only the explicit rejoin action.
      expect(find.text('Rudisha'), findsNothing);
    },
  );

  testWidgets(
    'confirming the explicit rejoin action calls rejoinMember, never changeStatus',
    (tester) async {
      final fakeRepo = FakeMemberRepository()
        ..nextListResult = GroupMemberPage(
          items: [_member(status: 'EXITED')],
          totalCount: 1,
          limit: 10,
          offset: 0,
        )
        ..nextMemberResult = _member(status: 'EXITED');
      await _pumpSignedInApp(tester, memberRepository: fakeRepo);

      await _goToMembersList(tester);
      await tester.tap(find.text('Amina Juma'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rudisha kwenye Kikundi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rudisha kwenye Kikundi').last);
      await tester.pumpAndSettle();

      expect(fakeRepo.rejoinMemberCalls, hasLength(1));
      expect(fakeRepo.changeStatusCalls, isEmpty);
      expect(
        find.text('Mwanachama amerudishwa kwenye kikundi.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Onyesha Zaidi (load more) requests the next page beyond the first 10',
    (tester) async {
      final firstPage = [
        for (var i = 0; i < 10; i++) _member(id: 'm$i', name: 'member $i'),
      ];
      final fakeRepo = FakeMemberRepository()
        ..nextListResult = GroupMemberPage(
          items: firstPage,
          totalCount: 15,
          limit: 10,
          offset: 0,
        );
      await _pumpSignedInApp(tester, memberRepository: fakeRepo);

      await _goToMembersList(tester);

      expect(find.text('Member 0'), findsOneWidget);
      expect(fakeRepo.listMembersCalls.last.limit, 10);

      final secondPage = [
        for (var i = 0; i < 15; i++) _member(id: 'm$i', name: 'member $i'),
      ];
      fakeRepo.nextListResult = GroupMemberPage(
        items: secondPage,
        totalCount: 15,
        limit: 20,
        offset: 0,
      );

      await tester.dragUntilVisible(
        find.text('Onyesha Zaidi'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.tap(find.text('Onyesha Zaidi'));
      await tester.pumpAndSettle();

      // Requested the next page beyond the first 10 (proves load-more
      // actually grows the request, not just re-fetching the same page).
      expect(fakeRepo.listMembersCalls.last.limit, 20);

      // The newly-loaded 15th member is reachable by scrolling further
      // (not silently stopped after 10 — prompt 05B §19).
      await tester.dragUntilVisible(
        find.text('Member 14'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      expect(find.text('Member 14'), findsOneWidget);
    },
  );
}
