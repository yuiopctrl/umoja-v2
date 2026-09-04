/// One settled (or previewed-to-settle) obligation component — used by
/// [PaymentAllocationPreview], [PaymentDetail], and [Receipt]. Never a
/// cash event itself; see `docs/product/payments.md` for the
/// three-layer separation this reflects.
///
/// [contributionTypeName]/[periodLabel]/[periodPurpose] give the
/// business context a bare [componentType] cannot (UAT-FIX-01: two
/// BASE rows from different periods were previously indistinguishable
/// — "Base 20,000 / Base 10,000"). For an already-POSTED allocation
/// (from [PaymentDetail]/[Receipt]) these are the values snapshotted
/// at posting time — never re-derived from the current, possibly
/// since-renamed contribution type/period — so a receipt never
/// becomes misleading after a later rename. For a preview (not yet
/// posted), they reflect the live current names, since nothing has
/// been snapshotted yet.
class PaymentAllocationLine {
  const PaymentAllocationLine({
    this.chargeId,
    this.componentId,
    required this.componentType,
    required this.dueDate,
    required this.amount,
    this.contributionTypeName,
    this.periodId,
    this.periodLabel,
    this.periodPurpose,
    this.componentOutstandingBefore,
    this.obligationKind = 'CONTRIBUTION',
    this.loanAccountId,
    this.loanInstallmentId,
    this.loanNumber,
    this.loanProductName,
    this.installmentNumber,
    this.loanPenaltyChargeId,
  });

  /// `rpc_get_payment_detail` shape (charge_id/component_id present for
  /// a contribution row; loan_account_id/loan_installment_id present
  /// for a loan row instead) — key `amount`. `due_date` is null for a
  /// LOAN_PRINCIPAL_PREPAYMENT row: that allocation is deliberately not
  /// tied to any single installment (a lump-sum prepayment against the
  /// loan's whole future principal, never impersonating an ordinary
  /// installment allocation — see the 09E locked invariant), so there
  /// is no natural due date to report.
  factory PaymentAllocationLine.fromJson(Map<String, dynamic> json) {
    return PaymentAllocationLine(
      chargeId: json['charge_id'] as String?,
      componentId: json['component_id'] as String?,
      componentType: json['component_type'] as String,
      dueDate: json['due_date'] == null
          ? null
          : DateTime.parse(json['due_date'] as String),
      amount: (json['amount'] as num).toDouble(),
      contributionTypeName: json['contribution_type_name'] as String?,
      periodLabel: json['period_label'] as String?,
      periodPurpose: json['period_purpose'] as String?,
      obligationKind: _obligationKindOf(json),
      loanAccountId: json['loan_account_id'] as String?,
      loanInstallmentId: json['loan_installment_id'] as String?,
      loanNumber: json['loan_number'] as String?,
      loanProductName: json['loan_product_name'] as String?,
      installmentNumber: json['installment_number'] as int?,
      loanPenaltyChargeId: json['loan_penalty_charge_id'] as String?,
    );
  }

  /// `rpc_preview_payment_allocation`/`rpc_preview_wallet_allocation`
  /// shape — key `allocate_amount`.
  factory PaymentAllocationLine.fromPreviewJson(Map<String, dynamic> json) {
    return PaymentAllocationLine(
      chargeId: json['charge_id'] as String?,
      componentId: json['component_id'] as String?,
      componentType: json['component_type'] as String,
      dueDate: DateTime.parse(json['due_date'] as String),
      amount: (json['allocate_amount'] as num).toDouble(),
      contributionTypeName: json['contribution_type_name'] as String?,
      periodId: json['period_id'] as String?,
      periodLabel: json['period_label'] as String?,
      periodPurpose: json['period_purpose'] as String?,
      componentOutstandingBefore: json['component_outstanding_before'] == null
          ? null
          : (json['component_outstanding_before'] as num).toDouble(),
      obligationKind: _obligationKindOf(json),
      loanAccountId: json['loan_account_id'] as String?,
      loanInstallmentId: json['loan_installment_id'] as String?,
      loanNumber: json['loan_number'] as String?,
      loanProductName: json['loan_product_name'] as String?,
      installmentNumber: json['installment_number'] as int?,
      loanPenaltyChargeId: json['loan_penalty_charge_id'] as String?,
    );
  }

