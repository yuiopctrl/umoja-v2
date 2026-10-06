import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/my_contributions_repository.dart';
import '../data/supabase_my_contributions_repository.dart';

final myContributionsRepositoryProvider = Provider<MyContributionsRepository>(
  (ref) => SupabaseMyContributionsRepository(ref.watch(supabaseClientProvider)),
);
