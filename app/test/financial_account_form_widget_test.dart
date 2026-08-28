import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/features/financial_accounts/data/financial_account_failure.dart';

import 'fakes/financial_accounts_test_app.dart';
import 'fakes/fake_financial_account_repository.dart';

void main() {
  testWidgets('creating an account with an opening balance sends the exact '
      'amount to rpc_create_financial_account', (tester) async {
    final fakeRepo = FakeFinancialAccountRepository();

    final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
    router.push(AppRoutes.financialAccountNew);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('financialAccountNameField')),
      'Main Cash',
    );
    await tester.enterText(
      find.byKey(const Key('financialAccountOpeningBalanceField')),
      '50000',
    );
    await tester.tap(find.text('Hifadhi'));
    await tester.pumpAndSettle();

    expect(fakeRepo.createFinancialAccountCalls, hasLength(1));
    expect(fakeRepo.createFinancialAccountCalls.single.name, 'Main Cash');
    expect(fakeRepo.createFinancialAccountCalls.single.openingBalance, 50000);
    expect(fakeRepo.createFinancialAccountCalls.single.accountType, 'CASH');
  });

  testWidgets('creating an account with no opening balance sends null', (
    tester,
  ) async {
    final fakeRepo = FakeFinancialAccountRepository();

    final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
    router.push(AppRoutes.financialAccountNew);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('financialAccountNameField')),
      'Bank X',
    );
    await tester.tap(find.text('Hifadhi'));
    await tester.pumpAndSettle();

    expect(fakeRepo.createFinancialAccountCalls, hasLength(1));
    expect(fakeRepo.createFinancialAccountCalls.single.openingBalance, isNull);
  });

  testWidgets('a duplicate account name shows the localized error message', (
    tester,
  ) async {
    final fakeRepo = FakeFinancialAccountRepository();

    final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
    router.push(AppRoutes.financialAccountNew);
    await tester.pumpAndSettle();

    fakeRepo.failure = const FinancialAccountFailure(
      FinancialAccountFailureType.duplicateName,
      'duplicate',
    );

    await tester.enterText(
      find.byKey(const Key('financialAccountNameField')),
      'Main Cash',
    );
    await tester.tap(find.text('Hifadhi'));
    await tester.pumpAndSettle();

    expect(
      find.text('Jina hilo la akaunti tayari linatumika kwenye kikundi hiki.'),
      findsOneWidget,
    );
  });
}
