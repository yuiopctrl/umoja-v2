import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/my_contribution.dart';
import 'my_contributions_failure.dart';
import 'my_contributions_repository.dart';

final _log = Logger('SupabaseMyContributionsRepository');

/// Performs one RPC call. Injected so tests can assert the exact
/// function name and parameter map without a live Supabase client.
typedef MyContributionsRpcInvoker = Future<dynamic> Function(
  String function,
  Map<String, dynamic> params,
);

class SupabaseMyContributionsRepository implements MyContributionsRepository {
  SupabaseMyContributionsRepository(SupabaseClient client)
    : _invoke = ((function, params) => client.rpc(function, params: params));

  /// Test seam: lets a test capture the exact RPC name and payload.
  SupabaseMyContributionsRepository.withInvoker(this._invoke);

  final MyContributionsRpcInvoker _invoke;

  @override
  Future<MyContributionsPage> getMyContributions({
    required String groupId,
    MyContributionStatus? status,
    String? contributionTypeId,
    DateTime? fromDate,
    DateTime? toDate,
    required int limit,
    required int offset,
  }) async {
    try {
      final result = await _invoke('rpc_get_my_contributions', {
        'p_group_id': groupId,
        'p_status': status?.wire,
        'p_contribution_type_id': contributionTypeId,
        'p_from_date': _dateOnlyOrNull(fromDate),
        'p_to_date': _dateOnlyOrNull(toDate),
        'p_limit': limit,
        'p_offset': offset,
      });
      return MyContributionsPage.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace, isDetail: false);
    }
  }

  @override
  Future<MyContributionDetail> getMyContributionChargeDetail({
    required String groupId,
    required String chargeId,
  }) async {
    try {
      final result = await _invoke('rpc_get_my_contribution_charge_detail', {
        'p_group_id': groupId,
        'p_charge_id': chargeId,
      });
      return MyContributionDetail.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace, isDetail: true);
    }
  }
}

MyContributionsFailure _mapError(
  Object error,
  StackTrace stackTrace, {
  required bool isDetail,
}) {
  if (error is PostgrestException) {
    _log.warning(
      'My contributions RPC error (code=${error.code})',
      error,
      stackTrace,
    );
    switch (error.code) {
      case '42501':
      case '28000':
        return const MyContributionsFailure(
          MyContributionsFailureType.notAuthorized,
        );
      case '22023':
        if (isDetail) {
          return const MyContributionsFailure(
            MyContributionsFailureType.notFound,
          );
        }
        return MyContributionsFailure(
          error.message.contains('p_from_date')
              ? MyContributionsFailureType.invalidDateRange
              : MyContributionsFailureType.invalidRequest,
        );
    }
    return const MyContributionsFailure(MyContributionsFailureType.unexpected);
  }

  // A payload that does not match the documented contract is a client/
  // server mismatch, not a network problem.
  if (error is FormatException || error is TypeError) {
    _log.warning('My contributions response did not match', error, stackTrace);
    return const MyContributionsFailure(MyContributionsFailureType.unexpected);
  }

  _log.warning('My contributions unexpected error', error, stackTrace);
  return const MyContributionsFailure(MyContributionsFailureType.network);
}

String? _dateOnlyOrNull(DateTime? date) {
  if (date == null) return null;
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
