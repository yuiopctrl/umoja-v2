import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/loan_repository.dart';
import '../data/supabase_loan_repository.dart';

final loanRepositoryProvider = Provider<LoanRepository>((ref) {
  return SupabaseLoanRepository(ref.watch(supabaseClientProvider));
});
