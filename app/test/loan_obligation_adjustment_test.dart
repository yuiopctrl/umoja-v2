import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/loans/data/loan_failure.dart';
import 'package:umoja/features/loans/domain/loan_installment.dart';
import 'package:umoja/features/loans/domain/loan_obligation_adjustment.dart';
import 'package:umoja/l10n/app_localizations_en.dart';
import 'package:umoja/l10n/app_localizations_sw.dart';

import 'fakes/fake_loan_repository.dart';
import 'fakes/loans_test_app.dart';

/// Prompt 09F-A: Loan Waivers & Corrections — domain parsing,
/// permission-gated visibility, preview/confirm flows, zero-cash-impact
/// presentation, error mapping, localization, and adjustment history
/// (including reversal).
void main() {
  group('Domain parsing', () {
    test('LoanObligationWaiverPreview.fromJson parses every field', () {
      final preview = LoanObligationWaiverPreview.fromJson({
        'target_type': 'LOAN_PENALTY',
        'target_id': 'charge-1',
        'current_outstanding': 40000,
        'waiver_amount': 15000,
        'remaining_outstanding': 25000,
        'cash_impact': 0,
        'payment_created': false,
        'receipt_created': false,
      });
      expect(preview.targetType, 'LOAN_PENALTY');
      expect(preview.currentOutstanding, 40000);
      expect(preview.remainingOutstanding, 25000);
      expect(preview.cashImpact, 0);
      expect(preview.paymentCreated, false);
      expect(preview.receiptCreated, false);
    });

    test('LoanObligationCorrectionPreview.fromJson parses every field', () {
      final preview = LoanObligationCorrectionPreview.fromJson({
        'target_type': 'LOAN_PENALTY',
        'target_id': 'charge-1',
        'adjustment_type': 'CORRECTION_INCREASE',
        'source_original_amount': 50000,
        'prior_net_corrections': -10000,
        'current_effective_amount': 40000,
        'proposed_correction': 30000,
        'new_effective_amount': 70000,
        'outstanding_before': 40000,
        'outstanding_after': 70000,
        'cash_impact': 0,
        'payment_created': false,
        'receipt_created': false,
      });
      expect(preview.adjustmentType, 'CORRECTION_INCREASE');
      expect(preview.sourceOriginalAmount, 50000);
      expect(preview.proposedCorrection, 30000);
      expect(preview.newEffectiveAmount, 70000);
    });

    test('LoanObligationAdjustmentPostResult.fromJson tolerates a missing '
        'outstanding_after (the idempotent-retry response shape)', () {
      final result = LoanObligationAdjustmentPostResult.fromJson({
        'adjustment_id': 'a1',
        'target_type': 'LOAN_PENALTY',
        'adjustment_type': 'WAIVER',
        'amount': -15000,
        'already_posted': true,
        'loan_status': 'ACTIVE',
      });
      expect(result.outstandingAfter, isNull);
      expect(result.alreadyPosted, true);
    });

    test('LoanObligationAdjustmentPage.fromJson parses a list of items', () {
      final page = LoanObligationAdjustmentPage.fromJson({
        'total_count': 1,
        'items': [
          {
            'id': 'a1',
            'target_type': 'LOAN_PENALTY',
            'loan_penalty_charge_id': 'charge-1',
            'loan_installment_id': null,
            'installment_number': 1,
            'adjustment_type': 'WAIVER',
            'amount': -15000,
            'reason_code': 'HARDSHIP',
            'note': null,
            'effective_date': '2026-01-01',
            'created_at': '2026-01-01T00:00:00Z',
            'created_by': 'u1',
            'reverses_adjustment_id': null,
            'is_reversed': false,
            'reversed_by_adjustment_id': null,
          },
        ],
      });
      expect(page.totalCount, 1);
      expect(page.items.single.isReversalCandidate, true);
      expect(page.items.single.isReversal, false);
    });
  });

  group('Loan Detail: permission-gated Waive/Correct visibility', () {
    testWidgets(
      'a TREASURER sees Waive but never Correct on a penalty charge',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextAccount = fakeLoanAccount(
            id: 'loan-1',
            status: 'ACTIVE',
            penaltyEnabled: true,
            penaltyType: 'FIXED',
            penaltyFrequency: 'ONCE',
          )
          ..nextPenaltyCharges = [
            fakeLoanPenaltyCharge(id: 'charge-1', outstandingAmount: 40000),
          ];

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
          find.byKey(const Key('loanWaivePenaltyAction_charge-1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('loanCorrectPenaltyAction_charge-1')),
          findsNothing,
        );
      },
    );

    testWidgets('an ADMIN sees both Waive and Correct on a penalty charge', (
      tester,
    ) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(
          id: 'loan-1',
          status: 'ACTIVE',
          penaltyEnabled: true,
          penaltyType: 'FIXED',
          penaltyFrequency: 'ONCE',
        )
        ..nextPenaltyCharges = [
          fakeLoanPenaltyCharge(id: 'charge-1', outstandingAmount: 40000),
        ];

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('loanWaivePenaltyAction_charge-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('loanCorrectPenaltyAction_charge-1')),
        findsOneWidget,
      );
    });

    testWidgets(
      'a member with neither permission sees no Waive/Correct actions, on '
      'either a penalty charge or an installment with outstanding interest',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextAccount = fakeLoanAccount(
            id: 'loan-1',
            status: 'ACTIVE',
            penaltyEnabled: true,
            penaltyType: 'FIXED',
            penaltyFrequency: 'ONCE',
            installments: [
              LoanInstallment(
                id: 'installment-1',
                installmentNumber: 1,
                dueDate: DateTime.utc(2026, 1, 1),
                principalDue: 100000,
                interestDue: 6000,
                totalDue: 106000,
                interestOutstanding: 6000,
              ),
            ],
          )
          ..nextPenaltyCharges = [
            fakeLoanPenaltyCharge(id: 'charge-1', outstandingAmount: 40000),
          ];

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
          find.byKey(const Key('loanWaivePenaltyAction_charge-1')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('loanCorrectPenaltyAction_charge-1')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('loanWaiveInterestAction_installment-1')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('loanCorrectInterestAction_installment-1')),
          findsNothing,
        );
      },
    );

    testWidgets('a MIGRATED loan'
        's opening penalty charge is waivable through the '
        'exact same action as any NEW loan'
        's charge', (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(
          id: 'loan-1',
          status: 'ACTIVE',
          loanOrigin: 'MIGRATED',
          penaltyEnabled: true,
          penaltyType: 'FIXED',
          penaltyFrequency: 'ONCE',
        )
        ..nextPenaltyCharges = [
          fakeLoanPenaltyCharge(
            id: 'opening-charge-1',
            origin: 'OPENING',
            outstandingAmount: 20000,
          ),
        ];

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('loanWaivePenaltyAction_opening-charge-1')),
        findsOneWidget,
      );
    });
  });

  group('Waiver screen', () {
    testWidgets(
      'preview shows current/waiver/remaining outstanding and zero cash '
      'impact / no payment / no receipt; confirm posts the exact params',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'ACTIVE')
          ..nextWaiverPreview = fakeLoanObligationWaiverPreview(
            targetType: 'LOAN_PENALTY',
            targetId: 'charge-1',
            currentOutstanding: 40000,
            waiverAmount: 15000,
            remainingOutstanding: 25000,
          );

        final router = await pumpLoansApp(
          tester,
          fakeRepo: fakeRepo,
          language: AppLanguage.english,
        );
        router.push(
          AppRoutes.loanObligationWaivePath(
            'loan-1',
            'LOAN_PENALTY',
            'charge-1',
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('loanObligationWaiverAmountField')),
          '15000',
        );
        await tester.tap(
          find.byKey(const Key('loanObligationWaiverPreviewAction')),
        );
        await tester.pumpAndSettle();

        expect(fakeRepo.previewLoanObligationWaiverCalls.length, 1);
        expect(
          fakeRepo.previewLoanObligationWaiverCalls.single.targetType,
          'LOAN_PENALTY',
        );
        expect(
          fakeRepo.previewLoanObligationWaiverCalls.single.targetId,
          'charge-1',
        );
        expect(fakeRepo.previewLoanObligationWaiverCalls.single.amount, 15000);

        expect(find.textContaining('40,000'), findsOneWidget);
        expect(find.textContaining('15,000'), findsWidgets);
        expect(find.textContaining('25,000'), findsOneWidget);
        expect(
          find.text(AppLocalizationsEn().loanObligationNoLabel),
          findsNWidgets(2),
        );

        await tester.tap(
          find.byKey(const Key('loanObligationWaiverConfirmAction')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirm Waiver').last);
        await tester.pumpAndSettle();

        expect(fakeRepo.postLoanObligationWaiverCalls.length, 1);
        expect(
          fakeRepo.postLoanObligationWaiverCalls.single.targetType,
          'LOAN_PENALTY',
        );
        expect(fakeRepo.postLoanObligationWaiverCalls.single.amount, 15000);
      },
    );

    testWidgets(
      'a future-interest rejection shows the friendly localized message, '
      'never the raw domain code',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'ACTIVE');

        final router = await pumpLoansApp(
          tester,
          fakeRepo: fakeRepo,
          language: AppLanguage.english,
        );
        router.push(
          AppRoutes.loanObligationWaivePath(
            'loan-1',
            'LOAN_INTEREST',
            'installment-2',
          ),
        );
        await tester.pumpAndSettle();

        fakeRepo.failure = const LoanFailure(
          LoanFailureType.futureInterestNotWaivable,
          'unused fallback',
        );

        await tester.enterText(
          find.byKey(const Key('loanObligationWaiverAmountField')),
          '1000',
        );
        await tester.tap(
          find.byKey(const Key('loanObligationWaiverPreviewAction')),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(AppLocalizationsEn().loanErrorFutureInterestNotWaivable),
          findsOneWidget,
        );
        expect(find.textContaining('LOAN_FUTURE_INTEREST'), findsNothing);
      },
    );
  });

  group('Correction screen', () {
    testWidgets(
      'CORRECTION_INCREASE is never offered for LOAN_INTEREST, even when '
      'canIncrease is true',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'ACTIVE');

        final router = await pumpLoansApp(
          tester,
          fakeRepo: fakeRepo,
          language: AppLanguage.english,
        );
        router.push(
          AppRoutes.loanObligationCorrectPath(
            'loan-1',
            'LOAN_INTEREST',
            'installment-1',
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('loanObligationCorrectionTypeField')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Decrease'), findsWidgets);
        expect(find.text('Increase'), findsNothing);
      },
    );

    testWidgets(
      'CORRECTION_INCREASE is ADMIN-only: a TREASURER navigating to a '
      'penalty correction never sees the Increase option',
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
        router.push(
          AppRoutes.loanObligationCorrectPath(
            'loan-1',
            'LOAN_PENALTY',
            'charge-1',
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('loanObligationCorrectionTypeField')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Increase'), findsNothing);
      },
    );

    testWidgets(
      'an ADMIN correcting a penalty sees the Increase option, and preview '
      'shows source/prior/current/proposed/new effective amounts',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'ACTIVE')
          ..nextCorrectionPreview = fakeLoanObligationCorrectionPreview(
            targetType: 'LOAN_PENALTY',
            adjustmentType: 'CORRECTION_INCREASE',
            sourceOriginalAmount: 50000,
            priorNetCorrections: -10000,
            proposedCorrection: 30000,
          );

        final router = await pumpLoansApp(
          tester,
          fakeRepo: fakeRepo,
          language: AppLanguage.english,
        );
        router.push(
          AppRoutes.loanObligationCorrectPath(
            'loan-1',
            'LOAN_PENALTY',
            'charge-1',
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('loanObligationCorrectionTypeField')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Increase'), findsWidgets);
        await tester.tap(find.text('Increase').last);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('loanObligationCorrectionAmountField')),
          '30000',
        );
        await tester.tap(
          find.byKey(const Key('loanObligationCorrectionPreviewAction')),
        );
        await tester.pumpAndSettle();

        expect(
          fakeRepo.previewLoanObligationCorrectionCalls.single.adjustmentType,
          'CORRECTION_INCREASE',
        );
        expect(find.textContaining('50,000'), findsOneWidget);
        expect(find.textContaining('-10,000'), findsOneWidget);
        expect(find.textContaining('30,000'), findsWidgets);
        expect(find.textContaining('70,000'), findsOneWidget);
      },
    );

    testWidgets(
      'a correction-increase-exceeds-bound rejection shows the friendly '
      'localized message',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'ACTIVE');

        final router = await pumpLoansApp(
          tester,
          fakeRepo: fakeRepo,
          language: AppLanguage.english,
        );
        router.push(
          AppRoutes.loanObligationCorrectPath(
            'loan-1',
            'LOAN_PENALTY',
            'charge-1',
          ),
        );
        await tester.pumpAndSettle();

        fakeRepo.failure = const LoanFailure(
          LoanFailureType.correctionIncreaseExceedsBound,
          'unused fallback',
        );

        await tester.tap(
          find.byKey(const Key('loanObligationCorrectionTypeField')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Increase').last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('loanObligationCorrectionAmountField')),
          '5000000',
        );
        await tester.tap(
          find.byKey(const Key('loanObligationCorrectionPreviewAction')),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            AppLocalizationsEn().loanErrorCorrectionIncreaseExceedsBound,
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('Adjustment history', () {
    testWidgets(
      'shows every adjustment, hides Reverse for an already-reversed one, '
      'and shows the Reversed label instead',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'ACTIVE')
          ..nextAdjustmentsPage = LoanObligationAdjustmentPage(
            totalCount: 2,
            items: [
              fakeLoanObligationAdjustment(
                id: 'a1',
                adjustmentType: 'WAIVER',
                amount: -15000,
                isReversed: false,
              ),
              fakeLoanObligationAdjustment(
                id: 'a2',
                adjustmentType: 'CORRECTION_DECREASE',
                amount: -5000,
                isReversed: true,
              ),
            ],
          );

        final router = await pumpLoansApp(
          tester,
          fakeRepo: fakeRepo,
          language: AppLanguage.english,
        );
        router.push(AppRoutes.loanAccountDetailPath('loan-1'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('loanObligationReverseAction_a1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('loanObligationReverseAction_a2')),
          findsNothing,
        );
        expect(
          find.text(AppLocalizationsEn().loanObligationHistoryReversedLabel),
          findsOneWidget,
        );
      },
    );

    testWidgets('reversing an adjustment prompts for a reason and calls the '
        'repository, showing a success message', (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'ACTIVE')
        ..nextAdjustmentsPage = LoanObligationAdjustmentPage(
          totalCount: 1,
          items: [
            fakeLoanObligationAdjustment(id: 'a1', adjustmentType: 'WAIVER'),
          ],
        );

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('loanObligationReverseAction_a1')),
      );
      await tester.tap(find.byKey(const Key('loanObligationReverseAction_a1')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('loanObligationReverseReasonField')),
        'no dependent activity',
      );
      await tester.tap(
        find.byKey(const Key('loanObligationReverseConfirmAction')),
      );
      await tester.pumpAndSettle();

      expect(fakeRepo.reverseLoanObligationAdjustmentCalls.length, 1);
      expect(
        fakeRepo.reverseLoanObligationAdjustmentCalls.single.adjustmentId,
        'a1',
      );
      expect(
        fakeRepo.reverseLoanObligationAdjustmentCalls.single.reversalReason,
        'no dependent activity',
      );
      expect(
        find.text(AppLocalizationsEn().loanObligationReverseSuccessMessage),
        findsOneWidget,
      );
    });

    testWidgets(
      'a dependent-reversal-blocked rejection shows the friendly localized '
      'message',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'ACTIVE')
          ..nextAdjustmentsPage = LoanObligationAdjustmentPage(
            totalCount: 1,
            items: [
              fakeLoanObligationAdjustment(id: 'a1', adjustmentType: 'WAIVER'),
            ],
          );

        final router = await pumpLoansApp(
          tester,
          fakeRepo: fakeRepo,
          language: AppLanguage.english,
        );
        router.push(AppRoutes.loanAccountDetailPath('loan-1'));
        await tester.pumpAndSettle();

        fakeRepo.failure = const LoanFailure(
          LoanFailureType.adjustmentReversalBlockedSubsequentActivity,
          'unused fallback',
        );

        await tester.ensureVisible(
          find.byKey(const Key('loanObligationReverseAction_a1')),
        );
        await tester.tap(
          find.byKey(const Key('loanObligationReverseAction_a1')),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('loanObligationReverseReasonField')),
          'attempt',
        );
        await tester.tap(
          find.byKey(const Key('loanObligationReverseConfirmAction')),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            AppLocalizationsEn()
                .loanErrorAdjustmentReversalBlockedSubsequentActivity,
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('an empty history shows the empty state', (tester) async {
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
        find.text(AppLocalizationsEn().loanObligationHistoryEmptyMessage),
        findsOneWidget,
      );
    });
  });

  group('Localization', () {
    testWidgets('SW: the Kiswahili history title/reverse action are shown', (
      tester,
    ) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'ACTIVE')
        ..nextAdjustmentsPage = LoanObligationAdjustmentPage(
          totalCount: 1,
          items: [
            fakeLoanObligationAdjustment(id: 'a1', adjustmentType: 'WAIVER'),
          ],
        );

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.swahili,
      );
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      expect(
        find.text(AppLocalizationsSw().loanObligationHistoryTitle),
        findsOneWidget,
      );
      expect(
        find.text(AppLocalizationsSw().loanObligationReverseAction),
        findsOneWidget,
      );
    });
  });
}
