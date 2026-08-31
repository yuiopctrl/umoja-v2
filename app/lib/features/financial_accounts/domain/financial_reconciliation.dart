/// One financial account reconciliation record (Prompt 08B) — evidence
/// that the derived account balance was compared against an external
/// bank/mobile/cash statement at a point in time. Never implies a
/// cashbook movement of its own; immutable after creation except for
/// the single RECONCILED -> CANCELLED status transition.
class FinancialReconciliation {
  const FinancialReconciliation({
    required this.id,
    required this.financialAccountId,
    this.periodStart,
    required this.reconciliationAt,
    required this.systemBalance,
    required this.statedBalance,
    required this.difference,
    required this.status,
    this.notes,
    required this.reconciledBy,
    required this.reconciledAt,
    this.cancelledAt,
    this.cancelledBy,
    this.cancellationReason,
  });

  factory FinancialReconciliation.fromJson(Map<String, dynamic> json) {
    return FinancialReconciliation(
      id: json['id'] as String,
      financialAccountId: json['financial_account_id'] as String,
      periodStart: json['period_start'] == null
          ? null
          : DateTime.parse(json['period_start'] as String),
      reconciliationAt: DateTime.parse(json['reconciliation_at'] as String),
      systemBalance: (json['system_balance'] as num).toDouble(),
      statedBalance: (json['stated_balance'] as num).toDouble(),
      difference: (json['difference'] as num).toDouble(),
      status: json['status'] as String,
      notes: json['notes'] as String?,
      reconciledBy: json['reconciled_by'] as String,
      reconciledAt: DateTime.parse(json['reconciled_at'] as String),
      cancelledAt: json['cancelled_at'] == null
          ? null
          : DateTime.parse(json['cancelled_at'] as String),
      cancelledBy: json['cancelled_by'] as String?,
      cancellationReason: json['cancellation_reason'] as String?,
    );
  }

  final String id;
  final String financialAccountId;
  final DateTime? periodStart;
  final DateTime reconciliationAt;

  /// The authoritative derived account balance at reconciliation time
  /// — never recomputed client-side.
  final double systemBalance;

  /// The entered bank/mobile statement or physical cash count.
  final double statedBalance;

  /// Always `statedBalance - systemBalance`, server-computed.
  final double difference;

  /// 'RECONCILED' or 'CANCELLED'.
  final String status;
  final String? notes;
  final String reconciledBy;
  final DateTime reconciledAt;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final String? cancellationReason;

  bool get isBalanced => difference == 0;
  bool get isCancelled => status == 'CANCELLED';
}

/// One page of `rpc_list_financial_account_reconciliations()` results.
class FinancialReconciliationPage {
  const FinancialReconciliationPage({
    required this.items,
    required this.totalCount,
    required this.limit,
    required this.offset,
  });

  factory FinancialReconciliationPage.fromJson(Map<String, dynamic> json) {
    return FinancialReconciliationPage(
      items: (json['items'] as List<dynamic>)
          .map(
            (item) =>
                FinancialReconciliation.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      totalCount: json['total_count'] as int,
      limit: json['limit'] as int,
      offset: json['offset'] as int,
    );
  }

  static const empty = FinancialReconciliationPage(
    items: [],
    totalCount: 0,
    limit: 10,
    offset: 0,
  );

  final List<FinancialReconciliation> items;
  final int totalCount;
  final int limit;
  final int offset;

  bool get hasMore => offset + items.length < totalCount;
}
