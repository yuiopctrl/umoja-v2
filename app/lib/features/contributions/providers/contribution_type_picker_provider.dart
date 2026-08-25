import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/contribution_type.dart';
import 'contribution_repository_provider.dart';

/// Every *active* contribution type, for use in a picker (e.g. the
/// Contribution Setup create form) — deliberately separate from
/// [contributionTypesListProvider]/its query state, since a picker must
/// never be affected by whatever search/filter the Contribution Types
/// list screen happens to have active, and must only ever offer types a
/// new setup could actually be created against
/// (`CONTRIBUTION_TYPE_INACTIVE` otherwise).
final contributionActiveTypesForPickerProvider =
    FutureProvider<List<ContributionType>>((ref) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) return const [];

      final repository = ref.watch(contributionRepositoryProvider);
      final page = await repository.listContributionTypes(
        groupId: selectedGroup.membership.group.groupId,
        isActive: true,
        limit: 100,
      );
      return page.items;
    });
