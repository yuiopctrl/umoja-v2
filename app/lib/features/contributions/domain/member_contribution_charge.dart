/// One posted member contribution charge, as returned by
/// `rpc_list_contribution_period_charges()`.
///
/// Deliberately has no paid/unpaid/balance concept — there is no
/// payments module yet (see docs/accounting/invariants.md). This is
/// only ever the assessed obligation.
class MemberContributionCharge {
  const MemberContributionCharge({
    required this.chargeId,
    required this.membershipId,
    required this.memberNumberSnapshot,
    required this.memberNameSnapshot,
    required this.effectiveAt,
    required this.dueDate,
    required this.createdAt,
    required this.baseAmount,
    this.penaltyAmount = 0,
    this.penaltyCount = 0,
    double? totalAmount,
  }) : totalAmount = totalAmount ?? baseAmount;

  factory MemberContributionCharge.fromJson(Map<String, dynamic> json) {
    return MemberContributionCharge(
      chargeId: json['charge_id'] as String,
      membershipId: json['membership_id'] as String,
      memberNumberSnapshot: json['member_number_snapshot'] as String,
      memberNameSnapshot: json['member_name_snapshot'] as String,
      effectiveAt: DateTime.parse(json['effective_at'] as String),
      dueDate: DateTime.parse(json['due_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      baseAmount: (json['base_amount'] as num).toDouble(),
      penaltyAmount: (json['penalty_amount'] as num?)?.toDouble() ?? 0,
      penaltyCount: json['penalty_count'] as int? ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble(),
    );
  }

  final String chargeId;
  final String membershipId;
  final String memberNumberSnapshot;
  final String memberNameSnapshot;
  final DateTime effectiveAt;
  final DateTime dueDate;
  final DateTime createdAt;
  final double baseAmount;

  /// Prompt 06B: sum/count of this charge's posted PENALTY components.
  /// Zero for a charge with no penalty policy or none yet due.
  final double penaltyAmount;
  final int penaltyCount;

  /// Server-computed `base_amount + penaltyAmount` — never re-derived
  /// client-side from the two, even though it happens to equal their
  /// sum, per "Flutter must not calculate authoritative financial
  /// amounts."
  final double totalAmount;
}
