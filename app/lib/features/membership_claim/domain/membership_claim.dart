/// A signed-in user's request to link their own `auth.uid()` to an
/// existing roster-only membership (Prompt 09G-B1). Read-only,
/// server-computed — Flutter never infers or fabricates a status;
/// every field is rendered exactly as one of `rpc_request_membership_
/// claim_by_reference`/`rpc_list_my_membership_claims`/
/// `rpc_cancel_membership_claim` returns it. The three RPCs return
/// slightly different subsets of the same shape (e.g. the request
/// result adds [alreadyRequested] but omits [resolvedAt]/
/// [rejectionReason]; the cancel result omits [rejectionReason]) —
/// this single model tolerates any of them, with every optional field
/// null-safe.
class MembershipClaim {
  const MembershipClaim({
    required this.claimId,
    this.groupId,
    this.membershipId,
    required this.status,
    this.requestedAt,
    this.resolvedAt,
    this.rejectionReason,
    this.alreadyRequested = false,
  });

  factory MembershipClaim.fromJson(Map<String, dynamic> json) {
    return MembershipClaim(
      claimId: json['claim_id'] as String,
      groupId: json['group_id'] as String?,
      membershipId: json['membership_id'] as String?,
      status: MembershipClaimStatus.fromRaw(json['status'] as String?),
      requestedAt: json['requested_at'] == null
          ? null
          : DateTime.parse(json['requested_at'] as String),
      resolvedAt: json['resolved_at'] == null
          ? null
          : DateTime.parse(json['resolved_at'] as String),
      rejectionReason: json['rejection_reason'] as String?,
      alreadyRequested: json['already_requested'] as bool? ?? false,
    );
  }

  final String claimId;
  final String? groupId;
  final String? membershipId;
  final MembershipClaimStatus status;
  final DateTime? requestedAt;
  final DateTime? resolvedAt;

  /// Only ever populated when [status] is
  /// [MembershipClaimStatus.rejected] — never fabricated client-side.
  final String? rejectionReason;

  /// `true` only on the response of `rpc_request_membership_claim_by_
  /// reference` when the caller's own existing PENDING claim was
  /// returned rather than a fresh one created — never meaningful on a
  /// row read via [MembershipClaim.fromJson] from the claims list.
  final bool alreadyRequested;

  bool get isPending => status == MembershipClaimStatus.pending;
  bool get isApproved => status == MembershipClaimStatus.approved;
  bool get isRejected => status == MembershipClaimStatus.rejected;
  bool get isCancelled => status == MembershipClaimStatus.cancelled;
}

/// `membership_claim_requests.status` — [unknown] is the forward-safe
/// fallback for any status value this client build doesn't recognize
/// yet; parsing never throws for it.
enum MembershipClaimStatus {
  pending,
  approved,
  rejected,
  cancelled,
  unknown;

  static MembershipClaimStatus fromRaw(String? raw) {
    return switch (raw) {
      'PENDING' => MembershipClaimStatus.pending,
      'APPROVED' => MembershipClaimStatus.approved,
      'REJECTED' => MembershipClaimStatus.rejected,
      'CANCELLED' => MembershipClaimStatus.cancelled,
      _ => MembershipClaimStatus.unknown,
    };
  }
}
