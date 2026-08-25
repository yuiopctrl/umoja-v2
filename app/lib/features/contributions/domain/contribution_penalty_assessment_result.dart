/// The server-computed result of `rpc_assess_contribution_penalties()`.
/// Flutter never calculates any of these numbers itself — it only
/// displays what the backend actually posted.
class ContributionPenaltyAssessmentResult {
  const ContributionPenaltyAssessmentResult({
    required this.periodId,
    required this.assessmentDate,
    required this.qualifyingChargeCount,
    required this.penaltiesCreatedCount,
    required this.alreadyCurrentChargeCount,
    required this.totalPenaltyAssessedThisRun,
  });

  factory ContributionPenaltyAssessmentResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return ContributionPenaltyAssessmentResult(
      periodId: json['period_id'] as String,
      assessmentDate: DateTime.parse(json['assessment_date'] as String),
      qualifyingChargeCount: json['qualifying_charge_count'] as int,
      penaltiesCreatedCount: json['penalties_created_count'] as int,
      alreadyCurrentChargeCount: json['already_current_charge_count'] as int,
      totalPenaltyAssessedThisRun:
          (json['total_penalty_assessed_this_run'] as num).toDouble(),
    );
  }

  final String periodId;
  final DateTime assessmentDate;

  /// Charges that were overdue as of [assessmentDate] (whether or not a
  /// new occurrence was actually posted this run).
  final int qualifyingChargeCount;

  /// New PENALTY components posted by this call.
  final int penaltiesCreatedCount;

  /// Overdue charges that already had the correct number of occurrences
  /// for [assessmentDate] before this call — i.e. nothing new for them.
  final int alreadyCurrentChargeCount;

  /// Sum of only the newly-created components' amounts (not the
  /// period's running total — see [ContributionPeriod.totalPenaltyAssessed]
  /// for that).
  final double totalPenaltyAssessedThisRun;
}
