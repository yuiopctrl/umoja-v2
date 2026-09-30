/// `rpc_get_my_member_profile(p_group_id)`'s result (Prompt 09G-B2) —
/// the caller's OWN account profile + their OWN membership/roles in a
/// single selected group. Never another member's data: the RPC itself
/// resolves ownership exclusively from `auth.uid()`, so this model has
/// no membership id/user id input, only the returned facts.
///
/// Deliberately keeps the account-level fields (`accountFullName`,
/// `accountPhone`) separate from the roster-level fields
/// (`membershipDisplayName`, `membershipPhone`... note: roster phone is
/// not currently returned by the RPC, only account phone) — editing
/// one must never silently change the other (see
/// `docs/product/member-identity-model.md`).
class MyMemberProfile {
  const MyMemberProfile({
    required this.accountFullName,
    required this.accountPhone,
    required this.accountAvatarUrl,
    required this.membershipId,
    required this.membershipDisplayName,
    required this.memberNumber,
    required this.membershipStatus,
    required this.joinedAt,
    required this.groupId,
    required this.groupName,
    required this.groupCode,
    required this.roleCodes,
  });

  factory MyMemberProfile.fromJson(Map<String, dynamic> json) {
    final account = json['account'] as Map<String, dynamic>? ?? const {};
    final membership = json['membership'] as Map<String, dynamic>? ?? const {};
    final group = json['group'] as Map<String, dynamic>? ?? const {};
    final roles = json['roles'] as List<dynamic>? ?? const [];

    return MyMemberProfile(
      accountFullName: account['full_name'] as String?,
      accountPhone: account['phone'] as String?,
      accountAvatarUrl: account['avatar_url'] as String?,
      membershipId: membership['membership_id'] as String,
      membershipDisplayName: membership['display_name'] as String,
      memberNumber: membership['member_number'] as String?,
      membershipStatus: membership['membership_status'] as String,
      joinedAt: membership['joined_at'] as String?,
      groupId: group['group_id'] as String,
      groupName: group['group_name'] as String,
      groupCode: group['group_code'] as String?,
      roleCodes: roles.map((code) => code as String).toList(growable: false),
    );
  }

  /// Account-level, editable via [MyMemberProfile]'s own edit flow.
  final String? accountFullName;

  /// The caller's VERIFIED Supabase Auth phone
  /// (`current_verified_auth_phone_e164()` server-side) — read-only
  /// (see `docs/product/member-identity-model.md`: a phone change
  /// requires a real Supabase Auth OTP-backed flow, not a plain text
  /// edit). Deliberately never `profiles.phone` (editable contact
  /// data) or `group_memberships.phone` (officer-maintained roster
  /// data) — `null` if the caller has no confirmed auth phone, never
  /// silently backfilled from either of those (Prompt 09G-B2-FIX-01).
  final String? accountPhone;

  final String? accountAvatarUrl;

  /// Officer-maintained roster data below — never editable from My
  /// Profile.
  final String membershipId;
  final String membershipDisplayName;
  final String? memberNumber;
  final String membershipStatus;
  final String? joinedAt;

  final String groupId;
  final String groupName;
  final String? groupCode;

  /// The caller's own role codes in this group — friendly labels are
  /// resolved in the UI layer (see `memberRoleLabel`), never returned
  /// pre-localized by the backend.
  final List<String> roleCodes;

  String get displayFullName => accountFullName?.trim().isNotEmpty == true
      ? accountFullName!.trim()
      : membershipDisplayName;
}
