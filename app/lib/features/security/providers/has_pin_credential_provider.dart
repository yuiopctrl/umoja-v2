import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../auth/providers/auth_session_provider.dart';

/// Whether the currently-authenticated user has a PIN credential
/// configured server-side (`public.user_pin_credentials`, via
/// `rpc_has_pin_credential()`) — prompt 05E §7/§30/§31: server-side PIN
/// auth is now authoritative for whether PIN login is available, never
/// local device storage (there is no local PIN storage left at all —
/// see docs/product/authentication.md).
///
/// `false` when signed out. Refetches whenever the authenticated
/// identity changes; `PinSetupController` invalidates this explicitly
/// right after a successful `setup-pin` call, the same pattern
/// `appContextProvider` uses after a profile/group write.
final hasPinCredentialProvider = FutureProvider<bool>((ref) async {
  final userId = ref.watch(authUserIdProvider);
  if (userId == null) return false;

  final client = ref.watch(supabaseClientProvider);
  final result = await client.rpc('rpc_has_pin_credential');
  return result as bool;
});
