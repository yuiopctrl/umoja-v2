import '../domain/member_financial_statement.dart';

/// Abstraction over the caller's own financial statement
/// (`rpc_get_my_member_statement`) — the single read boundary for this
/// feature. No other financial source table/view/RPC may be read
/// directly from this feature (Prompt 09G-B3-C §D).
abstract class MemberStatementRepository {
  Future<MemberFinancialStatement> getMyStatement({
    required String groupId,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 50,
    int offset = 0,
  });
}
