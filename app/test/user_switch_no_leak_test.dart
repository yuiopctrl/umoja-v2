import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/auth/models/app_context.dart';
import 'package:umoja/features/auth/models/app_user_profile.dart';
import 'package:umoja/features/auth/models/group_context.dart';
import 'package:umoja/features/auth/models/membership_context.dart';
import 'package:umoja/features/auth/providers/app_context_provider.dart';
import 'package:umoja/features/auth/providers/auth_session_provider.dart';
import 'package:umoja/features/auth/providers/selected_group_provider.dart';

MembershipContext _membership(String id, String groupName) {
  return MembershipContext(
    membershipId: id,
    group: GroupContext(
      groupId: 'group-$id',
      groupName: groupName,
      groupStatus: 'ACTIVE',
    ),
    membershipStatus: 'ACTIVE',
    displayName: 'Member',
    roleCodes: const ['ADMIN'],
    permissionCodes: const ['group.view'],
  );
}

void main() {
  test('a different signed-in user never observes the previous user\'s '
      'app context or selected group', () async {
    String? currentUserId = 'userA';
    final membershipA = _membership(
      'mA',
      'User A'
          's Group',
    );

    final container = ProviderContainer(
      overrides: [
        authUserIdProvider.overrideWith((ref) => currentUserId),
        appContextProvider.overrideWith((ref) async {
          final uid = ref.watch(authUserIdProvider);
          if (uid == null) return null;
          if (uid == 'userA') {
            return AppContext(
              userId: 'userA',
              profile: const AppUserProfile(id: 'userA', fullName: 'User A'),
              memberships: [membershipA],
            );
          }
          // userB has no memberships of their own yet.
          return const AppContext(
            userId: 'userB',
            profile: AppUserProfile(id: 'userB', fullName: 'User B'),
            memberships: [],
          );
        }),
      ],
    );
    addTearDown(container.dispose);

    // User A signs in and their single group auto-selects.
    await container.read(appContextProvider.future);
    final stateA = container.read(selectedGroupProvider);
    expect(stateA, isA<SelectedGroupResolved>());
    expect((stateA as SelectedGroupResolved).membership.membershipId, 'mA');

    // User A signs out.
    currentUserId = null;
    container.invalidate(authUserIdProvider);
    await container.read(appContextProvider.future);
    expect(container.read(appContextProvider).value, isNull);
    expect(container.read(selectedGroupProvider), isA<SelectedGroupNone>());

    // A different user (User B) signs in.
    currentUserId = 'userB';
    container.invalidate(authUserIdProvider);
    await container.read(appContextProvider.future);

    final contextB = container.read(appContextProvider).value;
    expect(contextB?.userId, 'userB');
    expect(contextB?.memberships, isEmpty);

    // Critically: User B must not see User A's group as selected.
    final stateB = container.read(selectedGroupProvider);
    expect(stateB, isA<SelectedGroupNone>());
  });
}
