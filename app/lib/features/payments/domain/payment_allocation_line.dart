/// One settled (or previewed-to-settle) obligation component — used by
/// [PaymentAllocationPreview], [PaymentDetail], and [Receipt]. Never a
/// cash event itself; see `docs/product/payments.md` for the
/// three-layer separation this reflects.
///
/// [contributionTypeName]/[periodLabel]/[periodPurpose] give the
/// business context a bare [componentType] cannot (UAT-FIX-01: two
/// BASE rows from different periods were previously indistinguishable
/// — "Base 20,000 / Base 10,000"). For an already-POSTED allocation
/// (from [PaymentDetail]/[Receipt]) these are the values snapshotted
/// at posting time — never re-derived from the current, possibly
/// since-renamed contribution type/period — so a receipt never
/// becomes misleading after a later rename. For a preview (not yet
/// posted), they reflect the live current names, since nothing has
/// been snapshotted yet.
class PaymentAllocationLine {
  const PaymentAllocationLine({
    this.chargeId,
    this.componentId,
    required this.componentType,
    required this.dueDate,
    required this.amount,
    this.contributionTypeName,
    this.periodId,
    this.periodLabel,
    this.periodPurpose,
    this.componentOutstandingBefore,
  });

  /// `rpc_get_payment_detail` shape (charge_id/component_id present) —
  /// key `amount`.
  factory PaymentAllocationLine.fromJson(Map<String, dynamic> json) {
    return PaymentAllocationLine(
      chargeId: json['charge_id'] as String?,
      componentId: json['component_id'] as String?,
      componentType: json['component_type'] as String,
      dueDate: DateTime.parse(json['due_date'] as String),
      amount: (json['amount'] as num).toDouble(),
      contributionTypeName: json['contribution_type_name'] as String?,
      periodLabel: json['period_label'] as String?,
      periodPurpose: json['period_purpose'] as String?,
    );
  }

  /// `rpc_preview_payment_allocation`/`rpc_preview_wallet_allocation`
  /// shape — key `allocate_amount`.
  factory PaymentAllocationLine.fromPreviewJson(Map<String, dynamic> json) {
    return PaymentAllocationLine(
      chargeId: json['charge_id'] as String,
      componentId: json['component_id'] as String,
      componentType: json['component_type'] as String,
      dueDate: DateTime.parse(json['due_date'] as String),
      amount: (json['allocate_amount'] as num).toDouble(),
      contributionTypeName: json['contribution_type_name'] as String?,
      periodId: json['period_id'] as String?,
      periodLabel: json['period_label'] as String?,
      periodPurpose: json['period_purpose'] as String?,
      componentOutstandingBefore: json['component_outstanding_before'] == null
          ? null
          : (json['component_outstanding_before'] as num).toDouble(),
    );
  }

  /// `rpc_get_receipt` shape (no charge_id/component_id) — key `amount`.
  factory PaymentAllocationLine.fromReceiptJson(Map<String, dynamic> json) {
    return PaymentAllocationLine(
      componentType: json['component_type'] as String,
      dueDate: DateTime.parse(json['due_date'] as String),
      amount: (json['amount'] as num).toDouble(),
      contributionTypeName: json['contribution_type_name'] as String?,
      periodLabel: json['period_label'] as String?,
      periodPurpose: json['period_purpose'] as String?,
    );
  }

  final String? chargeId;
  final String? componentId;

  /// One of BASE / PENALTY / ADJUSTMENT / OPENING_BALANCE.
  final String componentType;
  final DateTime dueDate;
  final double amount;

  /// Null only for a row posted before UAT-FIX-01 shipped — callers
  /// must render such a row using [componentType] alone, never crash.
  final String? contributionTypeName;
  final String? periodId;
  final String? periodLabel;

  /// 'NORMAL' or 'OPENING_BALANCE' — an OPENING_BALANCE charge's
  /// context label omits the period suffix (see
  /// `obligationContextLabel`).
  final String? periodPurpose;

  /// The component's outstanding amount immediately before this
  /// allocation was taken from it (preview only — always null for a
  /// posted [PaymentDetail]/[Receipt] line).
  final double? componentOutstandingBefore;

  bool get isOpeningBalance => periodPurpose == 'OPENING_BALANCE';
}
