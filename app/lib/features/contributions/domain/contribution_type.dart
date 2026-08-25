/// A contribution type (a domain `contribution_types` row) — business
/// classification of a contribution ("what kind"), as returned by
/// `rpc_list_contribution_types()`/`rpc_get_contribution_type()`/
/// `rpc_create_contribution_type()`/`rpc_update_contribution_type()`.
///
/// [accountingTreatment] of `MEMBER_SAVINGS` is reserved/deferred on the
/// backend — the create/edit UI must reject it client-side too (see
/// `contributionAccountingTreatmentOptions` in
/// `presentation/widgets/contribution_treatment_label.dart`), never
/// relying only on the backend's `MEMBER_SAVINGS_NOT_AVAILABLE` error.
class ContributionType {
  const ContributionType({
    required this.id,
    required this.groupId,
    required this.name,
    this.description,
    required this.category,
    required this.accountingTreatment,
    required this.isActive,
    required this.displayOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ContributionType.fromJson(Map<String, dynamic> json) {
    return ContributionType(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String,
      accountingTreatment: json['accounting_treatment'] as String,
      isActive: json['is_active'] as bool,
      displayOrder: json['display_order'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String groupId;
  final String name;
  final String? description;

  /// One of GENERAL / SOCIAL / SHARE.
  final String category;

  /// One of GROUP_INCOME / PASS_THROUGH / SHARE_CAPITAL / MEMBER_SAVINGS.
  final String accountingTreatment;
  final bool isActive;
  final int displayOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
}
