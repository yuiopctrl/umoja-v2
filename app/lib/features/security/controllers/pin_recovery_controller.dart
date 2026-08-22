import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/tanzania_phone_number.dart';
import '../../auth/data/auth_failure.dart';
import '../../auth/providers/auth_repository_provider.dart';

/// State for the "Umesahau PIN?" recovery flow (prompt 05E §17).
///
/// Deliberately separate from `PhoneAuthState`/`PhoneAuthController`:
/// this never signs the user out and never touches an existing PIN
/// credential until a replacement is actually confirmed. Unlike the
/// pre-05E design, it does hold its own phone number — "Umesahau
/// PIN?" is now reached from the signed-out login screen, so there is
/// no existing session to read a phone from yet; [start] is given the
/// phone explicitly (typically whatever the user already typed on the
/// login screen).
class PinRecoveryState {
  const PinRecoveryState({
    this.phone,
    this.otpSent = false,
    this.isSubmitting = false,
    this.errorType,
    this.resendAvailableAt,
  });

  final TanzaniaPhoneNumber? phone;
  final bool otpSent;
  final bool isSubmitting;

  /// Localize via `authFailureMessage` — never a raw string baked in at
  /// throw time, same convention as `PhoneAuthState`.
  final AuthFailureType? errorType;
  final DateTime? resendAvailableAt;

  bool get canResend =>
      resendAvailableAt == null || DateTime.now().isAfter(resendAvailableAt!);
}

/// Drives the recovery OTP send/verify. Never clears an existing PIN
/// credential itself — the old one stays valid (server-side) until
/// `PinSetupController.submitConfirm` -> `setup-pin` overwrites it at
/// the very end of a *successful* recovery, so cancelling at any point
/// here leaves the existing PIN credential completely intact.
class PinRecoveryController extends Notifier<PinRecoveryState> {
  @override
  PinRecoveryState build() => const PinRecoveryState();

  /// Starts recovery for [rawPhone] — validates it, sends an OTP, and
  /// returns `true` if the caller should navigate to the verify
  /// screen. On an invalid phone, sets an inline error instead
  /// (callers on the login screen show this without navigating away).
  Future<bool> start(String rawPhone) async {
    if (state.isSubmitting) return false;

    final TanzaniaPhoneNumber phone;
    try {
      phone = TanzaniaPhoneNumber.parse(rawPhone);
    } on PhoneNumberException {
      state = const PinRecoveryState(errorType: AuthFailureType.invalidPhone);
      return false;
    }

    state = PinRecoveryState(phone: phone, isSubmitting: true);
    try {
      await ref.read(authRepositoryProvider).sendOtp(phone.e164);
      state = PinRecoveryState(
        phone: phone,
        otpSent: true,
        resendAvailableAt: DateTime.now().add(const Duration(seconds: 60)),
      );
      return true;
    } on AuthFailure catch (error) {
      state = PinRecoveryState(phone: phone, errorType: error.type);
      return false;
    }
  }

  Future<void> resendOtp() async {
    final phone = state.phone;
    if (phone == null || !state.canResend || state.isSubmitting) return;

    state = PinRecoveryState(
      phone: phone,
      isSubmitting: true,
      otpSent: state.otpSent,
    );
    try {
      await ref.read(authRepositoryProvider).sendOtp(phone.e164);
      state = PinRecoveryState(
        phone: phone,
        otpSent: true,
        resendAvailableAt: DateTime.now().add(const Duration(seconds: 60)),
      );
    } on AuthFailure catch (error) {
      state = PinRecoveryState(
        phone: phone,
        otpSent: state.otpSent,
        errorType: error.type,
        resendAvailableAt: state.resendAvailableAt,
      );
    }
  }

  /// Returns `true` if the OTP was verified. On success, this proves
  /// possession of the phone and establishes a fresh Supabase session
  /// for it — the caller navigates on to the new-PIN step; nothing
  /// here mutates the PIN credential.
  Future<bool> verifyOtp(String code) async {
    final phone = state.phone;
    if (phone == null || state.isSubmitting) return false;

    state = PinRecoveryState(
      phone: phone,
      otpSent: true,
      isSubmitting: true,
      resendAvailableAt: state.resendAvailableAt,
    );
    try {
      await ref
          .read(authRepositoryProvider)
          .verifyOtp(e164Phone: phone.e164, otp: code);
      state = PinRecoveryState(
        phone: phone,
        otpSent: true,
        resendAvailableAt: state.resendAvailableAt,
      );
      return true;
    } on AuthFailure catch (error) {
      state = PinRecoveryState(
        phone: phone,
        otpSent: true,
        errorType: error.type,
        resendAvailableAt: state.resendAvailableAt,
      );
      return false;
    }
  }

  /// Resets to a clean slate — called when backing out of recovery, so
  /// a later attempt never resumes stale state from a previous phone
  /// number or a previous cancelled attempt.
  void reset() {
    state = const PinRecoveryState();
  }
}

final pinRecoveryControllerProvider =
    NotifierProvider<PinRecoveryController, PinRecoveryState>(
      PinRecoveryController.new,
    );
