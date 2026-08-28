/// Result of `rpc_get_member_wallet` — a member-owned advance held by
/// the group, never contribution income/profit/obligation/cashbook
/// account. Balance is always server-derived, never negative.
class MemberWallet {
  const MemberWallet({required this.membershipId, required this.walletBalance});

  factory MemberWallet.fromJson(Map<String, dynamic> json) {
    return MemberWallet(
      membershipId: json['membership_id'] as String,
      walletBalance: (json['wallet_balance'] as num).toDouble(),
    );
  }

  final String membershipId;
  final double walletBalance;
}
