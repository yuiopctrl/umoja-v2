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
