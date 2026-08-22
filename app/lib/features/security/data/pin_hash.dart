import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Generates a cryptographically random salt for [hashPin].
String generateSalt({int bytes = 16}) {
  final random = Random.secure();
  return base64Url.encode(
    List<int>.generate(bytes, (_) => random.nextInt(256)),
  );
}

/// A salted, one-way SHA-256 hash of [pin] — the only form of a PIN
/// [SecurePinRepository] ever writes to storage. Never reversible back
/// to [pin]; the same (pin, salt) pair always produces the same hash,
/// but different salts produce different hashes for the same PIN.
String hashPin(String pin, String salt) {
  return sha256.convert(utf8.encode('$salt:$pin')).toString();
}
