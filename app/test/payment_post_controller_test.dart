import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/auth/providers/selected_group_provider.dart';
import 'package:umoja/features/contributions/providers/member_contribution_summary_provider.dart';
import 'package:umoja/features/financial_accounts/providers/financial_account_detail_provider.dart';
import 'package:umoja/features/payments/controllers/payment_post_controller.dart';
import 'package:umoja/features/payments/data/payment_failure.dart';
import 'package:umoja/features/payments/providers/member_contribution_statement_provider.dart';
import 'package:umoja/features/payments/providers/payment_repository_provider.dart';
import 'package:umoja/features/payments/providers/payments_list_provider.dart';

import 'fakes/fake_payment_repository.dart';
import 'fakes/payments_test_app.dart';

class _FixedSelectedGroup extends SelectedGroupNotifier {
  @override
  SelectedGroupState build() => SelectedGroupResolved(paymentMembership());
}

const _listQuery = (search: '', membershipId: null, status: null, limit: 10);

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

  test('post sends the exact member/account/amount/method given', () async {
    fakeRepo.nextPostResult = fakePaymentPostResult(totalAllocated: 10000);

    final ok = await container
        .read(paymentPostControllerProvider.notifier)
        .post(
          groupId: 'g1',
          membershipId: 'm1',
          financialAccountId: 'a1',
          amount: 10000,
          effectiveAt: DateTime.utc(2026, 1, 10),
          paymentMethod: 'CASH',
        );

    expect(ok, isTrue);
    expect(fakeRepo.postPaymentCalls, hasLength(1));
    expect(fakeRepo.postPaymentCalls.single.amount, 10000);
    expect(fakeRepo.postPaymentCalls.single.paymentMethod, 'CASH');
    expect(
      container.read(paymentPostControllerProvider).result?.totalAllocated,
      10000,
    );
  });

  test(
    'an inactive financial account surfaces financialAccountInactive',
    () async {
      fakeRepo.failure = const PaymentFailure(
        PaymentFailureType.financialAccountInactive,
        'inactive',
      );

      final ok = await container
          .read(paymentPostControllerProvider.notifier)
          .post(
            groupId: 'g1',
            membershipId: 'm1',
            financialAccountId: 'a1',
            amount: 10000,
            effectiveAt: DateTime.utc(2026, 1, 10),
            paymentMethod: 'CASH',
          );

      expect(ok, isFalse);
      expect(
        container.read(paymentPostControllerProvider).errorType,
        PaymentFailureType.financialAccountInactive,
      );
    },
  );

  test('a successful post invalidates the payments list, member contribution '
      'summary, and the selected financial account balance', () async {
    // `.autoDispose` providers — hold live listeners so they stay
    // warm across the mutation (matching how the real screens keep
    // them alive via `ref.watch`), otherwise a bare read always
    // refetches fresh regardless of whether the controller
    // invalidated anything.
    var listBuilds = 0;
    var summaryBuilds = 0;
    var accountBuilds = 0;
    container.listen(
      paymentsListProvider(_listQuery),
      (_, _) => listBuilds++,
      fireImmediately: true,
    );
    container.listen(
      memberContributionSummaryProvider('m1'),
      (_, _) => summaryBuilds++,
      fireImmediately: true,
    );
    container.listen(
      financialAccountDetailProvider('a1'),
      (_, _) => accountBuilds++,
      fireImmediately: true,
    );
    await Future<void>.delayed(Duration.zero);
    final listBefore = listBuilds;
    final summaryBefore = summaryBuilds;
    final accountBefore = accountBuilds;

    await container
        .read(paymentPostControllerProvider.notifier)
        .post(
          groupId: 'g1',
          membershipId: 'm1',
          financialAccountId: 'a1',
          amount: 10000,
          effectiveAt: DateTime.utc(2026, 1, 10),
          paymentMethod: 'CASH',
        );
    await Future<void>.delayed(Duration.zero);

    expect(listBuilds, greaterThan(listBefore));
    expect(summaryBuilds, greaterThan(summaryBefore));
    expect(accountBuilds, greaterThan(accountBefore));
  });

  test('a second call while already submitting is a no-op', () async {
    fakeRepo.nextPostResult = fakePaymentPostResult();

    final future1 = container
        .read(paymentPostControllerProvider.notifier)
        .post(
          groupId: 'g1',
          membershipId: 'm1',
          financialAccountId: 'a1',
          amount: 10000,
          effectiveAt: DateTime.utc(2026, 1, 10),
          paymentMethod: 'CASH',
        );
    final second = await container
        .read(paymentPostControllerProvider.notifier)
        .post(
          groupId: 'g1',
          membershipId: 'm1',
          financialAccountId: 'a1',
          amount: 5000,
          effectiveAt: DateTime.utc(2026, 1, 10),
          paymentMethod: 'CASH',
        );
    await future1;

    expect(second, isFalse);
    expect(fakeRepo.postPaymentCalls, hasLength(1));
  });

  test('H: an exact payment invalidates the member statement, which then '
      'refetches and reports outstanding down to zero', () async {
    fakeRepo.nextStatement = fakeMemberContributionStatement(
      totalOutstanding: 30000,
      walletBalance: 0,
    );
    fakeRepo.nextPostResult = fakePaymentPostResult(
      amount: 30000,
      totalAllocated: 30000,
      walletCreditAmount: 0,
    );

    var builds = 0;
    container.listen(
      memberContributionStatementProvider('m1'),
      (_, _) => builds++,
      fireImmediately: true,
    );
    await Future<void>.delayed(Duration.zero);
    final before = builds;

    // The backend would now report zero outstanding — simulate that
    // by swapping the fake's next statement before the invalidated
    // provider refetches.
    fakeRepo.nextStatement = fakeMemberContributionStatement(
      charges: const [],
      totalOutstanding: 0,
      walletBalance: 0,
    );

    await container
        .read(paymentPostControllerProvider.notifier)
        .post(
          groupId: 'g1',
          membershipId: 'm1',
          financialAccountId: 'a1',
          amount: 30000,
          effectiveAt: DateTime.utc(2026, 1, 10),
          paymentMethod: 'CASH',
        );
    final statement = await container.read(
      memberContributionStatementProvider('m1').future,
    );

    expect(builds, greaterThan(before));
    expect(statement.totalOutstanding, 0.00);
  });

  test('I: an overpayment invalidates the member statement, which then '
      'refetches and visibly reports the credited wallet balance', () async {
    fakeRepo.nextStatement = fakeMemberContributionStatement(
      totalOutstanding: 30000,
      walletBalance: 0,
    );
    fakeRepo.nextPostResult = fakePaymentPostResult(
      amount: 50000,
      totalAllocated: 30000,
      walletCreditAmount: 20000,
    );

    container.listen(
      memberContributionStatementProvider('m1'),
      (_, _) {},
      fireImmediately: true,
    );
    await Future<void>.delayed(Duration.zero);

    fakeRepo.nextStatement = fakeMemberContributionStatement(
      charges: const [],
      totalOutstanding: 0,
      walletBalance: 20000,
    );

    await container
        .read(paymentPostControllerProvider.notifier)
        .post(
          groupId: 'g1',
          membershipId: 'm1',
          financialAccountId: 'a1',
          amount: 50000,
          effectiveAt: DateTime.utc(2026, 1, 10),
          paymentMethod: 'CASH',
        );
    final statement = await container.read(
      memberContributionStatementProvider('m1').future,
    );

    expect(statement.totalOutstanding, 0.00);
    expect(statement.walletBalance, 20000.00);
  });
}
