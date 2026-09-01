/// One account's balance as of the report cutoff, as returned within
/// `rpc_get_financial_position()`'s `accounts[]`.
class FinancialPositionAccount {
  const FinancialPositionAccount({
    required this.id,
    required this.name,
    required this.accountType,
    required this.isActive,
    required this.balance,
  });

  factory FinancialPositionAccount.fromJson(Map<String, dynamic> json) {
    return FinancialPositionAccount(
      id: json['id'] as String,
      name: json['name'] as String,
      accountType: json['account_type'] as String,
      isActive: json['is_active'] as bool,
      balance: (json['balance'] as num).toDouble(),
    );
  }

  final String id;
  final String name;

  /// 'CASH', 'BANK', or 'MOBILE_MONEY'.
  final String accountType;
  final bool isActive;
  final double balance;
}

/// The Financial Position / Hali ya Fedha read model (Prompt 08B), as
/// returned by `rpc_get_financial_position()`. Deliberately NOT a full
/// accounting balance sheet — see docs/product/financial_operations.md.
/// Every figure is server-derived; Flutter never recomputes any of
/// these from raw cashbook rows.
class FinancialPosition {
  const FinancialPosition({
    required this.asOf,
    this.periodFrom,
    this.periodTo,
    required this.accounts,
    required this.totalFinancialAccountBalance,
    required this.groupIncome,
    required this.expenses,
    required this.netOperatingResult,
    required this.passThroughReceived,
    required this.shareCapitalReceived,
    required this.memberWalletLiability,
    required this.totalOutstandingMemberObligations,
    this.fundedLoanPrincipalReceivable = 0,
    this.scheduledUnearnedInterest = 0,
    this.recognizedLoanInterestIncome = 0,
  });

  factory FinancialPosition.fromJson(Map<String, dynamic> json) {
    return FinancialPosition(
      asOf: DateTime.parse(json['as_of'] as String),
      periodFrom: json['period_from'] == null
          ? null
          : DateTime.parse(json['period_from'] as String),
      periodTo: json['period_to'] == null
          ? null
          : DateTime.parse(json['period_to'] as String),
      accounts: (json['accounts'] as List<dynamic>)
          .map(
            (item) =>
                FinancialPositionAccount.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      totalFinancialAccountBalance:
          (json['total_financial_account_balance'] as num).toDouble(),
      groupIncome: (json['group_income'] as num).toDouble(),
      expenses: (json['expenses'] as num).toDouble(),
      netOperatingResult: (json['net_operating_result'] as num).toDouble(),
      passThroughReceived: (json['pass_through_received'] as num).toDouble(),
      shareCapitalReceived: (json['share_capital_received'] as num).toDouble(),
      memberWalletLiability: (json['member_wallet_liability'] as num)
          .toDouble(),
      totalOutstandingMemberObligations:
          (json['total_outstanding_member_obligations'] as num).toDouble(),
      fundedLoanPrincipalReceivable:
          (json['funded_loan_principal_receivable'] as num?)?.toDouble() ?? 0,
      scheduledUnearnedInterest:
          (json['scheduled_unearned_interest'] as num?)?.toDouble() ?? 0,
      recognizedLoanInterestIncome:
          (json['recognized_loan_interest_income'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Account/wallet balances are cumulative through this cutoff
  /// (`periodTo`, defaulting to today) — a point-in-time snapshot, not
  /// a period movement.
  final DateTime asOf;

  /// `null` means unbounded on that side — never assumed as "current
  /// month" server-side; any such default belongs in the Flutter date
  /// range picker only.
  final DateTime? periodFrom;
  final DateTime? periodTo;

  final List<FinancialPositionAccount> accounts;

  /// Balance AS OF [asOf] — the cumulative physical cash position,
  /// never affected by internal transfers.
  final double totalFinancialAccountBalance;

  /// Movement DURING the period: GROUP_INCOME-treated contribution cash
  /// received, plus manual INCOME entries. Never includes
  /// [passThroughReceived] or [shareCapitalReceived].
  final double groupIncome;

  /// Movement DURING the period: manual EXPENSE entries.
  final double expenses;

  final double netOperatingResult;

  /// Movement DURING the period: PASS_THROUGH-treated contribution
  /// cash received — shown separately, never group income.
  final double passThroughReceived;

  /// Movement DURING the period: SHARE_CAPITAL-treated contribution
  /// cash received — shown separately, never ordinary operating
  /// income.
  final double shareCapitalReceived;

  /// Balance AS OF [asOf] — a member-owned advance/liability, never
  /// deducted from [totalFinancialAccountBalance] (cash balance and
  /// economic ownership are separate concepts).
  final double memberWalletLiability;

  /// Always current (never date-filtered) — an unpaid amount has no
  /// historical point-in-time meaning the way a balance does.
  final double totalOutstandingMemberObligations;

  /// Balance AS OF [asOf] (Prompt 09B) — the frozen principal of every
  /// DISBURSED/ACTIVE loan in the group. Never reduced by repayment in
  /// 09B (no repayment exists yet); that belongs to 09C.
  final double fundedLoanPrincipalReceivable;

  /// Balance AS OF [asOf] (Prompt 09B) — the contractual future
  /// interest across every funded loan's own schedule. Deliberately
  /// never added to [groupIncome]: interest recognition is a 09C
  /// policy decision, not a 09B one.
  final double scheduledUnearnedInterest;

  /// Movement DURING the period (Prompt 09C) — interest recognized as
  /// income only when an active loan allocation actually settles it;
  /// already included inside [groupIncome], never double-counted. Never
  /// derived from [scheduledUnearnedInterest] — the two are computed
  /// independently server-side and must never double-count.
  final double recognizedLoanInterestIncome;
}
