import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../auth/providers/app_context_provider.dart';
import '../../auth/providers/profile_repository_provider.dart';

final _log = Logger('ProfileOnboardingController');

/// Purely local validation, or a save failure — never a raw backend
/// message. Localize via `l10n.fullNameRequiredError`/`profileSaveError`.
enum ProfileOnboardingError { nameRequired, saveFailed }

class ProfileOnboardingState {
  const ProfileOnboardingState({this.isSubmitting = false, this.error});

  final bool isSubmitting;
  final ProfileOnboardingError? error;
}

/// Drives initial profile completion (full_name only — see
/// docs/product/authentication.md). Only ever writes the safe,
/// self-service columns via [ProfileRepository]; never
/// id/is_active/email/created_at.
class ProfileOnboardingController extends Notifier<ProfileOnboardingState> {
  @override
  ProfileOnboardingState build() => const ProfileOnboardingState();

  Future<bool> saveFullName(String fullName) async {
    if (state.isSubmitting) return false;

    final trimmed = fullName.trim();
    if (trimmed.isEmpty) {
      state = const ProfileOnboardingState(
        error: ProfileOnboardingError.nameRequired,
      );
      return false;
    }

    state = const ProfileOnboardingState(isSubmitting: true);
    try {
      await ref.read(profileRepositoryProvider).updateFullName(trimmed);
      ref.invalidate(appContextProvider);
      state = const ProfileOnboardingState();
      return true;
    } catch (error, stackTrace) {
      _log.warning('Failed to save profile', error, stackTrace);
      state = const ProfileOnboardingState(
        error: ProfileOnboardingError.saveFailed,
      );
      return false;
    }
  }
}

final profileOnboardingControllerProvider =
    NotifierProvider<ProfileOnboardingController, ProfileOnboardingState>(
      ProfileOnboardingController.new,
    );
