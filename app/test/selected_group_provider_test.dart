import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/auth/models/app_context.dart';
import 'package:umoja/features/auth/models/app_user_profile.dart';
import 'package:umoja/features/auth/models/group_context.dart';
import 'package:umoja/features/auth/models/membership_context.dart';
import 'package:umoja/features/auth/providers/app_context_provider.dart';
import 'package:umoja/features/auth/providers/selected_group_provider.dart';

MembershipContext _membership(
  String id,
  String groupName, {
  String membershipStatus = 'ACTIVE',
  String groupStatus = 'ACTIVE',
}) {
  return MembershipContext(
    membershipId: id,
    group: GroupContext(
      groupId: 'group-$id',
      groupName: groupName,
      groupStatus: groupStatus,
    ),
    membershipStatus: membershipStatus,
    displayName: 'Test Member',
    roleCodes: const ['MEMBER'],
    permissionCodes: const ['group.view'],
  );
}

ProviderContainer _containerWithMemberships(
  List<MembershipContext> memberships,
) {
  final container = ProviderContainer(
    overrides: [
      appContextProvider.overrideWith(
        (ref) async => AppContext(
          userId: 'u1',
          profile: const AppUserProfile(id: 'u1'),
          memberships: memberships,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('resolves to SelectedGroupNone with zero memberships', () async {
    final container = _containerWithMemberships(const []);

    await container.read(appContextProvider.future);
    final state = container.read(selectedGroupProvider);

    expect(state, isA<SelectedGroupNone>());
  });

  test(
    'auto-selects the single eligible membership when exactly one exists',
    () async {
      final membership = _membership('m1', 'Umoja Wamama');
      final container = _containerWithMemberships([membership]);

      await container.read(appContextProvider.future);
      final state = container.read(selectedGroupProvider);

      expect(state, isA<SelectedGroupResolved>());
      expect((state as SelectedGroupResolved).membership.membershipId, 'm1');
    },
  );

  test('requires explicit selection with multiple eligible memberships, then resolves it', () async {
    final membershipA = _membership('m1', 'Umoja Wamama');
    final membershipB = _membership('m2', 'Umoja Vijana');
    final container = _containerWithMemberships([membershipA, membershipB]);

    await container.read(appContextProvider.future);
    final pendingState = container.read(selectedGroupProvider);

    expect(pendingState, isA<SelectedGroupPending>());
    expect((pendingState as SelectedGroupPending).candidates, hasLength(2));

    container.read(selectedGroupProvider.notifier).selectGroup('m2');
    final resolvedState = container.read(selectedGroupProvider);

    expect(resolvedState, isA<SelectedGroupResolved>());
    expect(
      (resolvedState as SelectedGroupResolved).membership.membershipId,
      'm2',
    );
  });

  test('a SUSPENDED membership is not auto-selected', () async {
    final membership = _membership(
      'm1',
      'Umoja Wamama',
      membershipStatus: 'SUSPENDED',
    );
    final container = _containerWithMemberships([membership]);

    await container.read(appContextProvider.future);

    expect(container.read(selectedGroupProvider), isA<SelectedGroupNone>());
  });

  test('an EXITED membership is not auto-selected', () async {
    final membership = _membership(
      'm1',
      'Umoja Wamama',
      membershipStatus: 'EXITED',
    );
    final container = _containerWithMemberships([membership]);

    await container.read(appContextProvider.future);

    expect(container.read(selectedGroupProvider), isA<SelectedGroupNone>());
  });

  test(
    'an ACTIVE membership in a SUSPENDED group is not auto-selected',
    () async {
      final membership = _membership(
        'm1',
        'Umoja Wamama',
        groupStatus: 'SUSPENDED',
      );
      final container = _containerWithMemberships([membership]);

      await container.read(appContextProvider.future);

      expect(container.read(selectedGroupProvider), isA<SelectedGroupNone>());
    },
  );

  test('an ACTIVE membership in a CLOSED group is not auto-selected', () async {
    final membership = _membership('m1', 'Umoja Wamama', groupStatus: 'CLOSED');
    final container = _containerWithMemberships([membership]);

    await container.read(appContextProvider.future);

    expect(container.read(selectedGroupProvider), isA<SelectedGroupNone>());
  });

  test(
    'an eligible membership auto-selects even alongside ineligible ones',
    () async {
      final eligible = _membership('m1', 'Umoja Wamama');
      final suspended = _membership(
        'm2',
        'Umoja Vijana',
        membershipStatus: 'SUSPENDED',
      );
      final exited = _membership(
        'm3',
        'Umoja Zamani',
        membershipStatus: 'EXITED',
      );
      final container = _containerWithMemberships([
        eligible,
        suspended,
        exited,
      ]);

      await container.read(appContextProvider.future);
      final state = container.read(selectedGroupProvider);

      expect(state, isA<SelectedGroupResolved>());
      expect((state as SelectedGroupResolved).membership.membershipId, 'm1');
    },
  );

  test(
    'requireReselection returns to pending when multiple eligible groups exist',
    () async {
      final membershipA = _membership('m1', 'Umoja Wamama');
      final membershipB = _membership('m2', 'Umoja Vijana');
      final container = _containerWithMemberships([membershipA, membershipB]);

      await container.read(appContextProvider.future);
      container.read(selectedGroupProvider.notifier).selectGroup('m1');
      expect(
        container.read(selectedGroupProvider),
        isA<SelectedGroupResolved>(),
      );

      container.read(selectedGroupProvider.notifier).requireReselection([
        membershipA,
        membershipB,
      ]);

      expect(
        container.read(selectedGroupProvider),
        isA<SelectedGroupPending>(),
      );
    },
  );
}
