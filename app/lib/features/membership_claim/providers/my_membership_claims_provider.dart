import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/membership_claim.dart';
import 'membership_claim_repository_provider.dart';

/// The caller's own membership claims (Prompt 09G-B1) —
/// `.autoDispose` so leaving the screen discards any stale snapshot,
/// matching every other read-only detail provider's precedent (e.g.
/// `loanWriteOffSummaryProvider`). No group context is required: a
/// user with zero linked memberships has no selected group at all,
/// yet must still be able to see their own claim status.
final myMembershipClaimsProvider =
    FutureProvider.autoDispose<List<MembershipClaim>>((ref) async {
      final repository = ref.watch(membershipClaimRepositoryProvider);
      return repository.listMyMembershipClaims();
    });
