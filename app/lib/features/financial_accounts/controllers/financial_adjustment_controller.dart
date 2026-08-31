import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../data/financial_account_failure.dart';
import '../domain/financial_adjustment_result.dart';
import '../providers/financial_account_detail_provider.dart';
import '../providers/financial_account_entries_provider.dart';
import '../providers/financial_account_repository_provider.dart';
import '../providers/financial_accounts_list_provider.dart';
import '../providers/financial_position_provider.dart';

final _log = Logger('FinancialAdjustmentController');

class FinancialAdjustmentState {
  const FinancialAdjustmentState({
    this.isSubmitting = false,
    this.errorType,
    this.lastResult,
  });

  final bool isSubmitting;
  final FinancialAccountFailureType? errorType;
  final FinancialAdjustmentResult? lastResult;
}

/// Drives `rpc_record_financial_adjustment` (Prompt 08B, section 18) —
/// a controlled, explicit correction for a verified real-world
/// discrepancy. Never counted as ordinary income/expense.
class FinancialAdjustmentController extends Notifier<FinancialAdjustmentState> {
  @override
  FinancialAdjustmentState build() => const FinancialAdjustmentState();

  Future<bool> record({
    required String groupId,
    required String financialAccountId,
    required String direction,
    required double amount,
    required String reason,
    required DateTime effectiveAt,
    String? financialReconciliationId,
    String? idempotencyKey,
  }) async {
    if (state.isSubmitting) return false;

    state = const FinancialAdjustmentState(isSubmitting: true);
    try {
      final result = await ref
          .read(financialAccountRepositoryProvider)
          .recordFinancialAdjustment(
            groupId: groupId,
            financialAccountId: financialAccountId,
            direction: direction,
            amount: amount,
            reason: reason,
            effectiveAt: effectiveAt,
            financialReconciliationId: financialReconciliationId,
            idempotencyKey: idempotencyKey,
          );

      ref.invalidate(financialAccountDetailProvider(financialAccountId));
      ref.invalidate(financialAccountEntriesProvider);
      ref.invalidate(financialAccountsListProvider);
      ref.invalidate(financialPositionProvider);
      state = FinancialAdjustmentState(lastResult: result);
      return true;
    } on FinancialAccountFailure catch (error) {
      state = FinancialAdjustmentState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to record financial adjustment', error, stackTrace);
      state = const FinancialAdjustmentState(
        errorType: FinancialAccountFailureType.unexpected,
      );
      return false;
    }
  }
}

final financialAdjustmentControllerProvider =
    NotifierProvider<FinancialAdjustmentController, FinancialAdjustmentState>(
      FinancialAdjustmentController.new,
    );
