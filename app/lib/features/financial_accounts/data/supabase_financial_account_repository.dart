import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/financial_account.dart';
import '../domain/financial_account_entry_page.dart';
import '../domain/financial_account_page.dart';
import '../domain/financial_account_transfer_result.dart';
import '../domain/financial_adjustment_result.dart';
import '../domain/financial_category.dart';
import '../domain/financial_manual_entry.dart';
import '../domain/financial_position.dart';
import '../domain/financial_reconciliation.dart';
import 'financial_account_failure.dart';
import 'financial_account_repository.dart';

final _log = Logger('SupabaseFinancialAccountRepository');

/// [FinancialAccountRepository] backed by the Prompt 08A RPCs. Never
/// inserts/updates the underlying tables directly — those direct
/// grants are revoked server-side.
class SupabaseFinancialAccountRepository implements FinancialAccountRepository {
  SupabaseFinancialAccountRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<FinancialAccountPage> listFinancialAccounts({
    required String groupId,
    bool? isActive,
    String? search,
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_list_financial_accounts',
        params: {
          'p_group_id': groupId,
          'p_is_active': isActive,
          'p_search': (search == null || search.trim().isEmpty)
              ? null
              : search.trim(),
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      return FinancialAccountPage.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<FinancialAccount> getFinancialAccount({
    required String groupId,
    required String accountId,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_get_financial_account',
        params: {'p_group_id': groupId, 'p_account_id': accountId},
      );
      return FinancialAccount.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<FinancialAccount> createFinancialAccount({
    required String groupId,
    required String name,
    required String accountType,
    double? openingBalance,
    DateTime? openingBalanceDate,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_create_financial_account',
        params: {
          'p_group_id': groupId,
          'p_name': name,
          'p_account_type': accountType,
          'p_opening_balance': openingBalance,
          'p_opening_balance_date': _dateOnlyOrNull(openingBalanceDate),
        },
      );
      return FinancialAccount.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<FinancialAccount> updateFinancialAccount({
    required String groupId,
    required String accountId,
    String? name,
    bool? isActive,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_update_financial_account',
        params: {
          'p_group_id': groupId,
          'p_account_id': accountId,
          'p_name': name,
          'p_is_active': isActive,
        },
      );
      return FinancialAccount.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<FinancialAccountTransferResult> recordFinancialAccountTransfer({
    required String groupId,
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    DateTime? effectiveAt,
    String? description,
    String? reference,
    String? idempotencyKey,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_record_financial_account_transfer',
        params: {
          'p_group_id': groupId,
          'p_from_account_id': fromAccountId,
          'p_to_account_id': toAccountId,
          'p_amount': amount,
          'p_effective_at': _dateOnlyOrNull(effectiveAt),
          'p_description': description,
          'p_reference': reference,
          'p_idempotency_key': idempotencyKey,
        },
      );
      return FinancialAccountTransferResult.fromJson(
        result as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<FinancialAccountEntryPage> listFinancialAccountEntries({
    required String groupId,
    required String accountId,
    int limit = 10,
    int offset = 0,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? entryType,
    String? sourceType,
    String? categoryId,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_list_financial_account_entries',
        params: {
          'p_group_id': groupId,
          'p_account_id': accountId,
          'p_limit': limit,
          'p_offset': offset,
          'p_date_from': _dateOnlyOrNull(dateFrom),
          'p_date_to': _dateOnlyOrNull(dateTo),
          'p_entry_type': entryType,
          'p_source_type': sourceType,
          'p_category_id': categoryId,
        },
      );
      return FinancialAccountEntryPage.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<List<FinancialCategory>> listFinancialCategories({
    required String groupId,
    String? categoryType,
    bool? isActive,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_list_financial_categories',
        params: {
          'p_group_id': groupId,
          'p_category_type': categoryType,
          'p_is_active': isActive,
        },
      );
      final items = (result as Map<String, dynamic>)['items'] as List<dynamic>;
      return items
          .map(
            (item) => FinancialCategory.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<FinancialCategory> createFinancialCategory({
    required String groupId,
    required String name,
    required String categoryType,
    String? description,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_create_financial_category',
        params: {
          'p_group_id': groupId,
          'p_name': name,
          'p_category_type': categoryType,
          'p_description': description,
        },
      );
      return FinancialCategory.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<FinancialCategory> updateFinancialCategory({
    required String groupId,
    required String categoryId,
    String? name,
    String? description,
    bool? isActive,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_update_financial_category',
        params: {
          'p_group_id': groupId,
          'p_category_id': categoryId,
          'p_name': name,
          'p_description': description,
          'p_is_active': isActive,
        },
      );
      return FinancialCategory.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<int> seedDefaultFinancialCategories({required String groupId}) async {
    try {
      final result = await _client.rpc(
        'rpc_seed_default_financial_categories',
        params: {'p_group_id': groupId},
      );
      return (result as Map<String, dynamic>)['inserted_count'] as int;
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<FinancialManualEntryPostResult> recordManualIncome({
    required String groupId,
    required String financialAccountId,
    required String categoryId,
    required double amount,
    required DateTime effectiveAt,
    String? description,
    String? reference,
    String? idempotencyKey,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_record_manual_income',
        params: {
          'p_group_id': groupId,
          'p_financial_account_id': financialAccountId,
          'p_category_id': categoryId,
          'p_amount': amount,
          'p_effective_at': _dateOnlyOrNull(effectiveAt),
          'p_description': description,
          'p_reference': reference,
          'p_idempotency_key': idempotencyKey,
        },
      );
      return FinancialManualEntryPostResult.fromJson(
        result as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<FinancialManualEntryPostResult> recordExpense({
    required String groupId,
    required String financialAccountId,
    required String categoryId,
    required double amount,
    required DateTime effectiveAt,
    String? description,
    String? reference,
    String? idempotencyKey,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_record_expense',
        params: {
          'p_group_id': groupId,
          'p_financial_account_id': financialAccountId,
          'p_category_id': categoryId,
          'p_amount': amount,
          'p_effective_at': _dateOnlyOrNull(effectiveAt),
          'p_description': description,
          'p_reference': reference,
          'p_idempotency_key': idempotencyKey,
        },
      );
      return FinancialManualEntryPostResult.fromJson(
        result as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<FinancialManualEntryDetail> getFinancialManualEntry({
    required String groupId,
    required String entryId,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_get_financial_manual_entry',
        params: {'p_group_id': groupId, 'p_entry_id': entryId},
      );
      return FinancialManualEntryDetail.fromJson(
        result as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<void> reverseFinancialManualEntry({
    required String groupId,
    required String entryId,
    required String reversalReason,
  }) async {
    try {
      await _client.rpc(
        'rpc_reverse_financial_manual_entry',
        params: {
          'p_group_id': groupId,
          'p_entry_id': entryId,
          'p_reversal_reason': reversalReason,
        },
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<FinancialAdjustmentResult> recordFinancialAdjustment({
    required String groupId,
    required String financialAccountId,
    required String direction,
    required double amount,
    required String reason,
    required DateTime effectiveAt,
    String? financialReconciliationId,
    String? idempotencyKey,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_record_financial_adjustment',
        params: {
          'p_group_id': groupId,
          'p_financial_account_id': financialAccountId,
          'p_direction': direction,
          'p_amount': amount,
          'p_reason': reason,
          'p_effective_at': _dateOnlyOrNull(effectiveAt),
          'p_financial_reconciliation_id': financialReconciliationId,
          'p_idempotency_key': idempotencyKey,
        },
      );
      return FinancialAdjustmentResult.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<FinancialReconciliation> createFinancialReconciliation({
    required String groupId,
    required String financialAccountId,
    required double statedBalance,
    required DateTime reconciliationAt,
    DateTime? periodStart,
    String? notes,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_create_financial_reconciliation',
        params: {
          'p_group_id': groupId,
          'p_financial_account_id': financialAccountId,
          'p_stated_balance': statedBalance,
          'p_reconciliation_at': _dateOnlyOrNull(reconciliationAt),
          'p_period_start': _dateOnlyOrNull(periodStart),
          'p_notes': notes,
        },
      );
      return FinancialReconciliation.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<void> cancelFinancialReconciliation({
    required String groupId,
    required String reconciliationId,
    required String cancellationReason,
  }) async {
    try {
      await _client.rpc(
        'rpc_cancel_financial_reconciliation',
        params: {
          'p_group_id': groupId,
          'p_reconciliation_id': reconciliationId,
          'p_cancellation_reason': cancellationReason,
        },
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<FinancialReconciliationPage> listFinancialAccountReconciliations({
    required String groupId,
    required String financialAccountId,
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_list_financial_account_reconciliations',
        params: {
          'p_group_id': groupId,
          'p_financial_account_id': financialAccountId,
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      return FinancialReconciliationPage.fromJson(
        result as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<FinancialPosition> getFinancialPosition({
    required String groupId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_get_financial_position',
        params: {
          'p_group_id': groupId,
          'p_date_from': _dateOnlyOrNull(dateFrom),
          'p_date_to': _dateOnlyOrNull(dateTo),
        },
      );
      return FinancialPosition.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }
}

String? _dateOnlyOrNull(DateTime? date) {
  if (date == null) return null;
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Maps a backend failure to a safe, user-presentable
/// [FinancialAccountFailure]. Technical details are logged, never
/// shown to the user.
FinancialAccountFailure _mapError(Object error, StackTrace stackTrace) {
  if (error is PostgrestException) {
    _log.warning(
      'Financial account RPC error (code=${error.code})',
      error,
      stackTrace,
    );

    final message = error.message;
    final code = error.code;

    if (message.contains(
      'FINANCIAL_ACCOUNT_OPENING_BALANCE_MUST_BE_POSITIVE',
    )) {
      return const FinancialAccountFailure(
        FinancialAccountFailureType.openingBalanceMustBePositive,
        'The opening balance must be a positive number.',
      );
    }
    if (message.contains('FINANCIAL_ACCOUNT_TRANSFER_SAME_ACCOUNT')) {
      return const FinancialAccountFailure(
        FinancialAccountFailureType.transferSameAccount,
        'Cannot transfer an account to itself.',
      );
    }
    if (message.contains(
      'FINANCIAL_ACCOUNT_TRANSFER_AMOUNT_MUST_BE_POSITIVE',
    )) {
      return const FinancialAccountFailure(
        FinancialAccountFailureType.transferAmountMustBePositive,
        'The transfer amount must be greater than zero.',
      );
    }
    if (message.contains('FINANCIAL_ACCOUNT_INSUFFICIENT_BALANCE')) {
      return const FinancialAccountFailure(
        FinancialAccountFailureType.insufficientBalance,
        'The source account does not have enough balance for this transfer.',
      );
    }
    if (message.contains('FINANCIAL_ACCOUNT_INACTIVE')) {
      return const FinancialAccountFailure(
        FinancialAccountFailureType.accountInactive,
        'This financial account is inactive.',
      );
    }
    if (message.contains('Effective date is required')) {
      return const FinancialAccountFailure(
        FinancialAccountFailureType.effectiveDateRequired,
        'An effective date is required.',
      );
    }
    if (message.contains('FINANCIAL_MANUAL_ENTRY_AMOUNT_MUST_BE_POSITIVE') ||
        message.contains('FINANCIAL_ADJUSTMENT_AMOUNT_MUST_BE_POSITIVE')) {
      return const FinancialAccountFailure(
        FinancialAccountFailureType.amountMustBePositive,
        'The amount must be greater than zero.',
      );
    }
    if (message.contains('FINANCIAL_CATEGORY_WRONG_TYPE')) {
      return const FinancialAccountFailure(
        FinancialAccountFailureType.categoryWrongType,
        'That category cannot be used for this kind of entry.',
      );
    }
    if (message.contains('FINANCIAL_CATEGORY_INACTIVE')) {
      return const FinancialAccountFailure(
        FinancialAccountFailureType.categoryInactive,
        'This category is no longer active.',
      );
    }
    if (message.contains('FINANCIAL_MANUAL_ENTRY_IDEMPOTENCY_KEY_CONFLICT') ||
        message.contains('FINANCIAL_ADJUSTMENT_IDEMPOTENCY_KEY_CONFLICT')) {
      return const FinancialAccountFailure(
        FinancialAccountFailureType.idempotencyKeyConflict,
        'This submission conflicts with an earlier one. Please refresh and try again.',
      );
    }
    if (message.contains('FINANCIAL_ENTRY_REVERSAL_REASON_REQUIRED')) {
      return const FinancialAccountFailure(
        FinancialAccountFailureType.reversalReasonRequired,
        'A reversal reason is required.',
      );
    }
    if (message.contains('FINANCIAL_MANUAL_ENTRY_ALREADY_REVERSED')) {
      return const FinancialAccountFailure(
        FinancialAccountFailureType.entryAlreadyReversed,
        'This entry has already been reversed.',
      );
    }
    if (message.contains('FINANCIAL_ADJUSTMENT_REASON_REQUIRED')) {
      return const FinancialAccountFailure(
        FinancialAccountFailureType.adjustmentReasonRequired,
        'A reason is required.',
      );
    }
    if (message.contains(
      'FINANCIAL_RECONCILIATION_CANCELLATION_REASON_REQUIRED',
    )) {
      return const FinancialAccountFailure(
        FinancialAccountFailureType.reconciliationCancellationReasonRequired,
        'A cancellation reason is required.',
      );
    }
    if (message.contains('FINANCIAL_RECONCILIATION_ALREADY_CANCELLED')) {
      return const FinancialAccountFailure(
        FinancialAccountFailureType.reconciliationAlreadyCancelled,
        'This reconciliation has already been cancelled.',
      );
    }
    if (message.contains('name is required')) {
      return const FinancialAccountFailure(
        FinancialAccountFailureType.nameRequired,
        'An account name is required.',
      );
    }
    if (code == '23505') {
      return const FinancialAccountFailure(
        FinancialAccountFailureType.duplicateName,
        'That account name is already used in this group.',
      );
    }
    if (message.contains('not found')) {
      return const FinancialAccountFailure(
        FinancialAccountFailureType.notFound,
        'Financial account not found.',
      );
    }
    if (code == '42501') {
      return const FinancialAccountFailure(
        FinancialAccountFailureType.permissionDenied,
        'You do not have permission to do that.',
      );
    }

    return const FinancialAccountFailure(
      FinancialAccountFailureType.unexpected,
      'Something went wrong. Please try again.',
    );
  }

  _log.severe(
    'Unexpected financial account repository error',
    error,
    stackTrace,
  );

  final text = error.toString().toLowerCase();
  final looksLikeNetworkError =
      text.contains('socket') ||
      text.contains('network') ||
      text.contains('connection') ||
      text.contains('failed host lookup') ||
      text.contains('timeout');

  if (looksLikeNetworkError) {
    return const FinancialAccountFailure(
      FinancialAccountFailureType.network,
      'Network error. Check your connection and try again.',
    );
  }

  return const FinancialAccountFailure(
    FinancialAccountFailureType.unexpected,
    'Something went wrong. Please try again.',
  );
}
