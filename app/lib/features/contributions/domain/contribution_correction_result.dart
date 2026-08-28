/// Shared result shape for both `rpc_create_contribution_adjustment()`
/// and `rpc_waive_contribution_charge()` — [amount] is always the
/// caller's own signed (adjustment) or positive-magnitude (waiver)
/// input echoed back, never a value to re-derive a sign from.
/// [netAssessed] is the server-authoritative total after posting (or
/// after the original post, on an idempotent retry) — the UI shows this
/// directly rather than computing it from prior state.
class ContributionCorrectionResult {
  const ContributionCorrectionResult({
    required this.componentId,
    required this.chargeId,
    required this.amount,
    required this.alreadyPosted,
    required this.netAssessed,
  });

  factory ContributionCorrectionResult.fromJson(Map<String, dynamic> json) {
    return ContributionCorrectionResult(
      componentId: json['component_id'] as String,
      chargeId: json['charge_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      alreadyPosted: json['already_posted'] as bool,
      netAssessed: (json['net_assessed'] as num).toDouble(),
    );
  }

  final String componentId;
  final String chargeId;
  final double amount;

  /// True only when an idempotency-key retry matched an existing
  /// component instead of posting a new one.
  final bool alreadyPosted;
  final double netAssessed;
}
