import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/membership_claim.dart';
import '../domain/membership_claim_queue_item.dart';
import 'membership_claim_repository_provider.dart';

/// The officer-facing claim queue for one group (Prompt 09G-B1-D3) —
/// `.autoDispose.family` so leaving the screen discards the snapshot
/// and each distinct query gets its own cache entry, matching
/// `loanAccountsProvider`'s own record-family precedent. [status]
/// `null` means every status (History); a concrete value (default
/// [MembershipClaimStatus.pending]) filters to it.
typedef MembershipClaimsQueueQuery = ({
  String groupId,
  MembershipClaimStatus? status,
  int limit,
  int offset,
});

final membershipClaimsQueueProvider = FutureProvider.autoDispose
    .family<MembershipClaimQueuePage, MembershipClaimsQueueQuery>((
      ref,
      query,
    ) async {
      final repository = ref.watch(membershipClaimRepositoryProvider);
      return repository.listMembershipClaims(
        groupId: query.groupId,
        status: query.status,
        limit: query.limit,
        offset: query.offset,
      );
    });
