import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/member_statement_repository.dart';
import '../data/supabase_member_statement_repository.dart';

final memberStatementRepositoryProvider = Provider<MemberStatementRepository>(
  (ref) => SupabaseMemberStatementRepository(ref.watch(supabaseClientProvider)),
);
