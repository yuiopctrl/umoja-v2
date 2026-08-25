import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/contributions/controllers/contribution_period_enroll_controller.dart';
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

  test('a FIXED setup enrolls without requiring an amount', () async {
    final ok = await container
        .read(contributionPeriodEnrollControllerProvider.notifier)
        .enroll(
          groupId: 'g1',
          periodId: 'period-1',
          membershipId: 'm1',
          isCustomAmount: false,
        );

    expect(ok, isTrue);
    expect(fakeRepo.enrollMemberInContributionPeriodCalls, hasLength(1));
    expect(
      fakeRepo.enrollMemberInContributionPeriodCalls.single.amount,
      isNull,
    );
  });

  test(
    'a CUSTOM_PER_MEMBER setup rejects enrollment without a positive amount',
    () async {
      final ok = await container
          .read(contributionPeriodEnrollControllerProvider.notifier)
          .enroll(
            groupId: 'g1',
            periodId: 'period-1',
            membershipId: 'm1',
            isCustomAmount: true,
          );

      expect(ok, isFalse);
      expect(fakeRepo.enrollMemberInContributionPeriodCalls, isEmpty);
      expect(
        container.read(contributionPeriodEnrollControllerProvider).errorType,
        ContributionFailureType.amountRequired,
      );
    },
  );

  test('a CUSTOM_PER_MEMBER setup enrolls with a positive amount', () async {
    final ok = await container
        .read(contributionPeriodEnrollControllerProvider.notifier)
        .enroll(
          groupId: 'g1',
          periodId: 'period-1',
          membershipId: 'm1',
          isCustomAmount: true,
          amount: 6000,
        );

    expect(ok, isTrue);
    expect(fakeRepo.enrollMemberInContributionPeriodCalls.single.amount, 6000);
  });

  test(
    'MEMBER_ALREADY_CHARGED_FOR_PERIOD surfaces the friendly message',
    () async {
      fakeRepo.failure = const ContributionFailure(
        ContributionFailureType.memberAlreadyCharged,
        'already charged',
      );

      final ok = await container
          .read(contributionPeriodEnrollControllerProvider.notifier)
          .enroll(
            groupId: 'g1',
            periodId: 'period-1',
            membershipId: 'm1',
            isCustomAmount: false,
          );

      expect(ok, isFalse);
      expect(
        container.read(contributionPeriodEnrollControllerProvider).errorType,
        ContributionFailureType.memberAlreadyCharged,
      );
    },
  );
}
