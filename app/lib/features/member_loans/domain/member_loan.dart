// Prompt 09G-B5-C: member self-service My Loans — read-only domain models
// for the four member-safe RPCs (migration
// 20261007090000_create_member_safe_loan_backend.sql):
//   rpc_get_my_loans, rpc_get_my_loan_detail,
//   rpc_get_my_loan_schedule, rpc_get_my_loan_timeline.
// Every key below is taken from that migration's jsonb_build_object output.
// Nothing is derived client-side: balances, totals, statuses and cash
// semantics are rendered exactly as the backend returns them.
//
// Unknown future enum values never throw: they map to an `unknown` case so
// one unexpected code cannot crash the whole page.

/// `member_status` on loan list items and detail. DRAFT is never returned,
/// and DISBURSED is never member-facing.
enum MemberLoanStatus {
  submitted('SUBMITTED'),
  approved('APPROVED'),
  rejected('REJECTED'),
  cancelled('CANCELLED'),
  active('ACTIVE'),
  closed('CLOSED'),
  writtenOff('WRITTEN_OFF'),
  unknown('');

  const MemberLoanStatus(this.wire);

  final String wire;

  static MemberLoanStatus fromWire(String? value) {
    for (final status in values) {
      if (status != MemberLoanStatus.unknown && status.wire == value) {
        return status;
      }
    }
    return MemberLoanStatus.unknown;
  }
}

/// `origin_context`. Exactly one stable code is ever returned for a
/// non-NEW loan. A NEW loan has `null`.
const String memberLoanOriginOpeningPosition = 'OPENING_POSITION';

/// `current_position`. Each amount is `null` when the backend cannot
/// reconstruct it (NOT_AVAILABLE). A null is never shown as zero.
class MemberLoanCurrentPosition {
  const MemberLoanCurrentPosition({
    required this.principalOutstanding,
    required this.interestOutstanding,
    required this.penaltyOutstanding,
    required this.totalOutstanding,
  });

  factory MemberLoanCurrentPosition.fromJson(Map<String, dynamic> json) {
    return MemberLoanCurrentPosition(
      principalOutstanding: _numOrNull(json['principal_outstanding']),
      interestOutstanding: _numOrNull(json['interest_outstanding']),
      penaltyOutstanding: _numOrNull(json['penalty_outstanding']),
      totalOutstanding: _numOrNull(json['total_outstanding']),
    );
  }

  final double? principalOutstanding;
  final double? interestOutstanding;
  final double? penaltyOutstanding;
  final double? totalOutstanding;

  bool get isAvailable => totalOutstanding != null;
}

class MemberLoanListItem {
  const MemberLoanListItem({
    required this.loanAccountId,
    required this.loanNumber,
    required this.productId,
    required this.productName,
    required this.status,
    required this.originContext,
    required this.originalPrincipal,
    required this.currentPosition,
    required this.nextDueDate,
    required this.overdueAmount,
  });

  factory MemberLoanListItem.fromJson(Map<String, dynamic> json) {
    return MemberLoanListItem(
      loanAccountId: json['loan_account_id'] as String,
      loanNumber: json['loan_number'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      status: MemberLoanStatus.fromWire(json['member_status'] as String?),
      originContext: json['origin_context'] as String?,
      originalPrincipal: _numOrNull(json['original_principal']),
      currentPosition: MemberLoanCurrentPosition.fromJson(
        json['current_position'] as Map<String, dynamic>,
      ),
      nextDueDate: _dateOrNull(json['next_due_date']),
      overdueAmount: _numOrNull(json['overdue_amount']),
    );
  }

  final String loanAccountId;
  final String loanNumber;
  final String productId;
  final String productName;
  final MemberLoanStatus status;
  final String? originContext;
  final double? originalPrincipal;
  final MemberLoanCurrentPosition currentPosition;
  final DateTime? nextDueDate;
  final double? overdueAmount;

  bool get isOpeningPosition =>
      originContext == memberLoanOriginOpeningPosition;
}

class MemberLoanPagination {
  const MemberLoanPagination({
    required this.limit,
    required this.offset,
    required this.totalCount,
    required this.hasMore,
  });

