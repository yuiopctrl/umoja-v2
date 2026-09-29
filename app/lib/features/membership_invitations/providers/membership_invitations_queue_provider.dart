import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/membership_invitation_queue_item.dart';
import '../domain/membership_invitation_status.dart';
import 'membership_invitation_repository_provider.dart';

/// The officer-facing invitation queue/history for one group (Prompt
/// 09G-B1-E2) — `.autoDispose.family` so leaving the screen discards
/// the snapshot and each distinct query gets its own cache entry,
/// matching `membershipClaimsQueueProvider`'s own record-family
/// precedent. [status] `null` means every status (History); a
/// concrete value (default [MembershipInvitationStatus.pending])
/// filters to it.
typedef MembershipInvitationsQueueQuery = ({
  String groupId,
  MembershipInvitationStatus? status,
  int limit,
  int offset,
});

final membershipInvitationsQueueProvider = FutureProvider.autoDispose
    .family<MembershipInvitationQueuePage, MembershipInvitationsQueueQuery>((
      ref,
      query,
    ) async {
      final repository = ref.watch(membershipInvitationRepositoryProvider);
      return repository.listMembershipInvitations(
        groupId: query.groupId,
        status: query.status,
        limit: query.limit,
        offset: query.offset,
      );
    });
