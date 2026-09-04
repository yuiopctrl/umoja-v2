import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';

import 'fakes/fake_loan_repository.dart';
import 'fakes/loans_test_app.dart';

/// Prompt 09E: Loan Prepayment, Early Settlement & Restructure — eligibility/
/// visibility, preview flow, stale-preview invalidation, review values,
/// confirm flow, and the shared money formatter.
void main() {
  group('Loan Detail: 09E action visibility', () {
    testWidgets(
      'an ACTIVE loan with full servicing permissions shows all three '
      'actions',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'ACTIVE');

        final router = await pumpLoansApp(
          tester,
          fakeRepo: fakeRepo,
          language: AppLanguage.english,
        );
        router.push(AppRoutes.loanAccountDetailPath('loan-1'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('loanEarlySettlementAction')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('loanPrepayPrincipalAction')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('loanRestructureAction')), findsOneWidget);
      },
    );

    testWidgets(
      'a TREASURER (the other role the DB actually grants all three 09E '
      'servicing permissions to) also shows all three actions',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'ACTIVE');

        final router = await pumpLoansApp(
          tester,
          fakeRepo: fakeRepo,
          membership: loanMembership(
            roles: const ['TREASURER'],
            permissions: loanTreasurerPermissions,
          ),
          language: AppLanguage.english,
        );
        router.push(AppRoutes.loanAccountDetailPath('loan-1'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('loanEarlySettlementAction')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('loanPrepayPrincipalAction')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('loanRestructureAction')), findsOneWidget);
      },
    );

    testWidgets(
      'a member without any servicing permission sees none of the three '
      'actions',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'ACTIVE');

        final router = await pumpLoansApp(
          tester,
          fakeRepo: fakeRepo,
          membership: loanMembership(
            roles: const ['MEMBER'],
            permissions: loanViewOnlyPermissions,
          ),
          language: AppLanguage.english,
        );
        router.push(AppRoutes.loanAccountDetailPath('loan-1'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('loanEarlySettlementAction')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('loanPrepayPrincipalAction')),
          findsNothing,
        );
        expect(find.byKey(const Key('loanRestructureAction')), findsNothing);
      },
    );

    testWidgets('a DRAFT loan shows none of the three servicing actions', (
      tester,
    ) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'DRAFT');

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('loanEarlySettlementAction')), findsNothing);
      expect(find.byKey(const Key('loanPrepayPrincipalAction')), findsNothing);
      expect(find.byKey(const Key('loanRestructureAction')), findsNothing);
    });
  });

  group('Early Settlement', () {
    testWidgets(
      'preview shows the server-computed quote, and confirm posts it',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'ACTIVE')
          ..nextEarlySettlementQuote = fakeLoanEarlySettlementQuote(
            futurePrincipalOutstanding: 100000,
            futureUnearnedInterest: 12000,
            totalSettlementAmount: 100000,
          );

        final router = await pumpLoansApp(
          tester,
          fakeRepo: fakeRepo,
          language: AppLanguage.english,
        );
        router.push(AppRoutes.loanAccountEarlySettlementPath('loan-1'));
        await tester.pumpAndSettle();

        // Input step: only the preview action is shown; no amount field
        // exists anywhere on this screen (the total is always server-
        // computed).
        expect(
          find.byKey(const Key('loanEarlySettlementPreviewAction')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('loanEarlySettlementQuoteCard')),
          findsNothing,
        );

        await tester.tap(
          find.byKey(const Key('loanEarlySettlementPreviewAction')),
        );
        await tester.pumpAndSettle();

        expect(fakeRepo.previewLoanEarlySettlementCalls.length, 1);
        expect(
          find.byKey(const Key('loanEarlySettlementQuoteCard')),
          findsOneWidget,
        );
        expect(find.textContaining('100,000'), findsWidgets);

        await tester.tap(
          find.byKey(const Key('loanEarlySettlementFinancialAccountField')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Main Cash — 50,000').last);
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(const Key('loanEarlySettlementConfirmAction')),
        );
        await tester.tap(
          find.byKey(const Key('loanEarlySettlementConfirmAction')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Settle Loan Early').last);
        await tester.pumpAndSettle();

        expect(fakeRepo.settleLoanEarlyCalls.length, 1);
        expect(fakeRepo.settleLoanEarlyCalls.single.loanAccountId, 'loan-1');
        expect(
          fakeRepo.settleLoanEarlyCalls.single.financialAccountId,
          'account-1',
        );
      },
    );
  });

  group('Principal Prepayment', () {
    testWidgets('preview shows the recomputed schedule; editing the amount '
        'afterwards invalidates the stale preview', (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'ACTIVE')
        ..nextPrepaymentPreview = fakeLoanPrepaymentPreview(
          amount: 50000,
          treatment: 'REDUCE_TERM',
          futurePrincipalOutstandingBefore: 150000,
          futurePrincipalOutstandingAfter: 100000,
        );

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.push(AppRoutes.loanAccountPrepayPath('loan-1'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('loanPrepaymentAmountField')),
        '50000',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('loanPrepaymentPreviewAction')));
      await tester.pumpAndSettle();

      expect(fakeRepo.previewLoanPrepaymentCalls.length, 1);
      expect(fakeRepo.previewLoanPrepaymentCalls.single.amount, 50000);
      expect(
        fakeRepo.previewLoanPrepaymentCalls.single.treatment,
        'REDUCE_TERM',
      );
      expect(
        find.byKey(const Key('loanPrepaymentPreviewCard')),
        findsOneWidget,
      );
      expect(find.textContaining('150,000'), findsOneWidget);
      expect(find.textContaining('100,000'), findsWidgets);

      // Stale-preview invalidation: the field is disabled once a
      // preview exists, so go back first (matching the mandatory
      // Input -> Preview -> Review -> Confirm shape), then confirm
      // that changing the amount clears the shown preview again.
      await tester.tap(find.byKey(const Key('loanPrepaymentBackAction')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('loanPrepaymentPreviewCard')), findsNothing);

      await tester.tap(find.byKey(const Key('loanPrepaymentPreviewAction')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('loanPrepaymentPreviewCard')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('loanPrepaymentAmountField')),
        '60000',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('loanPrepaymentPreviewCard')),
        findsNothing,
        reason: 'editing the amount after a preview must invalidate it',
      );
    });

    testWidgets('confirm posts the previewed amount/treatment exactly', (
      tester,
    ) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'ACTIVE')
        ..nextPrepaymentPreview = fakeLoanPrepaymentPreview(
          amount: 50000,
          treatment: 'REDUCE_INSTALLMENT',
        );

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.push(AppRoutes.loanAccountPrepayPath('loan-1'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('loanPrepaymentAmountField')),
        '50000',
      );
      await tester.tap(find.byKey(const Key('loanPrepaymentTreatmentField')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reduce Installment (keep term)').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('loanPrepaymentPreviewAction')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('loanPrepaymentFinancialAccountField')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Main Cash — 50,000').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('loanPrepaymentConfirmAction')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm Prepayment').last);
      await tester.pumpAndSettle();

      expect(fakeRepo.prepayLoanPrincipalCalls.length, 1);
      expect(fakeRepo.prepayLoanPrincipalCalls.single.amount, 50000);
      expect(
        fakeRepo.prepayLoanPrincipalCalls.single.treatment,
        'REDUCE_INSTALLMENT',
      );
    });
  });

  group('Restructure', () {
    testWidgets(
      'preview shows the proposed schedule and confirm submits the exact '
      'reason/term entered',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'ACTIVE')
          ..nextRestructurePreview = fakeLoanRestructurePreview(newTerm: 8);

        final router = await pumpLoansApp(
          tester,
          fakeRepo: fakeRepo,
          language: AppLanguage.english,
        );
        router.push(AppRoutes.loanAccountRestructurePath('loan-1'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('loanRestructureReasonField')),
          'Borrower hardship',
        );
        await tester.enterText(
          find.byKey(const Key('loanRestructureNewTermField')),
          '8',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('loanRestructurePreviewAction')));
        await tester.pumpAndSettle();

        expect(fakeRepo.previewLoanRestructureCalls.length, 1);
        expect(fakeRepo.previewLoanRestructureCalls.single.newTerm, 8);
        expect(
          find.byKey(const Key('loanRestructurePreviewCard')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('loanRestructureConfirmAction')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirm Restructure').last);
        await tester.pumpAndSettle();

        expect(fakeRepo.restructureLoanCalls.length, 1);
        expect(
          fakeRepo.restructureLoanCalls.single.reason,
          'Borrower hardship',
        );
        expect(fakeRepo.restructureLoanCalls.single.newTerm, 8);
      },
    );
  });
}
