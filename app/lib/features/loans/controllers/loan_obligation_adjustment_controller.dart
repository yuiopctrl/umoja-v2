import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../financial_accounts/providers/financial_position_provider.dart';
import '../data/loan_failure.dart';
import '../domain/loan_obligation_adjustment.dart';
import '../providers/loan_account_detail_provider.dart';
import '../providers/loan_obligation_adjustments_provider.dart';
import '../providers/loan_penalty_charges_provider.dart';
import '../providers/loan_repository_provider.dart';

final _log = Logger('LoanObligationAdjustmentController');

/// Prompt 09F-A: Waiver and Correction each follow the SAME mandatory
/// shape as every other 09E servicing action — Input -> Server Preview
/// -> Review accounting impact -> Confirm/Post — so the preview is
/// cleared the instant any input changes, and posting always
/// independently re-validates/recomputes server-side.

class LoanObligationWaiverState {
  const LoanObligationWaiverState({
    this.isPreviewing = false,
    this.isSubmitting = false,
    this.errorType,
    this.preview,
    this.result,
  });

  final bool isPreviewing;
  final bool isSubmitting;
  final LoanFailureType? errorType;
  final LoanObligationWaiverPreview? preview;
  final LoanObligationAdjustmentPostResult? result;
}

class LoanObligationWaiverController
    extends Notifier<LoanObligationWaiverState> {
  @override
  LoanObligationWaiverState build() => const LoanObligationWaiverState();

  void invalidatePreview() {
    if (state.preview == null) return;
    state = const LoanObligationWaiverState();
  }

  Future<bool> preview({
    required String groupId,
    required String loanAccountId,
    required String targetType,
    required String targetId,
    required double amount,
    required String reasonCode,
    String? note,
  }) async {
    if (state.isPreviewing) return false;
    state = const LoanObligationWaiverState(isPreviewing: true);
    try {
      final preview = await ref
          .read(loanRepositoryProvider)
          .previewLoanObligationWaiver(
            groupId: groupId,
            loanAccountId: loanAccountId,
            targetType: targetType,
            targetId: targetId,
            amount: amount,
            reasonCode: reasonCode,
            note: note,
          );
      state = LoanObligationWaiverState(preview: preview);
      return true;
    } on LoanFailure catch (error) {
      state = LoanObligationWaiverState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning(
        'Failed to preview loan obligation waiver',
        error,
        stackTrace,
      );
      state = const LoanObligationWaiverState(
        errorType: LoanFailureType.unexpected,
      );
      return false;
    }
  }

  Future<bool> confirm({
    required String groupId,
    required String loanAccountId,
    required String targetType,
    required String targetId,
    required double amount,
    required String reasonCode,
    String? note,
    String? idempotencyKey,
  }) async {
    if (state.isSubmitting || state.preview == null) return false;
    state = LoanObligationWaiverState(
      isSubmitting: true,
      preview: state.preview,
    );
    try {
      final result = await ref
          .read(loanRepositoryProvider)
          .postLoanObligationWaiver(
            groupId: groupId,
            loanAccountId: loanAccountId,
            targetType: targetType,
            targetId: targetId,
            amount: amount,
            reasonCode: reasonCode,
            note: note,
            idempotencyKey: idempotencyKey,
          );
      ref.invalidate(loanAccountDetailProvider(loanAccountId));
      ref.invalidate(loanPenaltyChargesProvider(loanAccountId));
      ref.invalidate(loanObligationAdjustmentsProvider(loanAccountId));
      ref.invalidate(financialPositionProvider);
      state = LoanObligationWaiverState(result: result);
      return true;
    } on LoanFailure catch (error) {
      state = LoanObligationWaiverState(
        errorType: error.type,
        preview: state.preview,
      );
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to post loan obligation waiver', error, stackTrace);
      state = LoanObligationWaiverState(
        errorType: LoanFailureType.unexpected,
        preview: state.preview,
      );
      return false;
    }
  }
}

final loanObligationWaiverControllerProvider =
    NotifierProvider<LoanObligationWaiverController, LoanObligationWaiverState>(
      LoanObligationWaiverController.new,
    );

class LoanObligationCorrectionState {
  const LoanObligationCorrectionState({
    this.isPreviewing = false,
    this.isSubmitting = false,
    this.errorType,
    this.preview,
    this.result,
  });

  final bool isPreviewing;
  final bool isSubmitting;
  final LoanFailureType? errorType;
  final LoanObligationCorrectionPreview? preview;
  final LoanObligationAdjustmentPostResult? result;
}

