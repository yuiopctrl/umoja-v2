import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/contribution_period.dart';
import 'contribution_repository_provider.dart';

/// A single contribution period's detail (including OPEN/CLOSED
/// snapshot fields and summary counts — only present on this
/// `rpc_get_contribution_period` shape, never on the list shape).
/// `.family` keyed on periodId.
final contributionPeriodDetailProvider =
    FutureProvider.family<ContributionPeriod, String>((ref, periodId) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) {
        throw StateError('No resolved group context.');
      }

      final repository = ref.watch(contributionRepositoryProvider);
      return repository.getContributionPeriod(
        groupId: selectedGroup.membership.group.groupId,
        periodId: periodId,
      );
    });
