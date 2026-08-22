import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'pin_hash.dart';
import 'pin_repository.dart';

/// [PinRepository] backed by `flutter_secure_storage` (Keychain on
/// iOS/macOS, Keystore-backed EncryptedSharedPreferences on Android,
/// libsecret on Linux, Credential Manager on Windows, `window.crypto`-
/// backed storage on web) — deliberately never `SharedPreferences`,
/// which stores plaintext on most platforms.
///
/// Stores only a salted SHA-256 hash per user id (see [hashPin]), never
/// the PIN itself.
class SecurePinRepository implements PinRepository {
  SecurePinRepository(this._storage);

  final FlutterSecureStorage _storage;

  String _saltKey(String userId) => 'umoja.pin.salt.$userId';
  String _hashKey(String userId) => 'umoja.pin.hash.$userId';

  @override
  Future<bool> hasPin(String userId) async {
    return await _storage.read(key: _hashKey(userId)) != null;
  }

  @override
  Future<void> setPin({required String userId, required String pin}) async {
    final salt = generateSalt();
    await _storage.write(key: _saltKey(userId), value: salt);
    await _storage.write(key: _hashKey(userId), value: hashPin(pin, salt));
  }

  @override
  Future<bool> verifyPin({required String userId, required String pin}) async {
    final salt = await _storage.read(key: _saltKey(userId));
    final storedHash = await _storage.read(key: _hashKey(userId));
    if (salt == null || storedHash == null) return false;
    return hashPin(pin, salt) == storedHash;
  }

  @override
  Future<void> clearPin(String userId) async {
    await _storage.delete(key: _saltKey(userId));
    await _storage.delete(key: _hashKey(userId));
  }
}
