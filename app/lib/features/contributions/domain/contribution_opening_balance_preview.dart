import 'contribution_opening_balance_entry.dart';

/// Read-only, server-authoritative preview of what
/// `rpc_import_contribution_opening_balances()` would post — the batch
/// import screen shows [entries]/[memberCount]/[totalOpeningObligation]
/// exactly as returned here, and never sums the entered amounts itself.
/// [canImport] is false whenever any entry is already imported — the
/// import button stays disabled until the batch is edited to remove or
/// zero out that entry.
class ContributionOpeningBalancePreview {
  const ContributionOpeningBalancePreview({
    required this.contributionTypeId,
    required this.effectiveAt,
    required this.memberCount,
    required this.totalOpeningObligation,
    required this.entries,
    required this.canImport,
  });

  factory ContributionOpeningBalancePreview.fromJson(
    Map<String, dynamic> json,
  ) {
    return ContributionOpeningBalancePreview(
      contributionTypeId: json['contribution_type_id'] as String,
      effectiveAt: DateTime.parse(json['effective_at'] as String),
      memberCount: json['member_count'] as int,
      totalOpeningObligation: (json['total_opening_obligation'] as num)
          .toDouble(),
      entries: (json['entries'] as List<dynamic>)
          .map(
            (item) => ContributionOpeningBalanceEntry.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
      canImport: json['can_import'] as bool,
    );
  }

  final String contributionTypeId;
  final DateTime effectiveAt;
  final int memberCount;
  final double totalOpeningObligation;
  final List<ContributionOpeningBalanceEntry> entries;
  final bool canImport;
}
