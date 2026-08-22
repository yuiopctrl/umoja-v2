import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_failure.dart';
import '../../auth/providers/auth_repository_provider.dart';
import '../../auth/providers/auth_session_provider.dart';

/// State for the "Umesahau PIN?" recovery flow (prompt 05C §18-21).
///
/// Deliberately separate from `PhoneAuthState`/`PhoneAuthController`:
/// this never re-enters a phone number (it's already known from the
/// authenticated session) and never signs the user out — it only
/// re-verifies an OTP for the phone already on the account, so a
/// forgotten PIN can be replaced without touching the Supabase session
/// at all.
class PinRecoveryState {
  const PinRecoveryState({
    this.otpSent = false,
    this.isSubmitting = false,
    this.errorType,
    this.resendAvailableAt,
  });

  final bool otpSent;
  final bool isSubmitting;

  /// Localize via `authFailureMessage` — never a raw string baked in at
  /// throw time, same convention as `PhoneAuthState`.
  final AuthFailureType? errorType;
  final DateTime? resendAvailableAt;

  bool get canResend =>
      resendAvailableAt == null || DateTime.now().isAfter(resendAvailableAt!);
}

/// Drives the recovery OTP send/verify. Never calls `signOut()` and
/// never touches this device's stored PIN — the old PIN hash stays
/// valid until `PinSetupController.submitConfirm` overwrites it at the
/// very end of a *successful* recovery (see `pin_setup_controller.dart`
/// — it calls `setPin`, never `clearPin` first), so cancelling at any
/// point here leaves the existing PIN and session completely intact.
class PinRecoveryController extends Notifier<PinRecoveryState> {
  @override
  PinRecoveryState build() => const PinRecoveryState();

  /// The authenticated identity's own phone, normalized to E.164 with a
  /// leading `+` (Supabase's `User.phone` does not include one). `null`
  /// only if reached with no valid session, which should not happen
  /// given this route is only reachable while already signed in.
  String? get phone {
    final raw = ref.read(currentSupabaseUserProvider)?.phone;
    if (raw == null || raw.isEmpty) return null;
    return raw.startsWith('+') ? raw : '+$raw';
  }

  Future<void> sendOtp() async {
    final phone = this.phone;
    if (phone == null || state.isSubmitting) return;

    state = PinRecoveryState(isSubmitting: true, otpSent: state.otpSent);
    try {
      await ref.read(authRepositoryProvider).sendOtp(phone);
      state = PinRecoveryState(
        otpSent: true,
        resendAvailableAt: DateTime.now().add(const Duration(seconds: 60)),
      );
    } on AuthFailure catch (error) {
      state = PinRecoveryState(otpSent: state.otpSent, errorType: error.type);
    }
  }

  Future<void> resendOtp() async {
    if (!state.canResend || state.isSubmitting) return;
    await sendOtp();
  }

  /// Returns `true` if the OTP was verified. On success, this proves
  /// possession of the account's phone again — the caller navigates on
  /// to the new-PIN step; nothing here mutates the PIN or session.
  Future<bool> verifyOtp(String code) async {
    final phone = this.phone;
    if (phone == null || state.isSubmitting) return false;

    state = PinRecoveryState(
      otpSent: true,
      isSubmitting: true,
      resendAvailableAt: state.resendAvailableAt,
    );
    try {
      await ref
          .read(authRepositoryProvider)
          .verifyOtp(e164Phone: phone, otp: code);
      state = PinRecoveryState(
        otpSent: true,
        resendAvailableAt: state.resendAvailableAt,
      );
      return true;
    } on AuthFailure catch (error) {
      state = PinRecoveryState(
        otpSent: true,
        errorType: error.type,
        resendAvailableAt: state.resendAvailableAt,
      );
      return false;
    }
  }
}

final pinRecoveryControllerProvider =
    NotifierProvider<PinRecoveryController, PinRecoveryState>(
      PinRecoveryController.new,
    );
