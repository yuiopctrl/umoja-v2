import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../auth/providers/app_context_provider.dart';
import '../../auth/providers/profile_repository_provider.dart';

final _log = Logger('ProfileOnboardingController');

class ProfileOnboardingState {
  const ProfileOnboardingState({this.isSubmitting = false, this.errorMessage});

  final bool isSubmitting;
  final String? errorMessage;
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
        errorMessage: 'Enter your full name.',
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
        errorMessage: 'Could not save your profile. Please try again.',
      );
      return false;
    }
  }
}

final profileOnboardingControllerProvider =
    NotifierProvider<ProfileOnboardingController, ProfileOnboardingState>(
      ProfileOnboardingController.new,
    );
