import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/membership_invitation_repository.dart';
import '../data/supabase_membership_invitation_repository.dart';

final membershipInvitationRepositoryProvider =
    Provider<MembershipInvitationRepository>((ref) {
      return SupabaseMembershipInvitationRepository(
        ref.watch(supabaseClientProvider),
      );
    });
