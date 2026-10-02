import 'package:umoja/features/member_statement/data/member_statement_repository.dart';
import 'package:umoja/features/member_statement/domain/member_financial_statement.dart';

MemberFinancialStatement fakeMemberFinancialStatement({
  String membershipId = 'm1',
  String displayName = 'Test Member',
  String? memberNumber = 'G1-0001',
  String groupId = 'g1',
  String groupName = 'Test Group',
  double contributionsOutstanding = 9000,
  double loansOutstanding = 97000,
  double walletBalance = 25000,
  MemberStatementPeriodPosition? opening,
  MemberStatementPeriodPosition? closing,
  DateTime? fromDate,
  DateTime? toDate,
  List<MemberStatementActivityItem> items = const [],
  int limit = 20,
  int offset = 0,
  int? totalCount,
  bool hasMore = false,
}) {
  return MemberFinancialStatement(
    member: MemberStatementMember(
      membershipId: membershipId,
      displayName: displayName,
      memberNumber: memberNumber,
      membershipStatus: 'ACTIVE',
    ),
    group: MemberStatementGroup(
      groupId: groupId,
      groupName: groupName,
      groupCode: 'TG01',
      currency: 'TZS',
    ),
    period: MemberStatementPeriod(
      fromDate: fromDate,
      toDate: toDate,
      opening: opening,
      closing: closing,
    ),
    summary: MemberStatementSummary(
      contributionsCurrentOutstanding: contributionsOutstanding,
      contributionsPendingPenalties: 0,
      loansCurrentOutstanding: loansOutstanding,
      loansPendingPenalties: 0,
      walletCurrentBalance: walletBalance,
      lastPayment: null,
    ),
    activity: MemberStatementActivity(
      items: items,
      limit: limit,
      offset: offset,
      totalCount: totalCount ?? items.length,
      hasMore: hasMore,
    ),
  );
}

MemberStatementActivityItem fakeContributionActivityItem({
  String eventId = 'c1',
  String eventType = 'BASE',
  double amount = 50000,
  DateTime? effectiveDate,
  String? periodLabel = 'October 2026 Dues',
}) {
  return MemberStatementActivityItem(
    eventId: eventId,
    domain: 'CONTRIBUTION',
    eventType: eventType,
    effectiveDate: effectiveDate ?? DateTime(2026, 10, 1),
    amount: amount,
    isReversed: false,
    metadata: {'period_label': periodLabel},
  );
}

MemberStatementActivityItem fakePaymentActivityItem({
  String eventId = 'pay1',
  double amount = 100000,
  DateTime? effectiveDate,
  bool isReversed = false,
  String? receiptNumber = 'UMOJA-RCP-2026-000001',
  List<Map<String, dynamic>> allocations = const [],
}) {
  return MemberStatementActivityItem(
    eventId: eventId,
    domain: 'PAYMENT',
    eventType: 'PAYMENT',
    effectiveDate: effectiveDate ?? DateTime(2026, 2, 5),
    amount: amount,
    isReversed: isReversed,
    metadata: {
      'status': isReversed ? 'REVERSED' : 'POSTED',
      'receipt_number': receiptNumber,
      'allocations': allocations,
    },
  );
}

MemberStatementActivityItem fakeLoanActivityItem({
  String eventId = 'd1',
  String eventType = 'DISBURSEMENT',
  double amount = 50000,
  DateTime? effectiveDate,
  String? loanNumber = 'LN-001',
}) {
  return MemberStatementActivityItem(
    eventId: eventId,
    domain: 'LOAN',
    eventType: eventType,
    effectiveDate: effectiveDate ?? DateTime(2026, 1, 1),
    amount: amount,
    isReversed: false,
    metadata: {'loan_number': loanNumber},
  );
}

MemberStatementActivityItem fakeWalletActivityItem({
  String eventId = 'w1',
  String eventType = 'PAYMENT_CREDIT',
  double amount = 25000,
  DateTime? effectiveDate,
}) {
  return MemberStatementActivityItem(
    eventId: eventId,
    domain: 'WALLET',
    eventType: eventType,
    effectiveDate: effectiveDate ?? DateTime(2026, 2, 5),
    amount: amount,
    isReversed: false,
  );
}

/// A benign fake for widget/provider tests — mirrors
/// `FakeMemberProfileRepository`'s shape. [onGetMyStatement] lets a
/// test observe the exact (groupId, fromDate, toDate, limit, offset)
/// a caller requested, without touching the real Supabase client.
class FakeMemberStatementRepository implements MemberStatementRepository {
  FakeMemberStatementRepository({MemberFinancialStatement? statement})
    : statement = statement ?? fakeMemberFinancialStatement();

  MemberFinancialStatement statement;
  Object? nextError;
  void Function({
    required String groupId,
    DateTime? fromDate,
    DateTime? toDate,
    required int limit,
    required int offset,
  })?
  onGetMyStatement;

  int callCount = 0;

  @override
  Future<MemberFinancialStatement> getMyStatement({
    required String groupId,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 50,
    int offset = 0,
  }) async {
    callCount++;
    onGetMyStatement?.call(
      groupId: groupId,
      fromDate: fromDate,
      toDate: toDate,
      limit: limit,
      offset: offset,
    );
    if (nextError != null) throw nextError!;
    return statement;
  }
}
