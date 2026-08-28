/// Result of `rpc_import_contribution_opening_balances()` — atomic,
/// all-or-nothing. [importedCount]/[totalOpeningObligation] are the
/// server's own tally of what was actually posted, never re-derived
/// from the request payload.
class ContributionOpeningBalanceImportResult {
  const ContributionOpeningBalanceImportResult({
    required this.periodId,
    required this.contributionTypeId,
    required this.effectiveAt,
    required this.importedCount,
    required this.totalOpeningObligation,
  });

  factory ContributionOpeningBalanceImportResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return ContributionOpeningBalanceImportResult(
      periodId: json['period_id'] as String,
      contributionTypeId: json['contribution_type_id'] as String,
      effectiveAt: DateTime.parse(json['effective_at'] as String),
      importedCount: json['imported_count'] as int,
      totalOpeningObligation: (json['total_opening_obligation'] as num)
          .toDouble(),
    );
  }

  final String periodId;
  final String contributionTypeId;
  final DateTime effectiveAt;
  final int importedCount;
  final double totalOpeningObligation;
}
