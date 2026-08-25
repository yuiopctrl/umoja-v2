import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/contributions/controllers/contribution_setup_form_controller.dart';
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

  group('progressive disclosure validation', () {
    test('FIXED amount mode requires a positive fixedAmount', () async {
      final result = await container
          .read(contributionSetupFormControllerProvider.notifier)
          .createSetup(
            groupId: 'g1',
            contributionTypeId: 'type-1',
            name: 'Mchango wa Mwezi',
            scheduleMode: 'MONTHLY',
            amountMode: 'FIXED',
            fixedAmount: null,
          );

      expect(result, isNull);
      expect(fakeRepo.createContributionSetupCalls, isEmpty);
      expect(
        container.read(contributionSetupFormControllerProvider).errorType,
        ContributionFailureType.invalidAmount,
      );
    });

    test('CUSTOM_PER_MEMBER mode does not require fixedAmount', () async {
      final result = await container
          .read(contributionSetupFormControllerProvider.notifier)
          .createSetup(
            groupId: 'g1',
            contributionTypeId: 'type-1',
            name: 'Mchango wa Mwezi',
            scheduleMode: 'MONTHLY',
            amountMode: 'CUSTOM_PER_MEMBER',
            fixedAmount: null,
          );

      expect(result, isNotNull);
      expect(fakeRepo.createContributionSetupCalls, hasLength(1));
    });

    test('a non-NONE penalty mode requires a positive penaltyValue', () async {
      final result = await container
          .read(contributionSetupFormControllerProvider.notifier)
          .createSetup(
            groupId: 'g1',
            contributionTypeId: 'type-1',
            name: 'Mchango wa Mwezi',
            scheduleMode: 'MONTHLY',
            amountMode: 'FIXED',
            fixedAmount: 5000,
            penaltyMode: 'FIXED_ONCE',
            penaltyValue: null,
          );

      expect(result, isNull);
      expect(fakeRepo.createContributionSetupCalls, isEmpty);
      expect(
        container.read(contributionSetupFormControllerProvider).errorType,
        ContributionFailureType.invalidAmount,
      );
    });

    test('penaltyMode NONE never requires penalty fields', () async {
      final result = await container
          .read(contributionSetupFormControllerProvider.notifier)
          .createSetup(
            groupId: 'g1',
            contributionTypeId: 'type-1',
            name: 'Mchango wa Mwezi',
            scheduleMode: 'MONTHLY',
            amountMode: 'FIXED',
            fixedAmount: 5000,
          );

      expect(result, isNotNull);
      expect(fakeRepo.createContributionSetupCalls, hasLength(1));
    });
  });

  test('a blank name is rejected before calling the repository', () async {
    final result = await container
        .read(contributionSetupFormControllerProvider.notifier)
        .createSetup(
          groupId: 'g1',
          contributionTypeId: 'type-1',
          name: '   ',
          scheduleMode: 'MONTHLY',
          amountMode: 'FIXED',
          fixedAmount: 5000,
        );

    expect(result, isNull);
    expect(fakeRepo.createContributionSetupCalls, isEmpty);
  });

  test('a locked-setup rejection (CONTRIBUTION_SETUP_CONFIG_LOCKED) surfaces the friendly message', () async {
    fakeRepo.failure = const ContributionFailure(
      ContributionFailureType.setupConfigLocked,
      'locked',
    );

    final result = await container
        .read(contributionSetupFormControllerProvider.notifier)
        .createSetup(
          groupId: 'g1',
          contributionTypeId: 'type-1',
          name: 'Mchango wa Mwezi',
          scheduleMode: 'MONTHLY',
          amountMode: 'FIXED',
          fixedAmount: 5000,
        );

    expect(result, isNull);
    expect(
      container.read(contributionSetupFormControllerProvider).errorType,
      ContributionFailureType.setupConfigLocked,
    );
  });
}
