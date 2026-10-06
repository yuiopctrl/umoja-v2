// Prompt 09G-B4-C: Member self-service My Contributions — read-only
// domain models for `rpc_get_my_contributions` and
// `rpc_get_my_contribution_charge_detail` (migration
// 20260926090000_create_my_contributions_backend.sql). Every key below
// is taken from that migration's jsonb_build_object output; nothing is
// derived client-side. The backend is the financial authority: status,
// net assessed, allocated, outstanding, totals, and component state are
// rendered exactly as returned — never recomputed from items or pages.

/// Server-derived charge status. Exactly these four values exist on the
/// backend; there is deliberately NO paid/PAID state.
enum MyContributionStatus {
  open('OPEN'),
  partiallySettled('PARTIALLY_SETTLED'),
  overdue('OVERDUE'),
  settled('SETTLED');

  const MyContributionStatus(this.wire);

  /// The exact string the backend sends and accepts for `p_status`.
  final String wire;

  static MyContributionStatus fromWire(String value) {
    for (final status in values) {
      if (status.wire == value) return status;
    }
    throw FormatException('Unknown contribution status: $value');
  }
}

/// `period_purpose` — distinguishes OPENING_BALANCE obligations from
/// ordinary NORMAL contribution periods.
enum MyContributionPeriodPurpose {
  normal('NORMAL'),
  openingBalance('OPENING_BALANCE');

  const MyContributionPeriodPurpose(this.wire);

  final String wire;

  static MyContributionPeriodPurpose fromWire(String value) {
    for (final purpose in values) {
      if (purpose.wire == value) return purpose;
    }
    throw FormatException('Unknown period purpose: $value');
  }
}

/// `components[].component_type`.
enum MyContributionComponentType {
  base('BASE'),
  penalty('PENALTY'),
  adjustment('ADJUSTMENT'),
  waiver('WAIVER'),
  openingBalance('OPENING_BALANCE');

  const MyContributionComponentType(this.wire);

  final String wire;

  static MyContributionComponentType fromWire(String value) {
    for (final type in values) {
      if (type.wire == value) return type;
    }
    throw FormatException('Unknown component type: $value');
  }
}

/// `settlement_history[].source`.
enum MyContributionSettlementSource {
  payment('PAYMENT'),
  wallet('WALLET');

  const MyContributionSettlementSource(this.wire);

  final String wire;

  static MyContributionSettlementSource fromWire(String value) {
    for (final source in values) {
      if (source.wire == value) return source;
    }
    throw FormatException('Unknown settlement source: $value');
  }
}

double _amount(Object? value) => (value as num).toDouble();

double? _nullableAmount(Object? value) =>
    value == null ? null : (value as num).toDouble();

