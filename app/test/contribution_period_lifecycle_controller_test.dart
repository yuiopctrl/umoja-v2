import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/contributions/controllers/contribution_period_lifecycle_controller.dart';
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

  test('open calls rpc_open_contribution_period via the repository', () async {
    final ok = await container
        .read(contributionPeriodLifecycleControllerProvider.notifier)
        .open(groupId: 'g1', periodId: 'period-1');

    expect(ok, isTrue);
    expect(fakeRepo.openContributionPeriodCalls, hasLength(1));
    expect(fakeRepo.openContributionPeriodCalls.single.periodId, 'period-1');
  });

  test(
    'close calls rpc_close_contribution_period via the repository',
    () async {
      final ok = await container
          .read(contributionPeriodLifecycleControllerProvider.notifier)
          .close(groupId: 'g1', periodId: 'period-1');

      expect(ok, isTrue);
      expect(fakeRepo.closeContributionPeriodCalls, hasLength(1));
    },
  );

  test(
    'cancel calls rpc_cancel_contribution_period via the repository',
    () async {
      final ok = await container
          .read(contributionPeriodLifecycleControllerProvider.notifier)
          .cancel(groupId: 'g1', periodId: 'period-1');

      expect(ok, isTrue);
      expect(fakeRepo.cancelContributionPeriodCalls, hasLength(1));
    },
  );

  test(
    'MISSING_CUSTOM_AMOUNTS on open surfaces the friendly message',
    () async {
      fakeRepo.failure = const ContributionFailure(
        ContributionFailureType.missingCustomAmounts,
        'missing',
      );

      final ok = await container
          .read(contributionPeriodLifecycleControllerProvider.notifier)
          .open(groupId: 'g1', periodId: 'period-1');

      expect(ok, isFalse);
      expect(
        container.read(contributionPeriodLifecycleControllerProvider).errorType,
        ContributionFailureType.missingCustomAmounts,
      );
    },
  );

  test('CONTRIBUTION_PERIOD_NOT_CANCELLABLE on cancel surfaces the friendly message', () async {
    fakeRepo.failure = const ContributionFailure(
      ContributionFailureType.periodNotCancellable,
      'not cancellable',
    );

    final ok = await container
        .read(contributionPeriodLifecycleControllerProvider.notifier)
        .cancel(groupId: 'g1', periodId: 'period-1');

    expect(ok, isFalse);
    expect(
      container.read(contributionPeriodLifecycleControllerProvider).errorType,
      ContributionFailureType.periodNotCancellable,
    );
  });
}
