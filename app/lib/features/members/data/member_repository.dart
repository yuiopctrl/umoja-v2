import '../domain/group_member.dart';
import '../domain/group_member_page.dart';

/// Abstraction over the Members Management backend RPCs. UI/controllers
/// depend on this, never on the Supabase SDK directly — all mutations
/// go through the existing controlled RPCs
/// (`rpc_create_group_member`, `rpc_update_group_member`,
/// `rpc_change_group_member_status`, `rpc_assign_group_role`,
/// `rpc_remove_group_role`) and the new read RPCs
/// (`rpc_list_group_members`, `rpc_get_group_member`); this
/// abstraction never performs a direct table read/insert/update.
///
/// Implementations must throw [MemberFailure] (never a raw SDK
/// exception) for anything that should be shown to the user.
abstract class MemberRepository {
  Future<GroupMemberPage> listMembers({
    required String groupId,
    String? search,
    String? status,
    int limit = 25,
    int offset = 0,
  });

  Future<GroupMember> getMember({
    required String groupId,
    required String membershipId,
  });

  /// Creates a member with `user_id = null` — this never creates an
  /// auth account, sends an OTP, or invites anyone.
  Future<GroupMember> createMember({
    required String groupId,
    required String displayName,
    String? phone,
    String? memberNumber,
    DateTime? joinedAt,
  });

  /// Updates editable identity/contact fields only — never status.
  Future<GroupMember> updateMember({
    required String groupId,
    required String membershipId,
    String? displayName,
    String? phone,
    String? memberNumber,
  });

  /// Changes lifecycle status only — never identity/contact fields.
  Future<GroupMember> changeStatus({
    required String groupId,
    required String membershipId,
    required String status,
    DateTime? exitedAt,
  });

  Future<void> assignRole({
    required String groupId,
    required String membershipId,
    required String roleCode,
  });

  Future<void> removeRole({
    required String groupId,
    required String membershipId,
    required String roleCode,
  });
}
