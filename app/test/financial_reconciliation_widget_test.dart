import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/features/financial_accounts/domain/financial_reconciliation.dart';

import 'fakes/fake_financial_account_repository.dart';
import 'fakes/financial_accounts_test_app.dart';

// Prompt 08B sections 15-19/34/38 (L-N): reconciliation compares the
// authoritative derived balance against a statement/count — it never
// posts a cashbook entry of its own, and a non-zero difference is
// recorded as-is, never auto-corrected.
void main() {
  testWidgets(
    'L: entering a stated balance equal to the system balance shows the '
    'Balanced message, never a difference figure',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextAccount = fakeFinancialAccount(id: 'a1', balance: 50000);

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.financialAccountReconcilePath('a1'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('reconciliationStatedBalanceField')),
        '50000',
      );
      await tester.pumpAndSettle();

      expect(find.text('Imelingana'), findsOneWidget);
      expect(find.textContaining('Tofauti:'), findsNothing);
    },
  );

  testWidgets(
    'M: entering a stated balance different from the system balance shows '
    'the Difference figure, not the Balanced message',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextAccount = fakeFinancialAccount(id: 'a1', balance: 50000);

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.financialAccountReconcilePath('a1'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('reconciliationStatedBalanceField')),
        '48000',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Tofauti:'), findsOneWidget);
      expect(find.text('Imelingana'), findsNothing);
    },
  );

  testWidgets(
    'N: saving a discrepant reconciliation never itself posts a cashbook '
    'entry or otherwise corrects the balance — it is recorded as pure '
    'evidence, and no adjustment action appears alongside it',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextAccount = fakeFinancialAccount(id: 'a1', balance: 50000)
        ..nextReconciliation = fakeFinancialReconciliation(
          systemBalance: 50000,
          statedBalance: 48000,
        );

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.financialAccountReconcilePath('a1'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('reconciliationStatedBalanceField')),
        '48000',
      );
      await tester.tap(find.byKey(const Key('reconciliationSaveAction')));
      await tester.pumpAndSettle();

      expect(fakeRepo.createFinancialReconciliationCalls, hasLength(1));
      expect(
        fakeRepo.createFinancialReconciliationCalls.single.statedBalance,
        48000,
      );
      // No adjustment/transfer/manual-entry call was ever made as a
      // side effect of saving the reconciliation.
      expect(fakeRepo.recordFinancialAdjustmentCalls, isEmpty);
      expect(fakeRepo.recordManualIncomeCalls, isEmpty);
      expect(fakeRepo.recordExpenseCalls, isEmpty);
      expect(
        find.byKey(const Key('financialAdjustmentConfirmAction')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'the reconciliation history shows a discrepant record\'s difference '
    'and lets an authorized caller cancel it — cancelling never re-'
    'computes or corrects the balance either',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextAccount = fakeFinancialAccount(id: 'a1', balance: 50000)
        ..nextReconciliationsPage = FinancialReconciliationPage(
          items: [
            fakeFinancialReconciliation(
              id: 'r1',
              systemBalance: 50000,
              statedBalance: 48000,
              status: 'RECONCILED',
            ),
          ],
          totalCount: 1,
          limit: 10,
          offset: 0,
        );

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.financialAccountReconcilePath('a1'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Tofauti:'), findsOneWidget);

      await tester.tap(find.text('Ghairi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Futa Ulinganishaji').last);
      await tester.pumpAndSettle();

      expect(fakeRepo.cancelFinancialReconciliationCalls, hasLength(1));
      expect(
        fakeRepo.cancelFinancialReconciliationCalls.single.reconciliationId,
        'r1',
      );
      expect(fakeRepo.recordFinancialAdjustmentCalls, isEmpty);
    },
  );
}
