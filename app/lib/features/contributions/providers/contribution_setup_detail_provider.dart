import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/contribution_setup.dart';
import 'contribution_repository_provider.dart';

final contributionSetupDetailProvider =
    FutureProvider.family<ContributionSetup, String>((ref, setupId) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) {
        throw StateError('No resolved group context.');
      }

      final repository = ref.watch(contributionRepositoryProvider);
      return repository.getContributionSetup(
        groupId: selectedGroup.membership.group.groupId,
        setupId: setupId,
      );
    });
