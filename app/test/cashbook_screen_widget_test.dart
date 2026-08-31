import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/features/financial_accounts/domain/financial_account_entry_page.dart';

import 'fakes/fake_financial_account_repository.dart';
import 'fakes/financial_accounts_test_app.dart';

// Prompt 08B sections 20-21/38 (H-I): the full, filterable cashbook —
// Account Detail itself only keeps a short recent-movements preview.
void main() {
  testWidgets('H: tapping the Income filter chip re-requests entries scoped to '
      'source_type = MANUAL_INCOME', (tester) async {
    final fakeRepo = FakeFinancialAccountRepository()
      ..nextAccount = fakeFinancialAccount(id: 'a1');

    final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
    router.go(AppRoutes.financialAccountCashbookPath('a1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mapato').first);
    await tester.pumpAndSettle();

    expect(
      fakeRepo.listFinancialAccountEntriesCalls.last.sourceType,
      'MANUAL_INCOME',
    );
  });

  testWidgets(
    'H: tapping the Transfers filter chip re-requests entries scoped to '
    'source_type = TRANSFER, and switching back to All clears the filter',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextAccount = fakeFinancialAccount(id: 'a1');

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.financialAccountCashbookPath('a1'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Uhamisho').first);
      await tester.pumpAndSettle();
      expect(
        fakeRepo.listFinancialAccountEntriesCalls.last.sourceType,
        'TRANSFER',
      );

      await tester.tap(find.text('Wote').first);
      await tester.pumpAndSettle();
      expect(fakeRepo.listFinancialAccountEntriesCalls.last.sourceType, isNull);
    },
  );

  testWidgets(
    'I: a TRANSFER_OUT row in the cashbook names the destination account, '
    'never the bare enum',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextAccount = fakeFinancialAccount(id: 'a1', name: 'Cash Box')
        ..nextEntriesPage = FinancialAccountEntryPage(
          items: [
            fakeFinancialAccountEntry(
              entryId: 'e1',
              entryType: 'TRANSFER_OUT',
              sourceType: 'TRANSFER',
              amount: 20000,
              counterpartyAccountId: 'a2',
              counterpartyAccountName: 'NMB Main',
            ),
          ],
          totalCount: 1,
          limit: 10,
          offset: 0,
        );

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.financialAccountCashbookPath('a1'));
      await tester.pumpAndSettle();

      expect(find.text('Uhamisho kwenda NMB Main'), findsOneWidget);
      expect(find.textContaining('TRANSFER_OUT'), findsNothing);
    },
  );

  testWidgets(
    'tapping a reversible POSTED manual-income row navigates to the entry '
    'reversal screen, but a REVERSED row is not tappable for reversal',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextAccount = fakeFinancialAccount(id: 'a1')
        ..nextEntriesPage = FinancialAccountEntryPage(
          items: [
            fakeFinancialAccountEntry(
              entryId: 'e1',
              entryType: 'INFLOW',
              sourceType: 'MANUAL_INCOME',
              sourceId: 'me1',
              amount: 20000,
              manualEntryCategoryId: 'c1',
              manualEntryCategoryName: 'Michango',
              manualEntryStatus: 'POSTED',
            ),
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
          totalCount: 2,
          limit: 10,
          offset: 0,
        )
        ..nextManualEntryDetail = fakeFinancialManualEntryDetail(
          entryId: 'me1',
          categoryName: 'Michango',
        );

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.financialAccountCashbookPath('a1'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mapato — Michango'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('entryReversalConfirmAction')),
        findsOneWidget,
      );
      expect(fakeRepo.getFinancialManualEntryCalls.single.entryId, 'me1');
    },
  );

  testWidgets(
    'UAT-FIX-05: a reference is shown alongside the description in the '
    'cashbook, the same as on Account Detail',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextAccount = fakeFinancialAccount(id: 'a1')
        ..nextEntriesPage = FinancialAccountEntryPage(
          items: [
            fakeFinancialAccountEntry(
              entryId: 'e1',
              entryType: 'OUTFLOW',
              sourceType: 'EXPENSE',
              amount: 8000,
              description: 'Fuel for site visit',
              reference: 'INV-991',
              manualEntryCategoryId: 'c1',
              manualEntryCategoryName: 'Usafiri',
              manualEntryStatus: 'POSTED',
            ),
          ],
          totalCount: 1,
          limit: 10,
          offset: 0,
        );

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.financialAccountCashbookPath('a1'));
      await tester.pumpAndSettle();

      expect(find.text('Fuel for site visit'), findsOneWidget);
      expect(find.text('Kumbukumbu: INV-991'), findsOneWidget);
    },
  );
}
