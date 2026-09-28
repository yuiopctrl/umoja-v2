import 'membership_claim.dart';

/// One row of the officer-facing claim queue
/// (`rpc_list_membership_claims`, Prompt 09G-B1-B/D3) — a richer,
/// permission-gated read model than [MembershipClaim]. Deliberately a
/// SEPARATE type rather than extra nullable fields bolted onto
/// [MembershipClaim]: the claimant-facing model must never carry
/// another member's roster/phone details even as unused optional
/// fields, since that type is also used by ordinary claimant screens
/// (D2) that have no officer permission at all.
class MembershipClaimQueueItem {
  const MembershipClaimQueueItem({
    required this.claimId,
    required this.membershipId,
    this.membershipDisplayName,
    this.membershipMemberNumber,
    this.membershipPhone,
    this.claimantFullName,
    this.claimantPhone,
    required this.status,
    this.requestedAt,
    this.resolvedAt,
    this.rejectionReason,
  });

  factory MembershipClaimQueueItem.fromJson(Map<String, dynamic> json) {
    return MembershipClaimQueueItem(
      claimId: json['claim_id'] as String,
      membershipId: json['membership_id'] as String,
      membershipDisplayName: json['membership_display_name'] as String?,
      membershipMemberNumber: json['membership_member_number'] as String?,
      membershipPhone: json['membership_phone'] as String?,
      claimantFullName: json['claimant_full_name'] as String?,
      claimantPhone: json['claimant_phone'] as String?,
      status: MembershipClaimStatus.fromRaw(json['status'] as String?),
      requestedAt: json['requested_at'] == null
          ? null
          : DateTime.parse(json['requested_at'] as String),
      resolvedAt: json['resolved_at'] == null
          ? null
          : DateTime.parse(json['resolved_at'] as String),
      rejectionReason: json['rejection_reason'] as String?,
    );
  }

  final String claimId;
  final String membershipId;

  /// The roster row's own already member.view-visible fields — never
  /// an auth UUID, never fabricated.
  final String? membershipDisplayName;
  final String? membershipMemberNumber;
  final String? membershipPhone;

  /// The claimant's `public.profiles` full_name/phone — never a raw
  /// `auth.users` field. Shown to the reviewing officer specifically so
  /// they can visually cross-check the claimant against the roster row
  /// they're claiming (see `rpc_list_membership_claims`'s own SQL
  /// comment) — this is the one context in this feature where
  /// disclosing phone is intentional, unlike the claimant-facing
  /// initiation flow (D1), which deliberately omits it entirely.
  final String? claimantFullName;
  final String? claimantPhone;

  final MembershipClaimStatus status;
  final DateTime? requestedAt;
  final DateTime? resolvedAt;
  final String? rejectionReason;

  bool get isPending => status == MembershipClaimStatus.pending;
}

/// A page of the officer claim queue, mirroring
/// `rpc_list_membership_claims`'s `{items, total_count, limit, offset}`
/// shape — same pagination convention as `LoanAccountPage`/
/// `LoanProductPage`.
class MembershipClaimQueuePage {
  const MembershipClaimQueuePage({
    required this.items,
    required this.totalCount,
    required this.limit,
    required this.offset,
  });

  factory MembershipClaimQueuePage.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>? ?? const [];
    return MembershipClaimQueuePage(
      items: itemsJson
          .map(
            (item) =>
                MembershipClaimQueueItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      totalCount: json['total_count'] as int? ?? itemsJson.length,
      limit: json['limit'] as int? ?? itemsJson.length,
      offset: json['offset'] as int? ?? 0,
    );
  }

  static const empty = MembershipClaimQueuePage(
    items: [],
    totalCount: 0,
    limit: 20,
    offset: 0,
  );

  final List<MembershipClaimQueueItem> items;
  final int totalCount;
  final int limit;
  final int offset;

  bool get hasMore => offset + items.length < totalCount;
}
