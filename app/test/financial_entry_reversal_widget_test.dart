import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/features/financial_accounts/domain/financial_account_entry_page.dart';

import 'fakes/fake_financial_account_repository.dart';
import 'fakes/financial_accounts_test_app.dart';

// Prompt 08B section 13-14/38 (J-K): reversing a posted manual
// income/expense entry never edits/deletes the original — it posts one
// compensating cashbook entry and requires an explicit reason.
void main() {
  testWidgets('K: entering a reason and confirming reverses via '
      'rpc_reverse_financial_manual_entry and navigates back to the account', (
    tester,
  ) async {
    final fakeRepo = FakeFinancialAccountRepository()
      ..nextManualEntryDetail = fakeFinancialManualEntryDetail(
        entryId: 'me1',
        financialAccountId: 'a1',
        categoryName: 'Michango',
        status: 'POSTED',
      );

    final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
    router.go(AppRoutes.financialEntryReversePath('me1'));
    await tester.pumpAndSettle();

    // Never offered without an explicit reason.
    await tester.tap(find.byKey(const Key('entryReversalConfirmAction')));
    await tester.pumpAndSettle();
    expect(fakeRepo.reverseFinancialManualEntryCalls, isEmpty);

    await tester.enterText(
      find.byKey(const Key('entryReversalReasonField')),
      'Recorded against the wrong category',
    );
    await tester.tap(find.byKey(const Key('entryReversalConfirmAction')));
    await tester.pumpAndSettle();

    expect(fakeRepo.reverseFinancialManualEntryCalls, hasLength(1));
    expect(fakeRepo.reverseFinancialManualEntryCalls.single.entryId, 'me1');
    expect(
      fakeRepo.reverseFinancialManualEntryCalls.single.reversalReason,
      'Recorded against the wrong category',
    );
    expect(find.byKey(const Key('entryReversalConfirmAction')), findsNothing);
  });

  testWidgets(
    'J: an already-reversed entry shows the already-reversed message and '
    'never offers a reversal action a second time',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextManualEntryDetail = fakeFinancialManualEntryDetail(
          entryId: 'me1',
          financialAccountId: 'a1',
          categoryName: 'Michango',
          status: 'REVERSED',
        );

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.financialEntryReversePath('me1'));
      await tester.pumpAndSettle();

      expect(
        find.text('Kiingilio hiki tayari kimebatilishwa.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('entryReversalConfirmAction')), findsNothing);
    },
  );

  testWidgets('J: the cashbook never offers the reversal action for an already-'
      'reversed row', (tester) async {
    final fakeRepo = FakeFinancialAccountRepository()
      ..nextAccount = fakeFinancialAccount(id: 'a1')
      ..nextEntriesPage = FinancialAccountEntryPage(
        items: [
          fakeFinancialAccountEntry(
            entryId: 'e2',
            entryType: 'OUTFLOW',
            sourceType: 'EXPENSE',
            sourceId: 'me2',
            amount: 10000,
            manualEntryCategoryId: 'c2',
            manualEntryCategoryName: 'Usafiri',
            manualEntryStatus: 'REVERSED',
          ),
        ],
        totalCount: 1,
        limit: 10,
        offset: 0,
      );

    final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
    router.go(AppRoutes.financialAccountCashbookPath('a1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Matumizi — Usafiri'));
    await tester.pumpAndSettle();

    // No navigation happened — still on the cashbook, not the
    // reversal screen.
    expect(fakeRepo.getFinancialManualEntryCalls, isEmpty);
    expect(find.text('Imerekebishwa'), findsOneWidget);
  });
}
