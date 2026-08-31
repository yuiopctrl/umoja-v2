import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../data/financial_account_failure.dart';
import '../providers/financial_account_detail_provider.dart';
import '../providers/financial_account_entries_provider.dart';
import '../providers/financial_account_repository_provider.dart';
import '../providers/financial_accounts_list_provider.dart';
import '../providers/financial_manual_entry_detail_provider.dart';
import '../providers/financial_position_provider.dart';

final _log = Logger('FinancialEntryReversalController');

class FinancialEntryReversalState {
  const FinancialEntryReversalState({
    this.isSubmitting = false,
    this.errorType,
  });

  final bool isSubmitting;
  final FinancialAccountFailureType? errorType;
}

/// Drives `rpc_reverse_financial_manual_entry` (Prompt 08B, section
/// 13) — never edits/deletes the original manual income/expense entry;
/// posts one compensating cashbook entry in the opposite direction.
class FinancialEntryReversalController
    extends Notifier<FinancialEntryReversalState> {
  @override
  FinancialEntryReversalState build() => const FinancialEntryReversalState();

  Future<bool> reverse({
    required String groupId,
    required String entryId,
    required String financialAccountId,
    required String reversalReason,
  }) async {
    if (state.isSubmitting) return false;

    state = const FinancialEntryReversalState(isSubmitting: true);
    try {
      await ref
          .read(financialAccountRepositoryProvider)
          .reverseFinancialManualEntry(
            groupId: groupId,
            entryId: entryId,
            reversalReason: reversalReason,
          );

      ref.invalidate(financialManualEntryDetailProvider(entryId));
      ref.invalidate(financialAccountDetailProvider(financialAccountId));
      ref.invalidate(financialAccountEntriesProvider);
      ref.invalidate(financialAccountsListProvider);
      ref.invalidate(financialPositionProvider);
      state = const FinancialEntryReversalState();
      return true;
    } on FinancialAccountFailure catch (error) {
      state = FinancialEntryReversalState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to reverse financial entry', error, stackTrace);
      state = const FinancialEntryReversalState(
        errorType: FinancialAccountFailureType.unexpected,
      );
      return false;
    }
  }
}

final financialEntryReversalControllerProvider =
    NotifierProvider<
      FinancialEntryReversalController,
      FinancialEntryReversalState
    >(FinancialEntryReversalController.new);