  factory MemberLoanPagination.fromJson(Map<String, dynamic> json) {
    return MemberLoanPagination(
      limit: (json['limit'] as num).toInt(),
      offset: (json['offset'] as num).toInt(),
      totalCount: (json['total_count'] as num).toInt(),
      hasMore: json['has_more'] as bool,
    );
  }

  final int limit;
  final int offset;
  final int totalCount;
  final bool hasMore;
}

/// Root of `rpc_get_my_loans`: `{ items, pagination }`. There is no
/// aggregate total across loans. Each item is an independent account.
class MemberLoansPage {
  const MemberLoansPage({required this.items, required this.pagination});

  factory MemberLoansPage.fromJson(Map<String, dynamic> json) {
    return MemberLoansPage(
      items: [
        for (final item in json['items'] as List<dynamic>)
          MemberLoanListItem.fromJson(item as Map<String, dynamic>),
      ],
      pagination: MemberLoanPagination.fromJson(
        json['pagination'] as Map<String, dynamic>,
      ),
    );
  }

  final List<MemberLoanListItem> items;
  final MemberLoanPagination pagination;
}

class MemberLoanProduct {
  const MemberLoanProduct({required this.productId, required this.productName});

  factory MemberLoanProduct.fromJson(Map<String, dynamic> json) {
    return MemberLoanProduct(
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
    );
  }

  final String productId;
  final String productName;
}

/// `terms`. Only persisted, member-safe terms. Any term the backend did
/// not return is `null` and is simply not shown.
class MemberLoanTerms {
  const MemberLoanTerms({
    required this.interestRate,
    required this.interestRateBasis,
    required this.interestMethod,
    required this.term,
    required this.termUnit,
    required this.repaymentFrequency,
    required this.firstRepaymentDate,
  });

  factory MemberLoanTerms.fromJson(Map<String, dynamic> json) {
    return MemberLoanTerms(
      interestRate: _numOrNull(json['interest_rate']),
      interestRateBasis: json['interest_rate_basis'] as String?,
      interestMethod: json['interest_method'] as String?,
      term: (json['term'] as num?)?.toInt(),
      termUnit: json['term_unit'] as String?,
      repaymentFrequency: json['repayment_frequency'] as String?,
      firstRepaymentDate: _dateOrNull(json['first_repayment_date']),
    );
  }

  final double? interestRate;
  final String? interestRateBasis;
  final String? interestMethod;
  final int? term;
  final String? termUnit;
  final String? repaymentFrequency;
  final DateTime? firstRepaymentDate;
}

/// Root of `rpc_get_my_loan_detail`.
class MemberLoanDetail {
  const MemberLoanDetail({
    required this.loanAccountId,
    required this.loanNumber,
    required this.product,
    required this.status,
    required this.originContext,
    required this.applicationDate,
    required this.openingAsOfDate,
    required this.originalPrincipal,
    required this.originalDisbursementDate,
    required this.terms,
    required this.finalDueDate,
    required this.currentPosition,
    required this.nextDueDate,
    required this.overdueAmount,
  });

  factory MemberLoanDetail.fromJson(Map<String, dynamic> json) {
    return MemberLoanDetail(
      loanAccountId: json['loan_account_id'] as String,
      loanNumber: json['loan_number'] as String,
      product: MemberLoanProduct.fromJson(
        json['product'] as Map<String, dynamic>,
      ),
      status: MemberLoanStatus.fromWire(json['member_status'] as String?),
      originContext: json['origin_context'] as String?,
      applicationDate: _dateOrNull(json['application_date']),
      openingAsOfDate: _dateOrNull(json['opening_as_of_date']),
      originalPrincipal: _numOrNull(json['original_principal']),
      originalDisbursementDate: _dateOrNull(json['original_disbursement_date']),
      terms: MemberLoanTerms.fromJson(json['terms'] as Map<String, dynamic>),
      finalDueDate: _dateOrNull(json['final_due_date']),
      currentPosition: MemberLoanCurrentPosition.fromJson(
        json['current_position'] as Map<String, dynamic>,
      ),
      nextDueDate: _dateOrNull(json['next_due_date']),
      overdueAmount: _numOrNull(json['overdue_amount']),
    );
  }

