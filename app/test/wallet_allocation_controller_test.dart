import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/payments/controllers/wallet_allocation_controller.dart';
import 'package:umoja/features/payments/data/payment_failure.dart';
import 'package:umoja/features/payments/providers/member_wallet_provider.dart';
import 'package:umoja/features/payments/providers/payment_repository_provider.dart';

import 'fakes/fake_payment_repository.dart';

void main() {
  late FakePaymentRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    fakeRepo = FakePaymentRepository();
    container = ProviderContainer(
      overrides: [paymentRepositoryProvider.overrideWithValue(fakeRepo)],
    );
    addTearDown(container.dispose);
  });

  test('allocate sends the exact membership and amount given', () async {
    final ok = await container
        .read(walletAllocationControllerProvider.notifier)
        .allocate(groupId: 'g1', membershipId: 'm1', amount: 3000);

    expect(ok, isTrue);
    expect(fakeRepo.allocateMemberWalletCalls, hasLength(1));
    expect(fakeRepo.allocateMemberWalletCalls.single.amount, 3000);
  });

  test(
    'insufficient wallet balance surfaces walletInsufficientBalance',
    () async {
      fakeRepo.failure = const PaymentFailure(
        PaymentFailureType.walletInsufficientBalance,
        'insufficient',
      );

      final ok = await container
          .read(walletAllocationControllerProvider.notifier)
          .allocate(groupId: 'g1', membershipId: 'm1', amount: 999999);

      expect(ok, isFalse);
      expect(
        container.read(walletAllocationControllerProvider).errorType,
        PaymentFailureType.walletInsufficientBalance,
      );
    },
  );

  test('attempting to allocate against nothing outstanding surfaces '
      'walletAllocationNothingToAllocate', () async {
    fakeRepo.failure = const PaymentFailure(
      PaymentFailureType.walletAllocationNothingToAllocate,
      'nothing to allocate',
    );

    final ok = await container
        .read(walletAllocationControllerProvider.notifier)
        .allocate(groupId: 'g1', membershipId: 'm1', amount: 1000);

    expect(ok, isFalse);
    expect(
      container.read(walletAllocationControllerProvider).errorType,
      PaymentFailureType.walletAllocationNothingToAllocate,
    );
  });

  test(
    'a successful allocation invalidates the member wallet ledger provider',
    () async {
      const query = (membershipId: 'm1', limit: 10);
      var builds = 0;
      container.listen(
        memberWalletEntriesProvider(query),
        (_, _) => builds++,
        fireImmediately: true,
      );
      await Future<void>.delayed(Duration.zero);
      final before = builds;

      await container
          .read(walletAllocationControllerProvider.notifier)
          .allocate(groupId: 'g1', membershipId: 'm1', amount: 3000);
      await Future<void>.delayed(Duration.zero);

      expect(builds, greaterThan(before));
    },
  );
}
