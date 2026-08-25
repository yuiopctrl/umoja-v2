import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/contribution_type_page.dart';
import 'contribution_repository_provider.dart';
import 'contribution_types_query_provider.dart';

/// The current page of the Contribution Types list, scoped to the app's
/// existing selected-group context. Watching [selectedGroupProvider]
/// means this refetches automatically whenever the resolved group
/// changes.
final contributionTypesListProvider = FutureProvider<ContributionTypePage>((
  ref,
) async {
  final selectedGroup = ref.watch(selectedGroupProvider);
  if (selectedGroup is! SelectedGroupResolved) {
    return ContributionTypePage.empty;
  }

  final query = ref.watch(contributionTypesQueryProvider);
  final repository = ref.watch(contributionRepositoryProvider);

  return repository.listContributionTypes(
    groupId: selectedGroup.membership.group.groupId,
    search: query.search,
    isActive: query.isActive,
    limit: query.limit,
  );
});
