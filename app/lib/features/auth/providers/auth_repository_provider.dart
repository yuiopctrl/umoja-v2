import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/auth_repository.dart';
import '../data/supabase_auth_repository.dart';

/// The app's single [AuthRepository]. UI/controllers must depend on
/// this provider (or the [AuthRepository] type it exposes), never
/// construct/call the Supabase Auth SDK directly — this is what keeps
/// the auth flow testable without a live Supabase project.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});
