import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../data/contribution_failure.dart';
import '../data/contribution_repository.dart';
import '../providers/contribution_period_charges_provider.dart';
import '../providers/contribution_period_detail_provider.dart';
import '../providers/contribution_period_open_preview_provider.dart';
import '../providers/contribution_periods_list_provider.dart';
import '../providers/contribution_repository_provider.dart';

final _log = Logger('ContributionPeriodLifecycleController');

class ContributionPeriodLifecycleState {
  const ContributionPeriodLifecycleState({
    this.isSubmitting = false,
    this.errorType,
  });

  final bool isSubmitting;
  final ContributionFailureType? errorType;
}

/// Drives the DRAFT/SCHEDULED -> OPEN -> CLOSED lifecycle transitions
/// (`rpc_open_contribution_period`/`rpc_close_contribution_period`) and
/// the DRAFT/SCHEDULED -> CANCELLED terminal transition
/// (`rpc_cancel_contribution_period`). [open] should only be called
/// after the caller has already shown the open-preview confirmation
/// (see `contributionPeriodOpenPreviewProvider` +
/// `showUmojaConfirmationSheet`) — this controller does not itself
/// re-preview.
///
/// The mutation call and the post-success provider refresh are
/// deliberately separate steps, matching `MemberStatusController`: a
/// successful backend change is always reported as success even if the
/// *subsequent* refresh has trouble.
class ContributionPeriodLifecycleController
    extends Notifier<ContributionPeriodLifecycleState> {
  @override
  ContributionPeriodLifecycleState build() =>
      const ContributionPeriodLifecycleState();

  Future<bool> open({required String groupId, required String periodId}) async {
    final success = await _run(
      groupId: groupId,
      periodId: periodId,
      action: (repo) =>
          repo.openContributionPeriod(groupId: groupId, periodId: periodId),
    );
    if (success) {
      // OPEN posts every eligible member's charge in one atomic call —
      // any charges-list view for this period (whole family: it's keyed
      // on the viewer's own search/limit, which this controller has no
      // reason to know) and the now-stale open-preview must both be
      // refreshed, or a caller who already had either screen open would
      // keep showing pre-OPEN (empty/eligible-only) data indefinitely.
      ref.invalidate(contributionPeriodChargesProvider);
      ref.invalidate(contributionPeriodOpenPreviewProvider(periodId));
    }
    return success;
  }

  Future<bool> close({required String groupId, required String periodId}) =>
      _run(
        groupId: groupId,
        periodId: periodId,
        action: (repo) =>
            repo.closeContributionPeriod(groupId: groupId, periodId: periodId),
      );

  Future<bool> cancel({required String groupId, required String periodId}) =>
      _run(
        groupId: groupId,
        periodId: periodId,
        action: (repo) =>
            repo.cancelContributionPeriod(groupId: groupId, periodId: periodId),
      );

  Future<bool> _run({
    required String groupId,
    required String periodId,
    required Future<void> Function(ContributionRepository repo) action,
  }) async {
    if (state.isSubmitting) return false;

    state = const ContributionPeriodLifecycleState(isSubmitting: true);
    try {
      await action(ref.read(contributionRepositoryProvider));
    } on ContributionFailure catch (error) {
      state = ContributionPeriodLifecycleState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning(
        'Failed to change contribution period lifecycle state',
        error,
        stackTrace,
      );
      state = const ContributionPeriodLifecycleState(
        errorType: ContributionFailureType.unexpected,
      );
      return false;
    }

    state = const ContributionPeriodLifecycleState();
    ref.invalidate(contributionPeriodsListProvider);
    ref.invalidate(contributionPeriodDetailProvider(periodId));
    return true;
  }
}

final contributionPeriodLifecycleControllerProvider =
    NotifierProvider<
      ContributionPeriodLifecycleController,
      ContributionPeriodLifecycleState
    >(ContributionPeriodLifecycleController.new);
