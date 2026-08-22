import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_session_provider.dart';
import '../providers/lock_state_provider.dart';
import '../providers/pin_repository_provider.dart';

/// After this many consecutive wrong attempts, impose a short local
/// cooldown — a soft, in-memory-only rate limit (never a permanent
/// lockout; nothing here can lock a user out of their own account,
/// since the PIN is device-unlock UX, not backend authentication).
const _maxAttemptsBeforeCooldown = 5;
const _cooldownDuration = Duration(seconds: 30);

class PinUnlockState {
  const PinUnlockState({
    this.isSubmitting = false,
    this.invalid = false,
    this.failedAttempts = 0,
    this.cooldownUntil,
  });

  final bool isSubmitting;
  final bool invalid;
  final int failedAttempts;
  final DateTime? cooldownUntil;

  bool get isRateLimited =>
      cooldownUntil != null && DateTime.now().isBefore(cooldownUntil!);
}

/// Drives PIN entry to unlock the app over an already-authenticated
/// Supabase session. Never calls Supabase — this only compares against
/// the locally-stored salted hash and, on success, flips
/// [lockStateProvider] to unlocked.
class PinUnlockController extends Notifier<PinUnlockState> {
  @override
  PinUnlockState build() => const PinUnlockState();

  Future<bool> verify(String pin) async {
    if (state.isSubmitting || state.isRateLimited) return false;

    final userId = ref.read(authUserIdProvider);
    if (userId == null) return false;

    state = PinUnlockState(
      isSubmitting: true,
      failedAttempts: state.failedAttempts,
      cooldownUntil: state.cooldownUntil,
    );

    final ok = await ref
        .read(pinRepositoryProvider)
        .verifyPin(userId: userId, pin: pin);

    if (ok) {
      state = const PinUnlockState();
      ref.read(lockStateProvider.notifier).unlock();
      return true;
    }

    final attempts = state.failedAttempts + 1;
    state = PinUnlockState(
      invalid: true,
      failedAttempts: attempts,
      cooldownUntil: attempts >= _maxAttemptsBeforeCooldown
          ? DateTime.now().add(_cooldownDuration)
          : null,
    );
    return false;
  }
}

final pinUnlockControllerProvider =
    NotifierProvider<PinUnlockController, PinUnlockState>(
      PinUnlockController.new,
    );
