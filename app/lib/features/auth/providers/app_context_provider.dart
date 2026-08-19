import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../models/app_context.dart';
import 'auth_session_provider.dart';

/// The signed-in user's application context (profile + memberships),
/// fetched from `rpc_get_my_context()`. `null` when signed out — the
/// backend derives everything from `auth.uid()`, so there is nothing to
/// fetch until a user is authenticated.
final appContextProvider = FutureProvider<AppContext?>((ref) async {
  final user = ref.watch(currentSupabaseUserProvider);
  if (user == null) return null;

  final client = ref.watch(supabaseClientProvider);
  final result = await client.rpc('rpc_get_my_context');
  return AppContext.fromJson(result as Map<String, dynamic>);
});
