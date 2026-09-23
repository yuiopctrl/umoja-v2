import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../financial_accounts/providers/financial_position_provider.dart';
import '../data/loan_failure.dart';
import '../domain/loan_write_off_recovery.dart';
import '../providers/loan_account_detail_provider.dart';
import '../providers/loan_repository_provider.dart';
import '../providers/loan_write_off_summary_provider.dart';

final _log = Logger('LoanWriteOffRecoveryController');

/// Prompt 09F-B: Write-off and Recovery each follow the SAME mandatory
/// shape as every other 09E/09F-A financial action — Input -> Server
/// Preview -> Review accounting impact -> Confirm/Post — so the
/// preview is cleared the instant any input changes, and posting
/// always independently re-validates/recomputes server-side.

class LoanWriteOffState {
  const LoanWriteOffState({
    this.isPreviewing = false,
    this.isSubmitting = false,
    this.errorType,
    this.preview,
    this.result,
  });

  final bool isPreviewing;
  final bool isSubmitting;
  final LoanFailureType? errorType;
  final LoanWriteOffPreview? preview;
  final LoanWriteOffPostResult? result;
}

class LoanWriteOffController extends Notifier<LoanWriteOffState> {
  @override
  LoanWriteOffState build() => const LoanWriteOffState();

  void invalidatePreview() {
    if (state.preview == null) return;
    state = const LoanWriteOffState();
  }

  Future<bool> preview({
    required String groupId,
    required String loanAccountId,
    required String reasonCode,
    String? note,
  }) async {
    if (state.isPreviewing) return false;
    state = const LoanWriteOffState(isPreviewing: true);
    try {
      final preview = await ref
          .read(loanRepositoryProvider)
          .previewLoanWriteOff(
            groupId: groupId,
            loanAccountId: loanAccountId,
            reasonCode: reasonCode,
            note: note,
          );
      state = LoanWriteOffState(preview: preview);
      return true;
    } on LoanFailure catch (error) {
      state = LoanWriteOffState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to preview loan write-off', error, stackTrace);
      state = const LoanWriteOffState(errorType: LoanFailureType.unexpected);
      return false;
    }
  }

  Future<bool> confirm({
    required String groupId,
    required String loanAccountId,
    required String reasonCode,
    String? note,
    String? idempotencyKey,
  }) async {
    if (state.isSubmitting || state.preview == null) return false;
    state = LoanWriteOffState(isSubmitting: true, preview: state.preview);
    try {
      final result = await ref
          .read(loanRepositoryProvider)
          .postLoanWriteOff(
            groupId: groupId,
            loanAccountId: loanAccountId,
            reasonCode: reasonCode,
            note: note,
            idempotencyKey: idempotencyKey,
          );
      ref.invalidate(loanAccountDetailProvider(loanAccountId));
      ref.invalidate(loanWriteOffSummaryProvider(loanAccountId));
      ref.invalidate(financialPositionProvider);
      state = LoanWriteOffState(result: result);
      return true;
    } on LoanFailure catch (error) {
      state = LoanWriteOffState(errorType: error.type, preview: state.preview);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to post loan write-off', error, stackTrace);
      state = LoanWriteOffState(
        errorType: LoanFailureType.unexpected,
        preview: state.preview,
      );
      return false;
    }
  }
}

final loanWriteOffControllerProvider =
    NotifierProvider<LoanWriteOffController, LoanWriteOffState>(
      LoanWriteOffController.new,
    );

class LoanWriteOffReversalState {
  const LoanWriteOffReversalState({
    this.isSubmitting = false,
    this.errorType,
    this.result,
  });

  final bool isSubmitting;
  final LoanFailureType? errorType;
  final LoanWriteOffReversalResult? result;
}

