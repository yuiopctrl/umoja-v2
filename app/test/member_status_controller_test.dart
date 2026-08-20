import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/members/controllers/member_status_controller.dart';
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

  test('a valid status transition calls the repository', () async {
    final ok = await container
        .read(memberStatusControllerProvider.notifier)
        .changeStatus(groupId: 'g1', membershipId: 'm1', status: 'SUSPENDED');

    expect(ok, isTrue);
    expect(fakeRepo.changeStatusCalls, hasLength(1));
    expect(fakeRepo.changeStatusCalls.single.status, 'SUSPENDED');
    expect(container.read(memberStatusControllerProvider).errorMessage, isNull);
  });

  test(
    'LAST_ADMIN_REQUIRED surfaces the exact friendly Swahili message',
    () async {
      fakeRepo.failure = const MemberFailure(
        MemberFailureType.lastAdminRequired,
        'Kikundi lazima kibaki na angalau msimamizi mmoja aliye active.',
      );

      final ok = await container
          .read(memberStatusControllerProvider.notifier)
          .changeStatus(groupId: 'g1', membershipId: 'm1', status: 'SUSPENDED');

      expect(ok, isFalse);
      expect(
        container.read(memberStatusControllerProvider).errorMessage,
        'Kikundi lazima kibaki na angalau msimamizi mmoja aliye active.',
      );
    },
  );

  test('EXITED_MEMBERSHIP_IS_TERMINAL surfaces a friendly message, not a raw Postgres error', () async {
    fakeRepo.failure = const MemberFailure(
      MemberFailureType.invalidStatusTransition,
      'This member has already exited and cannot be reactivated this way.',
    );

    final ok = await container
        .read(memberStatusControllerProvider.notifier)
        .changeStatus(groupId: 'g1', membershipId: 'm1', status: 'ACTIVE');

    expect(ok, isFalse);
    final message = container.read(memberStatusControllerProvider).errorMessage;
    expect(message, isNotNull);
    expect(message!.toUpperCase().contains('SQLSTATE'), isFalse);
  });

  test(
    'a second call while one is in flight is ignored (no duplicate submission)',
    () async {
      final notifier = container.read(memberStatusControllerProvider.notifier);
      final first = notifier.changeStatus(
        groupId: 'g1',
        membershipId: 'm1',
        status: 'SUSPENDED',
      );
      final second = notifier.changeStatus(
        groupId: 'g1',
        membershipId: 'm1',
        status: 'EXITED',
      );

      await Future.wait([first, second]);

      expect(fakeRepo.changeStatusCalls, hasLength(1));
    },
  );
}
