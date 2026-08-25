import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/contribution_period_page.dart';
import 'contribution_periods_query_provider.dart';
import 'contribution_repository_provider.dart';

final contributionPeriodsListProvider = FutureProvider<ContributionPeriodPage>((
  ref,
) async {
  final selectedGroup = ref.watch(selectedGroupProvider);
  if (selectedGroup is! SelectedGroupResolved) {
    return ContributionPeriodPage.empty;
  }

  final query = ref.watch(contributionPeriodsQueryProvider);
  final repository = ref.watch(contributionRepositoryProvider);

  return repository.listContributionPeriods(
    groupId: selectedGroup.membership.group.groupId,
    contributionSetupId: query.contributionSetupId,
    status: query.status,
    limit: query.limit,
  );
});
