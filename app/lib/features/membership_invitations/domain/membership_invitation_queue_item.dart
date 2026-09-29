import 'membership_invitation_status.dart';

/// One row of the officer-facing invitation queue/history
/// (`rpc_list_membership_invitations`, Prompt 09G-B1-E1).
class MembershipInvitationQueueItem {
  const MembershipInvitationQueueItem({
    required this.invitationId,
    required this.membershipId,
    this.membershipDisplayName,
    this.membershipMemberNumber,
    required this.status,
    required this.isExpired,
    required this.roleCodes,
    required this.createdAt,
    required this.expiresAt,
    this.createdByFullName,
    this.acceptedAt,
    this.acceptedByFullName,
    this.cancelledAt,
    this.cancelledByFullName,
  });

  factory MembershipInvitationQueueItem.fromJson(Map<String, dynamic> json) {
    return MembershipInvitationQueueItem(
      invitationId: json['invitation_id'] as String,
      membershipId: json['membership_id'] as String,
      membershipDisplayName: json['membership_display_name'] as String?,
      membershipMemberNumber: json['membership_member_number'] as String?,
      status: MembershipInvitationStatus.fromRaw(json['status'] as String?),
      isExpired: json['is_expired'] as bool? ?? false,
      roleCodes: (json['roles'] as List<dynamic>? ?? const []).cast<String>(),
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      createdByFullName: json['created_by_full_name'] as String?,
      acceptedAt: json['accepted_at'] == null
          ? null
          : DateTime.parse(json['accepted_at'] as String),
      acceptedByFullName: json['accepted_by_full_name'] as String?,
      cancelledAt: json['cancelled_at'] == null
          ? null
          : DateTime.parse(json['cancelled_at'] as String),
      cancelledByFullName: json['cancelled_by_full_name'] as String?,
    );
  }

  final String invitationId;
  final String membershipId;
  final String? membershipDisplayName;
  final String? membershipMemberNumber;

  /// The RAW stored status — PENDING may still be `isExpired`; see
  /// [effectiveStatus] for the server-computed live view. Never
  /// written back by this client (the backend deliberately never
  /// lazily normalizes this column either — see the E1 migration).
  final MembershipInvitationStatus status;

  /// `is_expired`: server-computed live (`status = PENDING AND
  /// expires_at <= now()`), never persisted.
  final bool isExpired;

  final List<String> roleCodes;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? createdByFullName;
  final DateTime? acceptedAt;
  final String? acceptedByFullName;
  final DateTime? cancelledAt;
  final String? cancelledByFullName;

  bool get isPending => status == MembershipInvitationStatus.pending;

  /// The server's authoritative effective state for display: a
  /// PENDING row past its `expires_at` renders as expired, without
  /// this client ever fabricating or persisting an EXPIRED status
  /// anywhere — purely a presentation of [status] + [isExpired], both
  /// already server-computed.
  MembershipInvitationStatus get effectiveStatus =>
      isPending && isExpired ? MembershipInvitationStatus.expired : status;

  /// Cancel is only ever offered for a row that is genuinely still
  /// actionable — PENDING and not yet expired.
  bool get canCancel => isPending && !isExpired;
}

/// A page of the officer invitation queue, mirroring
/// `rpc_list_membership_invitations`'s `{items, total_count, limit,
/// offset}` shape — same pagination convention as
/// `MembershipClaimQueuePage`.
class MembershipInvitationQueuePage {
  const MembershipInvitationQueuePage({
    required this.items,
    required this.totalCount,
    required this.limit,
    required this.offset,
  });

  factory MembershipInvitationQueuePage.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>? ?? const [];
    return MembershipInvitationQueuePage(
      items: itemsJson
          .map(
            (item) => MembershipInvitationQueueItem.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
      totalCount: json['total_count'] as int? ?? itemsJson.length,
      limit: json['limit'] as int? ?? itemsJson.length,
      offset: json['offset'] as int? ?? 0,
    );
  }

  static const empty = MembershipInvitationQueuePage(
    items: [],
    totalCount: 0,
    limit: 20,
    offset: 0,
  );

  final List<MembershipInvitationQueueItem> items;
  final int totalCount;
  final int limit;
  final int offset;

  bool get hasMore => offset + items.length < totalCount;
}
