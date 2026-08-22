import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/members/controllers/member_role_controller.dart';
import 'package:umoja/features/members/data/member_failure.dart';
import 'package:umoja/features/members/providers/member_repository_provider.dart';

import 'fakes/fake_member_repository.dart';

void main() {
  late FakeMemberRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    fakeRepo = FakeMemberRepository();
    container = ProviderContainer(
      overrides: [memberRepositoryProvider.overrideWithValue(fakeRepo)],
    );
    addTearDown(container.dispose);
  });

  test('assignRole calls the repository with the given role code', () async {
    final ok = await container
        .read(memberRoleControllerProvider.notifier)
        .assignRole(groupId: 'g1', membershipId: 'm1', roleCode: 'TREASURER');

    expect(ok, isTrue);
    expect(fakeRepo.assignRoleCalls, hasLength(1));
    expect(fakeRepo.assignRoleCalls.single.roleCode, 'TREASURER');
  });

  test('removeRole calls the repository with the given role code', () async {
    final ok = await container
        .read(memberRoleControllerProvider.notifier)
        .removeRole(groupId: 'g1', membershipId: 'm1', roleCode: 'TREASURER');

    expect(ok, isTrue);
    expect(fakeRepo.removeRoleCalls, hasLength(1));
  });

  test(
    'an unauthorized assignment (backend-rejected) surfaces a friendly message',
    () async {
      fakeRepo.failure = const MemberFailure(
        MemberFailureType.permissionDenied,
        'You do not have permission to do that.',
      );

      final ok = await container
          .read(memberRoleControllerProvider.notifier)
          .assignRole(groupId: 'g1', membershipId: 'm1', roleCode: 'ADMIN');

      expect(ok, isFalse);
      expect(
        container.read(memberRoleControllerProvider).errorType,
        MemberFailureType.permissionDenied,
      );
    },
  );

  test('last-active-ADMIN protection on role removal surfaces the friendly message', () async {
    fakeRepo.failure = const MemberFailure(
      MemberFailureType.lastAdminRequired,
      'Kikundi lazima kibaki na angalau msimamizi mmoja aliye active.',
    );

    final ok = await container
        .read(memberRoleControllerProvider.notifier)
        .removeRole(groupId: 'g1', membershipId: 'm1', roleCode: 'ADMIN');

    expect(ok, isFalse);
    expect(
      container.read(memberRoleControllerProvider).errorType,
      MemberFailureType.lastAdminRequired,
    );
  });
}
