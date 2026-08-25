import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/member_contribution_charge_page.dart';
import 'contribution_repository_provider.dart';

/// The compound key for [contributionPeriodChargesProvider] — a single
/// period's charges list is inherently scoped to that period plus its
/// own local search/pagination state, so (unlike the group-wide
/// types/setups/periods lists) this stays a simple family FutureProvider
/// rather than a separate global query Notifier; the owning screen holds
/// search/limit as local widget state instead.
typedef ContributionPeriodChargesQuery = ({
  String periodId,
  String search,
  int limit,
});

final contributionPeriodChargesProvider =
    FutureProvider.family<
      MemberContributionChargePage,
      ContributionPeriodChargesQuery
    >((ref, query) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) {
        return MemberContributionChargePage.empty;
      }

      final repository = ref.watch(contributionRepositoryProvider);
      return repository.listContributionPeriodCharges(
        groupId: selectedGroup.membership.group.groupId,
        periodId: query.periodId,
        search: query.search,
        limit: query.limit,
      );
    });
