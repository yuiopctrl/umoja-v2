import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/auth/models/app_context.dart';
import 'package:umoja/features/auth/models/app_user_profile.dart';
import 'package:umoja/features/auth/models/group_context.dart';
import 'package:umoja/features/auth/models/membership_context.dart';
import 'package:umoja/features/auth/providers/app_context_provider.dart';
import 'package:umoja/features/auth/providers/selected_group_provider.dart';
import 'package:umoja/features/members/providers/members_query_provider.dart';

MembershipContext _membership(String groupId, String groupName) {
  return MembershipContext(
    membershipId: 'm-$groupId',
    group: GroupContext(
      groupId: groupId,
      groupName: groupName,
      groupStatus: 'ACTIVE',
    ),
    membershipStatus: 'ACTIVE',
    displayName: 'Admin',
    roleCodes: const ['ADMIN'],
    permissionCodes: const ['member.view'],
  );
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  test('starts with no search, no status filter, and the base page size', () {
    final query = container.read(membersQueryProvider);
    expect(query.search, isEmpty);
    expect(query.status, isNull);
    expect(query.limit, 10);
  });

  test('loadMore grows the limit without resetting filters', () {
    final notifier = container.read(membersQueryProvider.notifier);
    notifier.setSearch('Amina');
    notifier.setStatus('ACTIVE');
    notifier.loadMore();

    final query = container.read(membersQueryProvider);
    expect(query.search, 'Amina');
    expect(query.status, 'ACTIVE');
    expect(query.limit, 20);
  });

  test('changing the search resets pagination back to the first page', () {
    final notifier = container.read(membersQueryProvider.notifier);
    notifier.loadMore();
    notifier.loadMore();
    expect(container.read(membersQueryProvider).limit, 30);

    notifier.setSearch('Baraka');
    expect(container.read(membersQueryProvider).limit, 10);
  });

  test(
    'changing the status filter resets pagination back to the first page',
    () {
      final notifier = container.read(membersQueryProvider.notifier);
      notifier.loadMore();
      expect(container.read(membersQueryProvider).limit, 20);

      notifier.setStatus('SUSPENDED');
      expect(container.read(membersQueryProvider).limit, 10);
    },
  );

  test('resetPageSize keeps filters but restores the base page size', () {
    final notifier = container.read(membersQueryProvider.notifier);
    notifier.setSearch('Amina');
    notifier.setStatus('ACTIVE');
    notifier.loadMore();

    notifier.resetPageSize();

    final query = container.read(membersQueryProvider);
    expect(query.search, 'Amina');
    expect(query.status, 'ACTIVE');
    expect(query.limit, 10);
  });

  test('switching groups (via selectGroup) clears the previous group\'s '
      'loaded pages and search/filter', () async {
    final groupA = _membership('gA', 'Group A');
    final groupB = _membership('gB', 'Group B');

    final switchContainer = ProviderContainer(
      overrides: [
        appContextProvider.overrideWith(
          (ref) async => AppContext(
            userId: 'u1',
            profile: const AppUserProfile(id: 'u1', fullName: 'Admin'),
            memberships: [groupA, groupB],
          ),
        ),
      ],
    );
    addTearDown(switchContainer.dispose);

    await switchContainer.read(appContextProvider.future);

    // Two eligible memberships -> SelectedGroupPending until an
    // explicit selectGroup() call.
    expect(
      switchContainer.read(selectedGroupProvider),
      isA<SelectedGroupPending>(),
    );

    final queryNotifier = switchContainer.read(membersQueryProvider.notifier);
    queryNotifier.setSearch('Amina');
    queryNotifier.loadMore();
    expect(switchContainer.read(membersQueryProvider).limit, 20);
    expect(switchContainer.read(membersQueryProvider).search, 'Amina');

    switchContainer
        .read(selectedGroupProvider.notifier)
        .selectGroup(groupA.membershipId);

    final resetQuery = switchContainer.read(membersQueryProvider);
    expect(resetQuery.limit, 10);
    expect(resetQuery.search, isEmpty);
    expect(resetQuery.status, isNull);
  });
}
