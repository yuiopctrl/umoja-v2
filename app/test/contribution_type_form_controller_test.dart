import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/contributions/controllers/contribution_type_form_controller.dart';
import 'package:umoja/features/contributions/data/contribution_failure.dart';
import 'package:umoja/features/contributions/providers/contribution_repository_provider.dart';

import 'fakes/fake_contribution_repository.dart';

void main() {
  late FakeContributionRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    fakeRepo = FakeContributionRepository();
    container = ProviderContainer(
      overrides: [contributionRepositoryProvider.overrideWithValue(fakeRepo)],
    );
    addTearDown(container.dispose);
  });

  group('createType', () {
    test(
      'rejects MEMBER_SAVINGS client-side, never calling the repository',
      () async {
        final result = await container
            .read(contributionTypeFormControllerProvider.notifier)
            .createType(
              groupId: 'g1',
              name: 'Akiba',
              category: 'GENERAL',
              accountingTreatment: 'MEMBER_SAVINGS',
            );

        expect(result, isNull);
        expect(fakeRepo.createContributionTypeCalls, isEmpty);
        expect(
          container.read(contributionTypeFormControllerProvider).errorType,
          ContributionFailureType.memberSavingsNotAvailable,
        );
      },
    );

    test('rejects a blank name before calling the repository', () async {
      final result = await container
          .read(contributionTypeFormControllerProvider.notifier)
          .createType(
            groupId: 'g1',
            name: '   ',
            category: 'GENERAL',
            accountingTreatment: 'GROUP_INCOME',
          );

      expect(result, isNull);
      expect(fakeRepo.createContributionTypeCalls, isEmpty);
      expect(
        container.read(contributionTypeFormControllerProvider).errorType,
        ContributionFailureType.nameRequired,
      );
    });

    test('a valid GENERAL/GROUP_INCOME type calls the repository', () async {
      final result = await container
          .read(contributionTypeFormControllerProvider.notifier)
          .createType(
            groupId: 'g1',
            name: 'Michango ya Mwezi',
            category: 'GENERAL',
            accountingTreatment: 'GROUP_INCOME',
          );

      expect(result, isNotNull);
      expect(fakeRepo.createContributionTypeCalls, hasLength(1));
      expect(
        fakeRepo.createContributionTypeCalls.single.name,
        'Michango ya Mwezi',
      );
    });
  });

  group('updateType', () {
    test('rejects MEMBER_SAVINGS client-side on edit too', () async {
      final result = await container
          .read(contributionTypeFormControllerProvider.notifier)
          .updateType(
            groupId: 'g1',
            typeId: 'type-1',
            name: 'Akiba',
            category: 'GENERAL',
            accountingTreatment: 'MEMBER_SAVINGS',
          );

      expect(result, isFalse);
      expect(fakeRepo.updateContributionTypeCalls, isEmpty);
    });
  });
}
