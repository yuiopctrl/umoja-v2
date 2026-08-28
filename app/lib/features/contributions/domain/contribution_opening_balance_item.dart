/// One row of `rpc_list_contribution_opening_balances()` — a dedicated
/// reporting path, deliberately separate from the normal periods/charges
/// listings (which always exclude opening-balance system periods; see
/// `rpc_list_contribution_periods`). [netAssessed] reflects this
/// member's full obligation on this opening-balance charge, including
/// any later adjustment/waiver posted against it — not just the raw
/// imported amount.
class ContributionOpeningBalanceItem {
  const ContributionOpeningBalanceItem({
    required this.chargeId,
    required this.membershipId,
    required this.memberNumberSnapshot,
    required this.memberNameSnapshot,
    required this.effectiveAt,
    required this.contributionTypeName,
    required this.category,
    required this.accountingTreatment,
    required this.openingBalanceAmount,
    required this.netAssessed,
  });

  factory ContributionOpeningBalanceItem.fromJson(Map<String, dynamic> json) {
    return ContributionOpeningBalanceItem(
      chargeId: json['charge_id'] as String,
      membershipId: json['membership_id'] as String,
      memberNumberSnapshot: json['member_number_snapshot'] as String,
      memberNameSnapshot: json['member_name_snapshot'] as String,
      effectiveAt: DateTime.parse(json['effective_at'] as String),
      contributionTypeName: json['contribution_type_name'] as String,
      category: json['category'] as String,
      accountingTreatment: json['accounting_treatment'] as String,
      openingBalanceAmount: (json['opening_balance_amount'] as num).toDouble(),
      netAssessed: (json['net_assessed'] as num).toDouble(),
    );
  }

  final String chargeId;
  final String membershipId;
  final String memberNumberSnapshot;
  final String memberNameSnapshot;
  final DateTime effectiveAt;
  final String contributionTypeName;
  final String category;
  final String accountingTreatment;
  final double openingBalanceAmount;
  final double netAssessed;
}
