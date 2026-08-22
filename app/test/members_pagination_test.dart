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
import 'package:umoja/features/members/data/member_repository.dart';
import 'package:umoja/features/members/domain/group_member.dart';
import 'package:umoja/features/members/domain/group_member_page.dart';
import 'package:umoja/features/members/providers/member_repository_provider.dart';

import 'fakes/pin_bypass_overrides.dart';

/// A [MemberRepository] fake backed by a real in-memory list, so
/// `listMembers(limit: ...)` genuinely returns more rows as the
/// requested limit grows — unlike `FakeMemberRepository` (which always
/// returns one fixed, pre-baked page), this is what's needed to prove
/// "Onyesha Zaidi" actually fetches the next page rather than just
/// re-rendering the same fixture (prompt 05C §11).
class _PaginatedMemberRepository implements MemberRepository {
  _PaginatedMemberRepository(int totalMembers)
    : _all = List.generate(
        totalMembers,
        (i) => GroupMember(
          membershipId: 'm-${i + 1}',
          groupId: 'g1',
          displayName: 'Member ${(i + 1).toString().padLeft(2, '0')}',
          status: 'ACTIVE',
          createdAt: DateTime.utc(2026, 1, 15),
          isLoginLinked: false,
          roleCodes: const [],
        ),
      );

  final List<GroupMember> _all;
  final List<int> requestedLimits = [];

  @override
  Future<GroupMemberPage> listMembers({
    required String groupId,
    String? search,
    String? status,
    int limit = 25,
    int offset = 0,
  }) async {
    requestedLimits.add(limit);
    final items = _all.take(limit).toList(growable: false);
    return GroupMemberPage(
      items: items,
      totalCount: _all.length,
      limit: limit,
      offset: 0,
    );
  }

  @override
  Future<GroupMember> getMember({
    required String groupId,
    required String membershipId,
  }) => throw UnimplementedError();

  @override
  Future<GroupMember> createMember({
    required String groupId,
    required String displayName,
    String? phone,
    String? memberNumber,
    DateTime? joinedAt,
  }) => throw UnimplementedError();

  @override
  Future<void> updateMember({
    required String groupId,
    required String membershipId,
    String? displayName,
    String? phone,
    String? memberNumber,
  }) => throw UnimplementedError();

  @override
  Future<void> changeStatus({
    required String groupId,
    required String membershipId,
    required String status,
    DateTime? exitedAt,
  }) => throw UnimplementedError();

  @override
  Future<void> rejoinMember({
    required String groupId,
    required String membershipId,
  }) => throw UnimplementedError();

  @override
  Future<void> assignRole({
    required String groupId,
    required String membershipId,
    required String roleCode,
  }) => throw UnimplementedError();

  @override
  Future<void> removeRole({
    required String groupId,
    required String membershipId,
    required String roleCode,
  }) => throw UnimplementedError();
}

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
    permissionCodes: ['member.view'],
  );
}

Future<_PaginatedMemberRepository> _pumpMembersList(
  WidgetTester tester,
  int totalMembers,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = _PaginatedMemberRepository(totalMembers);

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
        memberRepositoryProvider.overrideWithValue(repo),
      ],
      child: const UmojaApp(),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('homeMembersShortcut')));
  await tester.pumpAndSettle();

  return repo;
}

/// The members list is a lazy [ListView] — only on-screen rows are
/// actually built — so reaching the last row/the trailing "Onyesha
/// Zaidi" button requires scrolling it into view first.
Future<void> _scrollToBottom(WidgetTester tester) async {
  await tester.dragUntilVisible(
    find.text('Onyesha Zaidi'),
    find.byType(ListView),
    const Offset(0, -300),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the members list requests exactly 10 members on first load', (
    tester,
  ) async {
    final repo = await _pumpMembersList(tester, 25);
    await _scrollToBottom(tester);

    expect(repo.requestedLimits, [10]);
    expect(find.text('Member 10'), findsOneWidget);
    expect(find.text('Member 11'), findsNothing);
    expect(find.text('Onyesha Zaidi'), findsOneWidget);
  });

  testWidgets('Onyesha Zaidi fetches the next page (limit 20) and appends it '
      'without duplicating existing rows', (tester) async {
    final repo = await _pumpMembersList(tester, 25);
    await _scrollToBottom(tester);

    await tester.tap(find.text('Onyesha Zaidi'));
    await tester.pumpAndSettle();
    await _scrollToBottom(tester);

    expect(repo.requestedLimits, [10, 20]);
    expect(find.text('Member 20'), findsOneWidget);
    expect(find.text('Member 21'), findsNothing);
    expect(find.text('Onyesha Zaidi'), findsOneWidget);

    // No duplicate rows: an item from the first page still renders
    // exactly once after the larger re-fetch replaces the list.
    await tester.dragUntilVisible(
      find.text('Member 01'),
      find.byType(ListView),
      const Offset(0, 300),
    );
    expect(find.text('Member 01'), findsOneWidget);
  });

  testWidgets('Onyesha Zaidi disappears once every member has been loaded', (
    tester,
  ) async {
    final repo = await _pumpMembersList(tester, 15);
    await _scrollToBottom(tester);

    expect(find.text('Onyesha Zaidi'), findsOneWidget);

    await tester.tap(find.text('Onyesha Zaidi'));
    await tester.pumpAndSettle();

    expect(repo.requestedLimits, [10, 20]);
    await tester.dragUntilVisible(
      find.text('Member 15'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    expect(find.text('Member 15'), findsOneWidget);
    expect(find.text('Onyesha Zaidi'), findsNothing);
  });
}
