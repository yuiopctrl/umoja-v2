import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_failure.dart';
import 'auth_repository.dart';

final _log = Logger('SupabaseAuthRepository');

/// [AuthRepository] backed by Supabase Auth's phone-OTP (SMS) flow.
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

/// Maps a non-[AuthException] failure (e.g. connectivity errors) to a
/// safe [AuthFailure]. Avoids `dart:io` types so this stays web-safe.
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
