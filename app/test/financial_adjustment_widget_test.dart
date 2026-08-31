import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';

import 'fakes/fake_financial_account_repository.dart';
import 'fakes/financial_accounts_test_app.dart';

// Prompt 08B section 18/38-O: Financial Adjustment is a highly-
// permissioned, explicit correction — never presented as ordinary
// income/expense, and never reachable without financial_adjustment
// .create.
void main() {
  testWidgets('O: the Financial Adjustment action is hidden on Account Detail '
      'without financial_adjustment.create', (tester) async {
    final fakeRepo = FakeFinancialAccountRepository()
      ..nextAccount = fakeFinancialAccount(id: 'a1');

    final router = await pumpFinancialAccountsApp(
      tester,
      fakeRepo: fakeRepo,
      membership: financialAccountMembership(
        roles: const ['TREASURER'],
        permissions: const [
          'group.view',
          'financial_account.view',
          'financial_income.create',
          'financial_expense.create',
        ],
      ),
    );
    router.go(AppRoutes.financialAccountDetailPath('a1'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('financialAdjustmentAction')), findsNothing);
  });

  testWidgets(
    'O: an ADMIN (full permissions) sees the Financial Adjustment action '
    'and it opens the adjustment screen',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextAccount = fakeFinancialAccount(id: 'a1');

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.financialAccountDetailPath('a1'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('financialAdjustmentAction')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('financialAdjustmentConfirmAction')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'confirming with no amount and no reason never calls the repository; '
    'filling both posts via rpc_record_financial_adjustment with the '
    'reason attached',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextAccount = fakeFinancialAccount(id: 'a1', balance: 50000)
        ..nextAdjustmentResult = fakeFinancialAdjustmentResult(
          direction: 'DECREASE',
          financialAccountBalance: 45000,
        );

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.financialAccountAdjustmentPath('a1'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('financialAdjustmentConfirmAction')),
      );
      await tester.pumpAndSettle();
      expect(fakeRepo.recordFinancialAdjustmentCalls, isEmpty);

      await tester.enterText(
        find.byKey(const Key('financialAdjustmentAmountField')),
        '5000',
      );
      await tester.enterText(
        find.byKey(const Key('financialAdjustmentReasonField')),
        'Cash count shortage confirmed after physical count',
      );
      await tester.tap(
        find.byKey(const Key('financialAdjustmentConfirmAction')),
      );
      await tester.pumpAndSettle();

      expect(fakeRepo.recordFinancialAdjustmentCalls, hasLength(1));
      expect(
        fakeRepo.recordFinancialAdjustmentCalls.single.direction,
        'DECREASE',
      );
      expect(fakeRepo.recordFinancialAdjustmentCalls.single.amount, 5000);
      expect(
        fakeRepo.recordFinancialAdjustmentCalls.single.reason,
        'Cash count shortage confirmed after physical count',
      );
      expect(find.text('Marekebisho ya fedha yamerekodiwa.'), findsOneWidget);
    },
  );
}
