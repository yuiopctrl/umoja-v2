import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../data/member_failure.dart';
import '../providers/member_detail_provider.dart';
import '../providers/member_repository_provider.dart';
import '../providers/members_list_provider.dart';

final _log = Logger('MemberStatusController');

class MemberStatusState {
  const MemberStatusState({this.isSubmitting = false, this.errorType});

  final bool isSubmitting;

  /// `null` means no error. Localize via `memberFailureMessage` (see
  /// `core/localization/failure_messages.dart`).
  final MemberFailureType? errorType;
}

/// Drives lifecycle status changes (`rpc_change_group_member_status`)
/// and the explicit rejoin workflow (`rpc_rejoin_group_member`) —
/// deliberately separate from [MemberFormController], so status can
/// never be changed as a side effect of an identity/contact edit.
/// Surfaces LAST_ADMIN_REQUIRED / EXITED_MEMBERSHIP_IS_TERMINAL /
/// MEMBERSHIP_NOT_EXITED / USER_ALREADY_HAS_ACTIVE_MEMBERSHIP as the
/// friendly messages [MemberFailure] already maps them to; the backend
/// remains authoritative regardless of what the UI offers.
///
/// The mutation call and the post-success provider refresh are
/// deliberately separate steps: a successful backend change is always
/// reported as success even if the *subsequent* refresh has trouble,
/// since a background refresh issue is not the same failure as the
/// mutation itself (a previous bug here reported "Something went
/// wrong" for a status change that had, in fact, already succeeded —
/// see `member_status_controller_test.dart`).
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
    } on MemberFailure catch (error) {
      state = MemberStatusState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to change member status', error, stackTrace);
      state = const MemberStatusState(errorType: MemberFailureType.unexpected);
      return false;
    }

    // Mutation succeeded. Refresh is best-effort from here — this
    // never turns a successful mutation into a reported failure.
    state = const MemberStatusState();
    ref.invalidate(membersListProvider);
    ref.invalidate(memberDetailProvider(membershipId));
    return true;
  }

  /// The explicit rejoin workflow for an EXITED member — see
  /// `rpc_rejoin_group_member` / docs/product/members.md. Never routes
  /// through [changeStatus], which the backend rejects for a terminal
  /// EXITED membership by design.
  Future<bool> rejoin({
    required String groupId,
    required String membershipId,
  }) async {
    if (state.isSubmitting) return false;

    state = const MemberStatusState(isSubmitting: true);
    try {
      await ref
          .read(memberRepositoryProvider)
          .rejoinMember(groupId: groupId, membershipId: membershipId);
    } on MemberFailure catch (error) {
      state = MemberStatusState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to rejoin member', error, stackTrace);
      state = const MemberStatusState(errorType: MemberFailureType.unexpected);
      return false;
    }

    state = const MemberStatusState();
    ref.invalidate(membersListProvider);
    ref.invalidate(memberDetailProvider(membershipId));
    return true;
  }
}

final memberStatusControllerProvider =
    NotifierProvider<MemberStatusController, MemberStatusState>(
      MemberStatusController.new,
    );
