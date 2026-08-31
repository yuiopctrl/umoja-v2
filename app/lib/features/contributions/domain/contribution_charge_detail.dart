import 'contribution_charge_component.dart';

/// Full per-component breakdown of one charge, as returned by
/// `rpc_get_contribution_charge_detail()` — the source for the charge
/// detail screen's Base/Penalty/Adjustment/Waiver/Opening Balance/Net
/// Assessed breakdown. [netAssessed] is always the server-computed sum
/// of every component and is never re-derived client-side.
class ContributionChargeDetail {
  const ContributionChargeDetail({
    required this.chargeId,
    required this.groupId,
    required this.periodId,
    required this.membershipId,
    required this.memberNumberSnapshot,
    required this.memberNameSnapshot,
    required this.effectiveAt,
    required this.dueDate,
    required this.components,
    required this.netAssessed,
    required this.totalOutstanding,
  });

  factory ContributionChargeDetail.fromJson(Map<String, dynamic> json) {
    return ContributionChargeDetail(
      chargeId: json['charge_id'] as String,
      groupId: json['group_id'] as String,
      periodId: json['period_id'] as String,
      membershipId: json['membership_id'] as String,
      memberNumberSnapshot: json['member_number_snapshot'] as String,
      memberNameSnapshot: json['member_name_snapshot'] as String,
      effectiveAt: DateTime.parse(json['effective_at'] as String),
      dueDate: DateTime.parse(json['due_date'] as String),
      components: (json['components'] as List<dynamic>)
          .map(
            (item) => ContributionChargeComponent.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
      netAssessed: (json['net_assessed'] as num).toDouble(),
      totalOutstanding: (json['total_outstanding'] as num).toDouble(),
    );
  }

  final String chargeId;
  final String groupId;
  final String periodId;
  final String membershipId;
  final String memberNumberSnapshot;
  final String memberNameSnapshot;
  final DateTime effectiveAt;
  final DateTime dueDate;
  final List<ContributionChargeComponent> components;
  final double netAssessed;

  /// Server-computed remaining unallocated amount across every
  /// component of this charge (Prompt 07 UAT-FIX-03) — never re-derived
  /// from [components] client-side.
  final double totalOutstanding;

  double _sumOf(String type) => components
      .where((c) => c.componentType == type)
      .fold(0.0, (sum, c) => sum + c.amount);

  double get baseAmount => _sumOf('BASE');
  double get penaltyAmount => _sumOf('PENALTY');
  double get adjustmentAmount => _sumOf('ADJUSTMENT');
  double get waiverAmount => _sumOf('WAIVER');
  double get openingBalanceAmount => _sumOf('OPENING_BALANCE');
}
