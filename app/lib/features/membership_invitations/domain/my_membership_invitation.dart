import 'membership_invitation_status.dart';

/// One row of the authenticated caller's own personal invitation inbox
/// (`rpc_list_my_membership_invitations`, Prompt 09G-B1-F1). The
/// server resolves ownership exclusively from the caller's own
/// Supabase-Auth-verified phone — this model never carries, and the
/// screen never sends, a phone/user id of any kind. Deliberately never
/// exposes `target_phone_e164`, `membership_id`, or `group_id` (the
/// RPC itself never returns them) — only display-safe fields plus the
/// opaque [invitationId] needed to accept/decline.
class MyMembershipInvitation {
  const MyMembershipInvitation({
    required this.invitationId,
    required this.status,
    required this.canAccept,
    this.groupName,
    this.membershipDisplayName,
    this.membershipMemberNumber,
    required this.roleNames,
    required this.invitedAt,
    required this.expiresAt,
  });

  factory MyMembershipInvitation.fromJson(Map<String, dynamic> json) {
    return MyMembershipInvitation(
      invitationId: json['invitation_id'] as String,
      status: MembershipInvitationStatus.fromRaw(json['status'] as String?),
      canAccept: json['can_accept'] as bool? ?? false,
      groupName: json['group_name'] as String?,
      membershipDisplayName: json['membership_display_name'] as String?,
      membershipMemberNumber: json['membership_member_number'] as String?,
      roleNames: (json['roles'] as List<dynamic>? ?? const []).cast<String>(),
      invitedAt: DateTime.parse(json['invited_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  final String invitationId;

  /// The server-computed EFFECTIVE status (PENDING/EXPIRED/ACCEPTED/
  /// CANCELLED/DECLINED) — the RPC itself already resolves PENDING-
  /// but-past-expiry to EXPIRED before returning.
  final MembershipInvitationStatus status;

  /// Server-computed: `status == PENDING && expires_at > now()`. The
  /// ONLY signal the UI uses to decide whether to offer Accept/Decline
  /// — never re-derived from [status]/[expiresAt] client-side.
  final bool canAccept;

  final String? groupName;
  final String? membershipDisplayName;
  final String? membershipMemberNumber;

  /// Role DISPLAY NAMES, never codes.
  final List<String> roleNames;
  final DateTime invitedAt;
  final DateTime expiresAt;
}

/// A page of the personal invitation inbox, mirroring
/// `rpc_list_my_membership_invitations`'s `{items, total_count, limit,
/// offset}` shape.
class MyMembershipInvitationsPage {
  const MyMembershipInvitationsPage({
    required this.items,
    required this.totalCount,
    required this.limit,
    required this.offset,
  });

  factory MyMembershipInvitationsPage.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>? ?? const [];
    return MyMembershipInvitationsPage(
      items: itemsJson
          .map(
            (item) =>
                MyMembershipInvitation.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      totalCount: json['total_count'] as int? ?? itemsJson.length,
      limit: json['limit'] as int? ?? itemsJson.length,
      offset: json['offset'] as int? ?? 0,
    );
  }

  static const empty = MyMembershipInvitationsPage(
    items: [],
    totalCount: 0,
    limit: 20,
    offset: 0,
  );

  final List<MyMembershipInvitation> items;
  final int totalCount;
  final int limit;
  final int offset;

  /// The count Home/More's lightweight indicator shows — derived from
  /// the SAME already-fetched list, never a second query (Prompt
  /// 09G-B1-F2 §M).
  int get pendingActionableCount => items.where((i) => i.canAccept).length;
}