class LoanObligationCorrectionController
    extends Notifier<LoanObligationCorrectionState> {
  @override
  LoanObligationCorrectionState build() =>
      const LoanObligationCorrectionState();

  void invalidatePreview() {
    if (state.preview == null) return;
    state = const LoanObligationCorrectionState();
  }

  Future<bool> preview({
    required String groupId,
    required String loanAccountId,
    required String targetType,
    required String targetId,
    required String adjustmentType,
    required double amount,
    required String reasonCode,
    String? note,
  }) async {
    if (state.isPreviewing) return false;
    state = const LoanObligationCorrectionState(isPreviewing: true);
    try {
      final preview = await ref
          .read(loanRepositoryProvider)
          .previewLoanObligationCorrection(
            groupId: groupId,
            loanAccountId: loanAccountId,
            targetType: targetType,
            targetId: targetId,
            adjustmentType: adjustmentType,
            amount: amount,
            reasonCode: reasonCode,
            note: note,
          );
      state = LoanObligationCorrectionState(preview: preview);
      return true;
    } on LoanFailure catch (error) {
      state = LoanObligationCorrectionState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning(
        'Failed to preview loan obligation correction',
        error,
        stackTrace,
      );
      state = const LoanObligationCorrectionState(
        errorType: LoanFailureType.unexpected,
      );
      return false;
    }
  }

  Future<bool> confirm({
    required String groupId,
    required String loanAccountId,
    required String targetType,
    required String targetId,
    required String adjustmentType,
    required double amount,
    required String reasonCode,
    String? note,
    String? idempotencyKey,
  }) async {
    if (state.isSubmitting || state.preview == null) return false;
    state = LoanObligationCorrectionState(
      isSubmitting: true,
      preview: state.preview,
    );
    try {
      final result = await ref
          .read(loanRepositoryProvider)
          .postLoanObligationCorrection(
            groupId: groupId,
            loanAccountId: loanAccountId,
            targetType: targetType,
            targetId: targetId,
            adjustmentType: adjustmentType,
            amount: amount,
            reasonCode: reasonCode,
            note: note,
            idempotencyKey: idempotencyKey,
          );
      ref.invalidate(loanAccountDetailProvider(loanAccountId));
      ref.invalidate(loanPenaltyChargesProvider(loanAccountId));
      ref.invalidate(loanObligationAdjustmentsProvider(loanAccountId));
      ref.invalidate(financialPositionProvider);
      state = LoanObligationCorrectionState(result: result);
      return true;
    } on LoanFailure catch (error) {
      state = LoanObligationCorrectionState(
        errorType: error.type,
        preview: state.preview,
      );
      return false;
    } catch (error, stackTrace) {
      _log.warning(
        'Failed to post loan obligation correction',
        error,
        stackTrace,
      );
      state = LoanObligationCorrectionState(
        errorType: LoanFailureType.unexpected,
        preview: state.preview,
      );
      return false;
    }
  }
}

final loanObligationCorrectionControllerProvider =
    NotifierProvider<
      LoanObligationCorrectionController,
      LoanObligationCorrectionState
    >(LoanObligationCorrectionController.new);

class LoanObligationAdjustmentReversalState {
  const LoanObligationAdjustmentReversalState({
    this.isSubmitting = false,
    this.errorType,
    this.result,
  });

  final bool isSubmitting;
  final LoanFailureType? errorType;
  final LoanObligationAdjustmentReversalResult? result;
}

class LoanObligationAdjustmentReversalController
    extends Notifier<LoanObligationAdjustmentReversalState> {
  @override
  LoanObligationAdjustmentReversalState build() =>
      const LoanObligationAdjustmentReversalState();

  Future<bool> reverse({
    required String groupId,
    required String loanAccountId,
    required String adjustmentId,
    required String reversalReason,
  }) async {
    if (state.isSubmitting) return false;
    state = const LoanObligationAdjustmentReversalState(isSubmitting: true);
    try {
      final result = await ref
          .read(loanRepositoryProvider)
          .reverseLoanObligationAdjustment(
            groupId: groupId,
            adjustmentId: adjustmentId,
            reversalReason: reversalReason,
          );
      ref.invalidate(loanAccountDetailProvider(loanAccountId));
      ref.invalidate(loanPenaltyChargesProvider(loanAccountId));
      ref.invalidate(loanObligationAdjustmentsProvider(loanAccountId));
      ref.invalidate(financialPositionProvider);
      state = LoanObligationAdjustmentReversalState(result: result);
      return true;
    } on LoanFailure catch (error) {
      state = LoanObligationAdjustmentReversalState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning(
        'Failed to reverse loan obligation adjustment',
        error,
        stackTrace,
      );
      state = const LoanObligationAdjustmentReversalState(
        errorType: LoanFailureType.unexpected,
      );
      return false;
    }
  }
}

final loanObligationAdjustmentReversalControllerProvider =
    NotifierProvider<
      LoanObligationAdjustmentReversalController,
      LoanObligationAdjustmentReversalState
    >(LoanObligationAdjustmentReversalController.new);
