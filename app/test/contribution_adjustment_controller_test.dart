import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/contributions/controllers/contribution_adjustment_controller.dart';
import 'package:umoja/features/contributions/data/contribution_failure.dart';
import 'package:umoja/features/contributions/providers/contribution_charge_detail_provider.dart';
import 'package:umoja/features/contributions/providers/contribution_repository_provider.dart';
import 'package:umoja/features/contributions/providers/member_contribution_summary_provider.dart';

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

  test('posts a positive adjustment with the exact signed amount', () async {
    fakeRepo.nextAdjustmentResult = fakeContributionCorrectionResult(
      amount: 20000,
      netAssessed: 120000,
    );

    final ok = await container
        .read(contributionAdjustmentControllerProvider.notifier)
        .createAdjustment(
          groupId: 'g1',
          chargeId: 'charge-1',
          periodId: 'period-1',
          membershipId: 'm1',
          amount: 20000,
          reason: 'undercharged',
          effectiveAt: DateTime.utc(2026, 1, 10),
        );

    expect(ok, isTrue);
    expect(fakeRepo.createContributionAdjustmentCalls, hasLength(1));
    expect(fakeRepo.createContributionAdjustmentCalls.single.amount, 20000);
    expect(
      container
          .read(contributionAdjustmentControllerProvider)
          .lastResult
          ?.netAssessed,
      120000,
    );
  });

  test('posts a negative adjustment with the exact signed amount', () async {
    final ok = await container
        .read(contributionAdjustmentControllerProvider.notifier)
        .createAdjustment(
          groupId: 'g1',
          chargeId: 'charge-1',
          periodId: 'period-1',
          membershipId: 'm1',
          amount: -30000,
          reason: 'overcharged',
          effectiveAt: DateTime.utc(2026, 1, 11),
        );

    expect(ok, isTrue);
    expect(fakeRepo.createContributionAdjustmentCalls.single.amount, -30000);
  });

  test(
    'a floor-violation rejection surfaces '
    'adjustmentWouldMakeObligationNegative and posts nothing further',
    () async {
      fakeRepo.failure = const ContributionFailure(
        ContributionFailureType.adjustmentWouldMakeObligationNegative,
        'would go negative',
      );

      final ok = await container
          .read(contributionAdjustmentControllerProvider.notifier)
          .createAdjustment(
            groupId: 'g1',
            chargeId: 'charge-1',
            periodId: 'period-1',
            membershipId: 'm1',
            amount: -999999,
            reason: 'too much',
            effectiveAt: DateTime.utc(2026, 1, 11),
          );

      expect(ok, isFalse);
      expect(
        container.read(contributionAdjustmentControllerProvider).errorType,
        ContributionFailureType.adjustmentWouldMakeObligationNegative,
      );
    },
  );

  test('a successful adjustment invalidates the charge detail and member '
      'summary providers so the UI refreshes without a restart', () async {
    var chargeDetailBuilds = 0;
    var summaryBuilds = 0;
    container.listen(
      contributionChargeDetailProvider('charge-1'),
      (_, _) => chargeDetailBuilds++,
      fireImmediately: true,
    );
    container.listen(
      memberContributionSummaryProvider('m1'),
      (_, _) => summaryBuilds++,
      fireImmediately: true,
    );
    await Future<void>.delayed(Duration.zero);
    final chargeDetailBuildsBefore = chargeDetailBuilds;
    final summaryBuildsBefore = summaryBuilds;

    await container
        .read(contributionAdjustmentControllerProvider.notifier)
        .createAdjustment(
          groupId: 'g1',
          chargeId: 'charge-1',
          periodId: 'period-1',
          membershipId: 'm1',
          amount: 5000,
          reason: 'fix',
          effectiveAt: DateTime.utc(2026, 1, 12),
        );
    await Future<void>.delayed(Duration.zero);

    expect(chargeDetailBuilds, greaterThan(chargeDetailBuildsBefore));
    expect(summaryBuilds, greaterThan(summaryBuildsBefore));
  });
}
