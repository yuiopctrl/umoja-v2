/// One member's requested opening-balance amount for
/// `previewContributionOpeningBalanceImport`/`importContributionOpeningBalances`
/// — mirrors [ContributionMemberAmountInput]'s shape. A `null`/zero
/// [amount] means "no opening balance for this member" and is simply
/// omitted server-side, never rejected.
class ContributionOpeningBalanceEntryInput {
  const ContributionOpeningBalanceEntryInput({
    required this.membershipId,
    required this.amount,
  });

  final String membershipId;
  final double? amount;
}
