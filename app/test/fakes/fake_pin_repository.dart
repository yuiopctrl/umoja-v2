import 'package:umoja/features/security/data/pin_repository.dart';

/// In-memory [PinRepository] fake for tests — keyed by userId, exactly
/// like the real implementation, so "PIN belongs to the current user"
/// behavior is exercised the same way.
class FakePinRepository implements PinRepository {
  final Map<String, String> _pinsByUserId = {};
  final List<String> verifyPinCalls = [];
  final List<String> setPinCalls = [];
  final List<String> clearPinCalls = [];

  @override
  Future<bool> hasPin(String userId) async => _pinsByUserId.containsKey(userId);

  @override
  Future<void> setPin({required String userId, required String pin}) async {
    setPinCalls.add(userId);
    _pinsByUserId[userId] = pin;
  }

  @override
  Future<bool> verifyPin({required String userId, required String pin}) async {
    verifyPinCalls.add(userId);
    return _pinsByUserId[userId] == pin;
  }

  @override
  Future<void> clearPin(String userId) async {
    clearPinCalls.add(userId);
    _pinsByUserId.remove(userId);
  }
}
