import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/member_loan.dart';
import 'member_loans_failure.dart';
import 'member_loans_repository.dart';

final _log = Logger('SupabaseMemberLoansRepository');

/// Performs one RPC call. Injected so tests can assert the exact function
/// name and parameter map without a live Supabase client.
typedef MemberLoansRpcInvoker = Future<dynamic> Function(
  String function,
  Map<String, dynamic> params,
);

class SupabaseMemberLoansRepository implements MemberLoansRepository {
  SupabaseMemberLoansRepository(SupabaseClient client)
    : _invoke = ((function, params) => client.rpc(function, params: params));

  /// Test seam: lets a test capture the exact RPC name and payload.
  SupabaseMemberLoansRepository.withInvoker(this._invoke);

  final MemberLoansRpcInvoker _invoke;

  @override
  Future<MemberLoansPage> getMyLoans({
    required String groupId,
    required int limit,
    required int offset,
  }) async {
    try {
      final result = await _invoke('rpc_get_my_loans', {
        'p_group_id': groupId,
        'p_limit': limit,
        'p_offset': offset,
      });
      return MemberLoansPage.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace, isLoanScoped: false);
    }
  }

  @override
  Future<MemberLoanDetail> getMyLoanDetail({
    required String groupId,
    required String loanAccountId,
  }) async {
    try {
      final result = await _invoke('rpc_get_my_loan_detail', {
        'p_group_id': groupId,
        'p_loan_account_id': loanAccountId,
      });
      return MemberLoanDetail.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace, isLoanScoped: true);
    }
  }

  @override
  Future<MemberLoanSchedule> getMyLoanSchedule({
    required String groupId,
    required String loanAccountId,
  }) async {
    try {
      final result = await _invoke('rpc_get_my_loan_schedule', {
        'p_group_id': groupId,
        'p_loan_account_id': loanAccountId,
      });
      return MemberLoanSchedule.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace, isLoanScoped: true);
    }
  }

  @override
  Future<MemberLoanTimelinePage> getMyLoanTimeline({
    required String groupId,
    required String loanAccountId,
    required int limit,
    required int offset,
  }) async {
    try {
      final result = await _invoke('rpc_get_my_loan_timeline', {
        'p_group_id': groupId,
        'p_loan_account_id': loanAccountId,
        'p_limit': limit,
        'p_offset': offset,
      });
      return MemberLoanTimelinePage.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace, isLoanScoped: true);
    }
  }
}

MemberLoansFailure _mapError(
  Object error,
  StackTrace stackTrace, {
  required bool isLoanScoped,
}) {
  if (error is MemberLoansFailure) return error;

  if (error is PostgrestException) {
    _log.warning('My loans RPC error (code=${error.code})', error, stackTrace);
    switch (error.code) {
      case '42501':
      case '28000':
        return const MemberLoansFailure(MemberLoansFailureType.notAuthorized);
      case '22023':
        return MemberLoansFailure(
          isLoanScoped
              ? MemberLoansFailureType.notFound
              : MemberLoansFailureType.invalidRequest,
        );
    }
    return const MemberLoansFailure(MemberLoansFailureType.unexpected);
  }

  // A payload that does not match the documented contract is a client/
  // server mismatch, not a network problem.
  if (error is FormatException || error is TypeError) {
    _log.warning('My loans response did not match', error, stackTrace);
    return const MemberLoansFailure(MemberLoansFailureType.unexpected);
  }

  _log.warning('My loans unexpected error', error, stackTrace);
  return const MemberLoansFailure(MemberLoansFailureType.network);
}
