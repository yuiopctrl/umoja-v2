import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../financial_accounts/providers/financial_account_detail_provider.dart';
import '../../financial_accounts/providers/financial_account_entries_provider.dart';
import '../../financial_accounts/providers/financial_accounts_list_provider.dart';
import '../../financial_accounts/providers/financial_position_provider.dart';
import '../data/loan_failure.dart';
import '../domain/loan_account.dart';
import '../providers/loan_account_detail_provider.dart';
import '../providers/loan_accounts_provider.dart';
import '../providers/loan_repository_provider.dart';

final _log = Logger('LoanWorkflowController');

class LoanWorkflowState {
  const LoanWorkflowState({
    this.isSubmitting = false,
    this.errorType,
    this.lastResult,
  });

  final bool isSubmitting;
  final LoanFailureType? errorType;
  final LoanAccount? lastResult;
}

/// Drives every Prompt 09B lifecycle transition — Submit, Approve,
/// Reject, Cancel (SUBMITTED/APPROVED), and Disburse. DRAFT
/// editing/regeneration/cancellation stays on
/// [LoanAccountDraftController]; this controller only ever exists once
/// a loan has left DRAFT (or is leaving it, in Submit's case).
class LoanWorkflowController extends Notifier<LoanWorkflowState> {
  @override
  LoanWorkflowState build() => const LoanWorkflowState();

  Future<bool> submit({
    required String groupId,
    required String loanAccountId,
  }) async {
    if (state.isSubmitting) return false;
    state = const LoanWorkflowState(isSubmitting: true);
    try {
      final result = await ref
          .read(loanRepositoryProvider)
          .submitLoanAccount(groupId: groupId, loanAccountId: loanAccountId);
      ref.invalidate(loanAccountsProvider);
      ref.invalidate(loanAccountDetailProvider(loanAccountId));
      state = LoanWorkflowState(lastResult: result);
      return true;
    } on LoanFailure catch (error) {
      state = LoanWorkflowState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to submit loan account', error, stackTrace);
      state = const LoanWorkflowState(errorType: LoanFailureType.unexpected);
      return false;
    }
  }

  Future<bool> approve({
    required String groupId,
    required String loanAccountId,
  }) async {
    if (state.isSubmitting) return false;
    state = const LoanWorkflowState(isSubmitting: true);
    try {
      final result = await ref
          .read(loanRepositoryProvider)
          .approveLoanAccount(groupId: groupId, loanAccountId: loanAccountId);
      ref.invalidate(loanAccountsProvider);
      ref.invalidate(loanAccountDetailProvider(loanAccountId));
      state = LoanWorkflowState(lastResult: result);
      return true;
    } on LoanFailure catch (error) {
      state = LoanWorkflowState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to approve loan account', error, stackTrace);
      state = const LoanWorkflowState(errorType: LoanFailureType.unexpected);
      return false;
    }
  }

  Future<bool> reject({
    required String groupId,
    required String loanAccountId,
    required String reason,
  }) async {
    if (state.isSubmitting) return false;
    state = const LoanWorkflowState(isSubmitting: true);
    try {
      final result = await ref
          .read(loanRepositoryProvider)
          .rejectLoanAccount(
            groupId: groupId,
            loanAccountId: loanAccountId,
            reason: reason,
          );
      ref.invalidate(loanAccountsProvider);
      ref.invalidate(loanAccountDetailProvider(loanAccountId));
      state = LoanWorkflowState(lastResult: result);
      return true;
    } on LoanFailure catch (error) {
      state = LoanWorkflowState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to reject loan account', error, stackTrace);
      state = const LoanWorkflowState(errorType: LoanFailureType.unexpected);
      return false;
    }
  }

  Future<bool> cancel({
    required String groupId,
    required String loanAccountId,
    required String reason,
  }) async {
    if (state.isSubmitting) return false;
    state = const LoanWorkflowState(isSubmitting: true);
    try {
      final result = await ref
          .read(loanRepositoryProvider)
          .cancelLoanAccount(
            groupId: groupId,
            loanAccountId: loanAccountId,
            reason: reason,
          );
      ref.invalidate(loanAccountsProvider);
      ref.invalidate(loanAccountDetailProvider(loanAccountId));
      state = LoanWorkflowState(lastResult: result);
      return true;
    } on LoanFailure catch (error) {
      state = LoanWorkflowState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to cancel loan account', error, stackTrace);
      state = const LoanWorkflowState(errorType: LoanFailureType.unexpected);
      return false;
    }
  }

  Future<bool> disburse({
    required String groupId,
    required String loanAccountId,
    required String financialAccountId,
    required DateTime effectiveAt,
    String? reference,
    String? notes,
    String? idempotencyKey,
  }) async {
    if (state.isSubmitting) return false;
    state = const LoanWorkflowState(isSubmitting: true);
    try {
      final result = await ref
          .read(loanRepositoryProvider)
          .disburseLoanAccount(
            groupId: groupId,
            loanAccountId: loanAccountId,
            financialAccountId: financialAccountId,
            effectiveAt: effectiveAt,
            reference: reference,
            notes: notes,
            idempotencyKey: idempotencyKey,
          );
      // A disbursement moves real money: every financial read that
      // could now be stale must be invalidated, not only the loan's
      // own providers (section 30) — the affected account's balance,
      // its cashbook, and Financial Position.
      ref.invalidate(loanAccountsProvider);
      ref.invalidate(loanAccountDetailProvider(loanAccountId));
      ref.invalidate(financialAccountsListProvider);
      ref.invalidate(financialAccountsActiveForPickerProvider);
      ref.invalidate(financialAccountDetailProvider(financialAccountId));
      ref.invalidate(financialAccountEntriesProvider);
      ref.invalidate(financialPositionProvider);
      state = LoanWorkflowState(lastResult: result);
      return true;
    } on LoanFailure catch (error) {
      state = LoanWorkflowState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to disburse loan account', error, stackTrace);
      state = const LoanWorkflowState(errorType: LoanFailureType.unexpected);
      return false;
    }
  }

  void reset() => state = const LoanWorkflowState();
}

final loanWorkflowControllerProvider =
    NotifierProvider<LoanWorkflowController, LoanWorkflowState>(
      LoanWorkflowController.new,
    );
