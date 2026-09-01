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

/// One ACTIVE loan's pre-payment obligation summary (Prompt
/// 09C-UAT-FIX-01), as returned within
/// [MemberContributionStatement.loans]. [currentlyPayableAmount] is
/// exactly what an ordinary payment would automatically allocate to
/// this loan today ([overdueAmount] + [dueNowAmount]) — [upcomingAmount]
/// (a future installment's scheduled amount) is never included in it,
/// matching the server allocator's own currently-due rule.
class MemberLoanObligationSummary {
  const MemberLoanObligationSummary({
    required this.loanAccountId,
    required this.loanNumber,
    required this.overdueAmount,
    required this.dueNowAmount,
    required this.currentlyPayableAmount,
    this.nextDueDate,
    required this.upcomingAmount,
  });

  factory MemberLoanObligationSummary.fromJson(Map<String, dynamic> json) {
    return MemberLoanObligationSummary(
      loanAccountId: json['loan_account_id'] as String,
      loanNumber: json['loan_number'] as String,
      overdueAmount: (json['overdue_amount'] as num).toDouble(),
      dueNowAmount: (json['due_now_amount'] as num).toDouble(),
      currentlyPayableAmount: (json['currently_payable_amount'] as num)
          .toDouble(),
      nextDueDate: json['next_due_date'] == null
          ? null
          : DateTime.parse(json['next_due_date'] as String),
      upcomingAmount: (json['upcoming_amount'] as num).toDouble(),
    );
  }

  final String loanAccountId;
  final String loanNumber;
  final double overdueAmount;
  final double dueNowAmount;
  final double currentlyPayableAmount;
  final DateTime? nextDueDate;

  /// Scheduled amount on installments due AFTER today — shown only as
  /// "upcoming", never folded into [currentlyPayableAmount] or into any
  /// "Amount Payable Now" figure.
  final double upcomingAmount;
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
    this.contributionOverdueAmount = 0,
    this.contributionDueNowAmount = 0,
    this.loans = const [],
    this.totalLoansCurrentlyPayableAmount = 0,
    this.totalPayableNow = 0,
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
      contributionOverdueAmount:
          (json['contribution_overdue_amount'] as num?)?.toDouble() ?? 0,
      contributionDueNowAmount:
          (json['contribution_due_now_amount'] as num?)?.toDouble() ?? 0,
      loans: json['loans'] == null
          ? const []
          : (json['loans'] as List<dynamic>)
                .map(
                  (item) => MemberLoanObligationSummary.fromJson(
                    item as Map<String, dynamic>,
                  ),
                )
                .toList(growable: false),
      totalLoansCurrentlyPayableAmount:
          (json['total_loans_currently_payable_amount'] as num?)?.toDouble() ??
          0,
      totalPayableNow: (json['total_payable_now'] as num?)?.toDouble() ?? 0,
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

  /// Prompt 09C-UAT-FIX-01 — a breakdown of [totalOutstanding] by due
  /// date, for display only (contribution allocatability itself is
  /// unchanged: a not-yet-due contribution charge remains a valid
  /// automatic-allocation target, unlike a loan installment).
  final double contributionOverdueAmount;
  final double contributionDueNowAmount;

  /// One entry per ACTIVE loan this member is borrower on.
  final List<MemberLoanObligationSummary> loans;

  /// Sum of every loan's [MemberLoanObligationSummary.currentlyPayableAmount].
  final double totalLoansCurrentlyPayableAmount;

  /// [totalOutstanding] + [totalLoansCurrentlyPayableAmount] — what an
  /// ordinary payment today would actually be able to allocate across
  /// both domains combined. Never includes any loan's
  /// [MemberLoanObligationSummary.upcomingAmount].
  final double totalPayableNow;
}
