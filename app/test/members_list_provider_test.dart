import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/auth/models/app_context.dart';
import 'package:umoja/features/auth/models/app_user_profile.dart';
import 'package:umoja/features/auth/models/group_context.dart';
import 'package:umoja/features/auth/models/membership_context.dart';
import 'package:umoja/features/auth/providers/app_context_provider.dart';
import 'package:umoja/features/members/domain/group_member_page.dart';
import 'package:umoja/features/members/providers/member_repository_provider.dart';
import 'package:umoja/features/members/providers/members_list_provider.dart';
import 'package:umoja/features/members/providers/members_query_provider.dart';

import 'fakes/fake_member_repository.dart';

MembershipContext _membership(String groupId, String groupName) {
  return MembershipContext(
    membershipId: 'membership-$groupId',
    group: GroupContext(
      groupId: groupId,
      groupName: groupName,
      groupStatus: 'ACTIVE',
    ),
    membershipStatus: 'ACTIVE',
    displayName: 'Caller',
    roleCodes: const ['ADMIN'],
    permissionCodes: const ['member.view', 'member.create'],
  );
}

void main() {
  test('with no resolved group, the list provider returns an empty page and never calls the repository', () async {
    final fakeRepo = FakeMemberRepository();
    final container = ProviderContainer(
      overrides: [
        memberRepositoryProvider.overrideWithValue(fakeRepo),
        appContextProvider.overrideWith(
          (ref) async => const AppContext(
            userId: 'u1',
            profile: AppUserProfile(id: 'u1'),
            memberships: [],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final page = await container.read(membersListProvider.future);

    expect(page.items, isEmpty);
    expect(fakeRepo.listMembersCalls, isEmpty);
  });

  test('with a resolved group, the list provider fetches from that group with the current query', () async {
    final fakeRepo = FakeMemberRepository()
      ..nextListResult = GroupMemberPage.empty;
    final container = ProviderContainer(
      overrides: [
        memberRepositoryProvider.overrideWithValue(fakeRepo),
        appContextProvider.overrideWith(
          (ref) async => AppContext(
            userId: 'u1',
            profile: const AppUserProfile(id: 'u1', fullName: 'Caller'),
            memberships: [_membership('g1', 'Group One')],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(appContextProvider.future);
    container.read(membersQueryProvider.notifier).setSearch('Amina');
    await container.read(membersListProvider.future);

    expect(fakeRepo.listMembersCalls, hasLength(1));
    expect(fakeRepo.listMembersCalls.single.groupId, 'g1');
    expect(fakeRepo.listMembersCalls.single.search, 'Amina');
  });

  test(
    'changing the selected group context refetches from the new group',
    () async {
      final fakeRepo = FakeMemberRepository();
      String currentGroupId = 'g1';
      final container = ProviderContainer(
        overrides: [
          memberRepositoryProvider.overrideWithValue(fakeRepo),
          appContextProvider.overrideWith(
            (ref) async => AppContext(
              userId: 'u1',
              profile: const AppUserProfile(id: 'u1', fullName: 'Caller'),
              memberships: [_membership(currentGroupId, 'Group')],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(appContextProvider.future);
      await container.read(membersListProvider.future);
      expect(fakeRepo.listMembersCalls.single.groupId, 'g1');

      currentGroupId = 'g2';
      container.invalidate(appContextProvider);
      await container.read(appContextProvider.future);
      await container.read(membersListProvider.future);

      expect(fakeRepo.listMembersCalls, hasLength(2));
      expect(fakeRepo.listMembersCalls.last.groupId, 'g2');
    },
  );
}
