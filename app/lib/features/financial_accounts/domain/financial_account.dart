/// A `financial_accounts` row (Prompt 08A) — where posted money
/// physically lives (cash box, bank account, mobile money account).
/// [balance] is always the server-derived value from
/// `financial_account_balance()` — never computed client-side from a
/// locally-held entries list.
class FinancialAccount {
  const FinancialAccount({
    required this.id,
    required this.groupId,
    required this.name,
    required this.accountType,
    required this.isActive,
    required this.balance,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FinancialAccount.fromJson(Map<String, dynamic> json) {
    return FinancialAccount(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      name: json['name'] as String,
      accountType: json['account_type'] as String,
      isActive: json['is_active'] as bool,
      balance: (json['balance'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String groupId;
  final String name;

  /// One of CASH / BANK / MOBILE_MONEY.
  final String accountType;
  final bool isActive;
  final double balance;
  final DateTime createdAt;
  final DateTime updatedAt;
}