  final String loanAccountId;
  final String loanNumber;
  final MemberLoanProduct product;
  final MemberLoanStatus status;
  final String? originContext;
  final DateTime? applicationDate;
  final DateTime? openingAsOfDate;
  final double? originalPrincipal;
  final DateTime? originalDisbursementDate;
  final MemberLoanTerms terms;
  final DateTime? finalDueDate;
  final MemberLoanCurrentPosition currentPosition;
  final DateTime? nextDueDate;
  final double? overdueAmount;

  bool get isOpeningPosition =>
      originContext == memberLoanOriginOpeningPosition;
}

/// `member_schedule_status` on CURRENT schedule rows. Deterministic and
/// computed by the backend. Officer PAID is never a member status.
enum MemberScheduleStatus {
  settled('SETTLED'),
  overdue('OVERDUE'),
  partiallySettled('PARTIALLY_SETTLED'),
  due('DUE'),
  upcoming('UPCOMING'),
  writtenOff('WRITTEN_OFF'),
  unknown('');

  const MemberScheduleStatus(this.wire);

  final String wire;

  static MemberScheduleStatus fromWire(String? value) {
    for (final status in values) {
      if (status != MemberScheduleStatus.unknown && status.wire == value) {
        return status;
      }
    }
    return MemberScheduleStatus.unknown;
  }
}

/// `member_schedule_status` on HISTORY rows.
enum MemberScheduleHistoryStatus {
  cancelled('CANCELLED'),
  replaced('REPLACED'),
  unknown('');

  const MemberScheduleHistoryStatus(this.wire);

  final String wire;

  static MemberScheduleHistoryStatus fromWire(String? value) {
    for (final status in values) {
      if (status != MemberScheduleHistoryStatus.unknown &&
          status.wire == value) {
        return status;
      }
    }
    return MemberScheduleHistoryStatus.unknown;
  }
}

/// One CURRENT installment, from `current[]`.
///
/// `scheduledFutureInterestOutstanding` is contractual future interest. It
/// is NOT current interest and is never added to any current total.
class MemberScheduleRow {
  const MemberScheduleRow({
    required this.installmentId,
    required this.installmentNumber,
    required this.dueDate,
    required this.scheduledPrincipal,
    required this.scheduledInterest,
    required this.scheduledTotal,
    required this.paidPrincipal,
    required this.paidInterest,
    required this.paidPenalty,
    required this.currentPrincipalOutstanding,
    required this.currentEarnedInterestOutstanding,
    required this.currentPenaltyOutstanding,
    required this.currentTotalOutstanding,
    required this.scheduledFutureInterestOutstanding,
    required this.status,
  });

  factory MemberScheduleRow.fromJson(Map<String, dynamic> json) {
    return MemberScheduleRow(
      installmentId: json['installment_id'] as String,
      installmentNumber: (json['installment_number'] as num).toInt(),
      dueDate: DateTime.parse(json['due_date'] as String),
      scheduledPrincipal: _num(json['scheduled_principal']),
      scheduledInterest: _num(json['scheduled_interest']),
      scheduledTotal: _num(json['scheduled_total']),
      paidPrincipal: _num(json['paid_principal']),
      paidInterest: _num(json['paid_interest']),
      paidPenalty: _num(json['paid_penalty']),
      currentPrincipalOutstanding: _num(json['current_principal_outstanding']),
      currentEarnedInterestOutstanding: _num(
        json['current_earned_interest_outstanding'],
      ),
      currentPenaltyOutstanding: _num(json['current_penalty_outstanding']),
      currentTotalOutstanding: _num(json['current_total_outstanding']),
      scheduledFutureInterestOutstanding: _num(
        json['scheduled_future_interest_outstanding'],
      ),
      status: MemberScheduleStatus.fromWire(
        json['member_schedule_status'] as String?,
      ),
    );
  }

