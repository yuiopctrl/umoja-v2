import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/contribution_charge_detail.dart';
import 'contribution_repository_provider.dart';

/// Full per-component breakdown for one charge — the charge/member
/// detail screen's data source (Prompt 06C).
final contributionChargeDetailProvider =
    FutureProvider.family<ContributionChargeDetail, String>((
      ref,
      chargeId,
    ) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) {
        throw StateError('No resolved group context.');
      }

      final repository = ref.watch(contributionRepositoryProvider);
      return repository.getContributionChargeDetail(
        groupId: selectedGroup.membership.group.groupId,
        chargeId: chargeId,
      );
    });
