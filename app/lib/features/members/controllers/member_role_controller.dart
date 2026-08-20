import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../data/member_failure.dart';
import '../providers/member_detail_provider.dart';
import '../providers/member_repository_provider.dart';

final _log = Logger('MemberRoleController');

class MemberRoleState {
  const MemberRoleState({this.isSubmitting = false, this.errorMessage});

  final bool isSubmitting;
  final String? errorMessage;
}

/// Drives role assignment/removal (`rpc_assign_group_role`/
/// `rpc_remove_group_role`) — the backend remains authoritative for
/// the ADMIN-role and last-active-ADMIN protections; this controller
/// only surfaces the resulting [MemberFailure] (e.g. LAST_ADMIN_REQUIRED)
/// as a friendly message, it does not itself decide what is allowed.
class MemberRoleController extends Notifier<MemberRoleState> {
  @override
  MemberRoleState build() => const MemberRoleState();

  Future<bool> assignRole({
    required String groupId,
    required String membershipId,
    required String roleCode,
  }) async {
    if (state.isSubmitting) return false;

    state = const MemberRoleState(isSubmitting: true);
    try {
      await ref
          .read(memberRepositoryProvider)
          .assignRole(
            groupId: groupId,
            membershipId: membershipId,
            roleCode: roleCode,
          );
      ref.invalidate(memberDetailProvider(membershipId));
      state = const MemberRoleState();
      return true;
    } on MemberFailure catch (error) {
      state = MemberRoleState(errorMessage: error.message);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to assign role', error, stackTrace);
      state = const MemberRoleState(
        errorMessage: 'Could not assign the role. Please try again.',
      );
      return false;
    }
  }

  Future<bool> removeRole({
    required String groupId,
    required String membershipId,
    required String roleCode,
  }) async {
    if (state.isSubmitting) return false;

    state = const MemberRoleState(isSubmitting: true);
    try {
      await ref
          .read(memberRepositoryProvider)
          .removeRole(
            groupId: groupId,
            membershipId: membershipId,
            roleCode: roleCode,
          );
      ref.invalidate(memberDetailProvider(membershipId));
      state = const MemberRoleState();
      return true;
    } on MemberFailure catch (error) {
      state = MemberRoleState(errorMessage: error.message);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to remove role', error, stackTrace);
      state = const MemberRoleState(
        errorMessage: 'Could not remove the role. Please try again.',
      );
      return false;
    }
  }
}

final memberRoleControllerProvider =
    NotifierProvider<MemberRoleController, MemberRoleState>(
      MemberRoleController.new,
    );
