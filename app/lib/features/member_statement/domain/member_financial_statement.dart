// Prompt 09G-B3-C: Member Financial Statement — read-only, server-
// computed domain models for `rpc_get_my_member_statement`
// (supabase/migrations/20260924090000_create_member_financial_statement_backend.sql,
// corrected by 09G-B3-B-FIX-01 for period.opening/period.closing).
// Every figure is rendered exactly as the RPC returns it; Flutter
// NEVER recomputes, re-sorts, or nets these values — see that
// migration's own locked contract (no synthetic cross-domain net
// balance, contributions/loans/wallet always three independent
// figures).

/// The caller's own membership, as returned by `member`.
class MemberStatementMember {
  const MemberStatementMember({
    required this.membershipId,
    required this.displayName,
    this.memberNumber,
    required this.membershipStatus,
  });

  factory MemberStatementMember.fromJson(Map<String, dynamic> json) {
    return MemberStatementMember(
      membershipId: json['membership_id'] as String,
      displayName: json['display_name'] as String,
      memberNumber: json['member_number'] as String?,
      membershipStatus: json['membership_status'] as String,
    );
  }

  final String membershipId;
  final String displayName;
  final String? memberNumber;
  final String membershipStatus;
}

/// `group` — currency is metadata only (see `money_format.dart`): no
/// currency-symbol/conversion logic exists anywhere in this project.
class MemberStatementGroup {
  const MemberStatementGroup({
    required this.groupId,
    required this.groupName,
    this.groupCode,
    required this.currency,
  });

  factory MemberStatementGroup.fromJson(Map<String, dynamic> json) {
    return MemberStatementGroup(
      groupId: json['group_id'] as String,
      groupName: json['group_name'] as String,
      groupCode: json['group_code'] as String?,
      currency: json['currency'] as String,
    );
  }

  final String groupId;
  final String groupName;
  final String? groupCode;
  final String currency;
}

/// One of `period.opening`/`period.closing` — the caller's own
/// three independent positions (contributions/loans/wallet) as of a
/// single cutoff date. Never a fourth, netted figure.
class MemberStatementPeriodPosition {
  const MemberStatementPeriodPosition({
    required this.asOfDate,
    required this.contributionsOutstanding,
    required this.loansOutstanding,
    required this.walletBalance,
  });

  factory MemberStatementPeriodPosition.fromJson(Map<String, dynamic> json) {
    return MemberStatementPeriodPosition(
      asOfDate: DateTime.parse(json['as_of_date'] as String),
      contributionsOutstanding:
          ((json['contributions'] as Map<String, dynamic>)['outstanding']
                  as num)
              .toDouble(),
      loansOutstanding:
          ((json['loans'] as Map<String, dynamic>)['outstanding'] as num)
              .toDouble(),
      walletBalance:
          ((json['wallet'] as Map<String, dynamic>)['balance'] as num)
              .toDouble(),
    );
  }

  final DateTime asOfDate;
  final double contributionsOutstanding;
  final double loansOutstanding;
  final double walletBalance;
}

/// `period` — `opening`/`closing` are `null` whenever the
/// corresponding date bound wasn't supplied; a `null` here is never
/// rendered as a fabricated zero (see `MemberStatementScreen`).
class MemberStatementPeriod {
  const MemberStatementPeriod({
    this.fromDate,
    this.toDate,
    this.opening,
    this.closing,
  });

  factory MemberStatementPeriod.fromJson(Map<String, dynamic> json) {
    return MemberStatementPeriod(
      fromDate: json['from_date'] == null
          ? null
          : DateTime.parse(json['from_date'] as String),
      toDate: json['to_date'] == null
          ? null
          : DateTime.parse(json['to_date'] as String),
      opening: json['opening'] == null
          ? null
          : MemberStatementPeriodPosition.fromJson(
              json['opening'] as Map<String, dynamic>,
            ),
      closing: json['closing'] == null
          ? null
          : MemberStatementPeriodPosition.fromJson(
              json['closing'] as Map<String, dynamic>,
            ),
    );
  }

  final DateTime? fromDate;
  final DateTime? toDate;
  final MemberStatementPeriodPosition? opening;
  final MemberStatementPeriodPosition? closing;
}

class MemberStatementLastPayment {
  const MemberStatementLastPayment({
    required this.amount,
    required this.effectiveAt,
    required this.receiptNumber,
  });

