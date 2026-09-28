import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/membership_claim_repository.dart';
import '../data/supabase_membership_claim_repository.dart';

final membershipClaimRepositoryProvider = Provider<MembershipClaimRepository>((
  ref,
) {
  return SupabaseMembershipClaimRepository(ref.watch(supabaseClientProvider));
});
