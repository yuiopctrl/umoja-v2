import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/features/financial_accounts/data/financial_account_failure.dart';
import 'package:umoja/features/financial_accounts/domain/financial_account_page.dart';

import 'fakes/financial_accounts_test_app.dart';
import 'fakes/fake_financial_account_repository.dart';

void main() {
  testWidgets('submitting a transfer sends the exact from/to/amount to '
      'rpc_record_financial_account_transfer', (tester) async {
    final fakeRepo = FakeFinancialAccountRepository()
      ..nextAccountsPage = FinancialAccountPage(
        items: [
          fakeFinancialAccount(id: 'a1', name: 'Main Cash'),
          fakeFinancialAccount(id: 'a2', name: 'Bank X', accountType: 'BANK'),
        ],
        totalCount: 2,
        limit: 100,
        offset: 0,
      );

    final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
    router.push(AppRoutes.financialAccountTransfer);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Main Cash (Taslimu)').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bank X (Benki)').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('financialAccountTransferAmountField')),
      '20000',
    );
    await tester.tap(find.text('Hamisha'));
    await tester.pumpAndSettle();

    expect(fakeRepo.recordFinancialAccountTransferCalls, hasLength(1));
    final call = fakeRepo.recordFinancialAccountTransferCalls.single;
    expect(call.fromAccountId, 'a1');
    expect(call.toAccountId, 'a2');
    expect(call.amount, 20000);
  });

  testWidgets(
    // UAT-DIAG-02: the screen never passed `effectiveAt` at all, so
    // the repository sent an explicit JSON `null` for
    // `p_effective_at` — which does NOT fall back to the RPC's own
    // `default current_date` (only a truly *omitted* argument does),
    // so the backend's "Effective date is required" validation fired
    // on every single transfer, surfaced to the user as a generic
    // "Something went wrong" error (same root-cause class as the
    // 06B penalty-assessment-date bug).
    'submitting a transfer always sends an explicit, non-null '
    'effective date — never relies on the RPC default',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextAccountsPage = FinancialAccountPage(
          items: [
            fakeFinancialAccount(id: 'a1', name: 'Main Cash'),
            fakeFinancialAccount(id: 'a2', name: 'Bank X', accountType: 'BANK'),
          ],
          totalCount: 2,
          limit: 100,
          offset: 0,
        );

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.push(AppRoutes.financialAccountTransfer);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Main Cash (Taslimu)').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bank X (Benki)').last);
      await tester.pumpAndSettle();

      // A realistic TZS amount, entered exactly as a user would type
      // it — no thousands separator, no currency label — to prove
      // Flutter never submits a display-formatted string.
      await tester.enterText(
        find.byKey(const Key('financialAccountTransferAmountField')),
        '100000',
      );
      await tester.tap(find.text('Hamisha'));
      await tester.pumpAndSettle();

      final call = fakeRepo.recordFinancialAccountTransferCalls.single;
      expect(call.amount, 100000);
      expect(call.effectiveAt, isNotNull);
      final now = DateTime.now();
      expect(call.effectiveAt!.year, now.year);
      expect(call.effectiveAt!.month, now.month);
      expect(call.effectiveAt!.day, now.day);
    },
  );

  testWidgets('insufficient balance shows the localized error message', (
    tester,
  ) async {
    final fakeRepo = FakeFinancialAccountRepository()
      ..nextAccountsPage = FinancialAccountPage(
        items: [
          fakeFinancialAccount(id: 'a1', name: 'Main Cash'),
          fakeFinancialAccount(id: 'a2', name: 'Bank X', accountType: 'BANK'),
        ],
        totalCount: 2,
        limit: 100,
        offset: 0,
      );

    final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
    router.push(AppRoutes.financialAccountTransfer);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Main Cash (Taslimu)').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bank X (Benki)').last);
    await tester.pumpAndSettle();

    // Set only after the account picker has already loaded — the
    // fake applies `failure` to every call, including the initial
    // active-accounts fetch.
    fakeRepo.failure = const FinancialAccountFailure(
      FinancialAccountFailureType.insufficientBalance,
      'insufficient',
    );

    await tester.enterText(
      find.byKey(const Key('financialAccountTransferAmountField')),
      '999999',
    );
    await tester.tap(find.text('Hamisha'));
    await tester.pumpAndSettle();

    expect(
      find.text('Akaunti ya kutoa haina salio la kutosha kwa uhamisho huu.'),
      findsOneWidget,
    );
  });

  testWidgets(
    // Defense-in-depth mapping added alongside the UAT-DIAG-02 fix: if
    // any future caller of `recordFinancialAccountTransfer` ever omits
    // `effectiveAt` again, the resulting backend error must surface as
    // a specific, localized message — never the generic
    // "Something went wrong" bucket that silently swallowed it before.
    '"Effective date is required" surfaces the specific localized '
    'error, never the generic unexpected message',
    (tester) async {
      final fakeRepo = FakeFinancialAccountRepository()
        ..nextAccountsPage = FinancialAccountPage(
          items: [
            fakeFinancialAccount(id: 'a1', name: 'Main Cash'),
            fakeFinancialAccount(id: 'a2', name: 'Bank X', accountType: 'BANK'),
          ],
          totalCount: 2,
          limit: 100,
          offset: 0,
        );

      final router = await pumpFinancialAccountsApp(tester, fakeRepo: fakeRepo);
      router.push(AppRoutes.financialAccountTransfer);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Main Cash (Taslimu)').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bank X (Benki)').last);
      await tester.pumpAndSettle();

      fakeRepo.failure = const FinancialAccountFailure(
        FinancialAccountFailureType.effectiveDateRequired,
        'Effective date is required',
      );

      await tester.enterText(
        find.byKey(const Key('financialAccountTransferAmountField')),
        '20000',
      );
      await tester.tap(find.text('Hamisha'));
      await tester.pumpAndSettle();

      expect(find.text('Tarehe ya uhamisho inahitajika.'), findsOneWidget);
      expect(find.text('Hitilafu imetokea. Jaribu tena.'), findsNothing);
    },
  );
}
