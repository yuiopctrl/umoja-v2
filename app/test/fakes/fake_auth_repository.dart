import 'dart:async';

import 'package:umoja/features/auth/data/auth_failure.dart';
import 'package:umoja/features/auth/data/auth_repository.dart';

/// In-memory [AuthRepository] fake for tests. No network/SMS/Supabase
/// involved — behavior is fully controlled by the test.
class FakeAuthRepository implements AuthRepository {
  AuthFailure? sendOtpFailure;
  AuthFailure? verifyOtpFailure;
  AuthFailure? setupPinFailure;
  AuthFailure? pinLoginFailure;

  /// When set, [pinLogin] awaits this before resolving — lets a test
  /// hold a call "in flight" to exercise duplicate-submission
  /// prevention (auto-submit racing the manual button) without a real
  /// network delay.
  Completer<void>? pinLoginGate;

  /// Same idea as [pinLoginGate], for [setupPin] — lets a test observe
  /// the PIN setup button's in-flight visual state (prompt 05E-A §9)
  /// without a real network delay.
  Completer<void>? setupPinGate;

  final List<String> sentOtpTo = [];
  final List<(String phone, String otp)> verifiedOtps = [];
  final List<String> setupPinCalls = [];
  final List<(String phone, String pin)> pinLoginCalls = [];
  int signOutCallCount = 0;

  @override
  Future<void> sendOtp(String e164Phone) async {
    sentOtpTo.add(e164Phone);
    final failure = sendOtpFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<void> verifyOtp({
    required String e164Phone,
    required String otp,
  }) async {
    verifiedOtps.add((e164Phone, otp));
    final failure = verifyOtpFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<void> setupPin(String pin) async {
    setupPinCalls.add(pin);
    final gate = setupPinGate;
    if (gate != null) await gate.future;
    final failure = setupPinFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<void> pinLogin({
    required String e164Phone,
    required String pin,
  }) async {
    pinLoginCalls.add((e164Phone, pin));
    final gate = pinLoginGate;
    if (gate != null) await gate.future;
    final failure = pinLoginFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<void> signOut() async {
    signOutCallCount++;
  }
}
