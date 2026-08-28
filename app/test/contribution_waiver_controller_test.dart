import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/contributions/controllers/contribution_waiver_controller.dart';
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

  test('sends the exact positive magnitude the caller requested', () async {
    fakeRepo.nextWaiverResult = fakeContributionCorrectionResult(
      amount: 30000,
      netAssessed: 70000,
    );

    final ok = await container
        .read(contributionWaiverControllerProvider.notifier)
        .waive(
          groupId: 'g1',
          chargeId: 'charge-1',
          membershipId: 'm1',
          amount: 30000,
          reason: 'goodwill',
          effectiveAt: DateTime.utc(2026, 1, 12),
        );

    expect(ok, isTrue);
    expect(fakeRepo.waiveContributionChargeCalls.single.amount, 30000);
    expect(
      container
          .read(contributionWaiverControllerProvider)
          .lastResult
          ?.netAssessed,
      70000,
    );
  });

  test('exceeding net assessed surfaces waiverExceedsNetAssessed', () async {
    fakeRepo.failure = const ContributionFailure(
      ContributionFailureType.waiverExceedsNetAssessed,
      'exceeds net',
    );

    final ok = await container
        .read(contributionWaiverControllerProvider.notifier)
        .waive(
          groupId: 'g1',
          chargeId: 'charge-1',
          membershipId: 'm1',
          amount: 200000,
          reason: 'too much',
          effectiveAt: DateTime.utc(2026, 1, 12),
        );

    expect(ok, isFalse);
    expect(
      container.read(contributionWaiverControllerProvider).errorType,
      ContributionFailureType.waiverExceedsNetAssessed,
    );
  });

  test('a blank reason surfaces waiverReasonRequired', () async {
    fakeRepo.failure = const ContributionFailure(
      ContributionFailureType.waiverReasonRequired,
      'reason required',
    );

    final ok = await container
        .read(contributionWaiverControllerProvider.notifier)
        .waive(
          groupId: 'g1',
          chargeId: 'charge-1',
          membershipId: 'm1',
          amount: 1000,
          reason: '',
          effectiveAt: DateTime.utc(2026, 1, 12),
        );

    expect(ok, isFalse);
    expect(
      container.read(contributionWaiverControllerProvider).errorType,
      ContributionFailureType.waiverReasonRequired,
    );
  });
}
