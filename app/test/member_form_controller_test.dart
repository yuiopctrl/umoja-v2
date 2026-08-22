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
    test('calls the repository with trimmed values and normalizes empty optionals to null, never sending a member number (server-generated)', () async {
      final result = await container
          .read(memberFormControllerProvider.notifier)
          .createMember(
            groupId: 'g1',
            displayName: '  Amina Juma  ',
            phone: '  ',
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
        container.read(memberFormControllerProvider).errorType,
        MemberFailureType.nameRequired,
      );
    });

    test(
      'a MemberFailure from the repository surfaces its failure type',
      () async {
        fakeRepo.failure = const MemberFailure(
          MemberFailureType.duplicateMemberNumber,
          'That member number is already used in this group.',
        );

        final result = await container
            .read(memberFormControllerProvider.notifier)
            .createMember(groupId: 'g1', displayName: 'Amina Juma');

        expect(result, isNull);
        expect(
          container.read(memberFormControllerProvider).errorType,
          MemberFailureType.duplicateMemberNumber,
        );
      },
    );

    test('an unexpected error surfaces a generic safe failure type, not raw exception text', () async {
      fakeRepo.failure = Exception('some raw internal detail');

      final result = await container
          .read(memberFormControllerProvider.notifier)
          .createMember(groupId: 'g1', displayName: 'Amina Juma');

      expect(result, isNull);
      expect(
        container.read(memberFormControllerProvider).errorType,
        MemberFailureType.unexpected,
      );
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

      expect(result, isTrue);
      expect(fakeRepo.updateMemberCalls, hasLength(1));
      expect(fakeRepo.updateMemberCalls.single.membershipId, 'm1');
      // MemberRepository.updateMember has no status parameter at all —
      // structurally cannot mutate status.
    });

    test('a blank name is rejected before calling the repository', () async {
      final result = await container
          .read(memberFormControllerProvider.notifier)
          .updateMember(groupId: 'g1', membershipId: 'm1', displayName: '');

      expect(result, isFalse);
      expect(fakeRepo.updateMemberCalls, isEmpty);
    });
  });
}
