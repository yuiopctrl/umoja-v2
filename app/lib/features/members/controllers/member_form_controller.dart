import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../data/member_failure.dart';
import '../domain/group_member.dart';
import '../providers/member_detail_provider.dart';
import '../providers/member_repository_provider.dart';
import '../providers/members_list_provider.dart';

final _log = Logger('MemberFormController');

class MemberFormState {
  const MemberFormState({this.isSubmitting = false, this.errorMessage});

  final bool isSubmitting;
  final String? errorMessage;
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

  Future<GroupMember?> createMember({
    required String groupId,
    required String displayName,
    String? phone,
    String? memberNumber,
  }) async {
    if (state.isSubmitting) return null;

    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty) {
      state = const MemberFormState(errorMessage: 'Full name is required.');
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
            memberNumber: _normalizeOptional(memberNumber),
          );
      ref.invalidate(membersListProvider);
      state = const MemberFormState();
      return member;
    } on MemberFailure catch (error) {
      state = MemberFormState(errorMessage: error.message);
      return null;
    } catch (error, stackTrace) {
      _log.warning('Failed to create member', error, stackTrace);
      state = const MemberFormState(
        errorMessage: 'Could not save the member. Please try again.',
      );
      return null;
    }
  }

  Future<GroupMember?> updateMember({
    required String groupId,
    required String membershipId,
    required String displayName,
    String? phone,
    String? memberNumber,
  }) async {
    if (state.isSubmitting) return null;

    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty) {
      state = const MemberFormState(errorMessage: 'Full name is required.');
      return null;
    }

    state = const MemberFormState(isSubmitting: true);
    try {
      final member = await ref
          .read(memberRepositoryProvider)
          .updateMember(
            groupId: groupId,
            membershipId: membershipId,
            displayName: trimmedName,
            phone: _normalizeOptional(phone),
            memberNumber: _normalizeOptional(memberNumber),
          );
      ref.invalidate(membersListProvider);
      ref.invalidate(memberDetailProvider(membershipId));
      state = const MemberFormState();
      return member;
    } on MemberFailure catch (error) {
      state = MemberFormState(errorMessage: error.message);
      return null;
    } catch (error, stackTrace) {
      _log.warning('Failed to update member', error, stackTrace);
      state = const MemberFormState(
        errorMessage: 'Could not save the member. Please try again.',
      );
      return null;
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
