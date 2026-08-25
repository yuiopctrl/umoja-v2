import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/contribution_type.dart';
import 'contribution_repository_provider.dart';

/// A single contribution type's detail, scoped to the current selected
/// group. `.family` keyed on typeId so the edit form can watch just its
/// own record.
final contributionTypeDetailProvider =
    FutureProvider.family<ContributionType, String>((ref, typeId) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) {
        throw StateError('No resolved group context.');
      }

      final repository = ref.watch(contributionRepositoryProvider);
      return repository.getContributionType(
        groupId: selectedGroup.membership.group.groupId,
        typeId: typeId,
      );
    });
