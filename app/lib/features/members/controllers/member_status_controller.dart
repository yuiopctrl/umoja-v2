import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../data/member_failure.dart';
import '../providers/member_detail_provider.dart';
import '../providers/member_repository_provider.dart';
import '../providers/members_list_provider.dart';

final _log = Logger('MemberStatusController');

class MemberStatusState {
  const MemberStatusState({this.isSubmitting = false, this.errorMessage});

  final bool isSubmitting;
  final String? errorMessage;
}

/// Drives lifecycle status changes only (`rpc_change_group_member_status`)
/// — deliberately separate from [MemberFormController], so status can
/// never be changed as a side effect of an identity/contact edit.
/// Surfaces LAST_ADMIN_REQUIRED / EXITED_MEMBERSHIP_IS_TERMINAL as the
/// friendly messages [MemberFailure] already maps them to; the backend
/// remains authoritative regardless of what the UI offers.
class MemberStatusController extends Notifier<MemberStatusState> {
  @override
  MemberStatusState build() => const MemberStatusState();

  Future<bool> changeStatus({
    required String groupId,
    required String membershipId,
    required String status,
  }) async {
    if (state.isSubmitting) return false;

    state = const MemberStatusState(isSubmitting: true);
    try {
      await ref
          .read(memberRepositoryProvider)
          .changeStatus(
            groupId: groupId,
            membershipId: membershipId,
            status: status,
          );
      ref.invalidate(membersListProvider);
      ref.invalidate(memberDetailProvider(membershipId));
      state = const MemberStatusState();
      return true;
    } on MemberFailure catch (error) {
      state = MemberStatusState(errorMessage: error.message);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to change member status', error, stackTrace);
      state = const MemberStatusState(
        errorMessage: 'Could not update the member status. Please try again.',
      );
      return false;
    }
  }
}

final memberStatusControllerProvider =
    NotifierProvider<MemberStatusController, MemberStatusState>(
      MemberStatusController.new,
    );
