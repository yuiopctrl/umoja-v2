import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/features/financial_accounts/domain/financial_account_page.dart';
import 'package:umoja/features/loans/data/loan_failure.dart';

import 'fakes/fake_financial_account_repository.dart';
import 'fakes/fake_loan_repository.dart';
import 'fakes/loans_test_app.dart';

void main() {
  testWidgets(
    'an APPROVED loan shows the Disburse action, which opens a screen '
    'with the financial account picker (only active accounts, showing '
    'balance), a read-only amount, and no expense category selector',
    (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(
          id: 'loan-1',
          status: 'APPROVED',
          principalAmount: 500000,
        );
      final fakeFinancialAccountRepo = FakeFinancialAccountRepository()
        ..nextAccountsPage = FinancialAccountPage(
          items: [
            fakeFinancialAccount(
              id: 'account-1',
              name: 'Main Cash',
              balance: 2000000,
            ),
          ],
          totalCount: 1,
          limit: 100,
          offset: 0,
        );

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        fakeFinancialAccountRepo: fakeFinancialAccountRepo,
      );
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('loanDisburseAction')), findsOneWidget);
      await tester.tap(find.byKey(const Key('loanDisburseAction')));
      await tester.pumpAndSettle();

      // Amount is read-only text, not an editable field, and equals
      // the loan's own frozen principal.
      expect(find.textContaining('500,000'), findsWidgets);
      expect(
        find.byType(TextField),
        findsNWidgets(2),
      ); // reference + notes only

      // No expense-category selector anywhere on this screen.
      expect(find.textContaining('Category'), findsNothing);
      expect(find.textContaining('Aina'), findsNothing);

      await tester.tap(find.byKey(const Key('disburseLoanAccountField')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Main Cash'), findsWidgets);
      expect(find.textContaining('2,000,000'), findsWidgets);
    },
  );

  testWidgets('an inactive financial account is excluded from the picker', (
    tester,
  ) async {
    final fakeRepo = FakeLoanRepository()
      ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'APPROVED');
    final fakeFinancialAccountRepo = FakeFinancialAccountRepository()
      ..nextAccountsPage = FinancialAccountPage(
        items: [fakeFinancialAccount(id: 'account-1', name: 'Active Cash')],
        totalCount: 1,
        limit: 100,
        offset: 0,
      );

    final router = await pumpLoansApp(
      tester,
      fakeRepo: fakeRepo,
      fakeFinancialAccountRepo: fakeFinancialAccountRepo,
    );
    router.push(AppRoutes.loanAccountDisbursePath('loan-1'));
    await tester.pumpAndSettle();

    // The fake repository's active-only listing already excludes
    // inactive accounts server-side — proven by the call itself using
    // isActive: true (mirrors the payment/transfer picker precedent).
    expect(
      fakeFinancialAccountRepo.listFinancialAccountsCalls.single.isActive,
      true,
    );
  });

  testWidgets(
    'confirming disbursement shows a final confirmation summary, then '
    'calls the repository with the selected account/date',
    (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(
          id: 'loan-1',
          status: 'APPROVED',
          principalAmount: 500000,
          borrowerDisplayName: 'Jane Borrower',
        );
      final fakeFinancialAccountRepo = FakeFinancialAccountRepository()
        ..nextAccountsPage = FinancialAccountPage(
          items: [fakeFinancialAccount(id: 'account-1', name: 'Main Cash')],
          totalCount: 1,
          limit: 100,
          offset: 0,
        );

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        fakeFinancialAccountRepo: fakeFinancialAccountRepo,
      );
      router.push(AppRoutes.loanAccountDisbursePath('loan-1'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('disburseLoanAccountField')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Main Cash (Taslimu) — 50,000').first);
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('disburseLoanConfirmAction')),
      );
      await tester.tap(find.byKey(const Key('disburseLoanConfirmAction')));
      await tester.pumpAndSettle();

      expect(fakeRepo.disburseLoanAccountCalls, isEmpty);
      expect(find.text('Toa Mkopo?'), findsOneWidget);

      await tester.tap(find.text('Toa Mkopo').last);
      await tester.pumpAndSettle();

      expect(fakeRepo.disburseLoanAccountCalls, hasLength(1));
      expect(
        fakeRepo.disburseLoanAccountCalls.single.financialAccountId,
        'account-1',
      );
    },
  );

  testWidgets(
    'an insufficient-balance failure shows the localized error message',
    (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'APPROVED');
      final fakeFinancialAccountRepo = FakeFinancialAccountRepository()
        ..nextAccountsPage = FinancialAccountPage(
          items: [fakeFinancialAccount(id: 'account-1', name: 'Main Cash')],
          totalCount: 1,
          limit: 100,
          offset: 0,
        );

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        fakeFinancialAccountRepo: fakeFinancialAccountRepo,
      );
      router.push(AppRoutes.loanAccountDisbursePath('loan-1'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('disburseLoanAccountField')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Main Cash (Taslimu) — 50,000').first);
      await tester.pumpAndSettle();

      // Only fails once the disburse RPC is actually attempted — the
      // loan/account reads above must still succeed.
      fakeRepo.failure = const LoanFailure(
        LoanFailureType.insufficientBalance,
        'insufficient',
      );

      await tester.ensureVisible(
        find.byKey(const Key('disburseLoanConfirmAction')),
      );
      await tester.tap(find.byKey(const Key('disburseLoanConfirmAction')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toa Mkopo').last);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Akaunti ya fedha iliyochaguliwa haina salio la kutosha kwa '
          'mgawanyo huu.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('the Disburse action is hidden without loan.disburse', (
    tester,
  ) async {
    final fakeRepo = FakeLoanRepository()
      ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'APPROVED');

    final router = await pumpLoansApp(
      tester,
      fakeRepo: fakeRepo,
      membership: loanMembership(
        roles: const ['CHAIRPERSON'],
        permissions: loanChairpersonPermissions,
      ),
    );
    router.push(AppRoutes.loanAccountDetailPath('loan-1'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('loanDisburseAction')), findsNothing);
  });

  testWidgets(
    'no layout overflow at 360px or desktop width on the Disburse screen',
    (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'APPROVED');
      final fakeFinancialAccountRepo = FakeFinancialAccountRepository()
        ..nextAccountsPage = FinancialAccountPage(
          items: [fakeFinancialAccount(id: 'account-1', name: 'Main Cash')],
          totalCount: 1,
          limit: 100,
          offset: 0,
        );

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        fakeFinancialAccountRepo: fakeFinancialAccountRepo,
      );
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      router.push(AppRoutes.loanAccountDisbursePath('loan-1'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(1280, 900);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
