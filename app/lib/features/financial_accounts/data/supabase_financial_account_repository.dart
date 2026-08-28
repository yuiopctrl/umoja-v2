import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/financial_account.dart';
import '../domain/financial_account_entry_page.dart';
import '../domain/financial_account_page.dart';
import '../domain/financial_account_transfer_result.dart';
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
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_list_financial_account_entries',
        params: {
          'p_group_id': groupId,
          'p_account_id': accountId,
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      return FinancialAccountEntryPage.fromJson(result as Map<String, dynamic>);
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
