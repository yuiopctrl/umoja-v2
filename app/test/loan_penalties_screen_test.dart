import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/features/loans/domain/loan_account.dart';
import 'package:umoja/features/loans/domain/loan_penalty_charge.dart';

import 'fakes/fake_loan_repository.dart';
import 'fakes/loans_test_app.dart';

/// Prompt 09D: `/loans/penalties` — total outstanding penalties, ACTIVE
/// loans currently carrying one, Run Assessment (permission-gated),
/// and its structured result. Flutter never computes a penalty amount
/// itself — only triggers the server run and renders its result.
void main() {
  testWidgets(
    'loans with an outstanding penalty are listed, with the correct total',
    (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccountsPage = LoanAccountPage(
          items: [
            fakeLoanAccount(
              id: 'loan-1',
              loanNumber: 'STD-LN-2026-0001',
              status: 'ACTIVE',
              penaltyOutstanding: 20000,
            ),
            fakeLoanAccount(
              id: 'loan-2',
              loanNumber: 'STD-LN-2026-0002',
              status: 'ACTIVE',
              penaltyOutstanding: 0,
            ),
          ],
          totalCount: 2,
          limit: 100,
          offset: 0,
        );

      final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.loanPenalties);
      await tester.pumpAndSettle();

      expect(find.textContaining('STD-LN-2026-0001'), findsOneWidget);
      expect(find.textContaining('STD-LN-2026-0002'), findsNothing);
      expect(
        find.byKey(const Key('loanPenaltiesOutstandingTotal')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Run Assessment calls rpc_assess_loan_penalties with the chosen date '
    'and shows the structured result',
    (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccountsPage = LoanAccountPage.empty
        ..nextAssessmentResult = LoanPenaltyAssessmentResult(
          assessmentDate: DateTime.utc(2026, 9, 1),
          eligibleInstallmentCount: 3,
          assessedCount: 2,
          skippedCount: 1,
          failedCount: 0,
          totalPenaltyAmount: 40000,
        );

      final router = await pumpLoansApp(tester, fakeRepo: fakeRepo);
      router.go(AppRoutes.loanPenalties);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('loanPenaltyAssessAction')));
      await tester.pumpAndSettle();

      expect(fakeRepo.assessLoanPenaltiesCalls, hasLength(1));
      expect(
        find.byKey(const Key('loanPenaltyAssessmentResult')),
        findsOneWidget,
      );
      expect(find.text('40,000'), findsOneWidget);
    },
  );

  testWidgets(
    'a view-only user (loan_penalty.view but not .assess) never sees the '
    'Run Assessment action',
    (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccountsPage = LoanAccountPage.empty;

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        membership: loanMembership(
          roles: const ['CHAIRPERSON'],
          permissions: loanChairpersonPermissions,
        ),
      );
      router.go(AppRoutes.loanPenalties);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('loanPenaltyAssessAction')), findsNothing);
    },
  );
}