  factory MemberStatementLastPayment.fromJson(Map<String, dynamic> json) {
    return MemberStatementLastPayment(
      amount: (json['amount'] as num).toDouble(),
      effectiveAt: DateTime.parse(json['effective_at'] as String),
      receiptNumber: json['receipt_number'] as String,
    );
  }

  final double amount;
  final DateTime effectiveAt;
  final String receiptNumber;
}

/// `summary` — always the CURRENT position (never a point-in-time "as
/// of p_to_date" figure — see [MemberStatementPeriod] for that).
class MemberStatementSummary {
  const MemberStatementSummary({
    required this.contributionsCurrentOutstanding,
    required this.contributionsPendingPenalties,
    required this.loansCurrentOutstanding,
    required this.loansPendingPenalties,
    required this.walletCurrentBalance,
    this.lastPayment,
  });

  factory MemberStatementSummary.fromJson(Map<String, dynamic> json) {
    final contributions = json['contributions'] as Map<String, dynamic>;
    final loans = json['loans'] as Map<String, dynamic>;
    final wallet = json['wallet'] as Map<String, dynamic>;
    return MemberStatementSummary(
      contributionsCurrentOutstanding:
          (contributions['current_outstanding'] as num).toDouble(),
      contributionsPendingPenalties: (contributions['pending_penalties'] as num)
          .toDouble(),
      loansCurrentOutstanding: (loans['current_outstanding'] as num).toDouble(),
      loansPendingPenalties: (loans['pending_penalties'] as num).toDouble(),
      walletCurrentBalance: (wallet['current_balance'] as num).toDouble(),
      lastPayment: json['last_payment'] == null
          ? null
          : MemberStatementLastPayment.fromJson(
              json['last_payment'] as Map<String, dynamic>,
            ),
    );
  }

  final double contributionsCurrentOutstanding;
  final double contributionsPendingPenalties;
  final double loansCurrentOutstanding;
  final double loansPendingPenalties;
  final double walletCurrentBalance;
  final MemberStatementLastPayment? lastPayment;
}

/// One nested allocation under a PAYMENT activity item's
/// `metadata.allocations` — detail explaining how the cash was
/// applied, never a separate top-level credit (see
/// [MemberStatementActivityItem]).
class MemberStatementAllocation {
  const MemberStatementAllocation({
    required this.amount,
    required this.targetType,
    this.chargeId,
    this.chargeComponentId,
    this.loanAccountId,
    this.loanInstallmentId,
    this.periodLabel,
    this.componentType,
  });

  factory MemberStatementAllocation.fromJson(Map<String, dynamic> json) {
    return MemberStatementAllocation(
      amount: (json['amount'] as num).toDouble(),
      targetType: json['target_type'] as String,
      chargeId: json['charge_id'] as String?,
      chargeComponentId: json['charge_component_id'] as String?,
      loanAccountId: json['loan_account_id'] as String?,
      loanInstallmentId: json['loan_installment_id'] as String?,
      periodLabel: json['period_label'] as String?,
      componentType: json['component_type'] as String?,
    );
  }

  final double amount;

  /// CONTRIBUTION_COMPONENT | LOAN_PRINCIPAL | LOAN_INTEREST |
  /// LOAN_PENALTY | ... (the project's `payment_allocation_target_type`
  /// enum) — rendered via a friendly label, backend code preserved
  /// verbatim for forward-safety against a value this client build
  /// doesn't know about yet.
  final String targetType;
  final String? chargeId;
  final String? chargeComponentId;
  final String? loanAccountId;
  final String? loanInstallmentId;

  /// Prompt 09G-B3-UX-01-FIX-01 §E: the contribution period's real
  /// persisted `label` (e.g. "Ada ya Septemba") — null for a LOAN_*
  /// allocation (no charge on those rows) and, defensively, for any
  /// response from before this additive enrichment reached the
  /// caller's environment.
  final String? periodLabel;

  /// The persisted `contribution_charge_components.component_type`
  /// (BASE/PENALTY/ADJUSTMENT/WAIVER/OPENING_BALANCE) — null for a
  /// LOAN_* allocation, same defensive-null reasoning as [periodLabel].
  final String? componentType;

  bool get isContribution => targetType == 'CONTRIBUTION_COMPONENT';
  bool get isLoan => !isContribution;
}

