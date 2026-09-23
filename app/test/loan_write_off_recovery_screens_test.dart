import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/routing/app_routes.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/loans/data/loan_failure.dart';
import 'package:umoja/features/loans/domain/loan_write_off_recovery.dart';
import 'package:umoja/l10n/app_localizations_en.dart';
import 'package:umoja/l10n/app_localizations_sw.dart';

import 'fakes/fake_loan_repository.dart';
import 'fakes/loans_test_app.dart';

/// Prompt 09F-B: domain parsing, permission-gated visibility, the
/// write-off Input -> Preview -> Review -> Confirm flow, the
/// WRITTEN_OFF Loan Detail summary/recovery history, the recovery
/// flow, reversal (eligible + blocked), route-target integrity, and
/// localization.
void main() {
  group('Domain parsing', () {
    test('LoanWriteOffPreview.fromJson parses every field', () {
      final preview = LoanWriteOffPreview.fromJson({
        'loan_account_id': 'loan-1',
        'reason_code': 'PROLONGED_DEFAULT',
        'note': null,
        'effective_date': '2026-09-01',
        'principal_amount': 200000,
        'interest_amount': 15000,
        'penalty_amount': 5000,
        'total_amount': 220000,
        'cash_impact': 0,
        'payment_created': false,
        'receipt_created': false,
      });
      expect(preview.principalAmount, 200000);
      expect(preview.interestAmount, 15000);
      expect(preview.penaltyAmount, 5000);
      expect(preview.totalAmount, 220000);
      expect(preview.cashImpact, 0);
      expect(preview.paymentCreated, false);
      expect(preview.receiptCreated, false);
    });

    test('LoanRecoveryPreview.fromJson parses the nested allocation/'
        'remaining objects', () {
      final preview = LoanRecoveryPreview.fromJson({
        'loan_account_id': 'loan-1',
        'write_off_event_id': 'w1',
        'write_off_total_amount': 220000,
        'remaining_before': {
          'principal': 200000,
          'interest': 15000,
          'penalty': 5000,
          'total': 220000,
        },
        'recovery_amount': 10000,
        'allocation': {'penalty': 5000, 'interest': 5000, 'principal': 0},
        'remaining_after': {
          'principal': 200000,
          'interest': 10000,
          'penalty': 0,
          'total': 210000,
        },
        'cash_impact': 10000,
        'payment_created': true,
        'receipt_created': true,
      });
      expect(preview.allocation.penalty, 5000);
      expect(preview.allocation.interest, 5000);
      expect(preview.allocation.principal, 0);
      expect(preview.remainingBefore.total, 220000);
      expect(preview.remainingAfter.total, 210000);
      expect(preview.cashImpact, 10000);
      expect(preview.paymentCreated, isTrue);
    });
  });

  group('Loan Detail: permission-gated Write Off/Recovery visibility', () {
    testWidgets('an ADMIN sees Write Off on an ACTIVE loan', (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'ACTIVE');

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('loanWriteOffAction')), findsOneWidget);
    });

    testWidgets('a TREASURER never sees Write Off on an ACTIVE loan', (
      tester,
    ) async {
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

      expect(find.byKey(const Key('loanWriteOffAction')), findsNothing);
    });

    testWidgets('a MEMBER with no loan-module permissions sees no Write Off '
        'action', (tester) async {
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

      expect(find.byKey(const Key('loanWriteOffAction')), findsNothing);
    });

    testWidgets(
      'a TREASURER sees Record Recovery (but never Reverse Write-Off) on '
      'a WRITTEN_OFF loan',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'WRITTEN_OFF')
          ..nextWriteOffSummary = fakeLoanWriteOffSummary(
            loanAccountId: 'loan-1',
          );

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
          find.byKey(const Key('loanRecordRecoveryAction')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('loanReverseWriteOffAction')),
          findsNothing,
        );
      },
    );

    testWidgets('a MEMBER with no permissions sees neither Record Recovery nor '
        'Reverse Write-Off on a WRITTEN_OFF loan', (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'WRITTEN_OFF')
        ..nextWriteOffSummary = fakeLoanWriteOffSummary(
          loanAccountId: 'loan-1',
        );

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

      expect(find.byKey(const Key('loanRecordRecoveryAction')), findsNothing);
      expect(find.byKey(const Key('loanReverseWriteOffAction')), findsNothing);
    });
  });

  group('Write-off screen', () {
    testWidgets(
      'preview shows the exact server-computed principal/interest/penalty/'
      'total and zero cash impact / no payment / no receipt; confirm posts '
      'the exact reason',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'ACTIVE')
          ..nextWriteOffPreview = fakeLoanWriteOffPreview(
            loanAccountId: 'loan-1',
            reasonCode: 'PROLONGED_DEFAULT',
            principalAmount: 200000,
            interestAmount: 15000,
            penaltyAmount: 5000,
          );

        final router = await pumpLoansApp(
          tester,
          fakeRepo: fakeRepo,
          language: AppLanguage.english,
        );
        router.push(AppRoutes.loanWriteOffPath('loan-1'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('loanWriteOffPreviewAction')));
        await tester.pumpAndSettle();

        expect(fakeRepo.previewLoanWriteOffCalls.length, 1);
        expect(
          fakeRepo.previewLoanWriteOffCalls.single.reasonCode,
          'PROLONGED_DEFAULT',
        );

        // Server-computed amounts rendered exactly — never recomputed.
        expect(find.text('200,000'), findsOneWidget);
        expect(find.text('15,000'), findsOneWidget);
        expect(find.text('5,000'), findsOneWidget);
        expect(find.text('220,000'), findsOneWidget);
        expect(
          find.text(AppLocalizationsEn().loanObligationNoLabel),
          findsNWidgets(2),
        );

        await tester.ensureVisible(
          find.byKey(const Key('loanWriteOffConfirmAction')),
        );
        await tester.tap(find.byKey(const Key('loanWriteOffConfirmAction')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(AppLocalizationsEn().loanWriteOffConfirmAction).last,
        );
        await tester.pumpAndSettle();

        expect(fakeRepo.postLoanWriteOffCalls.length, 1);
        expect(
          fakeRepo.postLoanWriteOffCalls.single.reasonCode,
          'PROLONGED_DEFAULT',
        );
      },
    );

    testWidgets('editing the reason after previewing invalidates the stale '
        'preview back to the input phase', (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'ACTIVE')
        ..nextWriteOffPreview = fakeLoanWriteOffPreview(
          loanAccountId: 'loan-1',
        );

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.push(AppRoutes.loanWriteOffPath('loan-1'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('loanWriteOffPreviewAction')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('loanWriteOffPreviewCard')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('loanWriteOffNoteField')),
        'changed my mind',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('loanWriteOffPreviewCard')), findsNothing);
      expect(
        find.byKey(const Key('loanWriteOffPreviewAction')),
        findsOneWidget,
      );
    });

    testWidgets(
      'a LOAN_WRITE_OFF_NOTHING_OUTSTANDING rejection shows the friendly '
      'localized message, never the raw domain code',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'ACTIVE');

        final router = await pumpLoansApp(
          tester,
          fakeRepo: fakeRepo,
          language: AppLanguage.english,
        );
        router.push(AppRoutes.loanWriteOffPath('loan-1'));
        await tester.pumpAndSettle();

        fakeRepo.failure = const LoanFailure(
          LoanFailureType.writeOffNothingOutstanding,
          'unused fallback',
        );

        await tester.tap(find.byKey(const Key('loanWriteOffPreviewAction')));
        await tester.pumpAndSettle();

        expect(
          find.text(AppLocalizationsEn().loanErrorWriteOffNothingOutstanding),
          findsOneWidget,
        );
        expect(find.textContaining('LOAN_WRITE_OFF_NOTHING'), findsNothing);
      },
    );
  });

  group('Written-off Loan Detail', () {
    testWidgets('shows the WRITTEN OFF badge, write-off summary, remaining '
        'recoverable, and recovery history, with server figures rendered '
        'exactly', (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'WRITTEN_OFF')
        ..nextWriteOffSummary = fakeLoanWriteOffSummary(
          loanAccountId: 'loan-1',
          writeOff: fakeLoanWriteOffEvent(
            principalAmount: 200000,
            interestAmount: 15000,
            penaltyAmount: 5000,
          ),
          remainingRecoverable: const LoanRecoveryComponentAmounts(
            principal: 150000,
            interest: 0,
            penalty: 0,
            total: 150000,
          ),
          recoveries: [
            fakeLoanRecoveryHistoryEntry(
              id: 'recovery-1',
              receiptNumber: 'RCT-1001',
              principalRecovered: 50000,
              interestRecovered: 15000,
              penaltyRecovered: 5000,
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

      expect(find.byKey(const Key('loanAccountStatusBadge')), findsOneWidget);
      expect(
        find.text(AppLocalizationsEn().loanStatusWrittenOff),
        findsOneWidget,
      );
      expect(find.byKey(const Key('loanWriteOffSummaryCard')), findsOneWidget);
      // Total written off (200000+15000+5000) and remaining recoverable.
      expect(find.text('220,000'), findsOneWidget);
      expect(find.text('150,000'), findsWidgets);
      expect(find.byKey(const Key('loanRecoveryHistoryCard')), findsOneWidget);
      expect(find.text('RCT-1001'), findsOneWidget);
    });

    testWidgets('the ordinary schedule/history sections remain visible for a '
        'WRITTEN_OFF loan (historical records are never hidden)', (
      tester,
    ) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'WRITTEN_OFF')
        ..nextWriteOffSummary = fakeLoanWriteOffSummary(
          loanAccountId: 'loan-1',
        );

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      expect(find.text(AppLocalizationsEn().loanScheduleTitle), findsOneWidget);
      // findsWidgets (not findsOneWidget): with an empty adjustment
      // history this title legitimately renders twice — once as the
      // section header, once again as the empty-state's own title
      // (pre-existing 09F-A behavior, unrelated to write-off/recovery).
      expect(
        find.text(AppLocalizationsEn().loanObligationHistoryTitle),
        findsWidgets,
      );
    });

    testWidgets(
      'an empty recovery history shows the empty state, not an error',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'WRITTEN_OFF')
          ..nextWriteOffSummary = fakeLoanWriteOffSummary(
            loanAccountId: 'loan-1',
            recoveries: const [],
          );

        final router = await pumpLoansApp(
          tester,
          fakeRepo: fakeRepo,
          language: AppLanguage.english,
        );
        router.push(AppRoutes.loanAccountDetailPath('loan-1'));
        await tester.pumpAndSettle();

        expect(
          find.text(AppLocalizationsEn().loanRecoveryHistoryEmptyMessage),
          findsOneWidget,
        );
      },
    );
  });

  group('Recovery screen', () {
    testWidgets(
      'preview renders PENALTY/INTEREST/PRINCIPAL allocation separately, '
      'from the server response — never recomputed client-side; confirm '
      'posts the exact amount/account/method',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'WRITTEN_OFF')
          ..nextRecoveryPreview = fakeLoanRecoveryPreview(
            loanAccountId: 'loan-1',
            writeOffTotalAmount: 220000,
            amount: 15000,
            penaltyRemainingBefore: 5000,
            interestRemainingBefore: 15000,
            principalRemainingBefore: 200000,
          );

        final router = await pumpLoansApp(
          tester,
          fakeRepo: fakeRepo,
          language: AppLanguage.english,
        );
        router.push(AppRoutes.loanRecordRecoveryPath('loan-1'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('loanRecoveryAmountField')),
          '15000',
        );
        await tester.tap(find.byKey(const Key('loanRecoveryAccountField')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Main Cash (Cash)').last);
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(const Key('loanRecoveryPreviewAction')),
        );
        await tester.tap(find.byKey(const Key('loanRecoveryPreviewAction')));
        await tester.pumpAndSettle();

        expect(fakeRepo.previewLoanRecoveryCalls.length, 1);
        expect(fakeRepo.previewLoanRecoveryCalls.single.amount, 15000);

        // Allocation: penalty 5000, interest 10000 (15000-5000), principal 0.
        expect(find.textContaining('5,000'), findsWidgets);
        expect(find.textContaining('10,000'), findsWidgets);
        expect(
          find.text(AppLocalizationsEn().loanRecoveryAllocationTitle),
          findsOneWidget,
        );

        await tester.ensureVisible(
          find.byKey(const Key('loanRecoveryConfirmAction')),
        );
        await tester.tap(find.byKey(const Key('loanRecoveryConfirmAction')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(AppLocalizationsEn().loanRecoveryConfirmAction).last,
        );
        await tester.pumpAndSettle();

        expect(fakeRepo.postLoanRecoveryCalls.length, 1);
        expect(fakeRepo.postLoanRecoveryCalls.single.amount, 15000);
        expect(
          fakeRepo.postLoanRecoveryCalls.single.financialAccountId,
          'account-1',
        );
        expect(fakeRepo.postLoanRecoveryCalls.single.paymentMethod, 'CASH');
      },
    );

    testWidgets('a LOAN_RECOVERY_EXCEEDS_REMAINING_BALANCE rejection shows the '
        'friendly localized message', (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'WRITTEN_OFF');

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.push(AppRoutes.loanRecordRecoveryPath('loan-1'));
      await tester.pumpAndSettle();

      fakeRepo.failure = const LoanFailure(
        LoanFailureType.recoveryExceedsRemainingBalance,
        'unused fallback',
      );

      await tester.enterText(
        find.byKey(const Key('loanRecoveryAmountField')),
        '999999',
      );
      await tester.tap(find.byKey(const Key('loanRecoveryPreviewAction')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          AppLocalizationsEn().loanErrorRecoveryExceedsRemainingBalance,
        ),
        findsOneWidget,
      );
    });
  });

  group('Write-off reversal', () {
    testWidgets(
      'an eligible write-off shows Reverse Write-Off for an ADMIN, and '
      'confirming it calls the repository with a reason',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'WRITTEN_OFF')
          ..nextWriteOffSummary = fakeLoanWriteOffSummary(
            loanAccountId: 'loan-1',
            writeOff: fakeLoanWriteOffEvent(id: 'write-off-1'),
          );

        final router = await pumpLoansApp(
          tester,
          fakeRepo: fakeRepo,
          language: AppLanguage.english,
        );
        router.push(AppRoutes.loanAccountDetailPath('loan-1'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('loanReverseWriteOffAction')),
          findsOneWidget,
        );
        await tester.ensureVisible(
          find.byKey(const Key('loanReverseWriteOffAction')),
        );
        await tester.tap(find.byKey(const Key('loanReverseWriteOffAction')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('loanReverseWriteOffReasonField')),
          'Written off in error',
        );
        await tester.tap(
          find.byKey(const Key('loanReverseWriteOffConfirmAction')),
        );
        await tester.pumpAndSettle();

        expect(fakeRepo.reverseLoanWriteOffCalls.length, 1);
        expect(
          fakeRepo.reverseLoanWriteOffCalls.single.writeOffEventId,
          'write-off-1',
        );
        expect(
          fakeRepo.reverseLoanWriteOffCalls.single.reversalReason,
          'Written off in error',
        );
      },
    );

    testWidgets('a reversal blocked by subsequent recovery activity shows the '
        'friendly localized message, never the raw domain code', (
      tester,
    ) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'WRITTEN_OFF')
        ..nextWriteOffSummary = fakeLoanWriteOffSummary(
          loanAccountId: 'loan-1',
          writeOff: fakeLoanWriteOffEvent(id: 'write-off-1'),
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
        find.byKey(const Key('loanReverseWriteOffAction')),
      );
      await tester.tap(find.byKey(const Key('loanReverseWriteOffAction')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('loanReverseWriteOffReasonField')),
        'attempt',
      );
      await tester.tap(
        find.byKey(const Key('loanReverseWriteOffConfirmAction')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          AppLocalizationsEn()
              .loanErrorAdjustmentReversalBlockedSubsequentActivity,
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('LOAN_ADJUSTMENT_REVERSAL_BLOCKED'),
        findsNothing,
      );
    });

    testWidgets('an already-reversed write-off never shows Reverse '
        'Write-Off', (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'WRITTEN_OFF')
        ..nextWriteOffSummary = fakeLoanWriteOffSummary(
          loanAccountId: 'loan-1',
          writeOff: fakeLoanWriteOffEvent(id: 'write-off-1', isReversed: true),
        );

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('loanReverseWriteOffAction')), findsNothing);
    });
  });

  group('Route-target integrity', () {
    testWidgets('the Write Off action from loan A routes to a write-off screen '
        'scoped to loan A, never loan B', (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(id: 'loan-a', status: 'ACTIVE');

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.english,
      );
      router.push(AppRoutes.loanAccountDetailPath('loan-a'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('loanWriteOffAction')));
      await tester.tap(find.byKey(const Key('loanWriteOffAction')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('loanWriteOffPreviewAction')));
      await tester.pumpAndSettle();

      expect(fakeRepo.previewLoanWriteOffCalls.single.loanAccountId, 'loan-a');
    });

    testWidgets(
      'the Record Recovery action from loan A routes to a recovery screen '
      'scoped to loan A, never loan B',
      (tester) async {
        final fakeRepo = FakeLoanRepository()
          ..nextAccount = fakeLoanAccount(id: 'loan-a', status: 'WRITTEN_OFF')
          ..nextWriteOffSummary = fakeLoanWriteOffSummary(
            loanAccountId: 'loan-a',
          );

        final router = await pumpLoansApp(
          tester,
          fakeRepo: fakeRepo,
          language: AppLanguage.english,
        );
        router.push(AppRoutes.loanAccountDetailPath('loan-a'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(const Key('loanRecordRecoveryAction')),
        );
        await tester.tap(find.byKey(const Key('loanRecordRecoveryAction')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('loanRecoveryAmountField')),
          '1000',
        );
        await tester.tap(find.byKey(const Key('loanRecoveryPreviewAction')));
        await tester.pumpAndSettle();

        expect(
          fakeRepo.previewLoanRecoveryCalls.single.loanAccountId,
          'loan-a',
        );
      },
    );
  });

  group('Localization', () {
    testWidgets('SW: the write-off action and warning message are shown', (
      tester,
    ) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'ACTIVE');

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.swahili,
      );
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      expect(
        find.text(AppLocalizationsSw().loanWriteOffAction),
        findsOneWidget,
      );

      await tester.ensureVisible(find.byKey(const Key('loanWriteOffAction')));
      await tester.tap(find.byKey(const Key('loanWriteOffAction')));
      await tester.pumpAndSettle();

      expect(
        find.text(AppLocalizationsSw().loanWriteOffWarningMessage),
        findsWidgets,
      );
    });

    testWidgets('SW: the written-off status label is shown', (tester) async {
      final fakeRepo = FakeLoanRepository()
        ..nextAccount = fakeLoanAccount(id: 'loan-1', status: 'WRITTEN_OFF')
        ..nextWriteOffSummary = fakeLoanWriteOffSummary(
          loanAccountId: 'loan-1',
        );

      final router = await pumpLoansApp(
        tester,
        fakeRepo: fakeRepo,
        language: AppLanguage.swahili,
      );
      router.push(AppRoutes.loanAccountDetailPath('loan-1'));
      await tester.pumpAndSettle();

      expect(
        find.text(AppLocalizationsSw().loanStatusWrittenOff),
        findsOneWidget,
      );
    });
  });
}