DateTime? _nullableDate(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

/// `member` — the caller's own membership. Never another member's data.
class MyContributionsMember {
  const MyContributionsMember({
    required this.membershipId,
    required this.displayName,
    this.memberNumber,
    required this.membershipStatus,
  });

  factory MyContributionsMember.fromJson(Map<String, dynamic> json) {
    return MyContributionsMember(
      membershipId: json['membership_id'] as String,
      displayName: json['display_name'] as String,
      memberNumber: json['member_number'] as String?,
      membershipStatus: json['membership_status'] as String,
    );
  }

  final String membershipId;
  final String displayName;
  final String? memberNumber;
  final String membershipStatus;
}

/// `group` — currency is metadata only; no conversion exists in the app.
class MyContributionsGroup {
  const MyContributionsGroup({
    required this.groupId,
    required this.groupName,
    this.groupCode,
    required this.currency,
  });

  factory MyContributionsGroup.fromJson(Map<String, dynamic> json) {
    return MyContributionsGroup(
      groupId: json['group_id'] as String,
      groupName: json['group_name'] as String,
      groupCode: json['group_code'] as String?,
      currency: json['currency'] as String,
    );
  }

  final String groupId;
  final String groupName;
  final String? groupCode;
  final String currency;
}

/// `summary` — `total_outstanding` is the server's unfiltered, unpaged
/// current own-member total. Never recomputed from loaded rows.
class MyContributionsSummary {
  const MyContributionsSummary({required this.totalOutstanding});

  factory MyContributionsSummary.fromJson(Map<String, dynamic> json) {
    return MyContributionsSummary(
      totalOutstanding: _amount(json['total_outstanding']),
    );
  }

  final double totalOutstanding;
}

/// One entry of `filter_options.contribution_types`. [name] is the
/// backend's primary name; [nameVariants]/[categoryVariants] are the
/// historical snapshot names that differ from it, when any exist.
class MyContributionTypeOption {
  const MyContributionTypeOption({
    required this.id,
    required this.name,
    required this.category,
    this.nameVariants = const [],
    this.categoryVariants = const [],
  });

  factory MyContributionTypeOption.fromJson(Map<String, dynamic> json) {
    return MyContributionTypeOption(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      nameVariants: _stringList(json['name_variants']),
      categoryVariants: _stringList(json['category_variants']),
    );
  }

  final String id;
  final String name;
  final String category;
  final List<String> nameVariants;
  final List<String> categoryVariants;

  /// Historical names that differ from the primary [name]. Empty when
  /// the type has only ever been recorded under one name.
  List<String> get previouslyRecordedNames =>
      nameVariants.where((variant) => variant != name).toList(growable: false);
}

List<String> _stringList(Object? value) {
  if (value == null) return const [];
  return (value as List<dynamic>).cast<String>();
}

/// `pagination` — `has_more` is authoritative for the load-more control.
class MyContributionsPagination {
  const MyContributionsPagination({
    required this.limit,
    required this.offset,
    required this.totalCount,
    required this.hasMore,
  });

  factory MyContributionsPagination.fromJson(Map<String, dynamic> json) {
    return MyContributionsPagination(
      limit: json['limit'] as int,
      offset: json['offset'] as int,
      totalCount: json['total_count'] as int,
      hasMore: json['has_more'] as bool,
    );
  }

  final int limit;
  final int offset;
  final int totalCount;
  final bool hasMore;
}

/// One row of `items`. Amounts are canonical backend values.
class MyContribution {
  const MyContribution({
    required this.chargeId,
    required this.contributionTypeId,
    required this.contributionTypeName,
    required this.contributionCategory,
    required this.periodId,
    required this.periodLabel,
    required this.periodPurpose,
    required this.effectiveAt,
    this.dueDate,
    required this.netAssessed,
    required this.allocatedAmount,
    required this.outstanding,
    required this.status,
  });

  factory MyContribution.fromJson(Map<String, dynamic> json) {
    return MyContribution(
      chargeId: json['charge_id'] as String,
      contributionTypeId: json['contribution_type_id'] as String,
      contributionTypeName: json['contribution_type_name'] as String?,
      contributionCategory: json['contribution_category'] as String?,
      periodId: json['period_id'] as String,
      periodLabel: json['period_label'] as String?,
      periodPurpose: MyContributionPeriodPurpose.fromWire(
        json['period_purpose'] as String,
      ),
      effectiveAt: DateTime.parse(json['effective_at'] as String),
      dueDate: _nullableDate(json['due_date']),
      netAssessed: _amount(json['net_assessed']),
      allocatedAmount: _amount(json['allocated_amount']),
      outstanding: _amount(json['outstanding']),
      status: MyContributionStatus.fromWire(json['status'] as String),
    );
  }

  final String chargeId;
  final String contributionTypeId;

  /// Null only when the backend has no type name for the charge; the UI
  /// shows a neutral generic label rather than inventing a type name.
  final String? contributionTypeName;
  final String? contributionCategory;
  final String periodId;

  /// Null for charges whose period carries no label.
  final String? periodLabel;
  final MyContributionPeriodPurpose periodPurpose;
  final DateTime effectiveAt;
  final DateTime? dueDate;
  final double netAssessed;
  final double allocatedAmount;
  final double outstanding;
  final MyContributionStatus status;
}

/// Full `rpc_get_my_contributions` response.
class MyContributionsPage {
  const MyContributionsPage({
    required this.member,
    required this.group,
    required this.summary,
    required this.contributionTypes,
    required this.items,
    required this.pagination,
  });

  factory MyContributionsPage.fromJson(Map<String, dynamic> json) {
    final filterOptions = json['filter_options'] as Map<String, dynamic>;
    return MyContributionsPage(
      member: MyContributionsMember.fromJson(
        json['member'] as Map<String, dynamic>,
      ),
      group: MyContributionsGroup.fromJson(
        json['group'] as Map<String, dynamic>,
      ),
      summary: MyContributionsSummary.fromJson(
        json['summary'] as Map<String, dynamic>,
      ),
      contributionTypes: (filterOptions['contribution_types'] as List<dynamic>)
          .map(
            (option) => MyContributionTypeOption.fromJson(
              option as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
      items: (json['items'] as List<dynamic>)
          .map((item) => MyContribution.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      pagination: MyContributionsPagination.fromJson(
        json['pagination'] as Map<String, dynamic>,
      ),
    );
  }

  final MyContributionsMember member;
  final MyContributionsGroup group;
  final MyContributionsSummary summary;

  /// `filter_options.contribution_types` — the backend's own-obligation
  /// universe. The type filter is built from this, never from [items].
  final List<MyContributionTypeOption> contributionTypes;
  final List<MyContribution> items;
  final MyContributionsPagination pagination;
}

/// One component of a charge (`components[]`). [netEffect], [allocated]
/// and [outstanding] are null where the backend has no meaningful
/// per-component state (e.g. WAIVER); they are never fabricated as zero.
class MyContributionComponent {
  const MyContributionComponent({
    required this.componentId,
    required this.componentType,
    required this.assessedAmount,
    this.netEffect,
    this.allocated,
    this.outstanding,
    required this.effectiveAt,
    this.reason,
  });

  factory MyContributionComponent.fromJson(Map<String, dynamic> json) {
    return MyContributionComponent(
      componentId: json['component_id'] as String,
      componentType: MyContributionComponentType.fromWire(
        json['component_type'] as String,
      ),
      assessedAmount: _amount(json['assessed_amount']),
      netEffect: _nullableAmount(json['net_effect']),
      allocated: _nullableAmount(json['allocated']),
      outstanding: _nullableAmount(json['outstanding']),
      effectiveAt: DateTime.parse(json['effective_at'] as String),
      reason: json['reason'] as String?,
    );
  }

  final String componentId;
  final MyContributionComponentType componentType;

  /// Signed: a negative WAIVER or ADJUSTMENT is preserved as negative.
  final double assessedAmount;
  final double? netEffect;
  final double? allocated;
  final double? outstanding;
  final DateTime effectiveAt;
  final String? reason;
}

/// One `settlement_history[]` row: a real persisted allocation, either
/// payment-sourced or wallet-sourced. Reversed payments stay listed
/// with [isReversed] = true and no longer reduce outstanding.
class MyContributionSettlement {
  const MyContributionSettlement({
    required this.allocationId,
    required this.componentId,
    required this.componentType,
    required this.amount,
    required this.source,
    required this.effectiveAt,
    this.paymentStatus,
    this.receiptNumber,
    this.isReversed,
  });

  factory MyContributionSettlement.fromJson(Map<String, dynamic> json) {
    return MyContributionSettlement(
      allocationId: json['allocation_id'] as String,
      componentId: json['component_id'] as String,
      componentType: MyContributionComponentType.fromWire(
        json['component_type'] as String,
      ),
      amount: _amount(json['amount']),
      source: MyContributionSettlementSource.fromWire(json['source'] as String),
      effectiveAt: DateTime.parse(json['effective_at'] as String),
      paymentStatus: json['payment_status'] as String?,
      receiptNumber: json['receipt_number'] as String?,
      isReversed: json['is_reversed'] as bool?,
    );
  }

  final String allocationId;
  final String componentId;
  final MyContributionComponentType componentType;
  final double amount;
  final MyContributionSettlementSource source;
  final DateTime effectiveAt;

  /// Null for WALLET settlements (no payment row exists).
  final String? paymentStatus;

  /// Null for WALLET settlements and any payment without a receipt.
  final String? receiptNumber;

  /// Null for WALLET settlements; true only for reversed payments.
  final bool? isReversed;

  bool get reversed => isReversed ?? false;
}

/// `rpc_get_my_contribution_charge_detail` response. Has no `member` or
/// `group` keys — the detail screen takes its context from the selected
/// group and the list it was opened from.
class MyContributionDetail {
  const MyContributionDetail({
    required this.chargeId,
    required this.contributionTypeId,
    required this.contributionTypeName,
    required this.contributionCategory,
    required this.periodId,
    required this.periodLabel,
    required this.periodPurpose,
    required this.effectiveAt,
    this.dueDate,
    required this.netAssessed,
    required this.allocatedAmount,
    required this.outstanding,
    required this.status,
    required this.components,
    required this.settlementHistory,
  });

  factory MyContributionDetail.fromJson(Map<String, dynamic> json) {
    return MyContributionDetail(
      chargeId: json['charge_id'] as String,
      contributionTypeId: json['contribution_type_id'] as String,
      contributionTypeName: json['contribution_type_name'] as String?,
      contributionCategory: json['contribution_category'] as String?,
      periodId: json['period_id'] as String,
      periodLabel: json['period_label'] as String?,
      periodPurpose: MyContributionPeriodPurpose.fromWire(
        json['period_purpose'] as String,
      ),
      effectiveAt: DateTime.parse(json['effective_at'] as String),
      dueDate: _nullableDate(json['due_date']),
      netAssessed: _amount(json['net_assessed']),
      allocatedAmount: _amount(json['allocated_amount']),
      outstanding: _amount(json['outstanding']),
      status: MyContributionStatus.fromWire(json['status'] as String),
      components: (json['components'] as List<dynamic>)
          .map(
            (item) =>
                MyContributionComponent.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      settlementHistory: (json['settlement_history'] as List<dynamic>)
          .map(
            (item) =>
                MyContributionSettlement.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }

  final String chargeId;
  final String contributionTypeId;
  final String? contributionTypeName;
  final String? contributionCategory;
  final String periodId;
  final String? periodLabel;
  final MyContributionPeriodPurpose periodPurpose;
  final DateTime effectiveAt;
  final DateTime? dueDate;
  final double netAssessed;
  final double allocatedAmount;
  final double outstanding;
  final MyContributionStatus status;
  final List<MyContributionComponent> components;
  final List<MyContributionSettlement> settlementHistory;
}
