// Prompt 09G-B6-C: member self-service My Payments & Receipts —
// read-only domain models for the three member-safe RPCs (migration
// 20261008090000_create_member_safe_payments_backend.sql):
//   rpc_get_my_payments, rpc_get_my_payment_detail, rpc_get_my_receipt.
// Every key below is taken from that migration's jsonb_build_object
// output. Nothing is derived client-side: amount, effective date, status,
// and reversal state are rendered exactly as the backend returns them.
// A payment is always one external cash event; allocations are breakdown
// only (never a second payment), and a wallet application (no `payments`
// row at all) can never be represented by any model here.
//
// Unknown future enum/code values never throw: they map to an `unknown`
// case so one unexpected code cannot crash the whole page.

/// `status` on list items, detail, and receipt. The backend's only two
/// stable values.
enum MyPaymentStatus {
  posted('POSTED'),
  reversed('REVERSED'),
  unknown('');

  const MyPaymentStatus(this.wire);

  final String wire;

  static MyPaymentStatus fromWire(String? value) {
    for (final status in values) {
      if (status != MyPaymentStatus.unknown && status.wire == value) {
        return status;
      }
    }
    return MyPaymentStatus.unknown;
  }
}

/// `payment_method` on list items, detail, and receipt.
enum MyPaymentMethod {
  cash('CASH'),
  bankTransfer('BANK_TRANSFER'),
  mobileMoney('MOBILE_MONEY'),
  other('OTHER'),
  unknown('');

  const MyPaymentMethod(this.wire);

  final String wire;

  static MyPaymentMethod fromWire(String? value) {
    for (final method in values) {
      if (method != MyPaymentMethod.unknown && method.wire == value) {
        return method;
      }
    }
    return MyPaymentMethod.unknown;
  }
}

/// `allocations[].target_type` — the complete B6 vocabulary. Anything
/// else is `unknown`, never dropped from the breakdown.
enum MyPaymentAllocationTargetType {
  contributionComponent('CONTRIBUTION_COMPONENT'),
  loanPrincipal('LOAN_PRINCIPAL'),
  loanInterest('LOAN_INTEREST'),
  loanPenalty('LOAN_PENALTY'),
  loanPrincipalPrepayment('LOAN_PRINCIPAL_PREPAYMENT'),
  loanRecoveryPrincipal('LOAN_RECOVERY_PRINCIPAL'),
  loanRecoveryInterest('LOAN_RECOVERY_INTEREST'),
  loanRecoveryPenalty('LOAN_RECOVERY_PENALTY'),
  unknown('');

  const MyPaymentAllocationTargetType(this.wire);

  final String wire;

  static MyPaymentAllocationTargetType fromWire(String? value) {
    for (final type in values) {
      if (type != MyPaymentAllocationTargetType.unknown && type.wire == value) {
        return type;
      }
    }
    return MyPaymentAllocationTargetType.unknown;
  }

  bool get isLoanTarget => switch (this) {
    loanPrincipal ||
    loanInterest ||
    loanPenalty ||
    loanPrincipalPrepayment ||
    loanRecoveryPrincipal ||
    loanRecoveryInterest ||
    loanRecoveryPenalty => true,
    contributionComponent || unknown => false,
  };
}

double _num(Object? value) => (value as num).toDouble();

DateTime _date(Object? value) => DateTime.parse(value as String);

