import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../data/member_failure.dart';
import '../domain/group_member.dart';
import '../providers/member_detail_provider.dart';
import '../providers/member_repository_provider.dart';
import '../providers/members_list_provider.dart';

final _log = Logger('MemberFormController');

class MemberFormState {
  const MemberFormState({this.isSubmitting = false, this.errorType});

  final bool isSubmitting;

  /// `null` means no error. Localize via `memberFailureMessage` (see
  /// `core/localization/failure_messages.dart`).
  final MemberFailureType? errorType;
}

/// Drives both member creation and member editing — they share the
/// same identity/contact fields and validation, and are kept
/// deliberately separate from status/role changes (see
/// [MemberStatusController]/[MemberRoleController]) by only ever
/// calling `rpc_create_group_member`/`rpc_update_group_member`, neither
/// of which accepts a status or role parameter.
class MemberFormController extends Notifier<MemberFormState> {
  @override
  MemberFormState build() => const MemberFormState();

  /// Returns the created member (its server-generated `memberNumber`
  /// included) so the caller can navigate to its detail page.
  Future<GroupMember?> createMember({
    required String groupId,
    required String displayName,
    String? phone,
  }) async {
    if (state.isSubmitting) return null;

    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty) {
      state = const MemberFormState(errorType: MemberFailureType.nameRequired);
      return null;
    }

    state = const MemberFormState(isSubmitting: true);
    try {
      final member = await ref
          .read(memberRepositoryProvider)
          .createMember(
            groupId: groupId,
            displayName: trimmedName,
            phone: _normalizeOptional(phone),
          );
      ref.invalidate(membersListProvider);
      state = const MemberFormState();
      return member;
    } on MemberFailure catch (error) {
      state = MemberFormState(errorType: error.type);
      return null;
    } catch (error, stackTrace) {
      _log.warning('Failed to create member', error, stackTrace);
      state = const MemberFormState(errorType: MemberFailureType.unexpected);
      return null;
    }
  }

  /// Returns `true` on success. The updated member is deliberately not
  /// returned (see [MemberRepository.updateMember]) — the caller just
  /// pops back to the (now-invalidated) detail screen.
  Future<bool> updateMember({
    required String groupId,
    required String membershipId,
    required String displayName,
    String? phone,
  }) async {
    if (state.isSubmitting) return false;

    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty) {
      state = const MemberFormState(errorType: MemberFailureType.nameRequired);
      return false;
    }

    state = const MemberFormState(isSubmitting: true);
    try {
      await ref
          .read(memberRepositoryProvider)
          .updateMember(
            groupId: groupId,
            membershipId: membershipId,
            displayName: trimmedName,
            phone: _normalizeOptional(phone),
          );
      ref.invalidate(membersListProvider);
      ref.invalidate(memberDetailProvider(membershipId));
      state = const MemberFormState();
      return true;
    } on MemberFailure catch (error) {
      state = MemberFormState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to update member', error, stackTrace);
      state = const MemberFormState(errorType: MemberFailureType.unexpected);
      return false;
    }
  }
}

String? _normalizeOptional(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

final memberFormControllerProvider =
    NotifierProvider<MemberFormController, MemberFormState>(
      MemberFormController.new,
    );
