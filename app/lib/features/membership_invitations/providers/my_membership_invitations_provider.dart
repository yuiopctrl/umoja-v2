import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/my_membership_invitation.dart';
import 'membership_invitation_repository_provider.dart';

/// The authenticated caller's OWN personal invitation inbox (Prompt
/// 09G-B1-F2) — `rpc_list_my_membership_invitations`, no status
/// filter, so this single fetch serves both the full inbox screen
/// (every status) AND the lightweight pending-count indicator on Home/
/// More (`MyMembershipInvitationsPage.pendingActionableCount`,
/// filtered from this SAME already-fetched list — never a second
/// query). `.autoDispose` (not `.family`, no arguments) so every
/// watcher shares the one cached fetch, and it is discarded once
/// nothing is watching it.
final myMembershipInvitationsProvider =
    FutureProvider.autoDispose<MyMembershipInvitationsPage>((ref) async {
      final repository = ref.watch(membershipInvitationRepositoryProvider);
      return repository.listMyInvitations(limit: 50);
    });
