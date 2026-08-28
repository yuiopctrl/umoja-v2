import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../data/contribution_failure.dart';
import '../domain/contribution_correction_result.dart';
import '../providers/contribution_charge_detail_provider.dart';
import '../providers/contribution_period_charges_provider.dart';
import '../providers/contribution_repository_provider.dart';
import '../providers/member_contribution_summary_provider.dart';

final _log = Logger('ContributionAdjustmentController');

class ContributionAdjustmentState {
  const ContributionAdjustmentState({
    this.isSubmitting = false,
    this.errorType,
    this.lastResult,
  });

  final bool isSubmitting;
  final ContributionFailureType? errorType;

  /// The most recent successful adjustment's server-computed result —
  /// shown to the user, never recomputed client-side.
  final ContributionCorrectionResult? lastResult;
}

/// Drives Prompt 06C's `rpc_create_contribution_adjustment` — posts a
/// signed ADJUSTMENT component (server converts a user's "increase" or
/// "reduce" choice plus a positive magnitude into the signed amount
/// before calling this) against an existing charge. Never edits
/// BASE/PENALTY. Works against OPEN or CLOSED charges alike.
class ContributionAdjustmentController
    extends Notifier<ContributionAdjustmentState> {
  @override
  ContributionAdjustmentState build() => const ContributionAdjustmentState();

  Future<bool> createAdjustment({
    required String groupId,
    required String chargeId,
    required String periodId,
    required String membershipId,
    required double amount,
    required String reason,
    required DateTime effectiveAt,
    String? idempotencyKey,
  }) async {
    if (state.isSubmitting) return false;

    state = const ContributionAdjustmentState(isSubmitting: true);
    try {
      final result = await ref
          .read(contributionRepositoryProvider)
          .createContributionAdjustment(
            groupId: groupId,
            chargeId: chargeId,
            amount: amount,
            reason: reason,
            effectiveAt: effectiveAt,
            idempotencyKey: idempotencyKey,
          );
      ref.invalidate(contributionChargeDetailProvider(chargeId));
      ref.invalidate(memberContributionSummaryProvider(membershipId));
      // Whole-family invalidation — this controller has no reason to
      // know the viewer's own search/limit state for the charges list
      // (same lesson as OPEN/ENROLL/penalty assessment).
      ref.invalidate(contributionPeriodChargesProvider);
      state = ContributionAdjustmentState(lastResult: result);
      return true;
    } on ContributionFailure catch (error) {
      state = ContributionAdjustmentState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning(
        'Failed to create contribution adjustment',
        error,
        stackTrace,
      );
      state = const ContributionAdjustmentState(
        errorType: ContributionFailureType.unexpected,
      );
      return false;
    }
  }
}

final contributionAdjustmentControllerProvider =
    NotifierProvider<
      ContributionAdjustmentController,
      ContributionAdjustmentState
    >(ContributionAdjustmentController.new);
