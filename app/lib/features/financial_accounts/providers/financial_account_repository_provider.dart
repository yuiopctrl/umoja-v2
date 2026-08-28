import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/financial_account_repository.dart';
import '../data/supabase_financial_account_repository.dart';

final financialAccountRepositoryProvider = Provider<FinancialAccountRepository>(
  (ref) {
    return SupabaseFinancialAccountRepository(
      ref.watch(supabaseClientProvider),
    );
  },
);
