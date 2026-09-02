/// A group's reusable lending policy/configuration (Prompt 09A) —
/// never a member's loan itself. See [LoanAccount], which snapshots
/// these terms at creation time rather than referencing them live.
class LoanProduct {
  const LoanProduct({
    required this.id,
    required this.groupId,
    required this.code,
    required this.name,
    this.description,
    required this.isActive,
    required this.minimumPrincipal,
    this.maximumPrincipal,
    required this.minimumTerm,
    required this.maximumTerm,
    required this.termUnit,
    required this.interestRate,
    required this.interestRateBasis,
    required this.interestMethod,
    required this.repaymentFrequency,
    required this.penaltyEnabled,
    this.penaltyType,
    this.penaltyFrequency,
    this.penaltyGraceDays,
    this.penaltyFixedAmount,
    this.penaltyRate,
    this.penaltyBasis,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LoanProduct.fromJson(Map<String, dynamic> json) {
    return LoanProduct(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool,
      minimumPrincipal: (json['minimum_principal'] as num).toDouble(),
      maximumPrincipal: (json['maximum_principal'] as num?)?.toDouble(),
      minimumTerm: json['minimum_term'] as int,
      maximumTerm: json['maximum_term'] as int,
      termUnit: json['term_unit'] as String,
      interestRate: (json['interest_rate'] as num).toDouble(),
      interestRateBasis: json['interest_rate_basis'] as String,
      interestMethod: json['interest_method'] as String,
      repaymentFrequency: json['repayment_frequency'] as String,
      penaltyEnabled: json['penalty_enabled'] as bool? ?? false,
      penaltyType: json['penalty_type'] as String?,
      penaltyFrequency: json['penalty_frequency'] as String?,
      penaltyGraceDays: json['penalty_grace_days'] as int?,
      penaltyFixedAmount: (json['penalty_fixed_amount'] as num?)?.toDouble(),
      penaltyRate: (json['penalty_rate'] as num?)?.toDouble(),
      penaltyBasis: json['penalty_basis'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String groupId;
  final String code;
  final String name;
  final String? description;
  final bool isActive;
  final double minimumPrincipal;
  final double? maximumPrincipal;
  final int minimumTerm;
  final int maximumTerm;

  /// 'MONTH'.
  final String termUnit;
  final double interestRate;

  /// 'MONTHLY' or 'ANNUAL'.
  final String interestRateBasis;

  /// 'FLAT' or 'REDUCING_BALANCE'.
  final String interestMethod;

  /// 'MONTHLY'.
  final String repaymentFrequency;

  final bool penaltyEnabled;

  /// 'FIXED' or 'PERCENTAGE'.
  final String? penaltyType;

  /// 'ONCE' or 'RECURRING_MONTHLY'.
  final String? penaltyFrequency;
  final int? penaltyGraceDays;
  final double? penaltyFixedAmount;
  final double? penaltyRate;

  /// 'OUTSTANDING_INSTALLMENT' (the only supported basis in this phase).
  final String? penaltyBasis;

  final DateTime createdAt;
  final DateTime updatedAt;
}

/// One page of `rpc_list_loan_products()` results.
class LoanProductPage {
  const LoanProductPage({
    required this.items,
    required this.totalCount,
    required this.limit,
    required this.offset,
  });

  factory LoanProductPage.fromJson(Map<String, dynamic> json) {
    return LoanProductPage(
      items: (json['items'] as List<dynamic>)
          .map((item) => LoanProduct.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      totalCount: json['total_count'] as int,
      limit: json['limit'] as int,
      offset: json['offset'] as int,
    );
  }

  static const empty = LoanProductPage(
    items: [],
    totalCount: 0,
    limit: 20,
    offset: 0,
  );

  final List<LoanProduct> items;
  final int totalCount;
  final int limit;
  final int offset;

  bool get hasMore => offset + items.length < totalCount;
}
