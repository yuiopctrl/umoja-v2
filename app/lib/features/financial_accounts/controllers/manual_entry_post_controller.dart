import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../data/financial_account_failure.dart';
import '../domain/financial_manual_entry.dart';
import '../providers/financial_account_detail_provider.dart';
import '../providers/financial_account_entries_provider.dart';
import '../providers/financial_account_repository_provider.dart';
import '../providers/financial_accounts_list_provider.dart';
import '../providers/financial_position_provider.dart';

final _log = Logger('ManualEntryPostController');

class ManualEntryPostState {
  const ManualEntryPostState({
    this.isSubmitting = false,
    this.errorType,
    this.result,
  });

  final bool isSubmitting;
  final FinancialAccountFailureType? errorType;
  final FinancialManualEntryPostResult? result;
}

/// Drives `rpc_record_manual_income`/`rpc_record_expense` (Prompt 08B —
/// sections 4/5). Shares one state class between both since they are
/// the same "post a manual cashbook entry" concern with only the
/// backend RPC/permission/category-type differing — mirrors how
/// `financial_account_entries.entry_type` already carries direction in
/// one table rather than two.
class ManualEntryPostController extends Notifier<ManualEntryPostState> {
  @override
  ManualEntryPostState build() => const ManualEntryPostState();

  Future<bool> postIncome({
    required String groupId,
    required String financialAccountId,
    required String categoryId,
    required double amount,
    required DateTime effectiveAt,
    String? description,
    String? reference,
    String? idempotencyKey,
  }) => _post(
    () => ref
        .read(financialAccountRepositoryProvider)
        .recordManualIncome(
          groupId: groupId,
          financialAccountId: financialAccountId,
          categoryId: categoryId,
          amount: amount,
          effectiveAt: effectiveAt,
          description: description,
          reference: reference,
          idempotencyKey: idempotencyKey,
        ),
    financialAccountId: financialAccountId,
    logMessage: 'Failed to record manual income',
  );

  Future<bool> postExpense({
    required String groupId,
    required String financialAccountId,
    required String categoryId,
    required double amount,
    required DateTime effectiveAt,
    String? description,
    String? reference,
    String? idempotencyKey,
  }) => _post(
    () => ref
        .read(financialAccountRepositoryProvider)
        .recordExpense(
          groupId: groupId,
          financialAccountId: financialAccountId,
          categoryId: categoryId,
          amount: amount,
          effectiveAt: effectiveAt,
          description: description,
          reference: reference,
          idempotencyKey: idempotencyKey,
        ),
    financialAccountId: financialAccountId,
    logMessage: 'Failed to record expense',
  );

  Future<bool> _post(
    Future<FinancialManualEntryPostResult> Function() call, {
    required String financialAccountId,
    required String logMessage,
  }) async {
    if (state.isSubmitting) return false;

    state = const ManualEntryPostState(isSubmitting: true);
    try {
      final result = await call();
      ref.invalidate(financialAccountDetailProvider(financialAccountId));
      ref.invalidate(financialAccountEntriesProvider);
      ref.invalidate(financialAccountsListProvider);
      ref.invalidate(financialPositionProvider);
      state = ManualEntryPostState(result: result);
      return true;
    } on FinancialAccountFailure catch (error) {
      state = ManualEntryPostState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning(logMessage, error, stackTrace);
      state = const ManualEntryPostState(
        errorType: FinancialAccountFailureType.unexpected,
      );
      return false;
    }
  }
}

final manualEntryPostControllerProvider =
    NotifierProvider<ManualEntryPostController, ManualEntryPostState>(
      ManualEntryPostController.new,
    );
