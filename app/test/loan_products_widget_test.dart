import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/features/loans/data/loan_failure.dart';
import 'package:umoja/features/loans/domain/loan_product.dart';

import 'fakes/fake_loan_repository.dart';
import 'fakes/loans_test_app.dart';

void main() {
  testWidgets('an empty products list shows the empty state', (tester) async {
    final fakeRepo = FakeLoanRepository()
      ..nextProductsPage = LoanProductPage.empty;

    final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
    router.go(AppRoutes.loanProductsList);
    await tester.pumpAndSettle();

    expect(find.text('Hakuna Aina za Mikopo'), findsOneWidget);
  });

  testWidgets(
    'a populated products list shows each product with its active state',
    (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextProductsPage = LoanProductPage(
          items: [
            fakeLoanProduct(id: 'p1', name: 'Standard Loan'),
            fakeLoanProduct(id: 'p2', name: 'Emergency Loan', isActive: false),
          ],
          totalCount: 2,
          limit: 20,
          offset: 0,
        );

      final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.loanProductsList);
      await tester.pumpAndSettle();

      expect(find.text('Standard Loan'), findsOneWidget);
      expect(find.text('Emergency Loan'), findsOneWidget);
      // Both texts also appear once as the active/inactive filter's
      // segment labels, so each is expected twice, not once.
      expect(find.text('Inatumika'), findsNWidgets(2));
      expect(find.text('Haitumiki'), findsNWidgets(2));
    },
  );

  testWidgets(
    'creating a loan product sends every field to rpc_create_loan_product',
    (tester) async {
      final fakeRepo = FakeLoanRepository();

      final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
      router.push(AppRoutes.loanProductNew);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('loanProductCodeField')),
        'STD',
      );
      await tester.enterText(
        find.byKey(const Key('loanProductNameField')),
        'Standard Loan',
      );
      await tester.enterText(
        find.byKey(const Key('loanProductMinimumPrincipalField')),
        '10000',
      );
      await tester.enterText(
        find.byKey(const Key('loanProductMinimumTermField')),
        '1',
      );
      await tester.enterText(
        find.byKey(const Key('loanProductMaximumTermField')),
        '12',
      );
      await tester.enterText(
        find.byKey(const Key('loanProductInterestRateField')),
        '12',
      );

      await tester.ensureVisible(
        find.byKey(const Key('loanProductSaveAction')),
      );
      await tester.tap(find.byKey(const Key('loanProductSaveAction')));
      await tester.pumpAndSettle();

      expect(fakeRepo.createLoanProductCalls, hasLength(1));
      expect(fakeRepo.createLoanProductCalls.single.code, 'STD');
      expect(fakeRepo.createLoanProductCalls.single.name, 'Standard Loan');
    },
  );

  testWidgets('a duplicate product code shows the localized error message', (
    tester,
  ) async {
    final fakeRepo = FakeLoanRepository();

    final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
    router.push(AppRoutes.loanProductNew);
    await tester.pumpAndSettle();

    fakeRepo.failure = const LoanFailure(
      LoanFailureType.duplicateCode,
      'duplicate',
    );

    await tester.enterText(
      find.byKey(const Key('loanProductCodeField')),
      'STD',
    );
    await tester.enterText(
      find.byKey(const Key('loanProductNameField')),
      'Standard Loan',
    );
    await tester.ensureVisible(find.byKey(const Key('loanProductSaveAction')));
    await tester.tap(find.byKey(const Key('loanProductSaveAction')));
    await tester.pumpAndSettle();

    expect(
      find.text('Msimbo huo tayari unatumika katika kikundi hiki.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'editing a product only sends name/description/isActive — code and '
    'term/rate-basis fields are not shown once a product exists (snapshot '
    'rule: editing never rewrites terms already frozen onto loan accounts)',
    (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextProduct = fakeLoanProduct(id: 'p1', name: 'Standard Loan');

      final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
      router.push(AppRoutes.loanProductEditPath('p1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('loanProductCodeField')), findsNothing);
      expect(
        find.byKey(const Key('loanProductMinimumTermField')),
        findsNothing,
      );

      await tester.ensureVisible(
        find.byKey(const Key('loanProductSaveAction')),
      );
      await tester.tap(find.byKey(const Key('loanProductSaveAction')));
      await tester.pumpAndSettle();

      expect(fakeRepo.updateLoanProductCalls, hasLength(1));
      expect(fakeRepo.updateLoanProductCalls.single.productId, 'p1');
    },
  );

  testWidgets('no layout overflow at a realistic small Android width (360)', (
    tester,
  ) async {
    final fakeRepo = FakeLoanRepository()
      ..nextProductsPage = LoanProductPage(
        items: [fakeLoanProduct(id: 'p1', name: 'Standard Loan')],
        totalCount: 1,
        limit: 20,
        offset: 0,
      );

    final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    router.go(AppRoutes.loanProductsList);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Standard Loan'), findsOneWidget);
  });
}
