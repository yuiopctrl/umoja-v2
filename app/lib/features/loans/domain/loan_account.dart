import 'loan_account_event.dart';
import 'loan_disbursement.dart';
import 'loan_installment.dart';

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
  /// 'DISBURSED' | 'ACTIVE' | 'CLOSED'. DISBURSED is transactional and
  /// never observed at rest in Prompt 09B — disbursement moves a loan
  /// straight from APPROVED to ACTIVE (see docs/product/loans.md).
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<LoanInstallment> installments;

  /// The lifecycle audit trail (Prompt 09B) — never a second source of
  /// current-status truth, only a history of how [status] got here.
  final List<LoanAccountEvent> events;

  /// Non-null only once `rpc_disburse_loan_account()` has succeeded.
  final LoanDisbursement? disbursement;

  bool get isDraft => status == 'DRAFT';
  bool get isSubmitted => status == 'SUBMITTED';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';
  bool get isCancelled => status == 'CANCELLED';
  bool get isFunded => status == 'DISBURSED' || status == 'ACTIVE';

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
