import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../data/contribution_failure.dart';
import '../providers/contribution_period_detail_provider.dart';
import '../providers/contribution_period_open_preview_provider.dart';
import '../providers/contribution_repository_provider.dart';

final _log = Logger('ContributionPeriodExclusionController');

class ContributionPeriodExclusionState {
  const ContributionPeriodExclusionState({
    this.isSubmitting = false,
    this.errorType,
  });

  final bool isSubmitting;
  final ContributionFailureType? errorType;
}

/// Drives pre-open member exclusion
/// (`rpc_exclude_contribution_period_member`/
/// `rpc_remove_contribution_period_member_exclusion`) for a
/// DRAFT/SCHEDULED period. This is never a "waiver" — no charge exists
/// yet for an excluded member, so nothing is being forgiven; the UI
/// never uses that word.
class ContributionPeriodExclusionController
    extends Notifier<ContributionPeriodExclusionState> {
  @override
  ContributionPeriodExclusionState build() =>
      const ContributionPeriodExclusionState();

  Future<bool> exclude({
    required String groupId,
    required String periodId,
    required String membershipId,
    String? reason,
  }) async {
    if (state.isSubmitting) return false;

    state = const ContributionPeriodExclusionState(isSubmitting: true);
    try {
      await ref
          .read(contributionRepositoryProvider)
          .excludeContributionPeriodMember(
            groupId: groupId,
            periodId: periodId,
            membershipId: membershipId,
            reason: reason,
          );
    } on ContributionFailure catch (error) {
      state = ContributionPeriodExclusionState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning(
        'Failed to exclude contribution period member',
        error,
        stackTrace,
      );
      state = const ContributionPeriodExclusionState(
        errorType: ContributionFailureType.unexpected,
      );
      return false;
    }

    state = const ContributionPeriodExclusionState();
    ref.invalidate(contributionPeriodDetailProvider(periodId));
    ref.invalidate(contributionPeriodOpenPreviewProvider(periodId));
    return true;
  }

  Future<bool> removeExclusion({
    required String groupId,
    required String periodId,
    required String membershipId,
  }) async {
    if (state.isSubmitting) return false;

    state = const ContributionPeriodExclusionState(isSubmitting: true);
    try {
      await ref
          .read(contributionRepositoryProvider)
          .removeContributionPeriodMemberExclusion(
            groupId: groupId,
            periodId: periodId,
            membershipId: membershipId,
          );
    } on ContributionFailure catch (error) {
      state = ContributionPeriodExclusionState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning(
        'Failed to remove contribution period member exclusion',
        error,
        stackTrace,
      );
      state = const ContributionPeriodExclusionState(
        errorType: ContributionFailureType.unexpected,
      );
      return false;
    }

    state = const ContributionPeriodExclusionState();
    ref.invalidate(contributionPeriodDetailProvider(periodId));
    ref.invalidate(contributionPeriodOpenPreviewProvider(periodId));
    return true;
  }
}

final contributionPeriodExclusionControllerProvider =
    NotifierProvider<
      ContributionPeriodExclusionController,
      ContributionPeriodExclusionState
    >(ContributionPeriodExclusionController.new);
