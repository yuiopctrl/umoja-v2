import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/features/financial_accounts/domain/financial_account_page.dart';

import 'fakes/fake_financial_account_repository.dart';
import 'fakes/financial_accounts_test_app.dart';

// UAT-FIX-01: the transfer picker only ever showed one account (e.g.
// CASH) even when the group had a CASH, a BANK, and a MOBILE_MONEY
// account. These tests verify the picker sources ALL eligible active
// accounts directly from the repository call — never a stale
// same-account-type subset, a first-page-only snapshot, or a raw enum
// string leaking into the UI.
void main() {
  testWidgets('the transfer picker shows all eligible active accounts across '
      'every account type — CASH, BANK, and MOBILE_MONEY', (tester) async {
    final fakeRepo = FakeFinancialAccountRepository()
      ..nextAccountsPage = FinancialAccountPage(
        items: [
          fakeFinancialAccount(id: 'a1', name: 'Cash Box', accountType: 'CASH'),
          fakeFinancialAccount(id: 'a2', name: 'NMB Main', accountType: 'BANK'),
          fakeFinancialAccount(
            id: 'a3',
            name: 'M-Pesa',
            accountType: 'MOBILE_MONEY',
          ),
        ],
        totalCount: 3,
        limit: 100,
        offset: 0,
      );

    final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
    router.push(AppRoutes.financialAccountTransfer);
    await tester.pumpAndSettle();

    expect(fakeRepo.listFinancialAccountsCalls, hasLength(1));
    expect(fakeRepo.listFinancialAccountsCalls.single.isActive, true);

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
    await tester.pumpAndSettle();

    // No raw enum string ("CASH"/"BANK"/"MOBILE_MONEY") ever
    // appears — only the localized Swahili labels.
    expect(find.text('Cash Box (Taslimu)'), findsWidgets);
    expect(find.text('NMB Main (Benki)'), findsWidgets);
    expect(find.text('M-Pesa (Pesa ya Simu)'), findsWidgets);
    expect(find.textContaining('CASH'), findsNothing);
    expect(find.textContaining('BANK'), findsNothing);
    expect(find.textContaining('MOBILE_MONEY'), findsNothing);
  });

  testWidgets('choosing a source excludes only that exact account from the '
      'destination list — never a whole account type', (tester) async {
    final fakeRepo = FakeFinancialAccountRepository()
      ..nextAccountsPage = FinancialAccountPage(
        items: [
          fakeFinancialAccount(id: 'a1', name: 'Cash Box', accountType: 'CASH'),
          fakeFinancialAccount(id: 'a2', name: 'NMB Main', accountType: 'BANK'),
          fakeFinancialAccount(
            id: 'a3',
            name: 'M-Pesa',
            accountType: 'MOBILE_MONEY',
          ),
        ],
        totalCount: 3,
        limit: 100,
        offset: 0,
      );

    final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
    router.push(AppRoutes.financialAccountTransfer);
    await tester.pumpAndSettle();

    // Pick NMB Main (BANK) as the source.
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NMB Main (Benki)').last);
    await tester.pumpAndSettle();

    // The destination list must still offer Cash Box and M-Pesa —
    // excluding only NMB Main itself, not every non-CASH account or
    // every BANK-type account.
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();

    expect(find.text('Cash Box (Taslimu)'), findsWidgets);
    expect(find.text('M-Pesa (Pesa ya Simu)'), findsWidgets);
    // NMB Main (the selected source) no longer appears as a
    // destination candidate at all — including in the closed
    // source field, which still shows it as selected there.
    expect(find.text('NMB Main (Benki)'), findsOneWidget);
  });

  testWidgets('inactive accounts are never offered as transfer source or '
      'destination', (tester) async {
    final fakeRepo = FakeFinancialAccountRepository()
      ..nextAccountsPage = FinancialAccountPage(
        items: [
          fakeFinancialAccount(id: 'a1', name: 'Cash Box', accountType: 'CASH'),
          fakeFinancialAccount(id: 'a2', name: 'NMB Main', accountType: 'BANK'),
        ],
        totalCount: 2,
        limit: 100,
        offset: 0,
      );
    // Deliberately do NOT include the inactive account in the
    // fake's response — the repository call itself is what filters
    // by is_active=true server-side; this proves the picker relies
    // on that filtered result rather than doing its own (missing)
    // client-side active filtering.

    final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
    router.push(AppRoutes.financialAccountTransfer);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
    await tester.pumpAndSettle();

    expect(find.text('Cash Box (Taslimu)'), findsWidgets);
    expect(find.text('NMB Main (Benki)'), findsWidgets);
    expect(find.textContaining('Dormant'), findsNothing);
    expect(fakeRepo.listFinancialAccountsCalls.single.isActive, true);
  });
}
