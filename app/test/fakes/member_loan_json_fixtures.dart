// JSON fixtures shaped exactly like the deployed B5-B RPC output
// (migration 20261007090000_create_member_safe_loan_backend.sql). These
// are the single source for the Flutter contract. Do not add keys the SQL
// does not return.

Map<String, dynamic> memberLoanPositionJson({
  num? principal = 5400,
  num? interest = 0,
  num? penalty = 50,
  num? total = 5450,
}) => {
  'principal_outstanding': principal,
  'interest_outstanding': interest,
  'penalty_outstanding': penalty,
  'total_outstanding': total,
};

Map<String, dynamic> memberLoanListItemJson({
  String loanAccountId = 'loan-701',
  String loanNumber = 'LN-B5B-701',
  String productName = 'Standard Loan',
  String memberStatus = 'ACTIVE',
  String? originContext,
  num? originalPrincipal = 10000,
  Map<String, dynamic>? position,
  String? nextDueDate = '2026-04-01',
  num? overdueAmount = 3050,
}) => {
  'loan_account_id': loanAccountId,
  'loan_number': loanNumber,
  'product_id': 'product-1',
  'product_name': productName,
  'member_status': memberStatus,
  'origin_context': originContext,
  'original_principal': originalPrincipal,
  'current_position': position ?? memberLoanPositionJson(),
  'next_due_date': nextDueDate,
  'overdue_amount': overdueAmount,
};

Map<String, dynamic> memberLoansPageJson({
  List<Map<String, dynamic>>? items,
  bool hasMore = false,
  int offset = 0,
  int limit = 20,
  int? totalCount,
}) {
  final list = items ?? [memberLoanListItemJson()];
  return {
    'items': list,
    'pagination': {
      'limit': limit,
      'offset': offset,
      'total_count': totalCount ?? (offset + list.length + (hasMore ? 1 : 0)),
      'has_more': hasMore,
    },
  };
}

Map<String, dynamic> memberLoanDetailJson({
  String loanAccountId = 'loan-701',
  String loanNumber = 'LN-B5B-701',
  String memberStatus = 'ACTIVE',
  String? originContext,
  String? openingAsOfDate,
  num? originalPrincipal = 10000,
  String? originalDisbursementDate = '2026-03-01',
  Map<String, dynamic>? position,
  String nextDueDate = '2026-04-01',
  String firstRepaymentDate = '2026-04-01',
}) => {
  'loan_account_id': loanAccountId,
  'loan_number': loanNumber,
  'product': {'product_id': 'product-1', 'product_name': 'Standard Loan'},
  'member_status': memberStatus,
  'origin_context': originContext,
  'application_date': '2026-02-15',
  'opening_as_of_date': openingAsOfDate,
  'original_principal': originalPrincipal,
  'original_disbursement_date': originalDisbursementDate,
  'terms': {
    'interest_rate': 5,
    'interest_rate_basis': 'MONTHLY',
    'interest_method': 'FLAT',
    'term': 3,
    'term_unit': 'MONTH',
    'repayment_frequency': 'MONTHLY',
    'first_repayment_date': firstRepaymentDate,
  },
  'final_due_date': '2099-06-01',
  'current_position': position ?? memberLoanPositionJson(),
  'next_due_date': nextDueDate,
  'overdue_amount': 3050,
};

Map<String, dynamic> memberScheduleCurrentRowJson({
  String installmentId = 'inst-1',
  int installmentNumber = 1,
  String dueDate = '2026-04-01',
  String memberScheduleStatus = 'OVERDUE',
  num currentTotal = 3050,
  num futureInterest = 0,
  num paidPrincipal = 1000,
  num paidInterest = 100,
  num paidPenalty = 0,
}) => {
  'installment_id': installmentId,
  'installment_number': installmentNumber,
  'due_date': dueDate,
  'scheduled_principal': 4000,
  'scheduled_interest': 100,
  'scheduled_total': 4100,
  'paid_principal': paidPrincipal,
  'paid_interest': paidInterest,
  'paid_penalty': paidPenalty,
  'current_principal_outstanding': 3000,
  'current_earned_interest_outstanding': 0,
  'current_penalty_outstanding': 50,
  'current_total_outstanding': currentTotal,
  'scheduled_future_interest_outstanding': futureInterest,
  'member_schedule_status': memberScheduleStatus,
};

Map<String, dynamic> memberScheduleHistoryRowJson({
  String installmentId = 'inst-h1',
  int installmentNumber = 2,
  String status = 'REPLACED',
  String? replacementReason = 'RESTRUCTURE',
}) => {
  'installment_id': installmentId,
  'installment_number': installmentNumber,
  'due_date': '2099-03-01',
  'scheduled_principal': 1000,
  'scheduled_interest': 10,
  'scheduled_total': 1010,
  'paid_principal': 0,
  'paid_interest': 0,
  'paid_penalty': 0,
  'cancelled_on': '2026-06-01',
  'member_schedule_status': status,
  'replacement_reason': replacementReason,
};

Map<String, dynamic> memberLoanScheduleJson({
  String loanAccountId = 'loan-701',
  String memberStatus = 'ACTIVE',
  List<Map<String, dynamic>>? current,
  List<Map<String, dynamic>>? history,
}) => {
  'loan_account_id': loanAccountId,
  'member_status': memberStatus,
  'current': current ?? [memberScheduleCurrentRowJson()],
  'history': history ?? const [],
};

Map<String, dynamic> memberTimelineEventJson({
  String eventId = 'event-1',
  String eventType = 'PAYMENT_POSTED',
  String? eventSubtype,
  String effectiveAt = '2026-04-10',
  String createdAt = '2026-04-10T09:00:00+00:00',
  bool isReversed = false,
  num? amount = 1100,
  bool isCash = true,
  String? cashDirection = 'IN',
  Map<String, dynamic>? componentBreakdown,
  Map<String, dynamic>? metadata,
}) => {
  'event_id': eventId,
  'event_type': eventType,
  'event_subtype': eventSubtype,
  'effective_at': effectiveAt,
  'created_at': createdAt,
  'is_reversed': isReversed,
  'amount': amount,
  'is_cash': isCash,
  'cash_direction': cashDirection,
  'component_breakdown':
      componentBreakdown ?? {'principal': 1000, 'interest': 100},
  'metadata':
      metadata ??
      {
        'receipt_number': 'B5B-RCPT-001',
        'payment_method': 'CASH',
        'reversed_at': null,
      },
};

Map<String, dynamic> memberLoanTimelinePageJson({
  String loanAccountId = 'loan-701',
  List<Map<String, dynamic>>? items,
  bool hasMore = false,
  int offset = 0,
  int limit = 20,
}) {
  final list = items ?? [memberTimelineEventJson()];
  return {
    'loan_account_id': loanAccountId,
    'items': list,
    'pagination': {
      'limit': limit,
      'offset': offset,
      'total_count': offset + list.length + (hasMore ? 1 : 0),
      'has_more': hasMore,
    },
  };
}
