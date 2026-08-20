import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/group_member.dart';
import '../domain/group_member_page.dart';
import 'member_failure.dart';
import 'member_repository.dart';

final _log = Logger('SupabaseMemberRepository');

/// [MemberRepository] backed by the existing member/role RPCs. Never
/// inserts/updates `group_memberships`/`group_membership_roles`
/// directly — those direct-table grants are revoked server-side
/// anyway (see docs/database/authorization.md), so this is enforced at
/// both layers.
class SupabaseMemberRepository implements MemberRepository {
  SupabaseMemberRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<GroupMemberPage> listMembers({
    required String groupId,
    String? search,
    String? status,
    int limit = 25,
    int offset = 0,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_list_group_members',
        params: {
          'p_group_id': groupId,
          'p_search': (search == null || search.trim().isEmpty)
              ? null
              : search.trim(),
          'p_status': status,
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      return GroupMemberPage.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<GroupMember> getMember({
    required String groupId,
    required String membershipId,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_get_group_member',
        params: {'p_group_id': groupId, 'p_membership_id': membershipId},
      );
      return GroupMember.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<GroupMember> createMember({
    required String groupId,
    required String displayName,
    String? phone,
    String? memberNumber,
    DateTime? joinedAt,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_create_group_member',
        params: {
          'p_group_id': groupId,
          'p_display_name': displayName,
          'p_phone': phone,
          'p_member_number': memberNumber,
          if (joinedAt != null) 'p_joined_at': _dateOnly(joinedAt),
        },
      );
      return GroupMember.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<GroupMember> updateMember({
    required String groupId,
    required String membershipId,
    String? displayName,
    String? phone,
    String? memberNumber,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_update_group_member',
        params: {
          'p_group_id': groupId,
          'p_membership_id': membershipId,
          'p_display_name': displayName,
          'p_phone': phone,
          'p_member_number': memberNumber,
        },
      );
      return GroupMember.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<GroupMember> changeStatus({
    required String groupId,
    required String membershipId,
    required String status,
    DateTime? exitedAt,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_change_group_member_status',
        params: {
          'p_group_id': groupId,
          'p_membership_id': membershipId,
          'p_status': status,
          if (exitedAt != null) 'p_exited_at': _dateOnly(exitedAt),
        },
      );
      return GroupMember.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<void> assignRole({
    required String groupId,
    required String membershipId,
    required String roleCode,
  }) async {
    try {
      await _client.rpc(
        'rpc_assign_group_role',
        params: {
          'p_group_id': groupId,
          'p_membership_id': membershipId,
          'p_role_code': roleCode,
        },
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<void> removeRole({
    required String groupId,
    required String membershipId,
    required String roleCode,
  }) async {
    try {
      await _client.rpc(
        'rpc_remove_group_role',
        params: {
          'p_group_id': groupId,
          'p_membership_id': membershipId,
          'p_role_code': roleCode,
        },
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }
}

String _dateOnly(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Maps a backend failure to a safe, user-presentable [MemberFailure].
/// Technical details are logged, never shown to the user. Classifies
/// by the stable message/errcode contract the RPCs raise (see
/// docs/database/authorization.md and docs/product/members.md):
/// ACCOUNT_DISABLED / LAST_ADMIN_REQUIRED / EXITED_MEMBERSHIP_IS_TERMINAL
/// as distinct raised messages, plus standard SQLSTATEs (42501
/// permission denied, 22023 not found/invalid input, 23505 duplicate).
MemberFailure _mapError(Object error, StackTrace stackTrace) {
  if (error is PostgrestException) {
    _log.warning('Member RPC error (code=${error.code})', error, stackTrace);

    final message = error.message;
    final code = error.code;

    if (message.contains('ACCOUNT_DISABLED')) {
      return const MemberFailure(
        MemberFailureType.accountDisabled,
        'Your account access has been disabled. Contact your group administrator.',
      );
    }

    if (message.contains('LAST_ADMIN_REQUIRED')) {
      return const MemberFailure(
        MemberFailureType.lastAdminRequired,
        'Kikundi lazima kibaki na angalau msimamizi mmoja aliye active.',
      );
    }

    if (message.contains('EXITED_MEMBERSHIP_IS_TERMINAL')) {
      return const MemberFailure(
        MemberFailureType.invalidStatusTransition,
        'This member has already exited and cannot be reactivated this way.',
      );
    }

    if (code == '23505' || message.contains('member_number already exists')) {
      return const MemberFailure(
        MemberFailureType.duplicateMemberNumber,
        'That member number is already used in this group.',
      );
    }

    if (message.contains('not found')) {
      return const MemberFailure(
        MemberFailureType.notFound,
        'Member not found.',
      );
    }

    if (code == '42501') {
      return const MemberFailure(
        MemberFailureType.permissionDenied,
        'You do not have permission to do that.',
      );
    }

    return const MemberFailure(
      MemberFailureType.unexpected,
      'Something went wrong. Please try again.',
    );
  }

  _log.severe('Unexpected member repository error', error, stackTrace);

  final text = error.toString().toLowerCase();
  final looksLikeNetworkError =
      text.contains('socket') ||
      text.contains('network') ||
      text.contains('connection') ||
      text.contains('failed host lookup') ||
      text.contains('timeout');

  if (looksLikeNetworkError) {
    return const MemberFailure(
      MemberFailureType.network,
      'Network error. Check your connection and try again.',
    );
  }

  return const MemberFailure(
    MemberFailureType.unexpected,
    'Something went wrong. Please try again.',
  );
}
