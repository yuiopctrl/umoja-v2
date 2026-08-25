import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/contribution_period_open_preview.dart';
import 'contribution_repository_provider.dart';

/// The server-authoritative open preview for one period. `.family` keyed
/// on periodId — always re-fetched (via `ref.invalidate`/`ref.refresh`)
/// right before showing the open-confirmation screen, since exclusions
/// or member amounts may have changed since it was last viewed.
final contributionPeriodOpenPreviewProvider =
    FutureProvider.family<ContributionPeriodOpenPreview, String>((
      ref,
      periodId,
    ) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) {
        throw StateError('No resolved group context.');
      }

      final repository = ref.watch(contributionRepositoryProvider);
      return repository.previewContributionPeriodOpen(
        groupId: selectedGroup.membership.group.groupId,
        periodId: periodId,
      );
    });
