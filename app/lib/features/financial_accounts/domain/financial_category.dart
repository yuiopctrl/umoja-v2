/// A group-scoped INCOME/EXPENSE label for manual cashbook postings
/// (Prompt 08B), as returned by `rpc_list_financial_categories()` /
/// `rpc_create_financial_category()` / `rpc_update_financial_category()`.
/// Never hard-deleted — see [isActive].
class FinancialCategory {
  const FinancialCategory({
    required this.id,
    required this.groupId,
    required this.name,
    required this.categoryType,
    this.systemCode,
    this.description,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FinancialCategory.fromJson(Map<String, dynamic> json) {
    return FinancialCategory(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      name: json['name'] as String,
      categoryType: json['category_type'] as String,
      systemCode: json['system_code'] as String?,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String groupId;
  final String name;

  /// 'INCOME' or 'EXPENSE'.
  final String categoryType;

  /// Set only for the standard categories `rpc_seed_default_financial_
  /// categories` creates (e.g. 'BANK_INTEREST', 'MISC_EXPENSE') — never
  /// used to hide/protect a category from deactivation, purely an
  /// identity marker.
  final String? systemCode;
  final String? description;

  /// A deactivated category can never be used for a new posting, but a
  /// historical entry's reference to it is never removed.
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isIncome => categoryType == 'INCOME';
  bool get isExpense => categoryType == 'EXPENSE';
}
