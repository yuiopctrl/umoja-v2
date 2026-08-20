import 'package:umoja/features/auth/data/auth_failure.dart';
import 'package:umoja/features/auth/data/auth_repository.dart';

/// In-memory [AuthRepository] fake for tests. No network/SMS/Supabase
/// involved — behavior is fully controlled by the test.
class FakeAuthRepository implements AuthRepository {
  AuthFailure? sendOtpFailure;
  AuthFailure? verifyOtpFailure;

  final List<String> sentOtpTo = [];
  final List<(String phone, String otp)> verifiedOtps = [];
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
  Future<void> signOut() async {
    signOutCallCount++;
  }
}
