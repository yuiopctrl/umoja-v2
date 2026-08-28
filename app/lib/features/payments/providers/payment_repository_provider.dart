import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/payment_repository.dart';
import '../data/supabase_payment_repository.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return SupabasePaymentRepository(ref.watch(supabaseClientProvider));
});
