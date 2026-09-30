import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../auth/providers/app_context_provider.dart';
import '../../auth/providers/profile_repository_provider.dart';
import 'my_member_profile_provider.dart';

final _log = Logger('EditMemberProfileController');

/// Purely local validation, or a save failure — never a raw backend
/// message. Localize via `l10n.fullNameRequiredError`/`profileSaveError`.
enum EditMemberProfileError { nameRequired, saveFailed }

class EditMemberProfileState {
  const EditMemberProfileState({this.isSubmitting = false, this.error});

  final bool isSubmitting;
  final EditMemberProfileError? error;
}

/// Drives My Profile's "Edit Profile" action — only ever writes
/// `profiles.full_name` via the same safe, self-service
/// [ProfileRepository] the onboarding flow already uses (Prompt
/// 09G-B2 §E: reuse the existing mechanism, never a second
/// profile-update architecture). Never touches membership/roster
/// fields — those remain officer-maintained.
class EditMemberProfileController extends Notifier<EditMemberProfileState> {
  @override
  EditMemberProfileState build() => const EditMemberProfileState();

  Future<bool> saveFullName(String fullName) async {
    if (state.isSubmitting) return false;

    final trimmed = fullName.trim();
    if (trimmed.isEmpty) {
      state = const EditMemberProfileState(
        error: EditMemberProfileError.nameRequired,
      );
      return false;
    }

    state = const EditMemberProfileState(isSubmitting: true);
    try {
      await ref.read(profileRepositoryProvider).updateFullName(trimmed);
      // Refresh the authoritative AppContext/profile state so Home,
      // top-bar/account surfaces, and My Profile all reflect the new
      // value — never a manually constructed replacement.
      ref.invalidate(appContextProvider);
      ref.invalidate(myMemberProfileProvider);
      state = const EditMemberProfileState();
      return true;
    } catch (error, stackTrace) {
      _log.warning('Failed to save profile', error, stackTrace);
      state = const EditMemberProfileState(
        error: EditMemberProfileError.saveFailed,
      );
      return false;
    }
  }
}

final editMemberProfileControllerProvider =
    NotifierProvider<EditMemberProfileController, EditMemberProfileState>(
      EditMemberProfileController.new,
    );
