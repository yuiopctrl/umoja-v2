import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';

/// Streams Supabase auth state changes (sign-in, sign-out, token
/// refresh). Only meaningful once Supabase is configured — callers
/// should check [isSupabaseConfiguredProvider] first.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

/// The currently authenticated Supabase user, or `null` when signed out
/// or when Supabase configuration is missing.
///
/// Reads the client's already-known current user as a synchronous
/// fallback so the UI does not flash a "signed out" state before the
/// first auth-change event arrives.
final currentSupabaseUserProvider = Provider<User?>((ref) {
  if (!ref.watch(isSupabaseConfiguredProvider)) return null;

  final client = ref.watch(supabaseClientProvider);
  final authState = ref.watch(authStateChangesProvider);

  return authState.maybeWhen(
    data: (state) => state.session?.user,
    orElse: () => client.auth.currentUser,
  );
});

/// The current user's id, or `null` when signed out. Unlike
/// [currentSupabaseUserProvider] (which re-emits a new [User] instance
/// on every auth event, including token refresh), this only changes
/// when the *identity* actually changes — plain [String]/`null`
/// equality means a token refresh for the same user does not trigger
/// dependents (like [appContextProvider]) to rebuild. Providers that
/// hold user-scoped state should key their re-fetch on this, not on
/// [currentSupabaseUserProvider] directly, so a real identity change
/// (User A signs out, User B signs in) reliably triggers a refetch
/// without noisy refetches on every token refresh.
final authUserIdProvider = Provider<String?>((ref) {
  return ref.watch(currentSupabaseUserProvider)?.id;
});

/// High-level session states the foundation UI needs to distinguish.
enum AuthSessionStatus { configMissing, signedOut, signedIn }

final authSessionStatusProvider = Provider<AuthSessionStatus>((ref) {
  if (!ref.watch(isSupabaseConfiguredProvider)) {
    return AuthSessionStatus.configMissing;
  }
  final user = ref.watch(currentSupabaseUserProvider);
  return user == null
      ? AuthSessionStatus.signedOut
      : AuthSessionStatus.signedIn;
});
