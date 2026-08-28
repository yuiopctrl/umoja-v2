import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/financial_accounts/controllers/financial_account_transfer_controller.dart';
import 'package:umoja/features/financial_accounts/data/financial_account_failure.dart';
import 'package:umoja/features/financial_accounts/providers/financial_account_detail_provider.dart';
import 'package:umoja/features/financial_accounts/providers/financial_account_repository_provider.dart';
import 'package:umoja/features/financial_accounts/providers/financial_accounts_list_provider.dart';

import 'fakes/fake_financial_account_repository.dart';

const _listQuery = (search: '', limit: 10);

void main() {
  late FakeFinancialAccountRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    fakeRepo = FakeFinancialAccountRepository();
    container = ProviderContainer(
      overrides: [
        financialAccountRepositoryProvider.overrideWithValue(fakeRepo),
      ],
    );
    addTearDown(container.dispose);
  });

  test('transfer posts the exact from/to/amount given', () async {
    fakeRepo.nextTransferResult = fakeFinancialAccountTransferResult(
      fromBalance: 30000,
      toBalance: 20000,
    );

    final ok = await container
        .read(financialAccountTransferControllerProvider.notifier)
        .transfer(
          groupId: 'g1',
          fromAccountId: 'a1',
          toAccountId: 'a2',
          amount: 20000,
        );

    expect(ok, isTrue);
    expect(fakeRepo.recordFinancialAccountTransferCalls, hasLength(1));
    expect(fakeRepo.recordFinancialAccountTransferCalls.single.amount, 20000);
    expect(
      container
          .read(financialAccountTransferControllerProvider)
          .lastResult
          ?.fromBalance,
      30000,
    );
  });

  test('insufficient balance surfaces insufficientBalance', () async {
    fakeRepo.failure = const FinancialAccountFailure(
      FinancialAccountFailureType.insufficientBalance,
      'insufficient',
    );

    final ok = await container
        .read(financialAccountTransferControllerProvider.notifier)
        .transfer(
          groupId: 'g1',
          fromAccountId: 'a1',
          toAccountId: 'a2',
          amount: 999999,
        );

    expect(ok, isFalse);
    expect(
      container.read(financialAccountTransferControllerProvider).errorType,
      FinancialAccountFailureType.insufficientBalance,
    );
  });

  test(
    'transferring an account to itself surfaces transferSameAccount',
    () async {
      fakeRepo.failure = const FinancialAccountFailure(
        FinancialAccountFailureType.transferSameAccount,
        'same account',
      );

      final ok = await container
          .read(financialAccountTransferControllerProvider.notifier)
          .transfer(
            groupId: 'g1',
            fromAccountId: 'a1',
            toAccountId: 'a1',
            amount: 100,
          );

      expect(ok, isFalse);
      expect(
        container.read(financialAccountTransferControllerProvider).errorType,
        FinancialAccountFailureType.transferSameAccount,
      );
    },
  );

  test('a successful transfer invalidates an already-warm accounts list '
      'and active-accounts picker, and both accounts'
      ' detail providers', () async {
    // All four providers are `.autoDispose` — hold live listeners so
    // they stay warm across the mutation (matching how the real
    // screens' own `ref.watch` keeps them alive), otherwise a bare
    // read always refetches fresh regardless of whether the
    // controller invalidated anything.
    var listBuilds = 0;
    var pickerBuilds = 0;
    var fromDetailBuilds = 0;
    var toDetailBuilds = 0;
    container.listen(
      financialAccountsListProvider(_listQuery),
      (_, _) => listBuilds++,
      fireImmediately: true,
    );
    container.listen(
      financialAccountsActiveForPickerProvider,
      (_, _) => pickerBuilds++,
      fireImmediately: true,
    );
    container.listen(
      financialAccountDetailProvider('a1'),
      (_, _) => fromDetailBuilds++,
      fireImmediately: true,
    );
    container.listen(
      financialAccountDetailProvider('a2'),
      (_, _) => toDetailBuilds++,
      fireImmediately: true,
    );
    await Future<void>.delayed(Duration.zero);
    final listBefore = listBuilds;
    final pickerBefore = pickerBuilds;
    final fromDetailBefore = fromDetailBuilds;
    final toDetailBefore = toDetailBuilds;

    await container
        .read(financialAccountTransferControllerProvider.notifier)
        .transfer(
          groupId: 'g1',
          fromAccountId: 'a1',
          toAccountId: 'a2',
          amount: 20000,
        );
    await Future<void>.delayed(Duration.zero);

    expect(listBuilds, greaterThan(listBefore));
    expect(pickerBuilds, greaterThan(pickerBefore));
    expect(fromDetailBuilds, greaterThan(fromDetailBefore));
    expect(toDetailBuilds, greaterThan(toDetailBefore));
  });

  test('retrying with the same idempotency key does not post a second '
      'transfer, but a fresh transfer (new key) posts normally', () async {
    fakeRepo.nextTransferResult = fakeFinancialAccountTransferResult(
      alreadyPosted: false,
    );

    final first = await container
        .read(financialAccountTransferControllerProvider.notifier)
        .transfer(
          groupId: 'g1',
          fromAccountId: 'a1',
          toAccountId: 'a2',
          amount: 20000,
          idempotencyKey: 'retry-key-1',
        );
    expect(first, isTrue);

    fakeRepo.nextTransferResult = fakeFinancialAccountTransferResult(
      alreadyPosted: true,
    );
    final retry = await container
        .read(financialAccountTransferControllerProvider.notifier)
        .transfer(
          groupId: 'g1',
          fromAccountId: 'a1',
          toAccountId: 'a2',
          amount: 20000,
          idempotencyKey: 'retry-key-1',
        );
    expect(retry, isTrue);
    expect(
      container
          .read(financialAccountTransferControllerProvider)
          .lastResult
          ?.alreadyPosted,
      isTrue,
    );

    expect(fakeRepo.recordFinancialAccountTransferCalls, hasLength(2));
    expect(
      fakeRepo.recordFinancialAccountTransferCalls
          .map((c) => c.idempotencyKey)
          .toSet(),
      {'retry-key-1'},
    );

    // A genuinely new transfer (different key) is never blocked by
    // an old one's key.
    fakeRepo.nextTransferResult = fakeFinancialAccountTransferResult(
      alreadyPosted: false,
    );
    final fresh = await container
        .read(financialAccountTransferControllerProvider.notifier)
        .transfer(
          groupId: 'g1',
          fromAccountId: 'a1',
          toAccountId: 'a2',
          amount: 5000,
          idempotencyKey: 'fresh-key-2',
        );
    expect(fresh, isTrue);
    expect(fakeRepo.recordFinancialAccountTransferCalls, hasLength(3));
    expect(
      fakeRepo.recordFinancialAccountTransferCalls.last.idempotencyKey,
      'fresh-key-2',
    );
  });
}
