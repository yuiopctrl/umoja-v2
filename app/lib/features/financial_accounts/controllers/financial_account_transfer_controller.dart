import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../data/financial_account_failure.dart';
import '../domain/financial_account_transfer_result.dart';
import '../providers/financial_account_detail_provider.dart';
import '../providers/financial_account_entries_provider.dart';
import '../providers/financial_account_repository_provider.dart';
import '../providers/financial_accounts_list_provider.dart';
import '../providers/financial_position_provider.dart';

final _log = Logger('FinancialAccountTransferController');

class FinancialAccountTransferState {
  const FinancialAccountTransferState({
    this.isSubmitting = false,
    this.errorType,
    this.lastResult,
  });

  final bool isSubmitting;
  final FinancialAccountFailureType? errorType;
  final FinancialAccountTransferResult? lastResult;
}

/// Drives `rpc_record_financial_account_transfer` — an internal
/// movement between two of the group's own accounts. Never an
/// external payment path; money never leaves the group.
class FinancialAccountTransferController
    extends Notifier<FinancialAccountTransferState> {
  @override
  FinancialAccountTransferState build() =>
      const FinancialAccountTransferState();

  Future<bool> transfer({
    required String groupId,
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    DateTime? effectiveAt,
    String? description,
    String? reference,
    String? idempotencyKey,
  }) async {
    if (state.isSubmitting) return false;

    state = const FinancialAccountTransferState(isSubmitting: true);
    try {
      final result = await ref
          .read(financialAccountRepositoryProvider)
          .recordFinancialAccountTransfer(
            groupId: groupId,
            fromAccountId: fromAccountId,
            toAccountId: toAccountId,
            amount: amount,
            effectiveAt: effectiveAt,
            description: description,
            reference: reference,
            idempotencyKey: idempotencyKey,
          );
      ref.invalidate(financialAccountsListProvider);
      ref.invalidate(financialAccountsActiveForPickerProvider);
      ref.invalidate(financialAccountDetailProvider(fromAccountId));
      ref.invalidate(financialAccountDetailProvider(toAccountId));
      ref.invalidate(financialAccountEntriesProvider);
      ref.invalidate(financialPositionProvider);
      state = FinancialAccountTransferState(lastResult: result);
      return true;
    } on FinancialAccountFailure catch (error) {
      state = FinancialAccountTransferState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning(
        'Failed to record financial account transfer',
        error,
        stackTrace,
      );
      state = const FinancialAccountTransferState(
        errorType: FinancialAccountFailureType.unexpected,
      );
      return false;
    }
  }
}

final financialAccountTransferControllerProvider =
    NotifierProvider<
      FinancialAccountTransferController,
      FinancialAccountTransferState
    >(FinancialAccountTransferController.new);
