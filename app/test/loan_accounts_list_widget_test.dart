import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/features/loans/domain/loan_account.dart';

import 'fakes/fake_loan_repository.dart';
import 'fakes/loans_test_app.dart';

void main() {
  testWidgets('an empty loan accounts list shows the empty state', (
    tester,
  ) async {
    final fakeRepo = FakeLoanRepository()
      ..nextAccountsPage = LoanAccountPage.empty;

    final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
    router.go(AppRoutes.loanAccountsList);
    await tester.pumpAndSettle();

    expect(find.text('Hakuna Mikopo'), findsOneWidget);
  });

  testWidgets(
    'a populated loan accounts list shows each loan with its status',
    (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccountsPage = LoanAccountPage(
          items: [
            fakeLoanAccount(id: 'l1', borrowerDisplayName: 'Jane Member'),
            fakeLoanAccount(
              id: 'l2',
              borrowerDisplayName: 'John Member',
              status: 'CANCELLED',
            ),
          ],
          totalCount: 2,
          limit: 20,
          offset: 0,
        );

      final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.loanAccountsList);
      await tester.pumpAndSettle();

      expect(find.text('Jane Member'), findsOneWidget);
      expect(find.text('John Member'), findsOneWidget);
      expect(find.text('Rasimu'), findsOneWidget);
      expect(find.text('Imeghairiwa'), findsOneWidget);
    },
  );

  testWidgets('the New Loan action is hidden without loan.create', (
    tester,
  ) async {
    final fakeRepo = FakeLoanRepository();

    final router = await pumpLoansApp(
      tester,
      fakeRepo: fakeRepo,
      membership: loanMembership(
        roles: const ['CHAIRPERSON'],
        permissions: loanViewOnlyPermissions,
      ),
    );
    router.go(AppRoutes.loanAccountsList);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('newLoanAccountFab')), findsNothing);
    expect(find.text('Mkopo Mpya'), findsNothing);
  });

  testWidgets('tapping a loan row opens its detail screen', (tester) async {
    final fakeRepo = FakeLoanRepository()
      ..nextAccountsPage = LoanAccountPage(
        items: [fakeLoanAccount(id: 'l1', borrowerDisplayName: 'Jane Member')],
        totalCount: 1,
        limit: 20,
        offset: 0,
      )
      ..nextAccount = fakeLoanAccount(
        id: 'l1',
        borrowerDisplayName: 'Jane Member',
      );

    final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
    router.go(AppRoutes.loanAccountsList);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Jane Member'));
    await tester.pumpAndSettle();

    expect(fakeRepo.getLoanAccountCalls, hasLength(1));
    expect(fakeRepo.getLoanAccountCalls.single.loanAccountId, 'l1');
  });

  testWidgets('no layout overflow at a realistic small Android width (360)', (
    tester,
  ) async {
    final fakeRepo = FakeLoanRepository()
      ..nextAccountsPage = LoanAccountPage(
        items: [fakeLoanAccount(id: 'l1')],
        totalCount: 1,
        limit: 20,
        offset: 0,
      );

    final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    router.go(AppRoutes.loanAccountsList);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
