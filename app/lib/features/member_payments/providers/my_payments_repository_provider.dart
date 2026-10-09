import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/my_payments_repository.dart';
import '../data/supabase_my_payments_repository.dart';

final myPaymentsRepositoryProvider = Provider<MyPaymentsRepository>(
  (ref) => SupabaseMyPaymentsRepository(ref.watch(supabaseClientProvider)),
);
