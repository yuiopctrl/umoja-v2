import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/tanzania_phone_number.dart';
import '../data/auth_failure.dart';
import '../providers/auth_repository_provider.dart';

/// State for the normal returning-login screen (`/auth/phone`, prompt
/// 05E §11): phone + 4-digit PIN, server-verified, no OTP.
class PinLoginState {
  const PinLoginState({this.isSubmitting = false, this.errorType});

  final bool isSubmitting;

  /// `null` means no error. Localize via `authFailureMessage`. Prompt
  /// 05E §19/§22: an actual login failure always surfaces as
  /// [AuthFailureType.invalidCredentials] or [AuthFailureType.pinLocked]
  /// — never a distinction between "wrong PIN" and "unknown phone".
  final AuthFailureType? errorType;
}

/// Drives phone + PIN login. Depends only on [AuthRepository], never
/// the Supabase SDK directly, so it is testable with a fake — same
/// pattern as [PhoneAuthController].
class PinLoginController extends Notifier<PinLoginState> {
  @override
  PinLoginState build() => const PinLoginState();

  /// Returns `true` if login succeeded — the auth-state stream flips
  /// to signed-in (a live `AuthChangeEvent.signedIn`, since
  /// `pin-login` hands back a session Flutter installs via
  /// `setSession(refreshToken, accessToken: ...)` — see
  /// `SupabaseAuthRepository.pinLogin`) and the router takes over from
  /// there on its own; this only reports success/failure for UI
  /// purposes (e.g. clearing the PIN field on failure).
  Future<bool> submit({required String rawPhone, required String pin}) async {
    if (state.isSubmitting) return false;

    final TanzaniaPhoneNumber phone;
    try {
      phone = TanzaniaPhoneNumber.parse(rawPhone);
    } on PhoneNumberException {
      state = const PinLoginState(errorType: AuthFailureType.invalidPhone);
      return false;
    }

    state = const PinLoginState(isSubmitting: true);
    try {
      await ref
          .read(authRepositoryProvider)
          .pinLogin(e164Phone: phone.e164, pin: pin);
      state = const PinLoginState();
      return true;
    } on AuthFailure catch (error) {
      state = PinLoginState(errorType: error.type);
      return false;
    }
  }
}

final pinLoginControllerProvider =
    NotifierProvider<PinLoginController, PinLoginState>(PinLoginController.new);
