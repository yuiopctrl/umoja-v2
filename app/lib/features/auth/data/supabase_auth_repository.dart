import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_failure.dart';
import 'auth_repository.dart';

final _log = Logger('SupabaseAuthRepository');

/// [AuthRepository] backed by Supabase Auth's phone-OTP (SMS) flow for
/// first-time/recovery verification, and the `setup-pin`/`pin-login`
/// Edge Functions (prompt 05E) for PIN creation and normal returning
/// login.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> sendOtp(String e164Phone) async {
    try {
      await _client.auth.signInWithOtp(phone: e164Phone);
    } on AuthException catch (error, stackTrace) {
      throw _mapAuthException(error, stackTrace);
    } catch (error, stackTrace) {
      throw _mapUnknownException(error, stackTrace);
    }
  }

  @override
  Future<void> verifyOtp({
    required String e164Phone,
    required String otp,
  }) async {
    try {
      await _client.auth.verifyOTP(
        phone: e164Phone,
        token: otp,
        type: OtpType.sms,
      );
    } on AuthException catch (error, stackTrace) {
      throw _mapAuthException(error, stackTrace);
    } catch (error, stackTrace) {
      throw _mapUnknownException(error, stackTrace);
    }
  }

  @override
  Future<void> setupPin(String pin) async {
    try {
      await _client.functions.invoke('setup-pin', body: {'pin': pin});
    } on FunctionException catch (error, stackTrace) {
      throw _mapSetupPinFunctionException(error, stackTrace);
    } catch (error, stackTrace) {
      throw _mapUnknownException(error, stackTrace);
    }
  }

  @override
  Future<void> pinLogin({
    required String e164Phone,
    required String pin,
  }) async {
    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'pin-login',
        body: {'phone': e164Phone, 'pin': pin},
      );
    } on FunctionException catch (error, stackTrace) {
      throw _mapPinLoginFunctionException(error, stackTrace);
    } catch (error, stackTrace) {
      throw _mapUnknownException(error, stackTrace);
    }

    final data = response.data;
    final session = data is Map ? data['session'] : null;
    final accessToken = session is Map
        ? session['access_token'] as String?
        : null;
    final refreshToken = session is Map
        ? session['refresh_token'] as String?
        : null;
    if (accessToken == null || refreshToken == null) {
      _log.severe('pin-login: response was missing a usable session');
      throw const AuthFailure(
        AuthFailureType.unexpected,
        'Something went wrong. Please try again.',
      );
    }

    try {
      // Both tokens passed together: the access token was just issued
      // by pin-login and is not yet expired, so this takes the
      // no-network-round-trip path and fires AuthChangeEvent.signedIn
      // — the correct semantics for a genuine login (see
      // docs/product/authentication.md).
      await _client.auth.setSession(refreshToken, accessToken: accessToken);
    } on AuthException catch (error, stackTrace) {
      throw _mapAuthException(error, stackTrace);
    } catch (error, stackTrace) {
      throw _mapUnknownException(error, stackTrace);
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}

/// Maps a Supabase [AuthException] to a safe, user-presentable
/// [AuthFailure]. Technical details are logged, never shown to the
/// user. Classification is heuristic (based on documented Supabase
/// auth error codes/status where available, falling back to message
/// content) since this cannot be exhaustively verified without a live
/// SMS provider — see docs/product/authentication.md.
AuthFailure _mapAuthException(AuthException error, StackTrace stackTrace) {
  _log.warning(
    'Supabase auth error (code=${error.code}, status=${error.statusCode})',
    error,
    stackTrace,
  );

  final code = error.code?.toLowerCase() ?? '';
  final message = error.message.toLowerCase();

  if (error.statusCode == '429' ||
      code.contains('rate_limit') ||
      message.contains('rate limit')) {
    return const AuthFailure(
      AuthFailureType.tooManyRequests,
      'Too many attempts. Please wait a moment and try again.',
    );
  }

  if (code.contains('expired') || message.contains('expired')) {
    return const AuthFailure(
      AuthFailureType.otpExpired,
      'This code has expired. Request a new one.',
    );
  }

  if (code.contains('otp') ||
      code.contains('token') ||
      message.contains('token')) {
    return const AuthFailure(
      AuthFailureType.invalidOtp,
      'That code is not correct. Please check and try again.',
    );
  }

  if (code.contains('phone') || message.contains('phone')) {
    return const AuthFailure(
      AuthFailureType.invalidPhone,
      'That phone number could not be used. Please check it and try again.',
    );
  }

  return const AuthFailure(
    AuthFailureType.unexpected,
    'Something went wrong. Please try again.',
  );
}

/// Maps a `setup-pin` [FunctionException] to a safe [AuthFailure].
/// Every code here should be effectively unreachable in normal use
/// (the client only ever calls this right after a real OTP verify,
/// with a client-validated 4-digit PIN) — a generic message is enough,
/// the specific code is only for logs.
AuthFailure _mapSetupPinFunctionException(
  FunctionException error,
  StackTrace stackTrace,
) {
  final code = _extractErrorCode(error);
  _log.warning(
    'setup-pin failed (code=$code, status=${error.status})',
    error,
    stackTrace,
  );
  return const AuthFailure(
    AuthFailureType.unexpected,
    'Something went wrong. Please try again.',
  );
}

/// Maps a `pin-login` [FunctionException] to a safe [AuthFailure] —
/// the one place `INVALID_CREDENTIALS`/`PIN_TEMPORARILY_LOCKED` become
/// user-facing failure types.
AuthFailure _mapPinLoginFunctionException(
  FunctionException error,
  StackTrace stackTrace,
) {
  final code = _extractErrorCode(error);
  _log.info(
    'pin-login failed (code=$code, status=${error.status})',
    error,
    stackTrace,
  );

  return switch (code) {
    'INVALID_CREDENTIALS' => const AuthFailure(
      AuthFailureType.invalidCredentials,
      'Phone number or PIN is incorrect.',
    ),
    'PIN_TEMPORARILY_LOCKED' => const AuthFailure(
      AuthFailureType.pinLocked,
      'Too many attempts. Please try again in a few minutes.',
    ),
    'NETWORK_ERROR' => const AuthFailure(
      AuthFailureType.network,
      'Network error. Check your connection and try again.',
    ),
    _ => const AuthFailure(
      AuthFailureType.unexpected,
      'Something went wrong. Please try again.',
    ),
  };
}

String? _extractErrorCode(FunctionException error) {
  final details = error.details;
  if (details is Map) {
    final errorField = details['error'];
    if (errorField is Map) {
      final code = errorField['code'];
      if (code is String) return code;
    }
  }
  return null;
}

/// Maps a non-[AuthException]/[FunctionException] failure (e.g.
/// connectivity errors) to a safe [AuthFailure]. Avoids `dart:io`
/// types so this stays web-safe.
AuthFailure _mapUnknownException(Object error, StackTrace stackTrace) {
  _log.severe('Unexpected auth error', error, stackTrace);

  final text = error.toString().toLowerCase();
  final looksLikeNetworkError =
      text.contains('socket') ||
      text.contains('network') ||
      text.contains('connection') ||
      text.contains('failed host lookup') ||
      text.contains('timeout');

  if (looksLikeNetworkError) {
    return const AuthFailure(
      AuthFailureType.network,
      'Network error. Check your connection and try again.',
    );
  }

  return const AuthFailure(
    AuthFailureType.unexpected,
    'Something went wrong. Please try again.',
  );
}
