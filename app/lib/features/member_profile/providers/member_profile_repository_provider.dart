import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/member_profile_repository.dart';
import '../data/supabase_member_profile_repository.dart';

final memberProfileRepositoryProvider = Provider<MemberProfileRepository>((
  ref,
) {
  return SupabaseMemberProfileRepository(ref.watch(supabaseClientProvider));
});