DateTime? _dateOrNull(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

/// `pagination` on `rpc_get_my_payments`.
class MyPaymentsPagination {
  const MyPaymentsPagination({
    required this.limit,
    required this.offset,
    required this.totalCount,
    required this.hasMore,
  });

  factory MyPaymentsPagination.fromJson(Map<String, dynamic> json) {
    return MyPaymentsPagination(
      limit: (json['limit'] as num).toInt(),
      offset: (json['offset'] as num).toInt(),
      totalCount: (json['total_count'] as num).toInt(),
      hasMore: json['has_more'] as bool,
    );
  }

  final int limit;
  final int offset;
  final int totalCount;
  final bool hasMore;
}

/// One row of `rpc_get_my_payments`'s `items`. `allocationCount` is a
/// breakdown-line count only — it is never itself a second payment.
class MyPayment {
  const MyPayment({
    required this.paymentId,
    required this.effectiveAt,
    required this.amount,
    required this.paymentMethod,
    required this.externalReference,
    required this.receiptNumber,
    required this.status,
    required this.allocationCount,
  });

  factory MyPayment.fromJson(Map<String, dynamic> json) {
    return MyPayment(
      paymentId: json['payment_id'] as String,
      effectiveAt: _date(json['effective_at']),
      amount: _num(json['amount']),
      paymentMethod: MyPaymentMethod.fromWire(
        json['payment_method'] as String?,
      ),
      externalReference: json['external_reference'] as String?,
      receiptNumber: json['receipt_number'] as String?,
      status: MyPaymentStatus.fromWire(json['status'] as String?),
      allocationCount: (json['allocation_count'] as num).toInt(),
    );
  }

  final String paymentId;
  final DateTime effectiveAt;
  final double amount;
  final MyPaymentMethod paymentMethod;
  final String? externalReference;
  final String? receiptNumber;
  final MyPaymentStatus status;
  final int allocationCount;
}

/// Root of `rpc_get_my_payments`: `{ items, pagination }`.
class MyPaymentsPage {
  const MyPaymentsPage({required this.items, required this.pagination});

  factory MyPaymentsPage.fromJson(Map<String, dynamic> json) {
    return MyPaymentsPage(
      items: [
        for (final item in json['items'] as List<dynamic>)
          MyPayment.fromJson(item as Map<String, dynamic>),
      ],
      pagination: MyPaymentsPagination.fromJson(
        json['pagination'] as Map<String, dynamic>,
      ),
    );
  }

  final List<MyPayment> items;
  final MyPaymentsPagination pagination;
}

/// One entry of `allocations[]`, shared verbatim by both
/// `rpc_get_my_payment_detail` and `rpc_get_my_receipt` (both are built
/// from the same backend helper, so detail and receipt can never
/// diverge on the same payment). Contribution context
/// (`contributionTypeName`/`periodLabel`/`periodPurpose`/`componentType`)
/// is populated only for a `CONTRIBUTION_COMPONENT` target; loan context
/// (`loanNumber`/`loanProductName`/`installmentNumber`) only for a loan
/// target. No raw internal charge/loan/installment id is ever present.
class MyPaymentAllocation {
  const MyPaymentAllocation({
    required this.allocationId,
    required this.targetType,
    required this.amount,
    this.contributionTypeName,
    this.periodLabel,
    this.periodPurpose,
    this.componentType,
    this.loanNumber,
    this.loanProductName,
    this.installmentNumber,
  });

  factory MyPaymentAllocation.fromJson(Map<String, dynamic> json) {
    return MyPaymentAllocation(
      allocationId: json['allocation_id'] as String,
      targetType: MyPaymentAllocationTargetType.fromWire(
        json['target_type'] as String?,
      ),
      amount: _num(json['amount']),
      contributionTypeName: json['contribution_type_name'] as String?,
      periodLabel: json['period_label'] as String?,
      periodPurpose: json['period_purpose'] as String?,
      componentType: json['component_type'] as String?,
      loanNumber: json['loan_number'] as String?,
      loanProductName: json['loan_product_name'] as String?,
      installmentNumber: (json['installment_number'] as num?)?.toInt(),
    );
  }

  final String allocationId;
  final MyPaymentAllocationTargetType targetType;
  final double amount;
  final String? contributionTypeName;
  final String? periodLabel;
  final String? periodPurpose;

  /// `BASE`/`PENALTY`/... for a CONTRIBUTION_COMPONENT allocation. For a
  /// loan allocation the backend falls back to the target type's own
  /// code here, so this is never null for a known target.
  final String? componentType;
  final String? loanNumber;
  final String? loanProductName;
  final int? installmentNumber;
}

/// `wallet_credit` on detail/receipt — the wallet value THIS payment
/// itself created (never a separate payment). `null` when this payment
/// created no wallet credit.
class MyPaymentWalletCredit {
  const MyPaymentWalletCredit({
    required this.amount,
    required this.isReversed,
    this.reversedAt,
  });

  factory MyPaymentWalletCredit.fromJson(Map<String, dynamic> json) {
    return MyPaymentWalletCredit(
      amount: _num(json['amount']),
      isReversed: json['is_reversed'] as bool? ?? false,
      reversedAt: _dateOrNull(json['reversed_at']),
    );
  }

  final double amount;
  final bool isReversed;
  final DateTime? reversedAt;
}

/// The payment fields shared by `rpc_get_my_payment_detail`'s `payment`
/// object. `reversedBy` is never returned by the backend and is not a
/// field here.
class MyPaymentDetailHeader {
  const MyPaymentDetailHeader({
    required this.paymentId,
    required this.effectiveAt,
    required this.amount,
    required this.paymentMethod,
    required this.externalReference,
    required this.receiptNumber,
    required this.status,
    this.reversedAt,
    this.reversalReason,
  });

  factory MyPaymentDetailHeader.fromJson(Map<String, dynamic> json) {
    return MyPaymentDetailHeader(
      paymentId: json['payment_id'] as String,
      effectiveAt: _date(json['effective_at']),
      amount: _num(json['amount']),
      paymentMethod: MyPaymentMethod.fromWire(
        json['payment_method'] as String?,
      ),
      externalReference: json['external_reference'] as String?,
      receiptNumber: json['receipt_number'] as String?,
      status: MyPaymentStatus.fromWire(json['status'] as String?),
      reversedAt: _dateOrNull(json['reversed_at']),
      reversalReason: json['reversal_reason'] as String?,
    );
  }

  final String paymentId;
  final DateTime effectiveAt;
  final double amount;
  final MyPaymentMethod paymentMethod;
  final String? externalReference;
  final String? receiptNumber;
  final MyPaymentStatus status;
  final DateTime? reversedAt;
  final String? reversalReason;
}

/// `summary` on `rpc_get_my_payment_detail` — informational only.
/// Neither field is ever the canonical payment amount; [MyPaymentDetail]
/// always shows [MyPaymentDetailHeader.amount] as the one payment total.
class MyPaymentDetailSummary {
  const MyPaymentDetailSummary({
    required this.allocatedAmount,
    required this.walletCreditAmount,
  });

  factory MyPaymentDetailSummary.fromJson(Map<String, dynamic> json) {
    return MyPaymentDetailSummary(
      allocatedAmount: _num(json['allocated_amount']),
      walletCreditAmount: _num(json['wallet_credit_amount']),
    );
  }

  final double allocatedAmount;
  final double walletCreditAmount;
}

/// Root of `rpc_get_my_payment_detail`: `{ payment, summary, allocations,
/// wallet_credit }`.
class MyPaymentDetail {
  const MyPaymentDetail({
    required this.payment,
    required this.summary,
    required this.allocations,
    this.walletCredit,
  });

  factory MyPaymentDetail.fromJson(Map<String, dynamic> json) {
    final walletCreditRaw = json['wallet_credit'] as Map<String, dynamic>?;
    return MyPaymentDetail(
      payment: MyPaymentDetailHeader.fromJson(
        json['payment'] as Map<String, dynamic>,
      ),
      summary: MyPaymentDetailSummary.fromJson(
        json['summary'] as Map<String, dynamic>,
      ),
      allocations: [
        for (final item in json['allocations'] as List<dynamic>)
          MyPaymentAllocation.fromJson(item as Map<String, dynamic>),
      ],
      walletCredit: walletCreditRaw == null
          ? null
          : MyPaymentWalletCredit.fromJson(walletCreditRaw),
    );
  }

  final MyPaymentDetailHeader payment;
  final MyPaymentDetailSummary summary;
  final List<MyPaymentAllocation> allocations;
  final MyPaymentWalletCredit? walletCredit;
}

/// Root of `rpc_get_my_receipt`. A flat, member-safe view of the same
/// payment `rpc_get_my_payment_detail` returns — never a second,
/// independently-derived interpretation.
class MyReceipt {
  const MyReceipt({
    required this.receiptNumber,
    required this.effectiveAt,
    required this.amount,
    required this.paymentMethod,
    required this.externalReference,
    required this.status,
    this.reversalReason,
    required this.memberDisplayName,
    this.memberNumber,
    required this.groupName,
    required this.allocations,
    this.walletCredit,
  });

  factory MyReceipt.fromJson(Map<String, dynamic> json) {
    final walletCreditRaw = json['wallet_credit'] as Map<String, dynamic>?;
    return MyReceipt(
      receiptNumber: json['receipt_number'] as String?,
      effectiveAt: _date(json['effective_at']),
      amount: _num(json['amount']),
      paymentMethod: MyPaymentMethod.fromWire(
        json['payment_method'] as String?,
      ),
      externalReference: json['external_reference'] as String?,
      status: MyPaymentStatus.fromWire(json['status'] as String?),
      reversalReason: json['reversal_reason'] as String?,
      memberDisplayName: json['member_display_name'] as String,
      memberNumber: json['member_number'] as String?,
      groupName: json['group_name'] as String,
      allocations: [
        for (final item in json['allocations'] as List<dynamic>)
          MyPaymentAllocation.fromJson(item as Map<String, dynamic>),
      ],
      walletCredit: walletCreditRaw == null
          ? null
          : MyPaymentWalletCredit.fromJson(walletCreditRaw),
    );
  }

  final String? receiptNumber;
  final DateTime effectiveAt;
  final double amount;
  final MyPaymentMethod paymentMethod;
  final String? externalReference;
  final MyPaymentStatus status;
  final String? reversalReason;
  final String memberDisplayName;
  final String? memberNumber;
  final String groupName;
  final List<MyPaymentAllocation> allocations;
  final MyPaymentWalletCredit? walletCredit;
}
