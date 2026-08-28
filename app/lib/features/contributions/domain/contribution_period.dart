/// A contribution period (a domain `contribution_periods` row) — one
/// concrete obligation cycle/event.
///
/// This single model tolerates the three different JSON shapes the
/// backend returns for a period, all sharing the same core fields:
/// - `rpc_create_contribution_period()`: core fields only.
/// - `rpc_list_contribution_periods()`: core fields + opened_at/
///   closed_at/cancelled_at (no *_by, no snapshot_*, no summary counts).
/// - `rpc_get_contribution_period()`: everything, including opened_by/
///   closed_by/cancelled_by, all snapshot_* fields (populated only once
///   OPEN), and [excludedCount]/[customAmountCount]/
///   [totalMembersCharged]/[totalBaseAssessed] (get-only summary
///   counts — never computed client-side from a paginated charges
///   list).
class ContributionPeriod {
  const ContributionPeriod({
    required this.id,
    required this.groupId,
    required this.contributionSetupId,
    required this.label,
    required this.periodStart,
    required this.periodEnd,
    required this.obligationDate,
    required this.eligibilityDate,
    required this.dueDate,
    required this.status,
    this.scheduledOpenDate,
    this.openedAt,
    this.openedBy,
    this.closedAt,
    this.closedBy,
    this.cancelledAt,
    this.cancelledBy,
    this.snapshotTypeName,
    this.snapshotCategory,
    this.snapshotAccountingTreatment,
    this.snapshotSetupName,
    this.snapshotScheduleMode,
    this.snapshotAmountMode,
    this.snapshotFixedAmount,
    this.snapshotPenaltyMode,
    this.snapshotPenaltyGraceDays,
    this.snapshotPenaltyValue,
    this.snapshotPenaltyCapAmount,
    required this.createdAt,
    required this.updatedAt,
    this.excludedCount,
    this.customAmountCount,
    this.totalMembersCharged,
    this.totalBaseAssessed,
    this.totalPenaltyAssessed,
    this.penaltyChargeCount,
    this.totalAdjustmentsAssessed,
    this.totalWaiversAssessed,
    this.netAssessedTotal,
  });

  factory ContributionPeriod.fromJson(Map<String, dynamic> json) {
    return ContributionPeriod(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      contributionSetupId: json['contribution_setup_id'] as String,
      label: json['label'] as String,
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      obligationDate: DateTime.parse(json['obligation_date'] as String),
      eligibilityDate: DateTime.parse(json['eligibility_date'] as String),
      dueDate: DateTime.parse(json['due_date'] as String),
      status: json['status'] as String,
      scheduledOpenDate: _date(json['scheduled_open_date']),
      openedAt: _dateTime(json['opened_at']),
      openedBy: json['opened_by'] as String?,
      closedAt: _dateTime(json['closed_at']),
      closedBy: json['closed_by'] as String?,
      cancelledAt: _dateTime(json['cancelled_at']),
      cancelledBy: json['cancelled_by'] as String?,
      snapshotTypeName: json['snapshot_type_name'] as String?,
      snapshotCategory: json['snapshot_category'] as String?,
      snapshotAccountingTreatment:
          json['snapshot_accounting_treatment'] as String?,
      snapshotSetupName: json['snapshot_setup_name'] as String?,
      snapshotScheduleMode: json['snapshot_schedule_mode'] as String?,
      snapshotAmountMode: json['snapshot_amount_mode'] as String?,
      snapshotFixedAmount: (json['snapshot_fixed_amount'] as num?)?.toDouble(),
      snapshotPenaltyMode: json['snapshot_penalty_mode'] as String?,
      snapshotPenaltyGraceDays: json['snapshot_penalty_grace_days'] as int?,
      snapshotPenaltyValue: (json['snapshot_penalty_value'] as num?)
          ?.toDouble(),
      snapshotPenaltyCapAmount: (json['snapshot_penalty_cap_amount'] as num?)
          ?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      excludedCount: json['excluded_count'] as int?,
      customAmountCount: json['custom_amount_count'] as int?,
      totalMembersCharged: json['total_members_charged'] as int?,
      totalBaseAssessed: (json['total_base_assessed'] as num?)?.toDouble(),
      totalPenaltyAssessed: (json['total_penalty_assessed'] as num?)
          ?.toDouble(),
      penaltyChargeCount: json['penalty_charge_count'] as int?,
      totalAdjustmentsAssessed: (json['total_adjustments_assessed'] as num?)
          ?.toDouble(),
      totalWaiversAssessed: (json['total_waivers_assessed'] as num?)
          ?.toDouble(),
      netAssessedTotal: (json['net_assessed_total'] as num?)?.toDouble(),
    );
  }

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    return DateTime.parse(value as String);
  }

  static DateTime? _dateTime(Object? value) {
    if (value == null) return null;
    return DateTime.parse(value as String);
  }

  final String id;
  final String groupId;
  final String contributionSetupId;
  final String label;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime obligationDate;
  final DateTime eligibilityDate;
  final DateTime dueDate;

  /// One of DRAFT / SCHEDULED / OPEN / CLOSED / CANCELLED.
  final String status;
  final DateTime? scheduledOpenDate;

  final DateTime? openedAt;
  final String? openedBy;
  final DateTime? closedAt;
  final String? closedBy;
  final DateTime? cancelledAt;
  final String? cancelledBy;

  // Configuration snapshot, frozen at OPEN — null while DRAFT/SCHEDULED.
  final String? snapshotTypeName;
  final String? snapshotCategory;
  final String? snapshotAccountingTreatment;
  final String? snapshotSetupName;
  final String? snapshotScheduleMode;
  final String? snapshotAmountMode;
  final double? snapshotFixedAmount;
  final String? snapshotPenaltyMode;
  final int? snapshotPenaltyGraceDays;
  final double? snapshotPenaltyValue;
  final double? snapshotPenaltyCapAmount;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Only populated by `rpc_get_contribution_period()`.
  final int? excludedCount;
  final int? customAmountCount;
  final int? totalMembersCharged;
  final double? totalBaseAssessed;

  /// Only populated by `rpc_get_contribution_period()` — sum of every
  /// posted PENALTY component across the period, and how many distinct
  /// charges have at least one. Prompt 06B.
  final double? totalPenaltyAssessed;
  final int? penaltyChargeCount;

  /// Only populated by `rpc_get_contribution_period()` — Prompt 06C:
  /// sum of every posted ADJUSTMENT/WAIVER component across the period
  /// (WAIVER already negative), and the full net-assessed total (BASE +
  /// PENALTY + ADJUSTMENT + WAIVER). [totalBaseAssessed] is never
  /// overwritten by these — it always stays the original BASE sum.
  final double? totalAdjustmentsAssessed;
  final double? totalWaiversAssessed;
  final double? netAssessedTotal;

  bool get isDraft => status == 'DRAFT';
  bool get isScheduled => status == 'SCHEDULED';
  bool get isOpen => status == 'OPEN';
  bool get isClosed => status == 'CLOSED';
  bool get isCancelled => status == 'CANCELLED';

  /// DRAFT/SCHEDULED: not yet posted, still fully editable/cancellable.
  bool get isPreOpen => isDraft || isScheduled;

  /// Whether this period's frozen snapshot has an actual penalty policy
  /// configured (`NONE`, or no snapshot at all pre-OPEN, both mean no
  /// policy) — gates whether the "Assess Penalties" action can ever be
  /// meaningful for this period.
  bool get hasPenaltyPolicy =>
      snapshotPenaltyMode != null && snapshotPenaltyMode != 'NONE';
}
