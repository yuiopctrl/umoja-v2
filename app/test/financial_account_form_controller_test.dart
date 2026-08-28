import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/financial_accounts/controllers/financial_account_form_controller.dart';
import 'package:umoja/features/financial_accounts/data/financial_account_failure.dart';
import 'package:umoja/features/financial_accounts/providers/financial_account_repository_provider.dart';

import 'fakes/fake_financial_account_repository.dart';

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

  test('create posts the exact name/type/opening balance given', () async {
    final ok = await container
        .read(financialAccountFormControllerProvider.notifier)
        .create(
          groupId: 'g1',
          name: 'Main Cash',
          accountType: 'CASH',
          openingBalance: 50000,
          openingBalanceDate: DateTime.utc(2026, 1, 1),
        );

    expect(ok, isTrue);
    expect(fakeRepo.createFinancialAccountCalls, hasLength(1));
    expect(fakeRepo.createFinancialAccountCalls.single.openingBalance, 50000);
  });

  test('a duplicate name surfaces duplicateName', () async {
    fakeRepo.failure = const FinancialAccountFailure(
      FinancialAccountFailureType.duplicateName,
      'duplicate',
    );

    final ok = await container
        .read(financialAccountFormControllerProvider.notifier)
        .create(groupId: 'g1', name: 'Main Cash', accountType: 'CASH');

    expect(ok, isFalse);
    expect(
      container.read(financialAccountFormControllerProvider).errorType,
      FinancialAccountFailureType.duplicateName,
    );
  });

  test('update sends only the fields provided', () async {
    final ok = await container
        .read(financialAccountFormControllerProvider.notifier)
        .update(groupId: 'g1', accountId: 'a1', isActive: false);

    expect(ok, isTrue);
    expect(fakeRepo.updateFinancialAccountCalls, hasLength(1));
    expect(fakeRepo.updateFinancialAccountCalls.single.isActive, false);
    expect(fakeRepo.updateFinancialAccountCalls.single.name, isNull);
  });
}
