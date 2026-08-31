/// One still-outstanding component of a charge, as returned within
/// [OutstandingCharge.components] — a fully-settled component never
/// appears here at all (the backend excludes it entirely).
class OutstandingComponent {
  const OutstandingComponent({
    required this.componentType,
    required this.grossAfterCorrections,
    required this.allocated,
    required this.outstanding,
  });

  factory OutstandingComponent.fromJson(Map<String, dynamic> json) {
    return OutstandingComponent(
      componentType: json['component_type'] as String,
      grossAfterCorrections: (json['gross_after_corrections'] as num)
          .toDouble(),
      allocated: (json['allocated'] as num).toDouble(),
      outstanding: (json['outstanding'] as num).toDouble(),
    );
  }

  /// One of BASE / PENALTY / ADJUSTMENT / OPENING_BALANCE.
  final String componentType;
  final double grossAfterCorrections;
  final double allocated;
  final double outstanding;
}

/// One still-outstanding charge — a fully-settled charge never appears
/// in [MemberContributionStatement.charges] at all.
class OutstandingCharge {
  const OutstandingCharge({
    required this.chargeId,
    required this.periodId,
    required this.dueDate,
    required this.contributionTypeName,
    required this.periodLabel,
    required this.periodPurpose,
    required this.components,
  });

  factory OutstandingCharge.fromJson(Map<String, dynamic> json) {
    return OutstandingCharge(
      chargeId: json['charge_id'] as String,
      periodId: json['period_id'] as String,
      dueDate: DateTime.parse(json['due_date'] as String),
      contributionTypeName: json['contribution_type_name'] as String,
      periodLabel: json['period_label'] as String,
      periodPurpose: json['period_purpose'] as String,
      components: (json['components'] as List<dynamic>)
          .map(
            (item) =>
                OutstandingComponent.fromJson(item as Map<String, dynamic>),
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
  final List<OutstandingComponent> components;

  bool get isOpeningBalance => periodPurpose == 'OPENING_BALANCE';
}

/// Result of `rpc_get_member_contribution_statement` — the
/// authoritative "before payment" summary (Prompt 07 UAT-FIX-01,
/// section 1/2): member identity, total outstanding debt, wallet
/// balance, and the specific obligations making up that debt. Shown
/// immediately after selecting a member in Record Payment, before any
/// amount is entered. Never computed client-side.
class MemberContributionStatement {
  const MemberContributionStatement({
    required this.membershipId,
    required this.memberDisplayName,
    this.memberNumber,
    required this.membershipStatus,
    required this.charges,
    required this.totalOutstanding,
    required this.totalAllocated,
    required this.walletBalance,
  });

  factory MemberContributionStatement.fromJson(Map<String, dynamic> json) {
    return MemberContributionStatement(
      membershipId: json['membership_id'] as String,
      memberDisplayName: json['member_display_name'] as String,
      memberNumber: json['member_number'] as String?,
      membershipStatus: json['membership_status'] as String,
      charges: (json['charges'] as List<dynamic>)
          .map(
            (item) => OutstandingCharge.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      totalOutstanding: (json['total_outstanding'] as num).toDouble(),
      totalAllocated: (json['total_allocated'] as num).toDouble(),
      walletBalance: (json['wallet_balance'] as num).toDouble(),
    );
  }

  final String membershipId;
  final String memberDisplayName;
  final String? memberNumber;

  /// One of ACTIVE / SUSPENDED / EXITED.
  final String membershipStatus;

  /// Only still-outstanding charges — a fully-settled charge is never
  /// included, not even with an empty components list. An empty list
  /// here means "no outstanding debt at all", never "failed to load".
  final List<OutstandingCharge> charges;
  final double totalOutstanding;

  /// Global sum of allocations across EVERY charge for this member
  /// (Prompt 07 UAT-FIX-03), including charges fully settled and
  /// therefore excluded from [charges] — "how much has this member
  /// paid/been allocated in total", not just what remains outstanding.
  final double totalAllocated;

  /// Always present, including exactly `0` — a zero wallet balance is
  /// a valid, normal state, never treated as missing data.
  final double walletBalance;
}
