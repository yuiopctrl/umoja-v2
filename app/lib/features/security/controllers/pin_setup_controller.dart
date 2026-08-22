import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../auth/providers/auth_session_provider.dart';
import '../providers/has_pin_configured_provider.dart';
import '../providers/lock_state_provider.dart';
import '../providers/pin_repository_provider.dart';

final _log = Logger('PinSetupController');

enum PinSetupStep { enterPin, confirmPin }

class PinSetupState {
  const PinSetupState({
    this.step = PinSetupStep.enterPin,
    this.firstPin,
    this.isSubmitting = false,
    this.mismatch = false,
    this.saveError = false,
  });

  final PinSetupStep step;
  final String? firstPin;
  final bool isSubmitting;
  final bool mismatch;
  final bool saveError;
}

/// Drives first-time PIN creation: enter 4 digits, confirm them, store
/// a salted hash for the current authenticated user (never plaintext,
/// never in `SharedPreferences` — see [PinRepository]). Unlocks
/// immediately on success (see [LockNotifier.unlock] doc) so the user
/// continues straight into onboarding/home without re-entering the PIN
/// they just created.
class PinSetupController extends Notifier<PinSetupState> {
  @override
  PinSetupState build() => const PinSetupState();

  /// First entry — advances to the confirmation step.
  void submitFirst(String pin) {
    if (state.isSubmitting) return;
    state = PinSetupState(step: PinSetupStep.confirmPin, firstPin: pin);
  }

  /// Confirmation entry. On mismatch, restarts from the first step
  /// (never partially retains the mismatched attempt).
  Future<bool> submitConfirm(String pin) async {
    if (state.isSubmitting) return false;

    if (pin != state.firstPin) {
      state = const PinSetupState(mismatch: true);
      return false;
    }

    final userId = ref.read(authUserIdProvider);
    if (userId == null) return false;

    state = PinSetupState(
      step: state.step,
      firstPin: state.firstPin,
      isSubmitting: true,
    );
    try {
      await ref.read(pinRepositoryProvider).setPin(userId: userId, pin: pin);
      ref.invalidate(hasPinConfiguredProvider);
      ref.read(lockStateProvider.notifier).unlock();
      state = const PinSetupState();
      return true;
    } catch (error, stackTrace) {
      _log.warning('Failed to save PIN', error, stackTrace);
      state = PinSetupState(
        step: state.step,
        firstPin: state.firstPin,
        saveError: true,
      );
      return false;
    }
  }
}

final pinSetupControllerProvider =
    NotifierProvider<PinSetupController, PinSetupState>(PinSetupController.new);
