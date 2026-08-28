/// A member's obligation summary across every one of their contribution
/// charges in a group, as returned by
/// `rpc_get_member_contribution_summary()` — the "Member Contribution
/// Obligation Summary". Deliberately has no paid/outstanding-after-
/// payment concept: there is no payments module yet.
class MemberContributionSummary {
  const MemberContributionSummary({
    required this.membershipId,
    required this.baseAssessed,
    required this.penaltiesAssessed,
    required this.adjustmentsAssessed,
    required this.waiversAssessed,
    required this.openingBalancesAssessed,
    required this.netAssessed,
  });

  factory MemberContributionSummary.fromJson(Map<String, dynamic> json) {
    return MemberContributionSummary(
      membershipId: json['membership_id'] as String,
      baseAssessed: (json['base_assessed'] as num).toDouble(),
      penaltiesAssessed: (json['penalties_assessed'] as num).toDouble(),
      adjustmentsAssessed: (json['adjustments_assessed'] as num).toDouble(),
      waiversAssessed: (json['waivers_assessed'] as num).toDouble(),
      openingBalancesAssessed: (json['opening_balances_assessed'] as num)
          .toDouble(),
      netAssessed: (json['net_assessed'] as num).toDouble(),
    );
  }

  final String membershipId;
  final double baseAssessed;
  final double penaltiesAssessed;
  final double adjustmentsAssessed;
  final double waiversAssessed;
  final double openingBalancesAssessed;
  final double netAssessed;
}
