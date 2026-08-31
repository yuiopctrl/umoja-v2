import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../data/financial_account_failure.dart';
import '../domain/financial_reconciliation.dart';
import '../providers/financial_account_reconciliations_provider.dart';
import '../providers/financial_account_repository_provider.dart';

final _log = Logger('FinancialReconciliationController');

class FinancialReconciliationState {
  const FinancialReconciliationState({
    this.isSubmitting = false,
    this.errorType,
    this.lastResult,
  });

  final bool isSubmitting;
  final FinancialAccountFailureType? errorType;
  final FinancialReconciliation? lastResult;
}

/// Drives `rpc_create_financial_reconciliation`/
/// `rpc_cancel_financial_reconciliation` (Prompt 08B, sections 15-19).
/// A reconciliation never posts a cashbook entry of its own — it is a
/// pure comparison/audit record; a non-zero difference is recorded
/// as-is, never auto-corrected.
class FinancialReconciliationController
    extends Notifier<FinancialReconciliationState> {
  @override
  FinancialReconciliationState build() => const FinancialReconciliationState();

  Future<bool> create({
    required String groupId,
    required String financialAccountId,
    required double statedBalance,
    required DateTime reconciliationAt,
    DateTime? periodStart,
    String? notes,
  }) async {
    if (state.isSubmitting) return false;

    state = const FinancialReconciliationState(isSubmitting: true);
    try {
      final result = await ref
          .read(financialAccountRepositoryProvider)
          .createFinancialReconciliation(
            groupId: groupId,
            financialAccountId: financialAccountId,
            statedBalance: statedBalance,
            reconciliationAt: reconciliationAt,
            periodStart: periodStart,
            notes: notes,
          );

      ref.invalidate(financialAccountReconciliationsProvider);
      state = FinancialReconciliationState(lastResult: result);
      return true;
    } on FinancialAccountFailure catch (error) {
      state = FinancialReconciliationState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning(
        'Failed to create financial reconciliation',
        error,
        stackTrace,
      );
      state = const FinancialReconciliationState(
        errorType: FinancialAccountFailureType.unexpected,
      );
      return false;
    }
  }

  Future<bool> cancel({
    required String groupId,
    required String reconciliationId,
    required String cancellationReason,
  }) async {
    if (state.isSubmitting) return false;

    state = const FinancialReconciliationState(isSubmitting: true);
    try {
      await ref
          .read(financialAccountRepositoryProvider)
          .cancelFinancialReconciliation(
            groupId: groupId,
            reconciliationId: reconciliationId,
            cancellationReason: cancellationReason,
          );

      ref.invalidate(financialAccountReconciliationsProvider);
      state = const FinancialReconciliationState();
      return true;
    } on FinancialAccountFailure catch (error) {
      state = FinancialReconciliationState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning(
        'Failed to cancel financial reconciliation',
        error,
        stackTrace,
      );
      state = const FinancialReconciliationState(
        errorType: FinancialAccountFailureType.unexpected,
      );
      return false;
    }
  }
}

final financialReconciliationControllerProvider =
    NotifierProvider<
      FinancialReconciliationController,
      FinancialReconciliationState
    >(FinancialReconciliationController.new);
