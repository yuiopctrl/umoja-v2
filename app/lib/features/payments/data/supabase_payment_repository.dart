import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/member_contribution_statement.dart';
import '../domain/member_wallet.dart';
import '../domain/payment_allocation_preview.dart';
import '../domain/payment_detail.dart';
import '../domain/payment_page.dart';
import '../domain/payment_post_result.dart';
import '../domain/receipt.dart';
import '../domain/wallet_allocation_preview.dart';
import '../domain/wallet_entry_page.dart';
import 'payment_failure.dart';
import 'payment_repository.dart';

final _log = Logger('SupabasePaymentRepository');

/// [PaymentRepository] backed by the Prompt 07 RPCs. Never
/// inserts/updates the underlying tables directly — those direct
/// grants are revoked server-side.
class SupabasePaymentRepository implements PaymentRepository {
  SupabasePaymentRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<PaymentPage> listPayments({
    required String groupId,
    String? membershipId,
    String? status,
    String? financialAccountId,
    String? search,
    DateTime? dateFrom,
    DateTime? dateTo,
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_list_member_payments',
        params: {
          'p_group_id': groupId,
          'p_membership_id': membershipId,
          'p_status': status,
          'p_financial_account_id': financialAccountId,
          'p_search': (search == null || search.trim().isEmpty)
              ? null
              : search.trim(),
          'p_date_from': _dateOnlyOrNull(dateFrom),
          'p_date_to': _dateOnlyOrNull(dateTo),
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      return PaymentPage.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<PaymentDetail> getPaymentDetail({
    required String groupId,
    required String paymentId,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_get_payment_detail',
        params: {'p_group_id': groupId, 'p_payment_id': paymentId},
      );
      return PaymentDetail.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<Receipt> getReceipt({
    required String groupId,
    required String paymentId,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_get_receipt',
        params: {'p_group_id': groupId, 'p_payment_id': paymentId},
      );
      return Receipt.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<MemberContributionStatement> getMemberContributionStatement({
    required String groupId,
    required String membershipId,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_get_member_contribution_statement',
        params: {'p_group_id': groupId, 'p_membership_id': membershipId},
      );
      return MemberContributionStatement.fromJson(
        result as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<PaymentAllocationPreview> previewPaymentAllocation({
    required String groupId,
    required String membershipId,
    required String financialAccountId,
    required double amount,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_preview_payment_allocation',
        params: {
          'p_group_id': groupId,
          'p_membership_id': membershipId,
          'p_financial_account_id': financialAccountId,
          'p_amount': amount,
        },
      );
      return PaymentAllocationPreview.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<PaymentPostResult> postPayment({
    required String groupId,
    required String membershipId,
    required String financialAccountId,
    required double amount,
    required DateTime effectiveAt,
    required String paymentMethod,
    String? externalReference,
    String? notes,
    String? idempotencyKey,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_post_payment',
        params: {
          'p_group_id': groupId,
          'p_membership_id': membershipId,
          'p_financial_account_id': financialAccountId,
          'p_amount': amount,
          // The RPC has no default for this argument, but every other
          // date-typed RPC in this codebase has shown the same
          // explicit-null-vs-omitted gotcha (06B, 08A UAT-DIAG-02) —
          // always send a real date, never leave this to chance.
          'p_effective_at': _dateOnlyOrNull(effectiveAt),
          'p_payment_method': paymentMethod,
          'p_external_reference': externalReference,
          'p_notes': notes,
          'p_idempotency_key': idempotencyKey,
        },
      );
      return PaymentPostResult.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<void> reversePayment({
    required String groupId,
    required String paymentId,
    required String reversalReason,
  }) async {
    try {
      await _client.rpc(
        'rpc_reverse_payment',
        params: {
          'p_group_id': groupId,
          'p_payment_id': paymentId,
          'p_reversal_reason': reversalReason,
        },
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<MemberWallet> getMemberWallet({
    required String groupId,
    required String membershipId,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_get_member_wallet',
        params: {'p_group_id': groupId, 'p_membership_id': membershipId},
      );
      return MemberWallet.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<WalletEntryPage> listMemberWalletEntries({
    required String groupId,
    required String membershipId,
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_list_member_wallet_entries',
        params: {
          'p_group_id': groupId,
          'p_membership_id': membershipId,
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      return WalletEntryPage.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<WalletAllocationPreview> previewWalletAllocation({
    required String groupId,
    required String membershipId,
    required double amount,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_preview_wallet_allocation',
        params: {
          'p_group_id': groupId,
          'p_membership_id': membershipId,
          'p_amount': amount,
        },
      );
      return WalletAllocationPreview.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<void> allocateMemberWallet({
    required String groupId,
    required String membershipId,
    required double amount,
    String? idempotencyKey,
  }) async {
    try {
      await _client.rpc(
        'rpc_allocate_member_wallet',
        params: {
          'p_group_id': groupId,
          'p_membership_id': membershipId,
          'p_amount': amount,
          'p_idempotency_key': idempotencyKey,
        },
      );
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

/// Maps a backend failure to a safe, user-presentable [PaymentFailure].
/// Technical details are logged, never shown to the user.
PaymentFailure _mapError(Object error, StackTrace stackTrace) {
  if (error is PostgrestException) {
    _log.warning('Payment RPC error (code=${error.code})', error, stackTrace);

    final message = error.message;
    final code = error.code;

    if (message.contains('PAYMENT_AMOUNT_MUST_BE_POSITIVE') ||
        message.contains('WALLET_ALLOCATION_AMOUNT_MUST_BE_POSITIVE')) {
      return const PaymentFailure(
        PaymentFailureType.amountMustBePositive,
        'The amount must be greater than zero.',
      );
    }
    if (message.contains('FINANCIAL_ACCOUNT_INACTIVE')) {
      return const PaymentFailure(
        PaymentFailureType.financialAccountInactive,
        'This financial account is inactive.',
      );
    }
    if (message.contains('PAYMENT_IDEMPOTENCY_KEY_CONFLICT') ||
        message.contains('WALLET_ALLOCATION_IDEMPOTENCY_KEY_CONFLICT')) {
      return const PaymentFailure(
        PaymentFailureType.idempotencyKeyConflict,
        'This submission conflicts with an earlier one. Please refresh and try again.',
      );
    }
    if (message.contains('PAYMENT_ALREADY_REVERSED')) {
      return const PaymentFailure(
        PaymentFailureType.paymentAlreadyReversed,
        'This payment has already been reversed.',
      );
    }
    if (message.contains('PAYMENT_REVERSAL_BLOCKED_WALLET_CREDIT_CONSUMED')) {
      return const PaymentFailure(
        PaymentFailureType.reversalBlockedWalletCreditConsumed,
        'This payment cannot be reversed: the wallet credit it created has already been used.',
      );
    }
    if (message.contains('PAYMENT_REVERSAL_REASON_REQUIRED')) {
      return const PaymentFailure(
        PaymentFailureType.reversalReasonRequired,
        'A reversal reason is required.',
      );
    }
    if (message.contains('WALLET_INSUFFICIENT_BALANCE')) {
      return const PaymentFailure(
        PaymentFailureType.walletInsufficientBalance,
        'The wallet does not have enough balance for this allocation.',
      );
    }
    if (message.contains('WALLET_ALLOCATION_NOTHING_TO_ALLOCATE')) {
      return const PaymentFailure(
        PaymentFailureType.walletAllocationNothingToAllocate,
        'There is no outstanding amount to allocate against.',
      );
    }
    if (message.contains('not found')) {
      return const PaymentFailure(PaymentFailureType.notFound, 'Not found.');
    }
    if (code == '42501') {
      return const PaymentFailure(
        PaymentFailureType.permissionDenied,
        'You do not have permission to do that.',
      );
    }

    return const PaymentFailure(
      PaymentFailureType.unexpected,
      'Something went wrong. Please try again.',
    );
  }

  _log.severe('Unexpected payment repository error', error, stackTrace);

  final text = error.toString().toLowerCase();
  final looksLikeNetworkError =
      text.contains('socket') ||
      text.contains('network') ||
      text.contains('connection') ||
      text.contains('failed host lookup') ||
      text.contains('timeout');

  if (looksLikeNetworkError) {
    return const PaymentFailure(
      PaymentFailureType.network,
      'Network error. Check your connection and try again.',
    );
  }

  return const PaymentFailure(
    PaymentFailureType.unexpected,
    'Something went wrong. Please try again.',
  );
}
