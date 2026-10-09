import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/my_payment.dart';
import 'my_payments_failure.dart';
import 'my_payments_repository.dart';

final _log = Logger('SupabaseMyPaymentsRepository');

/// Performs one RPC call. Injected so tests can assert the exact
/// function name and parameter map without a live Supabase client.
typedef MyPaymentsRpcInvoker = Future<dynamic> Function(
  String function,
  Map<String, dynamic> params,
);

class SupabaseMyPaymentsRepository implements MyPaymentsRepository {
  SupabaseMyPaymentsRepository(SupabaseClient client)
    : _invoke = ((function, params) => client.rpc(function, params: params));

  /// Test seam: lets a test capture the exact RPC name and payload.
  SupabaseMyPaymentsRepository.withInvoker(this._invoke);

  final MyPaymentsRpcInvoker _invoke;

  @override
  Future<MyPaymentsPage> getMyPayments({
    required String groupId,
    MyPaymentStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
    required int limit,
    required int offset,
  }) async {
    try {
      final result = await _invoke('rpc_get_my_payments', {
        'p_group_id': groupId,
        'p_status': status?.wire,
        'p_from_date': _dateOnlyOrNull(fromDate),
        'p_to_date': _dateOnlyOrNull(toDate),
        'p_limit': limit,
        'p_offset': offset,
      });
      return MyPaymentsPage.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace, isPaymentScoped: false);
    }
  }

  @override
  Future<MyPaymentDetail> getMyPaymentDetail({
    required String groupId,
    required String paymentId,
  }) async {
    try {
      final result = await _invoke('rpc_get_my_payment_detail', {
        'p_group_id': groupId,
        'p_payment_id': paymentId,
      });
      return MyPaymentDetail.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace, isPaymentScoped: true);
    }
  }

  @override
  Future<MyReceipt> getMyReceipt({
    required String groupId,
    required String paymentId,
  }) async {
    try {
      final result = await _invoke('rpc_get_my_receipt', {
        'p_group_id': groupId,
        'p_payment_id': paymentId,
      });
      return MyReceipt.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace, isPaymentScoped: true);
    }
  }
}

MyPaymentsFailure _mapError(
  Object error,
  StackTrace stackTrace, {
  required bool isPaymentScoped,
}) {
  if (error is PostgrestException) {
    _log.warning(
      'My payments RPC error (code=${error.code})',
      error,
      stackTrace,
    );
    switch (error.code) {
      case '42501':
      case '28000':
        return const MyPaymentsFailure(MyPaymentsFailureType.notAuthorized);
      case '22023':
        if (isPaymentScoped) {
          return const MyPaymentsFailure(MyPaymentsFailureType.notFound);
        }
        return MyPaymentsFailure(
          error.message.contains('p_from_date')
              ? MyPaymentsFailureType.invalidDateRange
              : MyPaymentsFailureType.invalidRequest,
        );
    }
    return const MyPaymentsFailure(MyPaymentsFailureType.unexpected);
  }

  // A payload that does not match the documented contract is a client/
  // server mismatch, not a network problem.
  if (error is FormatException || error is TypeError) {
    _log.warning('My payments response did not match', error, stackTrace);
    return const MyPaymentsFailure(MyPaymentsFailureType.unexpected);
  }

  _log.warning('My payments unexpected error', error, stackTrace);
  return const MyPaymentsFailure(MyPaymentsFailureType.network);
}

String? _dateOnlyOrNull(DateTime? date) {
  if (date == null) return null;
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
