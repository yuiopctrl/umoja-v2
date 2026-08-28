import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/member_contribution_summary.dart';
import 'contribution_repository_provider.dart';

/// The "Member Contribution Obligation Summary" — one member's
/// obligation aggregated across every one of their charges in the
/// group (Prompt 06C). `.family` keyed on membershipId.
final memberContributionSummaryProvider =
    FutureProvider.family<MemberContributionSummary, String>((
      ref,
      membershipId,
    ) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) {
        throw StateError('No resolved group context.');
      }

      final repository = ref.watch(contributionRepositoryProvider);
      return repository.getMemberContributionSummary(
        groupId: selectedGroup.membership.group.groupId,
        membershipId: membershipId,
      );
    });
