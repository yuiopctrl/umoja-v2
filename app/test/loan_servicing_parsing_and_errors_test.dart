import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/loans/data/loan_failure.dart';
import 'package:umoja/features/loans/domain/loan_servicing.dart';

import 'fakes/fake_loan_repository.dart';
import 'fakes/loans_test_app.dart';

/// Prompt 09E-UAT-BLOCKER-01 (section H items 2/4/5): the domain-model
/// parsing itself was verified NOT to be the root cause (this codebase
/// consistently receives PostgREST numeric columns as native JSON
/// numbers, never quoted strings — every other domain model already
/// relies on the same `(json['x'] as num).toDouble()` pattern in
/// production) — these tests lock that in for both a whole-number
/// (JSON int) and fractional (JSON double) server response, and verify
/// a known domain/server error renders its specific, actionable
/// message rather than the generic fallback.
void main() {
  group('LoanEarlySettlementQuote.fromJson', () {
    test('parses whole-number (JSON int) NUMERIC values correctly', () {
      final quote = LoanEarlySettlementQuote.fromJson({
        'effective_date': '2026-09-03',
        'overdue_penalty_outstanding': 0,
        'overdue_interest_outstanding': 0,
        'overdue_principal_outstanding': 0,
        'current_payable_penalty': 0,
        'current_payable_interest': 0,
        'current_payable_principal': 0,
        'future_principal_outstanding': 600000,
        'future_unearned_interest': 72000,
        'settlement_adjustment_amount': 0,
        'total_settlement_amount': 600000,
      });

      expect(quote.totalSettlementAmount, 600000.0);
      expect(quote.futurePrincipalOutstanding, 600000.0);
    });

    test('parses fractional (JSON double) NUMERIC values correctly', () {
      final quote = LoanEarlySettlementQuote.fromJson({
        'effective_date': '2026-09-03',
        'overdue_penalty_outstanding': 15000.50,
        'overdue_interest_outstanding': 18000.25,
        'overdue_principal_outstanding': 300000.00,
        'current_payable_penalty': 0,
        'current_payable_interest': 0,
        'current_payable_principal': 0,
        'future_principal_outstanding': 0,
        'future_unearned_interest': 0,
        'settlement_adjustment_amount': 0,
        'total_settlement_amount': 333000.75,
      });

      expect(quote.overduePenaltyOutstanding, 15000.50);
      expect(quote.overdueInterestOutstanding, 18000.25);
      expect(quote.totalSettlementAmount, 333000.75);
    });
  });

  group('LoanPrepaymentPreview.fromJson', () {
    test('parses whole-number (JSON int) NUMERIC values correctly', () {
      final preview = LoanPrepaymentPreview.fromJson({
        'amount': 50000,
        'treatment': 'REDUCE_TERM',
        'future_principal_outstanding_before': 150000,
        'future_principal_outstanding_after': 100000,
        'old_future_installments': <Map<String, dynamic>>[],
        'new_future_installments': <Map<String, dynamic>>[
          {
            'installment_number': 1,
            'due_date': '2026-10-01',
            'principal_due': 100000,
            'interest_due': 0,
          },
        ],
      });

      expect(preview.futurePrincipalOutstandingBefore, 150000.0);
      expect(preview.futurePrincipalOutstandingAfter, 100000.0);
      expect(preview.newFutureInstallments.single.principalDue, 100000.0);
    });

    test('parses fractional (JSON double) NUMERIC values correctly', () {
      final preview = LoanPrepaymentPreview.fromJson({
        'amount': 50000.33,
        'treatment': 'REDUCE_INSTALLMENT',
        'future_principal_outstanding_before': 150000.99,
        'future_principal_outstanding_after': 100000.66,
        'old_future_installments': <Map<String, dynamic>>[],
        'new_future_installments': <Map<String, dynamic>>[],
      });

      expect(preview.amount, 50000.33);
      expect(preview.futurePrincipalOutstandingBefore, 150000.99);
    });
  });

  group('Error UX: known domain failures render actionable messages', () {
    testWidgets(
      'Early Settlement preview failing with LOAN_NOT_ACTIVE shows that '
      'specific message, never the generic fallback',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'ACTIVE')
          ..failure = const LoanFailure(
            LoanFailureType.loanNotActive,
            'This loan is not active.',
          );

        final router = await pumpLoansApp(
          tester,
          fakeRepo: fakeRepo,
          language: AppLanguage.english,
        );
        router.push(AppRoutes.loanAccountEarlySettlementPath('loan-1'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('loanEarlySettlementPreviewAction')),
        );
        await tester.pumpAndSettle();

        expect(find.text('This loan is not active.'), findsOneWidget);
        expect(
          find.text('Something went wrong. Please try again.'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Principal Prepayment preview failing with the overdue-interest '
      'block shows that specific message, never the generic fallback',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'ACTIVE')
          ..failure = const LoanFailure(
            LoanFailureType.prepaymentBlockedOverdueInterest,
            'Clear the outstanding overdue interest with a normal payment '
            'before prepaying principal.',
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
        await tester.tap(find.byKey(const Key('loanPrepaymentPreviewAction')));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Clear the outstanding overdue interest with a normal payment '
            'before prepaying principal.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Something went wrong. Please try again.'),
          findsNothing,
        );
      },
    );
  });
}
