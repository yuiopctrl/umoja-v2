import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/membership_claim_queue_item.dart';
import 'membership_claim_repository_provider.dart';

/// One claim's officer-facing detail (Prompt 09G-B1-D3), keyed by
/// (groupId, claimId) — `.autoDispose.family`, matching every other
/// read-only detail provider's precedent (e.g.
/// `loanWriteOffSummaryProvider`).
typedef MembershipClaimDetailQuery = ({String groupId, String claimId});

final membershipClaimDetailProvider = FutureProvider.autoDispose
    .family<MembershipClaimQueueItem, MembershipClaimDetailQuery>((
      ref,
      query,
    ) async {
      final repository = ref.watch(membershipClaimRepositoryProvider);
      return repository.getMembershipClaim(
        groupId: query.groupId,
        claimId: query.claimId,
      );
    });
