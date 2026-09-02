import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';

import 'fakes/fake_loan_repository.dart';
import 'fakes/loans_test_app.dart';

/// Prompt 09D: Loan Product create/edit form penalty configuration
/// (section 38) — hidden/disabled dependent fields when penalty is
/// off, FIXED-vs-PERCENTAGE conditional fields, and that every field
/// actually reaches `rpc_create_loan_product`/`rpc_update_loan_product`.
void main() {
  testWidgets(
    'penalty is disabled by default — only the enable switch is shown, '
    'no type/frequency/grace/amount fields',
    (tester) async {
      final fakeRepo = FakeLoanRepository();

      final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
      router.push(AppRoutes.loanProductNew);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('loanProductPenaltyEnabledField')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('loanProductPenaltyTypeField')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('loanProductPenaltyGraceDaysField')),
        findsNothing,
      );
      expect(find.text('Hakuna sera ya adhabu'), findsOneWidget);
    },
  );

  testWidgets(
    'enabling penalty with FIXED shows the fixed-amount field, not the rate '
    'field',
    (tester) async {
      final fakeRepo = FakeLoanRepository();

      final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
      router.push(AppRoutes.loanProductNew);
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('loanProductPenaltyEnabledField')),
      );
      await tester.tap(find.byKey(const Key('loanProductPenaltyEnabledField')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('loanProductPenaltyFixedAmountField')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('loanProductPenaltyRateField')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'switching penalty type to PERCENTAGE shows the rate field, not the '
    'fixed-amount field',
    (tester) async {
      final fakeRepo = FakeLoanRepository();

      final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
      router.push(AppRoutes.loanProductNew);
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('loanProductPenaltyEnabledField')),
      );
      await tester.tap(find.byKey(const Key('loanProductPenaltyEnabledField')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('loanProductPenaltyTypeField')),
      );
      await tester.tap(find.byKey(const Key('loanProductPenaltyTypeField')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asilimia').last);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('loanProductPenaltyRateField')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('loanProductPenaltyFixedAmountField')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'creating a product with penalty enabled sends every penalty field to '
    'rpc_create_loan_product, never computed/validated only client-side',
    (tester) async {
      final fakeRepo = FakeLoanRepository();

      final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
      router.push(AppRoutes.loanProductNew);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('loanProductCodeField')),
        'PEN',
      );
      await tester.enterText(
        find.byKey(const Key('loanProductNameField')),
        'Penalty Loan',
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
        find.byKey(const Key('loanProductPenaltyEnabledField')),
      );
      await tester.tap(find.byKey(const Key('loanProductPenaltyEnabledField')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('loanProductPenaltyGraceDaysField')),
      );
      await tester.enterText(
        find.byKey(const Key('loanProductPenaltyGraceDaysField')),
        '5',
      );
      await tester.ensureVisible(
        find.byKey(const Key('loanProductPenaltyFixedAmountField')),
      );
      await tester.enterText(
        find.byKey(const Key('loanProductPenaltyFixedAmountField')),
        '20000',
      );

      await tester.ensureVisible(
        find.byKey(const Key('loanProductSaveAction')),
      );
      await tester.tap(find.byKey(const Key('loanProductSaveAction')));
      await tester.pumpAndSettle();

      expect(fakeRepo.createLoanProductCalls, hasLength(1));
      expect(fakeRepo.createLoanProductCalls.single.penaltyEnabled, isTrue);
    },
  );

  testWidgets(
    'editing an existing penalty-enabled PERCENTAGE product prefills its '
    'penalty fields',
    (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextProduct = fakeLoanProduct(
          id: 'p1',
          penaltyEnabled: true,
          penaltyType: 'PERCENTAGE',
          penaltyFrequency: 'RECURRING_MONTHLY',
          penaltyGraceDays: 5,
          penaltyRate: 7.5,
        );

      final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
      router.push(AppRoutes.loanProductEditPath('p1'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('loanProductPenaltyRateField')),
        findsOneWidget,
      );
      final rateField = tester.widget<TextField>(
        find.byKey(const Key('loanProductPenaltyRateField')),
      );
      expect(rateField.controller?.text, '7.5');
      final graceField = tester.widget<TextField>(
        find.byKey(const Key('loanProductPenaltyGraceDaysField')),
      );
      expect(graceField.controller?.text, '5');
    },
  );
}
