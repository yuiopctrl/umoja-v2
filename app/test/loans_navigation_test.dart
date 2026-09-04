import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';

import 'fakes/fake_loan_repository.dart';
import 'fakes/loans_test_app.dart';

void main() {
  testWidgets('the home shortcut opens Mikopo, from which both Aina za Mikopo '
      'and Akaunti za Mikopo are reachable (Prompt 09A)', (tester) async {
    final fakeRepo = FakeLoanRepository();

    final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
    router.go(AppRoutes.home);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('homeLoansShortcut')), findsOneWidget);

    await tester.tap(find.byKey(const Key('homeLoansShortcut')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('loanProductsEntry')), findsOneWidget);
    expect(find.byKey(const Key('loanAccountsEntry')), findsOneWidget);

    await tester.tap(find.byKey(const Key('loanProductsEntry')));
    await tester.pumpAndSettle();

    // Something only the products list screen itself renders — proves
    // this actually navigated there, not just changed the URL.
    expect(find.text('Aina za Mikopo'), findsWidgets);
  });

  testWidgets(
    'the home shortcut is hidden without loan.view/loan_product.view',
    (tester) async {
      final fakeRepo = FakeLoanRepository();

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        membership: loanMembership(
          roles: const ['MEMBER'],
          permissions: const ['group.view'],
        ),
      );
      router.go(AppRoutes.home);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('homeLoansShortcut')), findsNothing);
    },
  );

  testWidgets(
    'a CHAIRPERSON/SECRETARY-style view-only membership sees the Loans '
    'entries but no New Loan Product / New Loan actions',
    (tester) async {
      final fakeRepo = FakeLoanRepository();

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        membership: loanMembership(
          roles: const ['CHAIRPERSON'],
          permissions: loanViewOnlyPermissions,
        ),
      );
      router.go(AppRoutes.loansHome);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('loanProductsEntry')), findsOneWidget);
      expect(find.byKey(const Key('loanAccountsEntry')), findsOneWidget);

      await tester.tap(find.byKey(const Key('loanProductsEntry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('loanProductNewFab')), findsNothing);

      // Pop the pushed products screen before jumping to a different
      // declarative route — calling router.go() while a context.push
      // route still sits on the Navigator leaves that pushed route's
      // transition unable to ever fully settle, hanging pumpAndSettle
      // for its full default timeout instead of erroring.
      router.pop();
      await tester.pumpAndSettle();

      router.go(AppRoutes.loanAccountsList);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('newLoanAccountFab')), findsNothing);
    },
  );

  testWidgets(
    'a MEMBER (no loan permissions at all) reaching the routes directly '
    'sees no management actions',
    (tester) async {
      final fakeRepo = FakeLoanRepository();

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        membership: loanMembership(
          roles: const ['MEMBER'],
          permissions: const ['group.view'],
        ),
      );
      router.go(AppRoutes.loanProductsList);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('loanProductNewFab')), findsNothing);
    },
  );
}
