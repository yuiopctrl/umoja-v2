import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/contribution_setup_page.dart';
import 'contribution_repository_provider.dart';
import 'contribution_setups_query_provider.dart';

final contributionSetupsListProvider = FutureProvider<ContributionSetupPage>((
  ref,
) async {
  final selectedGroup = ref.watch(selectedGroupProvider);
  if (selectedGroup is! SelectedGroupResolved) {
    return ContributionSetupPage.empty;
  }

  final query = ref.watch(contributionSetupsQueryProvider);
  final repository = ref.watch(contributionRepositoryProvider);

  return repository.listContributionSetups(
    groupId: selectedGroup.membership.group.groupId,
    contributionTypeId: query.contributionTypeId,
    isActive: query.isActive,
    limit: query.limit,
  );
});
