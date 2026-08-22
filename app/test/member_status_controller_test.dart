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
    expect(container.read(memberStatusControllerProvider).errorType, isNull);
  });

  test(
    // Regression test for a real production bug: rpc_change_group_member_status
    // succeeds server-side but returns a partial jsonb shape (no
    // display_name/created_at) — MemberRepository.changeStatus no
    // longer tries to parse a full GroupMember from it (see its doc
    // comment), so FakeMemberRepository mirrors that void-returning
    // contract here. A successful mutation must report success even
    // though nothing is available to reconstruct a full member from.
    'a successful status change reports success without needing a full '
    'member shape back from the repository (root cause of the old false '
    '"Something went wrong" bug after a real, successful suspend)',
    () async {
      final ok = await container
          .read(memberStatusControllerProvider.notifier)
          .changeStatus(groupId: 'g1', membershipId: 'm1', status: 'SUSPENDED');

      expect(ok, isTrue);
      expect(container.read(memberStatusControllerProvider).errorType, isNull);
    },
  );

  test('LAST_ADMIN_REQUIRED surfaces the exact failure type', () async {
    fakeRepo.failure = const MemberFailure(
      MemberFailureType.lastAdminRequired,
      'Kikundi lazima kibaki na angalau msimamizi mmoja aliye active.',
    );

    final ok = await container
        .read(memberStatusControllerProvider.notifier)
        .changeStatus(groupId: 'g1', membershipId: 'm1', status: 'SUSPENDED');

    expect(ok, isFalse);
    expect(
      container.read(memberStatusControllerProvider).errorType,
      MemberFailureType.lastAdminRequired,
    );
  });

  test('EXITED_MEMBERSHIP_IS_TERMINAL surfaces a safe failure type, not a raw Postgres error', () async {
    fakeRepo.failure = const MemberFailure(
      MemberFailureType.invalidStatusTransition,
      'This member has already exited and cannot be reactivated this way.',
    );

    final ok = await container
        .read(memberStatusControllerProvider.notifier)
        .changeStatus(groupId: 'g1', membershipId: 'm1', status: 'ACTIVE');

    expect(ok, isFalse);
    expect(
      container.read(memberStatusControllerProvider).errorType,
      MemberFailureType.invalidStatusTransition,
    );
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

  group('rejoin', () {
    test(
      'a successful rejoin calls the repository and reports success',
      () async {
        final ok = await container
            .read(memberStatusControllerProvider.notifier)
            .rejoin(groupId: 'g1', membershipId: 'm1');

        expect(ok, isTrue);
        expect(fakeRepo.rejoinMemberCalls, hasLength(1));
        expect(fakeRepo.rejoinMemberCalls.single.membershipId, 'm1');
        expect(
          container.read(memberStatusControllerProvider).errorType,
          isNull,
        );
      },
    );

    test('never routes through changeStatus (the generic RPC rejects EXITED -> ACTIVE)', () async {
      await container
          .read(memberStatusControllerProvider.notifier)
          .rejoin(groupId: 'g1', membershipId: 'm1');

      expect(fakeRepo.changeStatusCalls, isEmpty);
    });

    test('a rejoin conflict surfaces its failure type', () async {
      fakeRepo.failure = const MemberFailure(
        MemberFailureType.rejoinConflict,
        'USER_ALREADY_HAS_ACTIVE_MEMBERSHIP',
      );

      final ok = await container
          .read(memberStatusControllerProvider.notifier)
          .rejoin(groupId: 'g1', membershipId: 'm1');

      expect(ok, isFalse);
      expect(
        container.read(memberStatusControllerProvider).errorType,
        MemberFailureType.rejoinConflict,
      );
    });
  });
}
