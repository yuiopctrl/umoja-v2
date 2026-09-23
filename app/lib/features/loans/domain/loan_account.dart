import 'loan_account_event.dart';
import 'loan_disbursement.dart';
import 'loan_installment.dart';
import 'loan_opening_position.dart';

/// One specific member's loan instance (Prompt 09A). NOT a cash
/// transaction and NOT yet a funded receivable — see
/// docs/product/loans.md. Every financial term below is a frozen
/// snapshot taken from the Loan Product at creation time;
/// [loanProductId] is provenance only, never re-read live.
///
/// Used for both the list row shape (no [installments]) and the
/// detail shape (installments populated) — list responses simply
/// never include the key, so [installments] defaults to empty.
class LoanAccount {
  const LoanAccount({
    required this.id,
    required this.groupId,
    required this.membershipId,
    required this.borrowerDisplayName,
    this.borrowerMemberNumber,
    required this.loanProductId,
    required this.loanProductName,
    required this.loanProductCode,
    required this.loanNumber,
    this.loanOrigin = 'NEW',
    this.openingPosition,
    required this.principalAmount,
    required this.interestRate,
    required this.interestRateBasis,
    required this.interestMethod,
    required this.term,
    required this.termUnit,
    required this.repaymentFrequency,
    required this.applicationDate,
    this.proposedDisbursementDate,
    required this.firstRepaymentDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.installments = const [],
    this.events = const [],
    this.disbursement,
    this.principalRepaid = 0,
    this.principalOutstanding,
    this.interestRecognized = 0,
    this.interestOutstanding,
    this.penaltyPaid = 0,
    this.penaltyOutstanding,
    this.totalOutstanding,
    this.nextDueDate,
    this.overdueAmount = 0,
    this.penaltyEnabled = false,
    this.penaltyType,
    this.penaltyFrequency,
    this.penaltyGraceDays,
    this.penaltyFixedAmount,
    this.penaltyRate,
    this.penaltyBasis,
  });

  factory LoanAccount.fromJson(Map<String, dynamic> json) {
    return LoanAccount(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      membershipId: json['membership_id'] as String,
      borrowerDisplayName: json['borrower_display_name'] as String,
      borrowerMemberNumber: json['borrower_member_number'] as String?,
      loanProductId: json['loan_product_id'] as String,
      loanProductName: json['loan_product_name'] as String,
      loanProductCode: json['loan_product_code'] as String,
      loanNumber: json['loan_number'] as String,
      loanOrigin: json['loan_origin'] as String? ?? 'NEW',
      openingPosition: json['opening_position'] == null
          ? null
          : LoanOpeningPosition.fromJson(
              json['opening_position'] as Map<String, dynamic>,
            ),
      principalAmount: (json['principal_amount'] as num).toDouble(),
      interestRate: (json['interest_rate'] as num).toDouble(),
      interestRateBasis: json['interest_rate_basis'] as String,
      interestMethod: json['interest_method'] as String,
      term: json['term'] as int,
      termUnit: json['term_unit'] as String,
      repaymentFrequency: json['repayment_frequency'] as String,
      applicationDate: DateTime.parse(json['application_date'] as String),
      proposedDisbursementDate: json['proposed_disbursement_date'] == null
          ? null
          : DateTime.parse(json['proposed_disbursement_date'] as String),
      firstRepaymentDate: DateTime.parse(
        json['first_repayment_date'] as String,
      ),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      installments: json['installments'] == null
          ? const []
          : (json['installments'] as List<dynamic>)
                .map(
                  (item) =>
                      LoanInstallment.fromJson(item as Map<String, dynamic>),
                )
                .toList(growable: false),
      events: json['events'] == null
          ? const []
          : (json['events'] as List<dynamic>)
                .map(
                  (item) =>
                      LoanAccountEvent.fromJson(item as Map<String, dynamic>),
                )
                .toList(growable: false),
      disbursement: json['disbursement'] == null
          ? null
          : LoanDisbursement.fromJson(
              json['disbursement'] as Map<String, dynamic>,
            ),
      principalRepaid: json['principal_repaid'] == null
          ? 0
          : (json['principal_repaid'] as num).toDouble(),
      principalOutstanding: json['principal_outstanding'] == null
          ? null
          : (json['principal_outstanding'] as num).toDouble(),
      interestRecognized: json['interest_recognized'] == null
          ? 0
          : (json['interest_recognized'] as num).toDouble(),
      interestOutstanding: json['interest_outstanding'] == null
          ? null
          : (json['interest_outstanding'] as num).toDouble(),
      penaltyPaid: json['penalty_paid'] == null
          ? 0
          : (json['penalty_paid'] as num).toDouble(),
      penaltyOutstanding: json['penalty_outstanding'] == null
          ? null
          : (json['penalty_outstanding'] as num).toDouble(),
      totalOutstanding: json['total_outstanding'] == null
          ? null
          : (json['total_outstanding'] as num).toDouble(),
      nextDueDate: json['next_due_date'] == null
          ? null
          : DateTime.parse(json['next_due_date'] as String),
      overdueAmount: json['overdue_amount'] == null
          ? 0
          : (json['overdue_amount'] as num).toDouble(),
      penaltyEnabled: json['penalty_enabled'] as bool? ?? false,
      penaltyType: json['penalty_type'] as String?,
      penaltyFrequency: json['penalty_frequency'] as String?,
      penaltyGraceDays: json['penalty_grace_days'] as int?,
      penaltyFixedAmount: (json['penalty_fixed_amount'] as num?)?.toDouble(),
      penaltyRate: (json['penalty_rate'] as num?)?.toDouble(),
      penaltyBasis: json['penalty_basis'] as String?,
    );
  }

