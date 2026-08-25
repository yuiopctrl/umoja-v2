import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../data/contribution_failure.dart';
import '../domain/contribution_penalty_assessment_result.dart';
import '../providers/contribution_period_charges_provider.dart';
import '../providers/contribution_period_detail_provider.dart';
import '../providers/contribution_repository_provider.dart';

final _log = Logger('ContributionPeriodPenaltyController');

class ContributionPeriodPenaltyState {
  const ContributionPeriodPenaltyState({
    this.isSubmitting = false,
    this.errorType,
    this.lastResult,
  });

  final bool isSubmitting;
  final ContributionFailureType? errorType;

  /// The most recent successful assessment's server-computed result —
  /// shown to the user, never recomputed client-side.
  final ContributionPenaltyAssessmentResult? lastResult;
}

/// Drives Prompt 06B penalty assessment
/// (`rpc_assess_contribution_penalties`) — OPEN periods with a
/// configured penalty policy only. Atomic and idempotent on the
/// backend: calling [assess] again for the same (or an earlier)
/// assessment date is always safe.
class ContributionPeriodPenaltyController
    extends Notifier<ContributionPeriodPenaltyState> {
  @override
  ContributionPeriodPenaltyState build() =>
      const ContributionPeriodPenaltyState();

  Future<bool> assess({
    required String groupId,
    required String periodId,
    DateTime? assessmentDate,
  }) async {
    if (state.isSubmitting) return false;

    state = const ContributionPeriodPenaltyState(isSubmitting: true);
    try {
      final result = await ref
          .read(contributionRepositoryProvider)
          .assessContributionPeriodPenalties(
            groupId: groupId,
            periodId: periodId,
            assessmentDate: assessmentDate,
          );
      ref.invalidate(contributionPeriodDetailProvider(periodId));
      // Whole-family invalidation — the charges provider is keyed on the
      // viewer's own search/limit, which this controller has no reason
      // to know (same lesson as OPEN/ENROLL in Prompt 06A-UAT-FIX).
      ref.invalidate(contributionPeriodChargesProvider);
      state = ContributionPeriodPenaltyState(lastResult: result);
      return true;
    } on ContributionFailure catch (error) {
      state = ContributionPeriodPenaltyState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning(
        'Failed to assess contribution period penalties',
        error,
        stackTrace,
      );
      state = const ContributionPeriodPenaltyState(
        errorType: ContributionFailureType.unexpected,
      );
      return false;
    }
  }
}

final contributionPeriodPenaltyControllerProvider =
    NotifierProvider<
      ContributionPeriodPenaltyController,
      ContributionPeriodPenaltyState
    >(ContributionPeriodPenaltyController.new);
