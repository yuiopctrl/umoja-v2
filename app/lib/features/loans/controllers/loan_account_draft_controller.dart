import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../data/loan_failure.dart';
import '../domain/loan_account.dart';
import '../domain/loan_schedule_preview.dart';
import '../providers/loan_account_detail_provider.dart';
import '../providers/loan_accounts_provider.dart';
import '../providers/loan_repository_provider.dart';

final _log = Logger('LoanAccountDraftController');

class LoanAccountDraftState {
  const LoanAccountDraftState({
    this.isPreviewing = false,
    this.isSubmitting = false,
    this.errorType,
    this.preview,
    this.lastResult,
  });

  final bool isPreviewing;
  final bool isSubmitting;
  final LoanFailureType? errorType;

  /// The server-computed schedule for the New Loan flow's "Schedule
  /// Preview" step (section W step 4) — never persisted until
  /// [createDraft] is called with the same terms.
  final LoanSchedulePreview? preview;
  final LoanAccount? lastResult;
}

/// Drives the New Loan draft workflow (Prompt 09A section W) and all
/// subsequent DRAFT-only mutations (edit terms, regenerate schedule,
/// cancel). No approval/disbursement/repayment action exists on this
/// controller — those belong to a later phase.
class LoanAccountDraftController extends Notifier<LoanAccountDraftState> {
  @override
  LoanAccountDraftState build() => const LoanAccountDraftState();

  Future<bool> preview({
    required String groupId,
    required String loanProductId,
    required double principalAmount,
    required int term,
    required DateTime firstRepaymentDate,
  }) async {
    if (state.isPreviewing) return false;

    state = const LoanAccountDraftState(isPreviewing: true);
    try {
      final result = await ref
          .read(loanRepositoryProvider)
          .previewLoanSchedule(
            groupId: groupId,
            loanProductId: loanProductId,
            principalAmount: principalAmount,
            term: term,
            firstRepaymentDate: firstRepaymentDate,
          );
      state = LoanAccountDraftState(preview: result);
      return true;
    } on LoanFailure catch (error) {
      state = LoanAccountDraftState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to preview loan schedule', error, stackTrace);
      state = const LoanAccountDraftState(
        errorType: LoanFailureType.unexpected,
      );
      return false;
    }
  }

  Future<bool> createDraft({
    required String groupId,
    required String membershipId,
    required String loanProductId,
    required double principalAmount,
    required int term,
    required DateTime firstRepaymentDate,
    DateTime? proposedDisbursementDate,
  }) async {
    if (state.isSubmitting) return false;

    state = LoanAccountDraftState(isSubmitting: true, preview: state.preview);
    try {
      final result = await ref
          .read(loanRepositoryProvider)
          .createDraftLoanAccount(
            groupId: groupId,
            membershipId: membershipId,
            loanProductId: loanProductId,
            principalAmount: principalAmount,
            term: term,
            firstRepaymentDate: firstRepaymentDate,
            proposedDisbursementDate: proposedDisbursementDate,
          );
      ref.invalidate(loanAccountsProvider);
      state = LoanAccountDraftState(lastResult: result);
      return true;
    } on LoanFailure catch (error) {
      state = LoanAccountDraftState(
        errorType: error.type,
        preview: state.preview,
      );
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to create draft loan account', error, stackTrace);
      state = LoanAccountDraftState(
        errorType: LoanFailureType.unexpected,
        preview: state.preview,
      );
      return false;
    }
  }

  Future<bool> updateTerms({
    required String groupId,
    required String loanAccountId,
    double? principalAmount,
    int? term,
    DateTime? firstRepaymentDate,
    DateTime? proposedDisbursementDate,
  }) async {
    if (state.isSubmitting) return false;

    state = const LoanAccountDraftState(isSubmitting: true);
    try {
      final result = await ref
          .read(loanRepositoryProvider)
          .updateDraftLoanTerms(
            groupId: groupId,
            loanAccountId: loanAccountId,
            principalAmount: principalAmount,
            term: term,
            firstRepaymentDate: firstRepaymentDate,
            proposedDisbursementDate: proposedDisbursementDate,
          );
      ref.invalidate(loanAccountsProvider);
      ref.invalidate(loanAccountDetailProvider(loanAccountId));
      state = LoanAccountDraftState(lastResult: result);
      return true;
    } on LoanFailure catch (error) {
      state = LoanAccountDraftState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to update draft loan terms', error, stackTrace);
      state = const LoanAccountDraftState(
        errorType: LoanFailureType.unexpected,
      );
      return false;
    }
  }

  Future<bool> regenerateSchedule({
    required String groupId,
    required String loanAccountId,
  }) async {
    if (state.isSubmitting) return false;

    state = const LoanAccountDraftState(isSubmitting: true);
    try {
      final result = await ref
          .read(loanRepositoryProvider)
          .regenerateLoanSchedule(
            groupId: groupId,
            loanAccountId: loanAccountId,
          );
      ref.invalidate(loanAccountDetailProvider(loanAccountId));
      state = LoanAccountDraftState(lastResult: result);
      return true;
    } on LoanFailure catch (error) {
      state = LoanAccountDraftState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to regenerate loan schedule', error, stackTrace);
      state = const LoanAccountDraftState(
        errorType: LoanFailureType.unexpected,
      );
      return false;
    }
  }

  Future<bool> cancelDraft({
    required String groupId,
    required String loanAccountId,
  }) async {
    if (state.isSubmitting) return false;

    state = const LoanAccountDraftState(isSubmitting: true);
    try {
      final result = await ref
          .read(loanRepositoryProvider)
          .cancelDraftLoanAccount(
            groupId: groupId,
            loanAccountId: loanAccountId,
          );
      ref.invalidate(loanAccountsProvider);
      ref.invalidate(loanAccountDetailProvider(loanAccountId));
      state = LoanAccountDraftState(lastResult: result);
      return true;
    } on LoanFailure catch (error) {
      state = LoanAccountDraftState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to cancel draft loan account', error, stackTrace);
      state = const LoanAccountDraftState(
        errorType: LoanFailureType.unexpected,
      );
      return false;
    }
  }

  void reset() => state = const LoanAccountDraftState();
}

final loanAccountDraftControllerProvider =
    NotifierProvider<LoanAccountDraftController, LoanAccountDraftState>(
      LoanAccountDraftController.new,
    );
