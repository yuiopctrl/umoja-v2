import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../auth/data/auth_failure.dart';
import '../../auth/providers/auth_repository_provider.dart';
import '../providers/has_pin_credential_provider.dart';

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

/// Drives first-time PIN creation: enter 4 digits, confirm them, then
/// hand the raw PIN to [AuthRepository.setupPin] — which sends it to
/// the `setup-pin` Edge Function over TLS and never stores or derives
/// anything client-side (prompt 05E). Nothing here unlocks a local
/// device lock — there is no such concept any more; the PIN credential
/// this creates is itself immediately authoritative server-side, so the
/// user continues straight into onboarding/home once
/// [hasPinCredentialProvider] is invalidated and refetches `true`.
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

    state = PinSetupState(
      step: state.step,
      firstPin: state.firstPin,
      isSubmitting: true,
    );
    try {
      await ref.read(authRepositoryProvider).setupPin(pin);
      ref.invalidate(hasPinCredentialProvider);
      state = const PinSetupState();
      return true;
    } on AuthFailure catch (error, stackTrace) {
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
