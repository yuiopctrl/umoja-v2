import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/contribution_setup.dart';
import 'contribution_repository_provider.dart';

/// Every *active* contribution setup, for use in a picker (e.g. the
/// Contribution Period create form) — see
/// [contributionActiveTypesForPickerProvider]'s doc for why this is
/// separate from the Contribution Setups list screen's own query state.
final contributionActiveSetupsForPickerProvider =
    FutureProvider<List<ContributionSetup>>((ref) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) return const [];

      final repository = ref.watch(contributionRepositoryProvider);
      final page = await repository.listContributionSetups(
        groupId: selectedGroup.membership.group.groupId,
        isActive: true,
        limit: 100,
      );
      return page.items;
    });
