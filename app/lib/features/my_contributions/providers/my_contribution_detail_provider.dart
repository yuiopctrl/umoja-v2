import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/my_contribution.dart';
import 'my_contributions_repository_provider.dart';

/// One charge's member-safe detail, for the CURRENTLY SELECTED group.
/// Keyed by charge id and watching [selectedGroupProvider], so a group
/// switch rebuilds it for the new group and the previous group's detail
/// cannot survive into it.
final myContributionDetailProvider = FutureProvider.autoDispose
    .family<MyContributionDetail, String>((ref, chargeId) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) {
        throw StateError('No selected group.');
      }

      final repository = ref.watch(myContributionsRepositoryProvider);
      return repository.getMyContributionChargeDetail(
        groupId: selectedGroup.membership.group.groupId,
        chargeId: chargeId,
      );
    });
