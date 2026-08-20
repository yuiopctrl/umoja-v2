import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../models/app_context.dart';
import 'auth_session_provider.dart';

/// The signed-in user's application context (profile + memberships),
/// fetched from `rpc_get_my_context()`. `null` when signed out — the
/// backend derives everything from `auth.uid()`, so there is nothing to
/// fetch until a user is authenticated.
///
/// Watches [authUserIdProvider] (not [currentSupabaseUserProvider])
/// deliberately: this must refetch when the signed-in identity actually
/// changes (so User B never sees User A's cached context — see
/// docs/product/authentication.md), but should not refetch on every
/// token refresh for the same user.
final appContextProvider = FutureProvider<AppContext?>((ref) async {
  final userId = ref.watch(authUserIdProvider);
  if (userId == null) return null;

  final client = ref.watch(supabaseClientProvider);
  final result = await client.rpc('rpc_get_my_context');
  return AppContext.fromJson(result as Map<String, dynamic>);
});
