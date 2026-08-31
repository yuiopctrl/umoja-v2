import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/auth/providers/selected_group_provider.dart';
import 'package:umoja/features/financial_accounts/providers/financial_account_detail_provider.dart';
import 'package:umoja/features/payments/controllers/payment_reversal_controller.dart';
import 'package:umoja/features/payments/data/payment_failure.dart';
import 'package:umoja/features/payments/providers/member_contribution_charges_provider.dart';
import 'package:umoja/features/payments/providers/member_contribution_statement_provider.dart';
import 'package:umoja/features/payments/providers/member_wallet_provider.dart';
import 'package:umoja/features/payments/providers/payment_detail_provider.dart';
import 'package:umoja/features/payments/providers/payment_repository_provider.dart';
import 'package:umoja/features/payments/providers/payments_list_provider.dart';

import 'fakes/fake_payment_repository.dart';
import 'fakes/payments_test_app.dart';

const _listQuery = (search: '', membershipId: null, status: null, limit: 10);

class _FixedSelectedGroup extends SelectedGroupNotifier {
  @override
  SelectedGroupState build() => SelectedGroupResolved(paymentMembership());
}

void main() {
  late FakePaymentRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    fakeRepo = FakePaymentRepository();
    container = ProviderContainer(
      overrides: [
        paymentRepositoryProvider.overrideWithValue(fakeRepo),
        selectedGroupProvider.overrideWith(_FixedSelectedGroup.new),
      ],
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

  test('a backend permission-denied response surfaces permissionDenied '
      'cleanly, not a generic failure (Prompt 07 UAT-FIX-04)', () async {
    fakeRepo.failure = const PaymentFailure(
      PaymentFailureType.permissionDenied,
      'not authorized',
    );

    final ok = await container
        .read(paymentReversalControllerProvider.notifier)
        .reverse(
          groupId: 'g1',
          paymentId: 'payment-1',
          financialAccountId: 'a1',
          reversalReason: 'testing denial',
        );

    expect(ok, isFalse);
    expect(
      container.read(paymentReversalControllerProvider).errorType,
      PaymentFailureType.permissionDenied,
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

  test('a successful reversal also invalidates the member statement, member '
      'charges, wallet, and financial account providers so every affected '
      'screen refreshes without a restart', () async {
    var statementBuilds = 0;
    var chargesBuilds = 0;
    var walletBuilds = 0;
    var accountBuilds = 0;
    container.listen(
      memberContributionStatementProvider('m1'),
      (_, _) => statementBuilds++,
      fireImmediately: true,
    );
    container.listen(
      memberContributionChargesProvider((
        membershipId: 'm1',
        filter: 'OUTSTANDING',
        limit: 10,
      )),
      (_, _) => chargesBuilds++,
      fireImmediately: true,
    );
    container.listen(
      memberWalletEntriesProvider((membershipId: 'm1', limit: 10)),
      (_, _) => walletBuilds++,
      fireImmediately: true,
    );
    container.listen(
      financialAccountDetailProvider('a1'),
      (_, _) => accountBuilds++,
      fireImmediately: true,
    );
    await Future<void>.delayed(Duration.zero);
    final statementBefore = statementBuilds;
    final chargesBefore = chargesBuilds;
    final walletBefore = walletBuilds;
    final accountBefore = accountBuilds;

    await container
        .read(paymentReversalControllerProvider.notifier)
        .reverse(
          groupId: 'g1',
          paymentId: 'payment-1',
          financialAccountId: 'a1',
          reversalReason: 'duplicate entry',
        );
    await Future<void>.delayed(Duration.zero);

    expect(statementBuilds, greaterThan(statementBefore));
    expect(chargesBuilds, greaterThan(chargesBefore));
    expect(walletBuilds, greaterThan(walletBefore));
    expect(accountBuilds, greaterThan(accountBefore));
  });
}