  final String id;
  final String groupId;
  final String membershipId;
  final String borrowerDisplayName;
  final String? borrowerMemberNumber;
  final String loanProductId;
  final String loanProductName;
  final String loanProductCode;
  final String loanNumber;

  /// 'NEW' (originated inside Umoja) or 'MIGRATED' (Prompt
  /// 09D-UAT-BLOCKER-01 — an opening financial position for a loan
  /// already funded before the group started using Umoja).
  final String loanOrigin;

  /// Non-null only for a MIGRATED loan.
  final LoanOpeningPosition? openingPosition;
  final double principalAmount;
  final double interestRate;

  /// 'MONTHLY' or 'ANNUAL'.
  final String interestRateBasis;

  /// 'FLAT' or 'REDUCING_BALANCE'.
  final String interestMethod;
  final int term;

  /// 'MONTH'.
  final String termUnit;

  /// 'MONTHLY'.
  final String repaymentFrequency;
  final DateTime applicationDate;
  final DateTime? proposedDisbursementDate;
  final DateTime firstRepaymentDate;

  /// 'DRAFT' | 'SUBMITTED' | 'APPROVED' | 'REJECTED' | 'CANCELLED' |
  /// 'DISBURSED' | 'ACTIVE' | 'CLOSED' | 'WRITTEN_OFF' (Prompt 09F-B).
  /// DISBURSED is transactional and never observed at rest in Prompt
  /// 09B — disbursement moves a loan straight from APPROVED to ACTIVE
  /// (see docs/product/loans.md). WRITTEN_OFF is reached only from
  /// ACTIVE and can be reversed back to ACTIVE while no dependent
  /// recovery activity exists.
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<LoanInstallment> installments;

  /// The lifecycle audit trail (Prompt 09B) — never a second source of
  /// current-status truth, only a history of how [status] got here.
  final List<LoanAccountEvent> events;

  /// Non-null only once `rpc_disburse_loan_account()` has succeeded.
  final LoanDisbursement? disbursement;

  /// Member loan summary (Prompt 09C) — always server-derived from
  /// allocations across every installment, never computed here. Zero/
  /// null for a loan that has never been disbursed.
  final double principalRepaid;
  final double? principalOutstanding;
  final double interestRecognized;
  final double? interestOutstanding;

  /// Penalty summary (Prompt 09D) — same derivation guarantee: always
  /// server-computed from `loan_penalty_charges` minus active
  /// allocations, never a stored balance.
  final double penaltyPaid;
  final double? penaltyOutstanding;
  final double? totalOutstanding;
  final DateTime? nextDueDate;
  final double overdueAmount;

  /// Frozen penalty policy snapshot (Prompt 09D) — taken from the loan
  /// product at DRAFT creation time, exactly like every other financial
  /// term; a later product edit never changes these for this loan.
  final bool penaltyEnabled;

  /// 'FIXED' or 'PERCENTAGE'.
  final String? penaltyType;

  /// 'ONCE' or 'RECURRING_MONTHLY'.
  final String? penaltyFrequency;
  final int? penaltyGraceDays;
  final double? penaltyFixedAmount;
  final double? penaltyRate;
  final String? penaltyBasis;

  bool get isMigrated => loanOrigin == 'MIGRATED';

  bool get isDraft => status == 'DRAFT';
  bool get isSubmitted => status == 'SUBMITTED';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';
  bool get isCancelled => status == 'CANCELLED';
  bool get isFunded => status == 'DISBURSED' || status == 'ACTIVE';
  bool get isActive => status == 'ACTIVE';
  bool get isClosed => status == 'CLOSED';

  /// Prompt 09F-B — reached only from ACTIVE, distinct from
  /// CANCELLED/CLOSED. The full write-off/recovery detail is a separate
  /// read model (`rpc_get_loan_write_off_summary`), not part of this
  /// class.
  bool get isWrittenOff => status == 'WRITTEN_OFF';

  /// Sum of every installment's interest — rendered directly from
  /// server-provided installment rows, never independently computed.
  double get totalInterest =>
      installments.fold(0.0, (sum, i) => sum + i.interestDue);

  /// Sum of every installment's total (principal + interest).
  double get totalRepayable =>
      installments.fold(0.0, (sum, i) => sum + i.totalDue);
}

/// One page of `rpc_list_loan_accounts()` results.
class LoanAccountPage {
  const LoanAccountPage({
    required this.items,
    required this.totalCount,
    required this.limit,
    required this.offset,
  });

  factory LoanAccountPage.fromJson(Map<String, dynamic> json) {
    return LoanAccountPage(
      items: (json['items'] as List<dynamic>)
          .map((item) => LoanAccount.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      totalCount: json['total_count'] as int,
      limit: json['limit'] as int,
      offset: json['offset'] as int,
    );
  }

  static const empty = LoanAccountPage(
    items: [],
    totalCount: 0,
    limit: 20,
    offset: 0,
  );

  final List<LoanAccount> items;
  final int totalCount;
  final int limit;
  final int offset;

  bool get hasMore => offset + items.length < totalCount;
}
