import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/loans/controllers/loan_write_off_recovery_controller.dart';
import 'package:umoja/features/loans/data/loan_failure.dart';
import 'package:umoja/features/loans/providers/loan_repository_provider.dart';

import 'fakes/fake_loan_repository.dart';

/// Prompt 09F-B: controller-level coverage for double-submit
/// prevention and preview invalidation — the same guard shape as every
/// other 09E/09F-A financial-action controller
/// (`if (state.isSubmitting || state.preview == null) return false;`).
void main() {
  late FakeLoanRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    fakeRepo = FakeLoanRepository();
    container = ProviderContainer(
      overrides: [loanRepositoryProvider.overrideWithValue(fakeRepo)],
    );
    addTearDown(container.dispose);
  });

  group('LoanWriteOffController', () {
    test('confirm() is a no-op without a preview first', () async {
      final ok = await container
          .read(loanWriteOffControllerProvider.notifier)
          .confirm(
            groupId: 'g1',
            loanAccountId: 'loan-1',
            reasonCode: 'PROLONGED_DEFAULT',
          );

      expect(ok, isFalse);
      expect(fakeRepo.postLoanWriteOffCalls, isEmpty);
    });

    test(
      'a second concurrent confirm() call while the first is still in '
      'flight is rejected, so only one post ever reaches the repository',
      () async {
        final postGate = Completer<void>();
        fakeRepo.postLoanWriteOffGate = postGate;

        await container
            .read(loanWriteOffControllerProvider.notifier)
            .preview(
              groupId: 'g1',
              loanAccountId: 'loan-1',
              reasonCode: 'PROLONGED_DEFAULT',
            );

        final first = container
            .read(loanWriteOffControllerProvider.notifier)
            .confirm(
              groupId: 'g1',
              loanAccountId: 'loan-1',
              reasonCode: 'PROLONGED_DEFAULT',
            );
        // The first confirm() is now in flight (isSubmitting == true) —
        // a second call must be rejected immediately, before the first
        // one's repository call even completes.
        final second = await container
            .read(loanWriteOffControllerProvider.notifier)
            .confirm(
              groupId: 'g1',
              loanAccountId: 'loan-1',
              reasonCode: 'PROLONGED_DEFAULT',
            );

        expect(second, isFalse);
        postGate.complete();
        final firstResult = await first;
        expect(firstResult, isTrue);
        expect(fakeRepo.postLoanWriteOffCalls.length, 1);
      },
    );

    test(
      'invalidatePreview() clears a stale preview back to input phase',
      () async {
        await container
            .read(loanWriteOffControllerProvider.notifier)
            .preview(
              groupId: 'g1',
              loanAccountId: 'loan-1',
              reasonCode: 'PROLONGED_DEFAULT',
            );
        expect(
          container.read(loanWriteOffControllerProvider).preview,
          isNotNull,
        );

        container
            .read(loanWriteOffControllerProvider.notifier)
            .invalidatePreview();

        expect(container.read(loanWriteOffControllerProvider).preview, isNull);
      },
    );

    test('a LOAN_WRITE_OFF_NOTHING_OUTSTANDING failure surfaces the '
        'dedicated failure type', () async {
      fakeRepo.failure = const LoanFailure(
        LoanFailureType.writeOffNothingOutstanding,
        'unused fallback',
      );

      final ok = await container
          .read(loanWriteOffControllerProvider.notifier)
          .preview(
            groupId: 'g1',
            loanAccountId: 'loan-1',
            reasonCode: 'PROLONGED_DEFAULT',
          );

      expect(ok, isFalse);
      expect(
        container.read(loanWriteOffControllerProvider).errorType,
        LoanFailureType.writeOffNothingOutstanding,
      );
    });
  });

  group('LoanRecoveryController', () {
    test('confirm() is a no-op without a preview first', () async {
      final ok = await container
          .read(loanRecoveryControllerProvider.notifier)
          .confirm(
            groupId: 'g1',
            loanAccountId: 'loan-1',
            amount: 10000,
            financialAccountId: 'account-1',
            paymentMethod: 'CASH',
          );

      expect(ok, isFalse);
      expect(fakeRepo.postLoanRecoveryCalls, isEmpty);
    });

    test('a second concurrent confirm() call while the first is still in '
        'flight is rejected, so only one recovery is ever posted', () async {
      final postGate = Completer<void>();
      fakeRepo.postLoanRecoveryGate = postGate;

      await container
          .read(loanRecoveryControllerProvider.notifier)
          .preview(groupId: 'g1', loanAccountId: 'loan-1', amount: 10000);

      final first = container
          .read(loanRecoveryControllerProvider.notifier)
          .confirm(
            groupId: 'g1',
            loanAccountId: 'loan-1',
            amount: 10000,
            financialAccountId: 'account-1',
            paymentMethod: 'CASH',
          );
      final second = await container
          .read(loanRecoveryControllerProvider.notifier)
          .confirm(
            groupId: 'g1',
            loanAccountId: 'loan-1',
            amount: 10000,
            financialAccountId: 'account-1',
            paymentMethod: 'CASH',
          );

      expect(second, isFalse);
      postGate.complete();
      final firstResult = await first;
      expect(firstResult, isTrue);
      expect(fakeRepo.postLoanRecoveryCalls.length, 1);
    });

    test('an amount change invalidates a stale preview', () async {
      await container
          .read(loanRecoveryControllerProvider.notifier)
          .preview(groupId: 'g1', loanAccountId: 'loan-1', amount: 10000);
      expect(container.read(loanRecoveryControllerProvider).preview, isNotNull);

      container
          .read(loanRecoveryControllerProvider.notifier)
          .invalidatePreview();

      expect(container.read(loanRecoveryControllerProvider).preview, isNull);
    });
  });

  group('LoanWriteOffReversalController', () {
    test('a second concurrent reverse() call while the first is still in '
        'flight is rejected', () async {
      final reverseGate = Completer<void>();
      fakeRepo.reverseLoanWriteOffGate = reverseGate;

      final first = container
          .read(loanWriteOffReversalControllerProvider.notifier)
          .reverse(
            groupId: 'g1',
            loanAccountId: 'loan-1',
            writeOffEventId: 'write-off-1',
            reversalReason: 'Written off in error',
          );
      final second = await container
          .read(loanWriteOffReversalControllerProvider.notifier)
          .reverse(
            groupId: 'g1',
            loanAccountId: 'loan-1',
            writeOffEventId: 'write-off-1',
            reversalReason: 'Written off in error',
          );

      expect(second, isFalse);
      reverseGate.complete();
      final firstResult = await first;
      expect(firstResult, isTrue);
      expect(fakeRepo.reverseLoanWriteOffCalls.length, 1);
    });

    test('a blocked-by-subsequent-activity failure surfaces the reused '
        '09F-A failure type', () async {
      fakeRepo.failure = const LoanFailure(
        LoanFailureType.adjustmentReversalBlockedSubsequentActivity,
        'unused fallback',
      );

      final ok = await container
          .read(loanWriteOffReversalControllerProvider.notifier)
          .reverse(
            groupId: 'g1',
            loanAccountId: 'loan-1',
            writeOffEventId: 'write-off-1',
            reversalReason: 'attempt',
          );

      expect(ok, isFalse);
      expect(
        container.read(loanWriteOffReversalControllerProvider).errorType,
        LoanFailureType.adjustmentReversalBlockedSubsequentActivity,
      );
    });
  });
}
