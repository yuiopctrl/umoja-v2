import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/contribution_repository.dart';
import '../data/supabase_contribution_repository.dart';

final contributionRepositoryProvider = Provider<ContributionRepository>((ref) {
  return SupabaseContributionRepository(ref.watch(supabaseClientProvider));
});
