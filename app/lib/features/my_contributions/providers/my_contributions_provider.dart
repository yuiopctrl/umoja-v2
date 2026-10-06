import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/my_contribution.dart';
import 'my_contributions_query_provider.dart';
import 'my_contributions_repository_provider.dart';

/// The caller's own contributions for the CURRENTLY SELECTED group.
/// Watches [selectedGroupProvider] directly, so a group switch always
/// refetches for the new group and can never show the previous group's
/// rows. Also watches [myContributionsQueryProvider], so changing a
/// filter or page size refetches naturally.
final myContributionsProvider = FutureProvider.autoDispose<MyContributionsPage>(
  (ref) async {
    final selectedGroup = ref.watch(selectedGroupProvider);
    if (selectedGroup is! SelectedGroupResolved) {
      // Only reachable through the guarded route, which requires a
      // resolved group — a transient fallback, not a real state.
      throw StateError('No selected group.');
    }

    final query = ref.watch(myContributionsQueryProvider);
    final repository = ref.watch(myContributionsRepositoryProvider);

    return repository.getMyContributions(
      groupId: selectedGroup.membership.group.groupId,
      status: query.status,
      contributionTypeId: query.contributionTypeId,
      fromDate: query.fromDate,
      toDate: query.toDate,
      limit: query.limit,
      offset: 0,
    );
  },
);
