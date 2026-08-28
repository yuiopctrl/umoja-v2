/// One row of `rpc_preview_contribution_opening_balance_import()`'s
/// server-authoritative preview — [amount] is exactly what the backend
/// will import (blank/zero entries are omitted server-side, never
/// listed here), and [alreadyImported] flags a member who already has
/// an opening balance for this exact (group, contribution type,
/// effective date), so the batch UI never has to guess or re-derive
/// this itself.
class ContributionOpeningBalanceEntry {
  const ContributionOpeningBalanceEntry({
    required this.membershipId,
    required this.memberNumber,
    required this.displayName,
    required this.amount,
    required this.alreadyImported,
  });

  factory ContributionOpeningBalanceEntry.fromJson(Map<String, dynamic> json) {
    return ContributionOpeningBalanceEntry(
      membershipId: json['membership_id'] as String,
      memberNumber: json['member_number'] as String?,
      displayName: json['display_name'] as String?,
      amount: (json['amount'] as num).toDouble(),
      alreadyImported: json['already_imported'] as bool,
    );
  }

  final String membershipId;
  final String? memberNumber;
  final String? displayName;
  final double amount;
  final bool alreadyImported;
}
