import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/tanzania_phone_number.dart';
import '../data/auth_failure.dart';
import '../providers/auth_repository_provider.dart';

enum PhoneAuthStep { enteringPhone, awaitingCode }

/// State for the two-screen phone-OTP flow (`/auth/phone` ->
/// `/auth/verify`). One controller backs both screens since they are a
/// single sequential flow, not two independent features.
class PhoneAuthState {
  const PhoneAuthState({
    this.step = PhoneAuthStep.enteringPhone,
    this.phone,
    this.isSubmitting = false,
    this.errorMessage,
    this.resendAvailableAt,
  });

  final PhoneAuthStep step;
  final TanzaniaPhoneNumber? phone;
  final bool isSubmitting;
  final String? errorMessage;

  /// When resend becomes available again. `null` means resend is
  /// available now. This is a client-side UX cooldown only — Supabase/
  /// the SMS provider's own rate limiting remains authoritative.
  final DateTime? resendAvailableAt;

  bool get canResend =>
      resendAvailableAt == null || DateTime.now().isAfter(resendAvailableAt!);
}

/// Drives phone-entry -> send OTP -> verify OTP. Depends only on
/// [AuthRepository] (via [authRepositoryProvider]), never the Supabase
/// SDK directly, so it is testable with a fake.
class PhoneAuthController extends Notifier<PhoneAuthState> {
  @override
  PhoneAuthState build() => const PhoneAuthState();

  /// Returns `true` if the OTP was sent successfully.
  Future<bool> submitPhone(String rawPhone) async {
    if (state.isSubmitting) return false;

    final TanzaniaPhoneNumber phone;
    try {
      phone = TanzaniaPhoneNumber.parse(rawPhone);
    } on PhoneNumberException catch (error) {
      state = PhoneAuthState(errorMessage: error.message);
      return false;
    }

    state = PhoneAuthState(phone: phone, isSubmitting: true);
    try {
      await ref.read(authRepositoryProvider).sendOtp(phone.e164);
      state = PhoneAuthState(
        step: PhoneAuthStep.awaitingCode,
        phone: phone,
        resendAvailableAt: DateTime.now().add(const Duration(seconds: 60)),
      );
      return true;
    } on AuthFailure catch (error) {
      state = PhoneAuthState(phone: phone, errorMessage: error.message);
      return false;
    }
  }

  Future<void> resendOtp() async {
    final phone = state.phone;
    if (phone == null || !state.canResend || state.isSubmitting) return;

    state = PhoneAuthState(
      step: state.step,
      phone: phone,
      isSubmitting: true,
      resendAvailableAt: state.resendAvailableAt,
    );
    try {
      await ref.read(authRepositoryProvider).sendOtp(phone.e164);
      state = PhoneAuthState(
        step: state.step,
        phone: phone,
        resendAvailableAt: DateTime.now().add(const Duration(seconds: 60)),
      );
    } on AuthFailure catch (error) {
      state = PhoneAuthState(
        step: state.step,
        phone: phone,
        errorMessage: error.message,
        resendAvailableAt: state.resendAvailableAt,
      );
    }
  }

  /// Returns `true` if the OTP was verified successfully. On success,
  /// the Supabase auth-state stream flips to signed-in and the router
  /// takes over — this only reports success/failure for UI purposes.
  Future<bool> verifyOtp(String code) async {
    final phone = state.phone;
    if (phone == null || state.isSubmitting) return false;

    state = PhoneAuthState(
      step: state.step,
      phone: phone,
      isSubmitting: true,
      resendAvailableAt: state.resendAvailableAt,
    );
    try {
      await ref
          .read(authRepositoryProvider)
          .verifyOtp(e164Phone: phone.e164, otp: code);
      state = PhoneAuthState(
        step: state.step,
        phone: phone,
        resendAvailableAt: state.resendAvailableAt,
      );
      return true;
    } on AuthFailure catch (error) {
      state = PhoneAuthState(
        step: state.step,
        phone: phone,
        errorMessage: error.message,
        resendAvailableAt: state.resendAvailableAt,
      );
      return false;
    }
  }

  /// Returns to the phone-entry step, discarding any in-progress OTP
  /// state ("Change Number").
  void changeNumber() {
    state = const PhoneAuthState();
  }
}

final phoneAuthControllerProvider =
    NotifierProvider<PhoneAuthController, PhoneAuthState>(
      PhoneAuthController.new,
    );
