import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/member_loans_repository.dart';
import '../data/supabase_member_loans_repository.dart';

final memberLoansRepositoryProvider = Provider<MemberLoansRepository>(
  (ref) => SupabaseMemberLoansRepository(ref.watch(supabaseClientProvider)),
);
