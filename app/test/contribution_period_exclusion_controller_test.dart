import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/contributions/controllers/contribution_period_exclusion_controller.dart';
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

  test('exclude calls the repository with the given reason', () async {
    final ok = await container
        .read(contributionPeriodExclusionControllerProvider.notifier)
        .exclude(
          groupId: 'g1',
          periodId: 'period-1',
          membershipId: 'm1',
          reason: 'Hayupo kwa sasa',
        );

    expect(ok, isTrue);
    expect(fakeRepo.excludeContributionPeriodMemberCalls, hasLength(1));
    expect(
      fakeRepo.excludeContributionPeriodMemberCalls.single.membershipId,
      'm1',
    );
  });

  test('removeExclusion calls the repository', () async {
    final ok = await container
        .read(contributionPeriodExclusionControllerProvider.notifier)
        .removeExclusion(
          groupId: 'g1',
          periodId: 'period-1',
          membershipId: 'm1',
        );

    expect(ok, isTrue);
    expect(fakeRepo.removeContributionPeriodMemberExclusionCalls, hasLength(1));
  });

  test('CONTRIBUTION_PERIOD_NOT_EDITABLE (period no longer DRAFT/SCHEDULED) surfaces the friendly message', () async {
    fakeRepo.failure = const ContributionFailure(
      ContributionFailureType.periodNotEditable,
      'not editable',
    );

    final ok = await container
        .read(contributionPeriodExclusionControllerProvider.notifier)
        .exclude(groupId: 'g1', periodId: 'period-1', membershipId: 'm1');

    expect(ok, isFalse);
    expect(
      container.read(contributionPeriodExclusionControllerProvider).errorType,
      ContributionFailureType.periodNotEditable,
    );
  });
}
