// Prompt 09E: Loan Prepayment, Early Settlement & Restructure
// foundation — read-only, server-computed domain models. Flutter
// never computes any of these figures itself; it only renders what
// the server returns and always re-previews before confirming.

/// One installment row in a proposed future schedule (prepayment
/// REDUCE_TERM/REDUCE_INSTALLMENT or restructure) — never itself
/// authoritative; confirming always independently recomputes the same
/// figures server-side.
class LoanServicingScheduleRow {
  const LoanServicingScheduleRow({
    required this.installmentNumber,
    required this.dueDate,
    required this.principalDue,
    required this.interestDue,
  });

  factory LoanServicingScheduleRow.fromJson(Map<String, dynamic> json) {
    return LoanServicingScheduleRow(
      installmentNumber: json['installment_number'] as int,
      dueDate: DateTime.parse(json['due_date'] as String),
      principalDue: (json['principal_due'] as num).toDouble(),
      interestDue: (json['interest_due'] as num).toDouble(),
    );
  }

  final int installmentNumber;
  final DateTime dueDate;
  final double principalDue;
  final double interestDue;
}

/// `rpc_preview_loan_early_settlement`'s full quote (Prompt 09E section
/// 1). No writes; `rpc_settle_loan_early` always recomputes the total
/// itself, never trusting this quote as authoritative input.
class LoanEarlySettlementQuote {
  const LoanEarlySettlementQuote({
    required this.effectiveDate,
    required this.overduePenaltyOutstanding,
    required this.overdueInterestOutstanding,
    required this.overduePrincipalOutstanding,
    required this.currentPayablePenalty,
    required this.currentPayableInterest,
    required this.currentPayablePrincipal,
    required this.futurePrincipalOutstanding,
    required this.futureUnearnedInterest,
    required this.settlementAdjustmentAmount,
    required this.totalSettlementAmount,
  });

  factory LoanEarlySettlementQuote.fromJson(Map<String, dynamic> json) {
    return LoanEarlySettlementQuote(
      effectiveDate: DateTime.parse(json['effective_date'] as String),
      overduePenaltyOutstanding: (json['overdue_penalty_outstanding'] as num)
          .toDouble(),
      overdueInterestOutstanding: (json['overdue_interest_outstanding'] as num)
          .toDouble(),
      overduePrincipalOutstanding:
          (json['overdue_principal_outstanding'] as num).toDouble(),
      currentPayablePenalty: (json['current_payable_penalty'] as num)
          .toDouble(),
      currentPayableInterest: (json['current_payable_interest'] as num)
          .toDouble(),
      currentPayablePrincipal: (json['current_payable_principal'] as num)
          .toDouble(),
      futurePrincipalOutstanding: (json['future_principal_outstanding'] as num)
          .toDouble(),
      futureUnearnedInterest: (json['future_unearned_interest'] as num)
          .toDouble(),
      settlementAdjustmentAmount: (json['settlement_adjustment_amount'] as num)
          .toDouble(),
      totalSettlementAmount: (json['total_settlement_amount'] as num)
          .toDouble(),
    );
  }

  final DateTime effectiveDate;
  final double overduePenaltyOutstanding;
  final double overdueInterestOutstanding;
  final double overduePrincipalOutstanding;
  final double currentPayablePenalty;
  final double currentPayableInterest;
  final double currentPayablePrincipal;
  final double futurePrincipalOutstanding;

  /// Informational only — never charged (Prompt 09E section 1: future
  /// interest is never charged merely because it exists in the
  /// original schedule).
  final double futureUnearnedInterest;

  /// Always 0 in v1 — no settlement discount/adjustment policy exists
  /// yet.
  final double settlementAdjustmentAmount;
  final double totalSettlementAmount;
}

/// `rpc_preview_loan_prepayment`'s full preview (Prompt 09E section 3/
/// 4). No writes; `rpc_prepay_loan_principal` always re-validates and
/// recomputes independently.
class LoanPrepaymentPreview {
  const LoanPrepaymentPreview({
    required this.amount,
    required this.treatment,
    required this.futurePrincipalOutstandingBefore,
    required this.futurePrincipalOutstandingAfter,
    required this.oldFutureInstallments,
    required this.newFutureInstallments,
  });

  factory LoanPrepaymentPreview.fromJson(Map<String, dynamic> json) {
    return LoanPrepaymentPreview(
      amount: (json['amount'] as num).toDouble(),
      treatment: json['treatment'] as String,
      futurePrincipalOutstandingBefore:
          (json['future_principal_outstanding_before'] as num).toDouble(),
      futurePrincipalOutstandingAfter:
          (json['future_principal_outstanding_after'] as num).toDouble(),
      oldFutureInstallments: (json['old_future_installments'] as List<dynamic>)
          .map(
            (item) =>
                LoanServicingScheduleRow.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      newFutureInstallments: (json['new_future_installments'] as List<dynamic>)
          .map(
            (item) =>
                LoanServicingScheduleRow.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }

  final double amount;

  /// 'REDUCE_TERM' or 'REDUCE_INSTALLMENT'.
  final String treatment;
  final double futurePrincipalOutstandingBefore;
  final double futurePrincipalOutstandingAfter;
  final List<LoanServicingScheduleRow> oldFutureInstallments;
  final List<LoanServicingScheduleRow> newFutureInstallments;
}

/// `rpc_preview_loan_restructure`'s full preview (Prompt 09E section
/// 6). No writes; `rpc_restructure_loan` always re-validates and
/// recomputes independently.
class LoanRestructurePreview {
  const LoanRestructurePreview({
    required this.remainingPrincipalOutstanding,
    required this.newInterestRate,
    required this.newTerm,
    required this.newFirstInstallmentDate,
    required this.oldRemainingInstallments,
    required this.newInstallments,
  });

  factory LoanRestructurePreview.fromJson(Map<String, dynamic> json) {
    return LoanRestructurePreview(
      remainingPrincipalOutstanding:
          (json['remaining_principal_outstanding'] as num).toDouble(),
      newInterestRate: (json['new_interest_rate'] as num).toDouble(),
      newTerm: json['new_term'] as int,
      newFirstInstallmentDate: DateTime.parse(
        json['new_first_installment_date'] as String,
      ),
      oldRemainingInstallments:
          (json['old_remaining_installments'] as List<dynamic>)
              .map(
                (item) => LoanServicingScheduleRow.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(growable: false),
      newInstallments: (json['new_installments'] as List<dynamic>)
          .map(
            (item) =>
                LoanServicingScheduleRow.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }

  final double remainingPrincipalOutstanding;
  final double newInterestRate;
  final int newTerm;
  final DateTime newFirstInstallmentDate;
  final List<LoanServicingScheduleRow> oldRemainingInstallments;
  final List<LoanServicingScheduleRow> newInstallments;
}

/// The result of a confirmed `rpc_settle_loan_early` /
/// `rpc_prepay_loan_principal` post.
class LoanServicingPaymentResult {
  const LoanServicingPaymentResult({
    required this.paymentId,
    required this.receiptNumber,
    required this.amount,
  });

  factory LoanServicingPaymentResult.fromJson(Map<String, dynamic> json) {
    return LoanServicingPaymentResult(
      paymentId: json['payment_id'] as String,
      receiptNumber: json['receipt_number'] as String,
      amount: (json['amount'] as num).toDouble(),
    );
  }

  final String paymentId;
  final String receiptNumber;
  final double amount;
}
