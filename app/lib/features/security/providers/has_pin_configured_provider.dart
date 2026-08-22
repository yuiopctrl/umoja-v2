import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_session_provider.dart';
import 'pin_repository_provider.dart';

/// Whether the currently-authenticated user has a PIN configured on
/// this device. `false` when signed out. Refetches whenever the
/// authenticated identity changes; callers that mutate PIN storage
/// (setup, clear) must `ref.invalidate` this explicitly afterward, the
/// same pattern `appContextProvider` uses after a profile/group write.
final hasPinConfiguredProvider = FutureProvider<bool>((ref) async {
  final userId = ref.watch(authUserIdProvider);
  if (userId == null) return false;
  return ref.watch(pinRepositoryProvider).hasPin(userId);
});
