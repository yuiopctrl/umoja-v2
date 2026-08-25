/// One row inside [ContributionPeriodOpenPreview.eligibleMembers].
class ContributionPreviewEligibleMember {
  const ContributionPreviewEligibleMember({
    required this.membershipId,
    required this.memberNumber,
    required this.displayName,
    this.amount,
  });

  factory ContributionPreviewEligibleMember.fromJson(
    Map<String, dynamic> json,
  ) {
    return ContributionPreviewEligibleMember(
      membershipId: json['membership_id'] as String,
      memberNumber: json['member_number'] as String?,
      displayName: json['display_name'] as String,
      amount: (json['amount'] as num?)?.toDouble(),
    );
  }

  final String membershipId;
  final String? memberNumber;
  final String displayName;

  /// The fixed amount, the already-configured custom amount, or `null`
  /// when CUSTOM_PER_MEMBER and no amount has been set for this member
  /// yet (see [ContributionPeriodOpenPreview.missingCustomAmountMembers]).
  final double? amount;
}

/// One row inside [ContributionPeriodOpenPreview.excludedMembers].
class ContributionPreviewExcludedMember {
  const ContributionPreviewExcludedMember({
    required this.membershipId,
    required this.memberNumber,
    required this.displayName,
    required this.reason,
  });

  factory ContributionPreviewExcludedMember.fromJson(
    Map<String, dynamic> json,
  ) {
    return ContributionPreviewExcludedMember(
      membershipId: json['membership_id'] as String,
      memberNumber: json['member_number'] as String?,
      displayName: json['display_name'] as String,
      reason: json['reason'] as String,
    );
  }

  final String membershipId;
  final String? memberNumber;
  final String displayName;

  /// Either an explicit exclusion reason (free text, or `'EXCLUDED'`
  /// when none was given) or one of the server's automatic-ineligibility
  /// codes: `SUSPENDED` / `EXITED` / `JOINED_AFTER_ELIGIBILITY_DATE` /
  /// `EXITED_DURING_PERIOD`. See [isAutomaticIneligibility].
  final String reason;

  static const _automaticReasons = {
    'SUSPENDED',
    'EXITED',
    'JOINED_AFTER_ELIGIBILITY_DATE',
    'EXITED_DURING_PERIOD',
  };

  /// Whether [reason] is one of the server's automatic-ineligibility
  /// codes rather than an explicit pre-open exclusion — automatic
  /// ineligibility has no `contribution_period_member_exclusions` row to
  /// remove, so "Remove exclusion" is only ever offered for the
  /// explicit case.
  bool get isAutomaticIneligibility => _automaticReasons.contains(reason);
}

/// One row inside
/// [ContributionPeriodOpenPreview.missingCustomAmountMembers].
class ContributionPreviewMissingAmountMember {
  const ContributionPreviewMissingAmountMember({
    required this.membershipId,
    required this.memberNumber,
    required this.displayName,
  });

  factory ContributionPreviewMissingAmountMember.fromJson(
    Map<String, dynamic> json,
  ) {
    return ContributionPreviewMissingAmountMember(
      membershipId: json['membership_id'] as String,
      memberNumber: json['member_number'] as String?,
      displayName: json['display_name'] as String,
    );
  }

  final String membershipId;
  final String? memberNumber;
  final String displayName;
}

/// The server-authoritative, read-only preview of what opening a period
/// would post, from `rpc_preview_contribution_period_open()`. Flutter
/// renders this as a confirmation screen before calling
/// `rpc_open_contribution_period()`; it never computes eligibility or
/// assessment totals itself.
class ContributionPeriodOpenPreview {
  const ContributionPeriodOpenPreview({
    required this.periodId,
    required this.status,
    required this.dueDate,
    required this.amountMode,
    required this.eligibleCount,
    required this.eligibleMembers,
    required this.excludedCount,
    required this.excludedMembers,
    required this.missingCustomAmountCount,
    required this.missingCustomAmountMembers,
    required this.expectedTotalAssessment,
    required this.canOpen,
  });

  factory ContributionPeriodOpenPreview.fromJson(Map<String, dynamic> json) {
    return ContributionPeriodOpenPreview(
      periodId: json['period_id'] as String,
      status: json['status'] as String,
      dueDate: DateTime.parse(json['due_date'] as String),
      amountMode: json['amount_mode'] as String,
      eligibleCount: json['eligible_count'] as int,
      eligibleMembers: (json['eligible_members'] as List<dynamic>)
          .map(
            (item) => ContributionPreviewEligibleMember.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
      excludedCount: json['excluded_count'] as int,
      excludedMembers: (json['excluded_members'] as List<dynamic>)
          .map(
            (item) => ContributionPreviewExcludedMember.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
      missingCustomAmountCount: json['missing_custom_amount_count'] as int,
      missingCustomAmountMembers:
          (json['missing_custom_amount_members'] as List<dynamic>)
              .map(
                (item) => ContributionPreviewMissingAmountMember.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(growable: false),
      expectedTotalAssessment: (json['expected_total_assessment'] as num)
          .toDouble(),
      canOpen: json['can_open'] as bool,
    );
  }

  final String periodId;
  final String status;
  final DateTime dueDate;
  final String amountMode;
  final int eligibleCount;
  final List<ContributionPreviewEligibleMember> eligibleMembers;
  final int excludedCount;
  final List<ContributionPreviewExcludedMember> excludedMembers;
  final int missingCustomAmountCount;
  final List<ContributionPreviewMissingAmountMember> missingCustomAmountMembers;
  final double expectedTotalAssessment;
  final bool canOpen;
}
