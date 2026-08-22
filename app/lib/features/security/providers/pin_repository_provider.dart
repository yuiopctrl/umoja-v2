import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/pin_repository.dart';
import '../data/secure_pin_repository.dart';

final pinRepositoryProvider = Provider<PinRepository>((ref) {
  return SecurePinRepository(const FlutterSecureStorage());
});
