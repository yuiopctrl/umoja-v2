import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/contribution_opening_balance_page.dart';
import 'contribution_repository_provider.dart';

/// Query key for [contributionOpeningBalancesListProvider] — mirrors
/// [ContributionPeriodChargesQuery]'s reasoning: the owning screen holds
/// its own filter/pagination state locally rather than this becoming a
/// group-wide query Notifier.
typedef ContributionOpeningBalancesQuery = ({
  String? contributionTypeId,
  int limit,
});

final contributionOpeningBalancesListProvider =
    FutureProvider.family<
      ContributionOpeningBalancePage,
      ContributionOpeningBalancesQuery
    >((ref, query) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) {
        return ContributionOpeningBalancePage.empty;
      }

      final repository = ref.watch(contributionRepositoryProvider);
      return repository.listContributionOpeningBalances(
        groupId: selectedGroup.membership.group.groupId,
        contributionTypeId: query.contributionTypeId,
        limit: query.limit,
      );
    });
