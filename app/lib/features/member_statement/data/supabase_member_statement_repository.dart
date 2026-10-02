import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/member_financial_statement.dart';
import 'member_statement_failure.dart';
import 'member_statement_repository.dart';

final _log = Logger('SupabaseMemberStatementRepository');

class SupabaseMemberStatementRepository implements MemberStatementRepository {
  SupabaseMemberStatementRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<MemberFinancialStatement> getMyStatement({
    required String groupId,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_get_my_member_statement',
        params: {
          'p_group_id': groupId,
          'p_from_date': _dateOnlyOrNull(fromDate),
          'p_to_date': _dateOnlyOrNull(toDate),
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      return MemberFinancialStatement.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }
}

MemberStatementFailure _mapError(Object error, StackTrace stackTrace) {
  if (error is PostgrestException) {
    _log.warning(
      'Member statement RPC error (code=${error.code})',
      error,
      stackTrace,
    );

    if (error.code == '42501') {
      return const MemberStatementFailure(
        MemberStatementFailureType.notAuthorized,
        'You are not authorized to view this financial statement.',
      );
    }
    if (error.code == '22023') {
      return const MemberStatementFailure(
        MemberStatementFailureType.invalidDateRange,
        'The "from" date must not be after the "to" date.',
      );
    }
    return const MemberStatementFailure(
      MemberStatementFailureType.unexpected,
      'Something went wrong. Please try again.',
    );
  }

  _log.warning('Member statement unexpected error', error, stackTrace);
  return const MemberStatementFailure(
    MemberStatementFailureType.network,
    'Network error. Check your connection and try again.',
  );
}

String? _dateOnlyOrNull(DateTime? date) {
  if (date == null) return null;
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
