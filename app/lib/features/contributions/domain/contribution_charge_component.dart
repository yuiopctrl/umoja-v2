/// One posted `contribution_charge_components` row, as returned by
/// `rpc_get_contribution_charge_detail()`.
///
/// [amount] carries whatever sign the backend stored — BASE/PENALTY/
/// OPENING_BALANCE are always positive, ADJUSTMENT may be either sign,
/// WAIVER is always negative (see the sign-convention CHECK constraint
/// added by Prompt 06C's migration). Never re-signed or reinterpreted
/// client-side.
class ContributionChargeComponent {
  const ContributionChargeComponent({
    required this.componentId,
    required this.componentType,
    required this.amount,
    this.reason,
    required this.effectiveAt,
    required this.sequence,
    required this.createdAt,
    this.createdBy,
  });

  factory ContributionChargeComponent.fromJson(Map<String, dynamic> json) {
    return ContributionChargeComponent(
      componentId: json['component_id'] as String,
      componentType: json['component_type'] as String,
      amount: (json['amount'] as num).toDouble(),
      reason: json['reason'] as String?,
      effectiveAt: DateTime.parse(json['effective_at'] as String),
      sequence: json['sequence'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String?,
    );
  }

  final String componentId;

  /// One of BASE / PENALTY / ADJUSTMENT / WAIVER / OPENING_BALANCE.
  final String componentType;
  final double amount;

  /// Only ever set for ADJUSTMENT/WAIVER — required by the backend when
  /// those are created.
  final String? reason;
  final DateTime effectiveAt;
  final int sequence;
  final DateTime createdAt;
  final String? createdBy;

  bool get isBase => componentType == 'BASE';
  bool get isPenalty => componentType == 'PENALTY';
  bool get isAdjustment => componentType == 'ADJUSTMENT';
  bool get isWaiver => componentType == 'WAIVER';
  bool get isOpeningBalance => componentType == 'OPENING_BALANCE';
}
