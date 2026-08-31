import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/member_contribution_charge.dart';
import 'payment_repository_provider.dart';

/// Query key for [memberContributionChargesProvider].
typedef MemberChargesQuery = ({String membershipId, String filter, int limit});

/// The member-centric Charges/Madeni list (Prompt 07 UAT-FIX-03).
/// `.autoDispose` for the same freshness reason as every other
/// Prompt 07 list provider — after a payment/waiver/adjustment/
/// reversal this must never show a stale snapshot.
final memberContributionChargesProvider = FutureProvider.autoDispose
    .family<MemberChargesPage, MemberChargesQuery>((ref, query) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) {
        return MemberChargesPage.empty;
      }

      final repository = ref.watch(paymentRepositoryProvider);
      return repository.listMemberContributionCharges(
        groupId: selectedGroup.membership.group.groupId,
        membershipId: query.membershipId,
        filter: query.filter,
        limit: query.limit,
      );
    });
