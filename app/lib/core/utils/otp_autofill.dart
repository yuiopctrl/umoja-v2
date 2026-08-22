import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_auth/smart_auth.dart';

/// SMS OTP autofill for `OtpVerifyScreen`/`PinRecoveryVerifyScreen` —
/// never the 4-digit login/setup PIN, which is never eligible for OS
/// autofill of any kind.
///
/// Races two Android mechanisms (via the `smart_auth` package) and
/// takes whichever resolves first:
///
/// - **SMS Retriever API** — fully automatic, no dialog, no
///   permission. The catch: Play services will only ever deliver a
///   message to it if the SMS body ends with this app's 11-character
///   signature hash. **The production NextSMS message does not
///   contain that hash yet** (a deliberate, separate, gated decision —
///   see docs/product/authentication.md, "OTP SMS autofill" /
///   "SMS Retriever API migration") — so today this side of the race
///   never actually wins; it is included now purely so that the
///   *moment* the message format is updated with the confirmed release
///   hash, autofill becomes fully automatic (no dialog) with **no
///   further Flutter change needed**.
/// - **SMS User Consent API** — the current, active, working path: a
///   one-tap system dialog for the next SMS received while listening.
///   No `READ_SMS`/`RECEIVE_SMS` permission, no message-format
///   requirement. This is what actually fills the code today.
///
/// Neither needs `READ_SMS`/`RECEIVE_SMS` — `AndroidManifest.xml`
/// declares no SMS permission at all.
///
/// iOS gets autofill for free via [AutofillHints.oneTimeCode] on the
/// code field itself (`UmojaCodeInput.isOneTimeCode`) — a native
/// affordance, no plugin involved. This class is Android-only and a
/// safe no-op everywhere else (`smart_auth` itself only implements the
/// underlying platform channel on Android).
class OtpAutofill {
  /// [retrieverListener]/[userConsentListener] default to the real
  /// `smart_auth`-backed implementations; tests inject fakes here
  /// instead (see `otp_autofill_race_test.dart`) so the *racing* logic
  /// itself — not just a wholesale-overridden [listenForCode] — is
  /// exercised without touching the real plugin.
  OtpAutofill({
    Future<String?> Function()? retrieverListener,
    Future<String?> Function()? userConsentListener,
  }) : _retrieverListener = retrieverListener ?? _defaultRetrieverListener,
       _userConsentListener =
           userConsentListener ?? _defaultUserConsentListener;

  static final SmartAuth _smartAuth = SmartAuth.instance;

  final Future<String?> Function() _retrieverListener;
  final Future<String?> Function() _userConsentListener;

  /// The NextSMS OTP message is always the fixed Swahili text
  /// `"Umoja: Namba yako ya uthibitisho ni <6 digits>. Usimpe mtu
  /// mwingine namba hii."`, optionally followed by a trailing app-hash
  /// suffix once that migration lands — anchoring the matcher on the
  /// exact phrase, with a look-behind so the match itself is only the
  /// digits, means an unrelated SMS arriving during the listening
  /// window is never mistaken for the OTP (never parses arbitrary
  /// messages broadly), and a trailing hash suffix never interferes.
  /// Supabase's phone/SMS OTP is always 6 digits.
  static final RegExp _otpMatcher = RegExp(r'(?<=uthibitisho ni )\d{6}');

  /// Starts listening for the next incoming SMS matching the OTP
  /// format via both mechanisms above, returning the extracted 6-digit
  /// code from whichever resolves first — or `null` if unsupported
  /// (non-Android), the user dismissed the consent dialog, the
  /// listener timed out, or no SMS matched. Never throws; every
  /// failure path is safe to ignore and fall back to manual entry.
  Future<String?> listenForCode() async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;

    final completer = Completer<String?>();
    var pending = 2;

    void onResult(String? code) {
      if (completer.isCompleted) return;
      if (code != null) {
        completer.complete(code);
        return;
      }
      pending--;
      if (pending == 0) completer.complete(null);
    }

    unawaited(_retrieverListener().then(onResult));
    unawaited(_userConsentListener().then(onResult));

    final result = await completer.future;
    // Whichever mechanism "won" (or if neither did), stop the other so
    // it can never pop a dialog late or fire into an already-filled
    // field.
    await cancel();
    return result;
  }

  static Future<String?> _defaultRetrieverListener() async {
    try {
      final result = await _smartAuth.getSmsWithRetrieverApi(
        matcher: _otpMatcher.pattern,
      );
      return result.hasData ? result.requireData.code : null;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _defaultUserConsentListener() async {
    try {
      final result = await _smartAuth.getSmsWithUserConsentApi(
        matcher: _otpMatcher.pattern,
      );
      return result.hasData ? result.requireData.code : null;
    } catch (_) {
      return null;
    }
  }

  /// Cancels both in-flight listeners. Call on successful verify, on
  /// screen dispose, and when leaving the OTP/recovery flow, so a
  /// stale listener never fires into a disposed/replaced screen.
  Future<void> cancel() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _smartAuth.removeSmsRetrieverApiListener();
    } catch (_) {
      // Nothing meaningful to do with a failure to remove a listener
      // that may already be gone (e.g. it already resolved).
    }
    try {
      await _smartAuth.removeUserConsentApiListener();
    } catch (_) {
      // Same as above.
    }
  }
}

/// Riverpod-provided, matching this codebase's convention for every
/// other testable dependency (`authRepositoryProvider` et al.) —
/// `OtpVerifyScreen`/`PinRecoveryVerifyScreen` read this rather than
/// constructing [OtpAutofill] directly, so tests can override it with a
/// fake subclass instead of touching the real `smart_auth` plugin.
final otpAutofillProvider = Provider<OtpAutofill>((ref) => OtpAutofill());
