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
  ///
  /// [memberNumber] is an override for a future controlled admin/import
  /// workflow only — `MemberFormController`/the normal create-member
  /// screen never supply it, since `rpc_create_group_member` now
  /// auto-generates a server-side, concurrency-safe number
  /// (`<group code>-<year>-<sequence>`) whenever it is omitted.
  Future<GroupMember> createMember({
    required String groupId,
    required String displayName,
    String? phone,
    String? memberNumber,
    DateTime? joinedAt,
  });

  /// Updates editable identity/contact fields only — never status.
  /// Returns `void`: `rpc_update_group_member` returns a partial row
  /// shape (no `created_at`), and no caller needs the updated member
  /// back — screens re-read via [memberDetailProvider] after
  /// invalidating it, rather than trusting this call's return value.
  Future<void> updateMember({
    required String groupId,
    required String membershipId,
    String? displayName,
    String? phone,
    String? memberNumber,
  });

  /// Changes lifecycle status only — never identity/contact fields.
  /// Returns `void` — see [updateMember] doc for why (same partial
  /// return-shape reasoning; `rpc_change_group_member_status`'s jsonb
  /// result also omits `display_name`/`created_at`, which would fail
  /// [GroupMember.fromJson] even though the mutation itself succeeded).
  Future<void> changeStatus({
    required String groupId,
    required String membershipId,
    required String status,
    DateTime? exitedAt,
  });

  /// The explicit, separate rejoin workflow for an EXITED member —
  /// never `changeStatus(status: 'ACTIVE')`, which the backend rejects
  /// for a terminal EXITED membership by design. Returns `void` for the
  /// same reason as [changeStatus].
  Future<void> rejoinMember({
    required String groupId,
    required String membershipId,
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
