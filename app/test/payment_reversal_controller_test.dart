import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/payments/controllers/payment_reversal_controller.dart';
import 'package:umoja/features/payments/data/payment_failure.dart';
import 'package:umoja/features/payments/providers/payment_detail_provider.dart';
import 'package:umoja/features/payments/providers/payment_repository_provider.dart';
import 'package:umoja/features/payments/providers/payments_list_provider.dart';

import 'fakes/fake_payment_repository.dart';

const _listQuery = (search: '', membershipId: null, status: null, limit: 10);

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

  test('reverse sends the exact payment id and reason given', () async {
    final ok = await container
        .read(paymentReversalControllerProvider.notifier)
        .reverse(
          groupId: 'g1',
          paymentId: 'payment-1',
          financialAccountId: 'a1',
          reversalReason: 'duplicate entry',
        );

    expect(ok, isTrue);
    expect(fakeRepo.reversePaymentCalls, hasLength(1));
    expect(
      fakeRepo.reversePaymentCalls.single.reversalReason,
      'duplicate entry',
    );
  });

  test('a wallet-credit-already-consumed block surfaces its own specific '
      'error type, never a generic failure', () async {
    fakeRepo.failure = const PaymentFailure(
      PaymentFailureType.reversalBlockedWalletCreditConsumed,
      'blocked',
    );

    final ok = await container
        .read(paymentReversalControllerProvider.notifier)
        .reverse(
          groupId: 'g1',
          paymentId: 'payment-1',
          financialAccountId: 'a1',
          reversalReason: 'oops',
        );

    expect(ok, isFalse);
    expect(
      container.read(paymentReversalControllerProvider).errorType,
      PaymentFailureType.reversalBlockedWalletCreditConsumed,
    );
  });

  test(
    'reversing an already-reversed payment surfaces paymentAlreadyReversed',
    () async {
      fakeRepo.failure = const PaymentFailure(
        PaymentFailureType.paymentAlreadyReversed,
        'already reversed',
      );

      final ok = await container
          .read(paymentReversalControllerProvider.notifier)
          .reverse(
            groupId: 'g1',
            paymentId: 'payment-1',
            financialAccountId: 'a1',
            reversalReason: 'again',
          );

      expect(ok, isFalse);
      expect(
        container.read(paymentReversalControllerProvider).errorType,
        PaymentFailureType.paymentAlreadyReversed,
      );
    },
  );

  test('a successful reversal invalidates the payments list and this '
      "payment's own detail provider", () async {
    var listBuilds = 0;
    var detailBuilds = 0;
    container.listen(
      paymentsListProvider(_listQuery),
      (_, _) => listBuilds++,
      fireImmediately: true,
    );
    container.listen(
      paymentDetailProvider('payment-1'),
      (_, _) => detailBuilds++,
      fireImmediately: true,
    );
    await Future<void>.delayed(Duration.zero);
    final listBefore = listBuilds;
    final detailBefore = detailBuilds;

    await container
        .read(paymentReversalControllerProvider.notifier)
        .reverse(
          groupId: 'g1',
          paymentId: 'payment-1',
          financialAccountId: 'a1',
          reversalReason: 'duplicate entry',
        );
    await Future<void>.delayed(Duration.zero);

    expect(listBuilds, greaterThan(listBefore));
    expect(detailBuilds, greaterThan(detailBefore));
  });
}
