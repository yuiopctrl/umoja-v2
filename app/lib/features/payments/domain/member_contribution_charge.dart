/// One raw component of a [MemberCharge], as returned by
/// `rpc_list_member_contribution_charges()` — carries every component
/// (including WAIVER/negative ADJUSTMENT) at its original signed
/// amount, deliberately never netted for display (Prompt 07
/// UAT-FIX-03, section 6). A negative amount reduces the obligation
/// and must never be presented as a payment.
class MemberChargeComponent {
  const MemberChargeComponent({
    required this.componentType,
    required this.amount,
    required this.effectiveAt,
  });

  factory MemberChargeComponent.fromJson(Map<String, dynamic> json) {
    return MemberChargeComponent(
      componentType: json['component_type'] as String,
      amount: (json['amount'] as num).toDouble(),
      effectiveAt: DateTime.parse(json['effective_at'] as String),
    );
  }

  /// One of BASE / PENALTY / ADJUSTMENT / WAIVER / OPENING_BALANCE.
  final String componentType;
  final double amount;
  final DateTime effectiveAt;
}

/// One charge for a member, as returned within
/// `rpc_list_member_contribution_charges()`'s `items[]` — every charge
/// across every period for that membership, never just the still
/// -outstanding ones (that filtering is explicit, via
/// [MemberChargesPage.filter]).
///
/// Distinct from `contributions/domain/member_contribution_charge.dart`
/// 's `MemberContributionCharge`, which is the period-centric "every
/// member's charge within one period" model used by
/// `rpc_list_contribution_period_charges()` — this one is the
/// member-centric "every charge for one member across every period"
/// model (Prompt 07 UAT-FIX-03).
class MemberCharge {
  const MemberCharge({
    required this.chargeId,
    required this.periodId,
    required this.dueDate,
    required this.contributionTypeName,
    required this.periodLabel,
    required this.periodPurpose,
    required this.periodStatus,
    required this.isOverdue,
    required this.netAssessed,
    required this.allocated,
    required this.outstanding,
    required this.components,
  });

  factory MemberCharge.fromJson(Map<String, dynamic> json) {
    return MemberCharge(
      chargeId: json['charge_id'] as String,
      periodId: json['period_id'] as String,
      dueDate: DateTime.parse(json['due_date'] as String),
      contributionTypeName: json['contribution_type_name'] as String,
      periodLabel: json['period_label'] as String,
      periodPurpose: json['period_purpose'] as String,
      periodStatus: json['period_status'] as String,
      isOverdue: json['is_overdue'] as bool,
      netAssessed: (json['net_assessed'] as num).toDouble(),
      allocated: (json['allocated'] as num).toDouble(),
      outstanding: (json['outstanding'] as num).toDouble(),
      components: (json['components'] as List<dynamic>)
          .map(
            (item) =>
                MemberChargeComponent.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }

  final String chargeId;
  final String periodId;
  final DateTime dueDate;
  final String contributionTypeName;
  final String periodLabel;

  /// 'NORMAL' or 'OPENING_BALANCE'.
  final String periodPurpose;

  /// The contribution period's own lifecycle status (e.g. OPEN/CLOSED).
  final String periodStatus;
  final bool isOverdue;
  final double netAssessed;
  final double allocated;
  final double outstanding;
  final List<MemberChargeComponent> components;

  bool get isOpeningBalance => periodPurpose == 'OPENING_BALANCE';
  bool get isSettled => outstanding <= 0;
}

/// One page of `rpc_list_member_contribution_charges()` results — the
/// member-centric Charges/Madeni view (Prompt 07 UAT-FIX-03): every
/// charge for one membership across every period, filterable and
/// paginated, so the treasurer never has to open each contribution
/// period individually to see one member's full charge history.
class MemberChargesPage {
  const MemberChargesPage({
    required this.membershipId,
    required this.memberDisplayName,
    this.memberNumber,
    required this.membershipStatus,
    required this.filter,
    required this.items,
    required this.totalCount,
    required this.limit,
    required this.offset,
  });

  factory MemberChargesPage.fromJson(Map<String, dynamic> json) {
    return MemberChargesPage(
      membershipId: json['membership_id'] as String,
      memberDisplayName: json['member_display_name'] as String,
      memberNumber: json['member_number'] as String?,
      membershipStatus: json['membership_status'] as String,
      filter: json['filter'] as String,
      items: (json['items'] as List<dynamic>)
          .map((item) => MemberCharge.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      totalCount: json['total_count'] as int,
      limit: json['limit'] as int,
      offset: json['offset'] as int,
    );
  }

  static const empty = MemberChargesPage(
    membershipId: '',
    memberDisplayName: '',
    membershipStatus: 'ACTIVE',
    filter: 'OUTSTANDING',
    items: [],
    totalCount: 0,
    limit: 10,
    offset: 0,
  );

  final String membershipId;
  final String memberDisplayName;
  final String? memberNumber;

  /// One of ACTIVE / SUSPENDED / EXITED. Historical charges remain
  /// visible regardless of this status — never filtered by it.
  final String membershipStatus;

  /// One of ALL / OUTSTANDING / SETTLED / OVERDUE, echoing whatever was
  /// requested (normalized to uppercase).
  final String filter;
  final List<MemberCharge> items;
  final int totalCount;
  final int limit;
  final int offset;

  bool get hasMore => offset + items.length < totalCount;
}
