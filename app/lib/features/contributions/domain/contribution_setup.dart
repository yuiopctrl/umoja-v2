/// A contribution setup (a domain `contribution_setups` row) — reusable
/// rules for how a contribution behaves ("how does it charge"), as
/// returned by `rpc_list_contribution_setups()`/
/// `rpc_get_contribution_setup()`/`rpc_create_contribution_setup()`/
/// `rpc_update_contribution_setup()`.
///
/// Penalty fields are configuration only in this Contribution Engine
/// foundation — no penalty component is ever posted from them yet.
class ContributionSetup {
  const ContributionSetup({
    required this.id,
    required this.groupId,
    required this.contributionTypeId,
    required this.name,
    this.description,
    required this.scheduleMode,
    required this.amountMode,
    this.fixedAmount,
    this.defaultDueDay,
    this.defaultDueMonthOffset,
    required this.penaltyMode,
    this.penaltyGraceDays,
    this.penaltyValue,
    this.penaltyCapAmount,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ContributionSetup.fromJson(Map<String, dynamic> json) {
    return ContributionSetup(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      contributionTypeId: json['contribution_type_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      scheduleMode: json['schedule_mode'] as String,
      amountMode: json['amount_mode'] as String,
      fixedAmount: (json['fixed_amount'] as num?)?.toDouble(),
      defaultDueDay: json['default_due_day'] as int?,
      defaultDueMonthOffset: json['default_due_month_offset'] as int?,
      penaltyMode: json['penalty_mode'] as String,
      penaltyGraceDays: json['penalty_grace_days'] as int?,
      penaltyValue: (json['penalty_value'] as num?)?.toDouble(),
      penaltyCapAmount: (json['penalty_cap_amount'] as num?)?.toDouble(),
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String groupId;
  final String contributionTypeId;
  final String name;
  final String? description;

  /// One of MONTHLY / ON_DEMAND / ONE_TIME.
  final String scheduleMode;

  /// One of FIXED / CUSTOM_PER_MEMBER.
  final String amountMode;
  final double? fixedAmount;
  final int? defaultDueDay;
  final int? defaultDueMonthOffset;

  /// One of NONE / FIXED_ONCE / FIXED_RECURRING / PERCENTAGE_ONCE /
  /// PERCENTAGE_RECURRING.
  final String penaltyMode;
  final int? penaltyGraceDays;
  final double? penaltyValue;
  final double? penaltyCapAmount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isFixedAmount => amountMode == 'FIXED';
  bool get isCustomPerMember => amountMode == 'CUSTOM_PER_MEMBER';
  bool get hasPenalty => penaltyMode != 'NONE';
}
