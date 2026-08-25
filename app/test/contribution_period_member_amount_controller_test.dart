import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/contributions/controllers/contribution_period_member_amount_controller.dart';
import 'package:umoja/features/contributions/data/contribution_member_amount_input.dart';
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

  test(
    'setAmounts batches every edited row into a single repository call',
    () async {
      final ok = await container
          .read(contributionPeriodMemberAmountControllerProvider.notifier)
          .setAmounts(
            groupId: 'g1',
            periodId: 'period-1',
            amounts: const [
              ContributionMemberAmountInput(membershipId: 'm1', amount: 5000),
              ContributionMemberAmountInput(membershipId: 'm2', amount: 7000),
              ContributionMemberAmountInput(membershipId: 'm3'),
            ],
          );

      expect(ok, isTrue);
      // Exactly one RPC call for the whole batch, not one per member.
      expect(fakeRepo.setContributionPeriodMemberAmountsCalls, hasLength(1));
      expect(
        fakeRepo.setContributionPeriodMemberAmountsCalls.single.amountsCount,
        3,
      );
    },
  );
}
