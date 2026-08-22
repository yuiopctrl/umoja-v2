import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../auth/providers/app_context_provider.dart';
import '../../auth/providers/group_repository_provider.dart';

final _log = Logger('GroupOnboardingController');

/// Purely local validation, or a save failure — never a raw backend
/// message. Localize via `l10n.groupNameRequiredError`/`groupSaveError`.
enum GroupOnboardingError { nameRequired, saveFailed }

class GroupOnboardingState {
  const GroupOnboardingState({this.isSubmitting = false, this.error});

  final bool isSubmitting;
  final GroupOnboardingError? error;
}

/// Drives first-group creation. Always goes through
/// `rpc_create_group()` (via [GroupRepository]) — never a direct
/// insert into groups/group_memberships/group_membership_roles, since
/// only the backend command creates all three atomically.
class GroupOnboardingController extends Notifier<GroupOnboardingState> {
  @override
  GroupOnboardingState build() => const GroupOnboardingState();

  /// Returns `true` on success. On failure, [state.error] is set
  /// and the caller should stay on the onboarding screen — text fields
  /// are owned by the screen, so entered values are naturally preserved.
  Future<bool> createGroup({required String name, String? description}) async {
    if (state.isSubmitting) return false;

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      state = const GroupOnboardingState(
        error: GroupOnboardingError.nameRequired,
      );
      return false;
    }

    state = const GroupOnboardingState(isSubmitting: true);
    try {
      final trimmedDescription = description?.trim();
      await ref
          .read(groupRepositoryProvider)
          .createGroup(
            name: trimmedName,
            description:
                (trimmedDescription == null || trimmedDescription.isEmpty)
                ? null
                : trimmedDescription,
          );

      // Refresh application context so the new group/membership/role
      // shows up and selected-group resolution can pick it up.
      ref.invalidate(appContextProvider);
      state = const GroupOnboardingState();
      return true;
    } catch (error, stackTrace) {
      _log.warning('Failed to create group', error, stackTrace);
      state = const GroupOnboardingState(
        error: GroupOnboardingError.saveFailed,
      );
      return false;
    }
  }
}

final groupOnboardingControllerProvider =
    NotifierProvider<GroupOnboardingController, GroupOnboardingState>(
      GroupOnboardingController.new,
    );
