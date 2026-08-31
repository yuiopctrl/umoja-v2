import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../data/contribution_failure.dart';
import '../domain/contribution_correction_result.dart';
import '../../payments/providers/member_contribution_charges_provider.dart';
import '../../payments/providers/member_contribution_statement_provider.dart';
import '../providers/contribution_charge_detail_provider.dart';
import '../providers/contribution_period_charges_provider.dart';
import '../providers/contribution_repository_provider.dart';
import '../providers/member_contribution_summary_provider.dart';

final _log = Logger('ContributionWaiverController');

class ContributionWaiverState {
  const ContributionWaiverState({
    this.isSubmitting = false,
    this.errorType,
    this.lastResult,
  });

  final bool isSubmitting;
  final ContributionFailureType? errorType;

  /// The most recent successful waiver's server-computed result — shown
  /// to the user, never recomputed client-side.
  final ContributionCorrectionResult? lastResult;
}

/// Drives Prompt 06C's `rpc_waive_contribution_charge` — [amount] is
/// always a positive magnitude to waive (partial or full); the backend
/// stores the component negative (locked sign convention). Never
/// deletes/rewrites an existing PENALTY component. Works against OPEN
/// or CLOSED charges alike. A WAIVER is never payable — it only reduces
/// the obligation, it does not create a payable line.
class ContributionWaiverController extends Notifier<ContributionWaiverState> {
  @override
  ContributionWaiverState build() => const ContributionWaiverState();

  Future<bool> waive({
    required String groupId,
    required String chargeId,
    required String membershipId,
    required double amount,
    required String reason,
    required DateTime effectiveAt,
    String? idempotencyKey,
  }) async {
    if (state.isSubmitting) return false;

    state = const ContributionWaiverState(isSubmitting: true);
    try {
      final result = await ref
          .read(contributionRepositoryProvider)
          .waiveContributionCharge(
            groupId: groupId,
            chargeId: chargeId,
            amount: amount,
            reason: reason,
            effectiveAt: effectiveAt,
            idempotencyKey: idempotencyKey,
          );
      ref.invalidate(contributionChargeDetailProvider(chargeId));
      ref.invalidate(memberContributionSummaryProvider(membershipId));
      ref.invalidate(contributionPeriodChargesProvider);
      ref.invalidate(memberContributionStatementProvider(membershipId));
      ref.invalidate(memberContributionChargesProvider);
      state = ContributionWaiverState(lastResult: result);
      return true;
    } on ContributionFailure catch (error) {
      state = ContributionWaiverState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to waive contribution charge', error, stackTrace);
      state = const ContributionWaiverState(
        errorType: ContributionFailureType.unexpected,
      );
      return false;
    }
  }
}

final contributionWaiverControllerProvider =
    NotifierProvider<ContributionWaiverController, ContributionWaiverState>(
      ContributionWaiverController.new,
    );