  final String installmentId;
  final int installmentNumber;
  final DateTime dueDate;
  final double scheduledPrincipal;
  final double scheduledInterest;
  final double scheduledTotal;
  final double paidPrincipal;
  final double paidInterest;
  final double paidPenalty;
  final double currentPrincipalOutstanding;
  final double currentEarnedInterestOutstanding;
  final double currentPenaltyOutstanding;
  final double currentTotalOutstanding;
  final double scheduledFutureInterestOutstanding;
  final MemberScheduleStatus status;
}

/// One HISTORY installment, from `history[]`. Never a current payable.
class MemberScheduleHistoryRow {
  const MemberScheduleHistoryRow({
    required this.installmentId,
    required this.installmentNumber,
    required this.dueDate,
    required this.scheduledPrincipal,
    required this.scheduledInterest,
    required this.scheduledTotal,
    required this.paidPrincipal,
    required this.paidInterest,
    required this.paidPenalty,
    required this.cancelledOn,
    required this.status,
    required this.replacementReason,
  });

  factory MemberScheduleHistoryRow.fromJson(Map<String, dynamic> json) {
    return MemberScheduleHistoryRow(
      installmentId: json['installment_id'] as String,
      installmentNumber: (json['installment_number'] as num).toInt(),
      dueDate: DateTime.parse(json['due_date'] as String),
      scheduledPrincipal: _num(json['scheduled_principal']),
      scheduledInterest: _num(json['scheduled_interest']),
      scheduledTotal: _num(json['scheduled_total']),
      paidPrincipal: _num(json['paid_principal']),
      paidInterest: _num(json['paid_interest']),
      paidPenalty: _num(json['paid_penalty']),
      cancelledOn: _dateOrNull(json['cancelled_on']),
      status: MemberScheduleHistoryStatus.fromWire(
        json['member_schedule_status'] as String?,
      ),
      replacementReason: json['replacement_reason'] as String?,
    );
  }

  final String installmentId;
  final int installmentNumber;
  final DateTime dueDate;
  final double scheduledPrincipal;
  final double scheduledInterest;
  final double scheduledTotal;
  final double paidPrincipal;
  final double paidInterest;
  final double paidPenalty;
  final DateTime? cancelledOn;
  final MemberScheduleHistoryStatus status;

  /// `RESTRUCTURE` or `PRINCIPAL_PREPAYMENT` for a REPLACED row, else null.
  final String? replacementReason;
}

/// Root of `rpc_get_my_loan_schedule`. `current` and `history` are kept
/// apart. Their figures are never combined.
class MemberLoanSchedule {
  const MemberLoanSchedule({
    required this.loanAccountId,
    required this.status,
    required this.current,
    required this.history,
  });

  factory MemberLoanSchedule.fromJson(Map<String, dynamic> json) {
    return MemberLoanSchedule(
      loanAccountId: json['loan_account_id'] as String,
      status: MemberLoanStatus.fromWire(json['member_status'] as String?),
      current: [
        for (final row in json['current'] as List<dynamic>)
          MemberScheduleRow.fromJson(row as Map<String, dynamic>),
      ],
      history: [
        for (final row in json['history'] as List<dynamic>)
          MemberScheduleHistoryRow.fromJson(row as Map<String, dynamic>),
      ],
    );
  }

  final String loanAccountId;
  final MemberLoanStatus status;
  final List<MemberScheduleRow> current;
  final List<MemberScheduleHistoryRow> history;
}

/// `event_type`. The complete B5 vocabulary. Anything else is `unknown`.
enum MemberLoanEventType {
  loanSubmitted('LOAN_SUBMITTED'),
  loanApproved('LOAN_APPROVED'),
  loanRejected('LOAN_REJECTED'),
  loanCancelled('LOAN_CANCELLED'),
  loanDisbursed('LOAN_DISBURSED'),
  openingPosition('OPENING_POSITION'),
  paymentPosted('PAYMENT_POSTED'),
  recoveryPosted('RECOVERY_POSTED'),
  walletApplied('WALLET_APPLIED'),
  penaltyAssessed('PENALTY_ASSESSED'),
  obligationWaiver('OBLIGATION_WAIVER'),
  obligationCorrection('OBLIGATION_CORRECTION'),
  obligationAdjustmentReversed('OBLIGATION_ADJUSTMENT_REVERSED'),
  principalPrepayment('PRINCIPAL_PREPAYMENT'),
  loanRestructured('LOAN_RESTRUCTURED'),
  loanEarlySettled('LOAN_EARLY_SETTLED'),
  loanClosed('LOAN_CLOSED'),
  loanReopened('LOAN_REOPENED'),
  writeOff('WRITE_OFF'),
  writeOffReversed('WRITE_OFF_REVERSED'),
  unknown('');

