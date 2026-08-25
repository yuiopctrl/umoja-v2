/// One entry of the batched `rpc_set_contribution_period_member_amounts`
/// payload. A `null`/omitted [amount] removes that member's configured
/// amount — see `ContributionRepository.setContributionPeriodMemberAmounts`.
class ContributionMemberAmountInput {
  const ContributionMemberAmountInput({
    required this.membershipId,
    this.amount,
  });

  final String membershipId;
  final double? amount;
}