class LoanWriteOffReversalController
    extends Notifier<LoanWriteOffReversalState> {
  @override
  LoanWriteOffReversalState build() => const LoanWriteOffReversalState();

  Future<bool> reverse({
    required String groupId,
    required String loanAccountId,
    required String writeOffEventId,
    required String reversalReason,
  }) async {
    if (state.isSubmitting) return false;
    state = const LoanWriteOffReversalState(isSubmitting: true);
    try {
      final result = await ref
          .read(loanRepositoryProvider)
          .reverseLoanWriteOff(
            groupId: groupId,
            writeOffEventId: writeOffEventId,
            reversalReason: reversalReason,
          );
      ref.invalidate(loanAccountDetailProvider(loanAccountId));
      ref.invalidate(loanWriteOffSummaryProvider(loanAccountId));
      ref.invalidate(financialPositionProvider);
      state = LoanWriteOffReversalState(result: result);
      return true;
    } on LoanFailure catch (error) {
      state = LoanWriteOffReversalState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to reverse loan write-off', error, stackTrace);
      state = const LoanWriteOffReversalState(
        errorType: LoanFailureType.unexpected,
      );
      return false;
    }
  }
}

final loanWriteOffReversalControllerProvider =
    NotifierProvider<LoanWriteOffReversalController, LoanWriteOffReversalState>(
      LoanWriteOffReversalController.new,
    );

class LoanRecoveryState {
  const LoanRecoveryState({
    this.isPreviewing = false,
    this.isSubmitting = false,
    this.errorType,
    this.preview,
    this.result,
  });

  final bool isPreviewing;
  final bool isSubmitting;
  final LoanFailureType? errorType;
  final LoanRecoveryPreview? preview;
  final LoanRecoveryPostResult? result;
}

class LoanRecoveryController extends Notifier<LoanRecoveryState> {
  @override
  LoanRecoveryState build() => const LoanRecoveryState();

  void invalidatePreview() {
    if (state.preview == null) return;
    state = const LoanRecoveryState();
  }

  Future<bool> preview({
    required String groupId,
    required String loanAccountId,
    required double amount,
  }) async {
    if (state.isPreviewing) return false;
    state = const LoanRecoveryState(isPreviewing: true);
    try {
      final preview = await ref
          .read(loanRepositoryProvider)
          .previewLoanRecovery(
            groupId: groupId,
            loanAccountId: loanAccountId,
            amount: amount,
          );
      state = LoanRecoveryState(preview: preview);
      return true;
    } on LoanFailure catch (error) {
      state = LoanRecoveryState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to preview loan recovery', error, stackTrace);
      state = const LoanRecoveryState(errorType: LoanFailureType.unexpected);
      return false;
    }
  }

  Future<bool> confirm({
    required String groupId,
    required String loanAccountId,
    required double amount,
    required String financialAccountId,
    required String paymentMethod,
    String? externalReference,
    String? notes,
    String? idempotencyKey,
  }) async {
    if (state.isSubmitting || state.preview == null) return false;
    state = LoanRecoveryState(isSubmitting: true, preview: state.preview);
    try {
      final result = await ref
          .read(loanRepositoryProvider)
          .postLoanRecovery(
            groupId: groupId,
            loanAccountId: loanAccountId,
            amount: amount,
            financialAccountId: financialAccountId,
            paymentMethod: paymentMethod,
            externalReference: externalReference,
            notes: notes,
            idempotencyKey: idempotencyKey,
          );
      ref.invalidate(loanAccountDetailProvider(loanAccountId));
      ref.invalidate(loanWriteOffSummaryProvider(loanAccountId));
      ref.invalidate(financialPositionProvider);
      state = LoanRecoveryState(result: result);
      return true;
    } on LoanFailure catch (error) {
      state = LoanRecoveryState(errorType: error.type, preview: state.preview);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to post loan recovery', error, stackTrace);
      state = LoanRecoveryState(
        errorType: LoanFailureType.unexpected,
        preview: state.preview,
      );
      return false;
    }
  }
}

final loanRecoveryControllerProvider =
    NotifierProvider<LoanRecoveryController, LoanRecoveryState>(
      LoanRecoveryController.new,
    );