  const MemberLoanEventType(this.wire);

  final String wire;

  static MemberLoanEventType fromWire(String? value) {
    for (final type in values) {
      if (type != MemberLoanEventType.unknown && type.wire == value) {
        return type;
      }
    }
    return MemberLoanEventType.unknown;
  }
}

/// `cash_direction`. Accounting metadata only. It is never the main title.
enum MemberLoanCashDirection {
  cashIn('IN'),
  cashOut('OUT');

  const MemberLoanCashDirection(this.wire);

  final String wire;

  static MemberLoanCashDirection? fromWire(String? value) {
    for (final direction in values) {
      if (direction.wire == value) return direction;
    }
    return null;
  }
}

/// One activity event, from `items[]` of `rpc_get_my_loan_timeline`.
///
/// `isCash` is `true` only for a genuine cash movement, and each payment
/// appears once. `amount` is not cash unless `isCash` is true. A reversed
/// payment stays one event with `isReversed` set.
class MemberLoanTimelineEvent {
  const MemberLoanTimelineEvent({
    required this.eventId,
    required this.eventType,
    required this.eventSubtype,
    required this.effectiveAt,
    required this.createdAt,
    required this.isReversed,
    required this.amount,
    required this.isCash,
    required this.cashDirection,
    required this.componentBreakdown,
    required this.metadata,
  });

  factory MemberLoanTimelineEvent.fromJson(Map<String, dynamic> json) {
    final breakdownRaw = json['component_breakdown'] as Map<String, dynamic>?;
    return MemberLoanTimelineEvent(
      eventId: json['event_id'] as String,
      eventType: MemberLoanEventType.fromWire(json['event_type'] as String?),
      eventSubtype: json['event_subtype'] as String?,
      effectiveAt: DateTime.parse(json['effective_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      isReversed: json['is_reversed'] as bool? ?? false,
      amount: _numOrNull(json['amount']),
      isCash: json['is_cash'] as bool? ?? false,
      cashDirection: MemberLoanCashDirection.fromWire(
        json['cash_direction'] as String?,
      ),
      componentBreakdown: breakdownRaw == null
          ? const {}
          : {
              for (final entry in breakdownRaw.entries)
                entry.key: (entry.value as num).toDouble(),
            },
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
    );
  }

  final String eventId;
  final MemberLoanEventType eventType;
  final String? eventSubtype;
  final DateTime effectiveAt;
  final DateTime createdAt;
  final bool isReversed;
  final double? amount;
  final bool isCash;
  final MemberLoanCashDirection? cashDirection;

  /// Keys: `principal`, `interest`, `penalty`. Only the components this
  /// event actually has are present.
  final Map<String, double> componentBreakdown;

  /// Only the safe keys the backend returns for this event. Typed accessors
  /// are below. Nothing else is interpreted.
  final Map<String, dynamic> metadata;

  String? get receiptNumber => metadata['receipt_number'] as String?;

  String? get treatment => metadata['treatment'] as String?;

  double? get principalReductionAmount =>
      _numOrNull(metadata['principal_reduction_amount']);
}

class MemberLoanTimelinePage {
  const MemberLoanTimelinePage({
    required this.loanAccountId,
    required this.items,
    required this.pagination,
  });

  factory MemberLoanTimelinePage.fromJson(Map<String, dynamic> json) {
    return MemberLoanTimelinePage(
      loanAccountId: json['loan_account_id'] as String,
      items: [
        for (final item in json['items'] as List<dynamic>)
          MemberLoanTimelineEvent.fromJson(item as Map<String, dynamic>),
      ],
      pagination: MemberLoanPagination.fromJson(
        json['pagination'] as Map<String, dynamic>,
      ),
    );
  }

  final String loanAccountId;
  final List<MemberLoanTimelineEvent> items;
  final MemberLoanPagination pagination;
}

double _num(Object? value) => (value as num).toDouble();

double? _numOrNull(Object? value) =>
    value == null ? null : (value as num).toDouble();

DateTime? _dateOrNull(Object? value) =>
    value == null ? null : DateTime.parse(value as String);