/// One row of `activity.items[]` — already in the server's exact
/// deterministic order (effective_date, source_priority, then
/// server-side tie-breakers). NEVER re-sorted, re-grouped, or
/// filtered by amount/domain/event-type client-side.
class MemberStatementActivityItem {
  const MemberStatementActivityItem({
    required this.eventId,
    required this.domain,
    required this.eventType,
    required this.effectiveDate,
    required this.amount,
    required this.isReversed,
    this.metadata = const {},
  });

  factory MemberStatementActivityItem.fromJson(Map<String, dynamic> json) {
    return MemberStatementActivityItem(
      eventId: json['event_id'] as String,
      domain: json['domain'] as String,
      eventType: json['event_type'] as String,
      effectiveDate: DateTime.parse(json['effective_date'] as String),
      amount: (json['amount'] as num).toDouble(),
      isReversed: json['is_reversed'] as bool? ?? false,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
    );
  }

  final String eventId;

  /// CONTRIBUTION | PAYMENT | LOAN | WALLET.
  final String domain;

  /// Contribution: BASE/PENALTY/ADJUSTMENT/WAIVER/OPENING_BALANCE.
  /// Payment: always "PAYMENT". Loan: DISBURSEMENT/WRITE_OFF/REVERSAL/
  /// WAIVER/CORRECTION_DECREASE/CORRECTION_INCREASE. Wallet:
  /// PAYMENT_CREDIT/ALLOCATION_DEBIT/REVERSAL. Preserved verbatim —
  /// never assumed exhaustive, a label helper falls back to the raw
  /// code for any value it doesn't recognize.
  final String eventType;
  final DateTime effectiveDate;
  final double amount;
  final bool isReversed;
  final Map<String, dynamic> metadata;

  /// PAYMENT-only. Empty for every other domain.
  List<MemberStatementAllocation> get allocations {
    final raw = metadata['allocations'] as List<dynamic>?;
    if (raw == null) return const [];
    return raw
        .map(
          (item) =>
              MemberStatementAllocation.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  String? get periodLabel => metadata['period_label'] as String?;
  String? get loanNumber => metadata['loan_number'] as String?;
  String? get receiptNumber => metadata['receipt_number'] as String?;
  String? get reasonCode => metadata['reason_code'] as String?;
  String? get note => metadata['note'] as String?;
}

/// `activity` — pagination metadata is entirely server-owned;
/// [hasMore] is NEVER inferred from `items.length` client-side.
class MemberStatementActivity {
  const MemberStatementActivity({
    required this.items,
    required this.limit,
    required this.offset,
    required this.totalCount,
    required this.hasMore,
  });

  factory MemberStatementActivity.fromJson(Map<String, dynamic> json) {
    return MemberStatementActivity(
      items: (json['items'] as List<dynamic>)
          .map(
            (item) => MemberStatementActivityItem.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
      limit: json['limit'] as int,
      offset: json['offset'] as int,
      totalCount: json['total_count'] as int,
      hasMore: json['has_more'] as bool,
    );
  }

  final List<MemberStatementActivityItem> items;
  final int limit;
  final int offset;
  final int totalCount;
  final bool hasMore;
}

/// `rpc_get_my_member_statement`'s full read model.
class MemberFinancialStatement {
  const MemberFinancialStatement({
    required this.member,
    required this.group,
    required this.period,
    required this.summary,
    required this.activity,
  });

  factory MemberFinancialStatement.fromJson(Map<String, dynamic> json) {
    return MemberFinancialStatement(
      member: MemberStatementMember.fromJson(
        json['member'] as Map<String, dynamic>,
      ),
      group: MemberStatementGroup.fromJson(
        json['group'] as Map<String, dynamic>,
      ),
      period: MemberStatementPeriod.fromJson(
        json['period'] as Map<String, dynamic>,
      ),
      summary: MemberStatementSummary.fromJson(
        json['summary'] as Map<String, dynamic>,
      ),
      activity: MemberStatementActivity.fromJson(
        json['activity'] as Map<String, dynamic>,
      ),
    );
  }

  final MemberStatementMember member;
  final MemberStatementGroup group;
  final MemberStatementPeriod period;
  final MemberStatementSummary summary;
  final MemberStatementActivity activity;
}