  /// `rpc_get_receipt` shape (no charge_id/component_id) — key `amount`.
  /// `due_date` is null for a LOAN_PRINCIPAL_PREPAYMENT row — see
  /// [fromJson]'s doc.
  factory PaymentAllocationLine.fromReceiptJson(Map<String, dynamic> json) {
    return PaymentAllocationLine(
      componentType: json['component_type'] as String,
      dueDate: json['due_date'] == null
          ? null
          : DateTime.parse(json['due_date'] as String),
      amount: (json['amount'] as num).toDouble(),
      contributionTypeName: json['contribution_type_name'] as String?,
      periodLabel: json['period_label'] as String?,
      periodPurpose: json['period_purpose'] as String?,
      obligationKind: _obligationKindOf(json),
      loanNumber: json['loan_number'] as String?,
      loanProductName: json['loan_product_name'] as String?,
      installmentNumber: json['installment_number'] as int?,
      loanPenaltyChargeId: json['loan_penalty_charge_id'] as String?,
    );
  }

  /// The preview RPCs return an explicit `obligation_kind`
  /// ('CONTRIBUTION'/'LOAN_INTEREST'/'LOAN_PRINCIPAL'); the posted
  /// detail/receipt RPCs return `allocation_target_type`
  /// ('CONTRIBUTION_COMPONENT'/'LOAN_INTEREST'/'LOAN_PRINCIPAL')
  /// instead — normalized here to one consistent value so every caller
  /// only ever branches on [obligationKind].
  static String _obligationKindOf(Map<String, dynamic> json) {
    final kind = json['obligation_kind'] as String?;
    if (kind != null) return kind;
    final targetType = json['allocation_target_type'] as String?;
    if (targetType == 'CONTRIBUTION_COMPONENT' || targetType == null) {
      return 'CONTRIBUTION';
    }
    return targetType;
  }

  final String? chargeId;
  final String? componentId;

  /// One of BASE / PENALTY / ADJUSTMENT / OPENING_BALANCE (contribution
  /// row) or INTEREST / PRINCIPAL (loan row) — see [obligationKind] to
  /// distinguish which.
  final String componentType;

  /// Null only for a LOAN_PRINCIPAL_PREPAYMENT row — that allocation is
  /// deliberately not tied to any single installment, so it has no
  /// natural due date. Populated for every other obligation kind.
  final DateTime? dueDate;
  final double amount;

  /// Null only for a row posted before UAT-FIX-01 shipped — callers
  /// must render such a row using [componentType] alone, never crash.
  final String? contributionTypeName;
  final String? periodId;
  final String? periodLabel;

  /// 'NORMAL' or 'OPENING_BALANCE' — an OPENING_BALANCE charge's
  /// context label omits the period suffix (see
  /// `obligationContextLabel`).
  final String? periodPurpose;

  /// The component's outstanding amount immediately before this
  /// allocation was taken from it (preview only — always null for a
  /// posted [PaymentDetail]/[Receipt] line).
  final double? componentOutstandingBefore;

  /// 'CONTRIBUTION' | 'LOAN_INTEREST' | 'LOAN_PRINCIPAL' (Prompt 09C).
  /// Discriminates a contribution line ([contributionTypeName] etc.
  /// populated) from a loan line ([loanNumber]/[installmentNumber]
  /// populated instead).
  final String obligationKind;
  final String? loanAccountId;
  final String? loanInstallmentId;
  final String? loanNumber;

  /// The borrower's loan PRODUCT name (Prompt 09C-UAT-FIX-02) — e.g.
  /// "Emergency Loan" — the piece that was previously missing entirely,
  /// making two ACTIVE loans indistinguishable in an allocation
  /// preview. Always resolved via a live join (never snapshotted,
  /// matching [loanNumber]'s existing precedent).
  final String? loanProductName;
  final int? installmentNumber;

  /// Populated only when [obligationKind] is 'LOAN_PENALTY' (Prompt
  /// 09D) — identifies exactly which penalty assessment (occurrence)
  /// this line settles, since an installment may carry more than one
  /// outstanding penalty charge (RECURRING_MONTHLY).
  final String? loanPenaltyChargeId;

  bool get isOpeningBalance => periodPurpose == 'OPENING_BALANCE';

  /// True for a line tied to a specific loan installment (interest/
  /// principal/penalty). Deliberately excludes
  /// [isPrincipalPrepayment] — a prepayment is loan-related but never
  /// tied to one installment, so it never has a [dueDate]/
  /// [installmentNumber] to group by the way these three do.
  bool get isLoan =>
      obligationKind == 'LOAN_INTEREST' ||
      obligationKind == 'LOAN_PRINCIPAL' ||
      obligationKind == 'LOAN_PENALTY';
  bool get isLoanInterest => obligationKind == 'LOAN_INTEREST';
  bool get isLoanPenalty => obligationKind == 'LOAN_PENALTY';

  /// A 09E lump-sum principal prepayment (Prompt 09E) — structurally
  /// never tied to a specific installment (see the class doc on
  /// [dueDate]), so it must never be grouped/labeled as an ordinary
  /// per-installment loan line.
  bool get isPrincipalPrepayment =>
      obligationKind == 'LOAN_PRINCIPAL_PREPAYMENT';
}
