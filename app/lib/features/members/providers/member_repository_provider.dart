import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/member_repository.dart';
import '../data/supabase_member_repository.dart';

final memberRepositoryProvider = Provider<MemberRepository>((ref) {
  return SupabaseMemberRepository(ref.watch(supabaseClientProvider));
});
