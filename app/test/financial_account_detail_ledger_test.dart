import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/financial_accounts/domain/financial_account_entry_page.dart';

import 'fakes/fake_financial_account_repository.dart';
import 'fakes/financial_accounts_test_app.dart';

// UAT-FIX-03: an account's ledger showed only generic "Transfer Out"/
// "Transfer In" text, giving no indication of WHERE the money went or
// came from. These tests prove the detail screen renders the resolved
// counterparty account name — sourced from the backend read model,
// never fabricated client-side — and never shows the raw entry-type
// enum.
void main() {
  testWidgets('a TRANSFER_OUT entry renders "Uhamisho kwenda {destination}" in '
      'Swahili, naming the destination account', (tester) async {
    final fakeRepo = FakeFinancialAccountRepository()
      ..nextAccount = fakeFinancialAccount(id: 'a1', name: 'Cash Box')
      ..nextEntriesPage = FinancialAccountEntryPage(
        items: [
          fakeFinancialAccountEntry(
            entryId: 'e1',
            entryType: 'TRANSFER_OUT',
            amount: 20000,
            transferReference: 't1',
            counterpartyAccountId: 'a2',
            counterpartyAccountName: 'NMB Main',
          ),
        ],
        totalCount: 1,
        limit: 10,
        offset: 0,
      );

    final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
    router.go(AppRoutes.financialAccountDetailPath('a1'));
    await tester.pumpAndSettle();

    expect(find.text('Uhamisho kwenda NMB Main'), findsOneWidget);
    expect(find.textContaining('TRANSFER_OUT'), findsNothing);
    expect(find.text('Uhamisho Ulioondoka'), findsNothing);
  });

  testWidgets('a TRANSFER_OUT entry renders "Transfer to {destination}" in '
      'English', (tester) async {
    final fakeRepo = FakeFinancialAccountRepository()
      ..nextAccount = fakeFinancialAccount(id: 'a1', name: 'Cash Box')
      ..nextEntriesPage = FinancialAccountEntryPage(
        items: [
          fakeFinancialAccountEntry(
            entryId: 'e1',
            entryType: 'TRANSFER_OUT',
            amount: 20000,
            transferReference: 't1',
            counterpartyAccountId: 'a2',
            counterpartyAccountName: 'NMB Main',
          ),
        ],
        totalCount: 1,
        limit: 10,
        offset: 0,
      );

    final router = await pumpFinancialAccountsApp(
      tester,
      fakeRepo: fakeRepo,
      language: AppLanguage.english,
    );
    router.go(AppRoutes.financialAccountDetailPath('a1'));
    await tester.pumpAndSettle();

    expect(find.text('Transfer to NMB Main'), findsOneWidget);
  });

  testWidgets('a TRANSFER_IN entry renders "Uhamisho kutoka {source}" in '
      'Swahili, naming the source account, and "Transfer from {source}" '
      'in English', (tester) async {
    final fakeRepoSw = FakeFinancialAccountRepository()
      ..nextAccount = fakeFinancialAccount(id: 'a2', name: 'NMB Main')
      ..nextEntriesPage = FinancialAccountEntryPage(
        items: [
          fakeFinancialAccountEntry(
            entryId: 'e2',
            entryType: 'TRANSFER_IN',
            amount: 20000,
            transferReference: 't1',
            counterpartyAccountId: 'a1',
            counterpartyAccountName: 'Cash Box',
          ),
        ],
        totalCount: 1,
        limit: 10,
        offset: 0,
      );

    final routerSw = await pumpFinancialAccountsApp(
      tester,
      fakeRepo: fakeRepoSw,
    );
    routerSw.go(AppRoutes.financialAccountDetailPath('a2'));
    await tester.pumpAndSettle();

    expect(find.text('Uhamisho kutoka Cash Box'), findsOneWidget);
    expect(find.textContaining('TRANSFER_IN'), findsNothing);
  });

  testWidgets(
    'a non-transfer entry (opening balance INFLOW) never fabricates a '
    'counterparty and shows the plain entry-type label',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextAccount = fakeFinancialAccount(id: 'a1', name: 'Cash Box')
        ..nextEntriesPage = FinancialAccountEntryPage(
          items: [
            fakeFinancialAccountEntry(
              entryId: 'e0',
              entryType: 'INFLOW',
              amount: 50000,
              sourceType: 'OPENING_BALANCE',
              counterpartyAccountId: null,
              counterpartyAccountName: null,
            ),
          ],
          totalCount: 1,
          limit: 10,
          offset: 0,
        );

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.financialAccountDetailPath('a1'));
      await tester.pumpAndSettle();

      expect(find.text('Kuingia'), findsOneWidget);
      expect(find.textContaining('kwenda'), findsNothing);
      expect(find.textContaining('kutoka'), findsNothing);
    },
  );

  testWidgets(
    'a description is shown alongside the transfer direction/context, '
    'never replacing it',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextAccount = fakeFinancialAccount(id: 'a1', name: 'Cash Box')
        ..nextEntriesPage = FinancialAccountEntryPage(
          items: [
            fakeFinancialAccountEntry(
              entryId: 'e1',
              entryType: 'TRANSFER_OUT',
              amount: 20000,
              description: 'Weekly bank deposit',
              transferReference: 't1',
              counterpartyAccountId: 'a2',
              counterpartyAccountName: 'NMB Main',
            ),
          ],
          totalCount: 1,
          limit: 10,
          offset: 0,
        );

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.financialAccountDetailPath('a1'));
      await tester.pumpAndSettle();

      expect(find.text('Uhamisho kwenda NMB Main'), findsOneWidget);
      expect(find.text('Weekly bank deposit'), findsOneWidget);
    },
  );
}
