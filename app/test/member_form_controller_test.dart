import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/members/controllers/member_form_controller.dart';
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

  group('createMember', () {
    test('calls the repository with trimmed values and normalizes empty optionals to null', () async {
      final result = await container
          .read(memberFormControllerProvider.notifier)
          .createMember(
            groupId: 'g1',
            displayName: '  Amina Juma  ',
            phone: '  ',
            memberNumber: '',
          );

      expect(result, isNotNull);
      expect(fakeRepo.createMemberCalls, hasLength(1));
      expect(fakeRepo.createMemberCalls.single.displayName, 'Amina Juma');
      expect(fakeRepo.createMemberCalls.single.phone, isNull);
      expect(fakeRepo.createMemberCalls.single.memberNumber, isNull);
    });

    test('a blank name is rejected before calling the repository', () async {
      final result = await container
          .read(memberFormControllerProvider.notifier)
          .createMember(groupId: 'g1', displayName: '   ');

      expect(result, isNull);
      expect(fakeRepo.createMemberCalls, isEmpty);
      expect(
        container.read(memberFormControllerProvider).errorMessage,
        isNotNull,
      );
    });

    test(
      'a MemberFailure from the repository surfaces its friendly message',
      () async {
        fakeRepo.failure = const MemberFailure(
          MemberFailureType.duplicateMemberNumber,
          'That member number is already used in this group.',
        );

        final result = await container
            .read(memberFormControllerProvider.notifier)
            .createMember(
              groupId: 'g1',
              displayName: 'Amina Juma',
              memberNumber: 'M-001',
            );

        expect(result, isNull);
        expect(
          container.read(memberFormControllerProvider).errorMessage,
          'That member number is already used in this group.',
        );
      },
    );

    test('an unexpected error surfaces a generic safe message, not raw exception text', () async {
      fakeRepo.failure = Exception('some raw internal detail');

      final result = await container
          .read(memberFormControllerProvider.notifier)
          .createMember(groupId: 'g1', displayName: 'Amina Juma');

      expect(result, isNull);
      final message = container.read(memberFormControllerProvider).errorMessage;
      expect(message, isNotNull);
      expect(message!.contains('raw internal detail'), isFalse);
    });
  });

  group('updateMember', () {
    test('calls the repository and does not touch status', () async {
      final result = await container
          .read(memberFormControllerProvider.notifier)
          .updateMember(
            groupId: 'g1',
            membershipId: 'm1',
            displayName: 'Amina Renamed',
          );

      expect(result, isNotNull);
      expect(fakeRepo.updateMemberCalls, hasLength(1));
      expect(fakeRepo.updateMemberCalls.single.membershipId, 'm1');
      // MemberRepository.updateMember has no status parameter at all —
      // structurally cannot mutate status.
    });

    test('a blank name is rejected before calling the repository', () async {
      final result = await container
          .read(memberFormControllerProvider.notifier)
          .updateMember(groupId: 'g1', membershipId: 'm1', displayName: '');

      expect(result, isNull);
      expect(fakeRepo.updateMemberCalls, isEmpty);
    });
  });
}
