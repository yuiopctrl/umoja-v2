import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../data/contribution_failure.dart';
import '../providers/contribution_period_charges_provider.dart';
import '../providers/contribution_period_detail_provider.dart';
import '../providers/contribution_repository_provider.dart';

final _log = Logger('ContributionPeriodEnrollController');

class ContributionPeriodEnrollState {
  const ContributionPeriodEnrollState({
    this.isSubmitting = false,
    this.errorType,
  });

  final bool isSubmitting;
  final ContributionFailureType? errorType;
}

/// Drives explicit post-open member enrollment
/// (`rpc_enroll_member_in_contribution_period`) — OPEN periods only.
/// [amount] is required for a CUSTOM_PER_MEMBER setup and ignored for a
/// FIXED one (the backend uses the setup's fixed amount either way).
class ContributionPeriodEnrollController
    extends Notifier<ContributionPeriodEnrollState> {
  @override
  ContributionPeriodEnrollState build() =>
      const ContributionPeriodEnrollState();

  Future<bool> enroll({
    required String groupId,
    required String periodId,
    required String membershipId,
    required bool isCustomAmount,
    double? amount,
  }) async {
    if (state.isSubmitting) return false;

    if (isCustomAmount && (amount == null || amount <= 0)) {
      state = const ContributionPeriodEnrollState(
        errorType: ContributionFailureType.amountRequired,
      );
      return false;
    }

    state = const ContributionPeriodEnrollState(isSubmitting: true);
    try {
      await ref
          .read(contributionRepositoryProvider)
          .enrollMemberInContributionPeriod(
            groupId: groupId,
            periodId: periodId,
            membershipId: membershipId,
            amount: isCustomAmount ? amount : null,
          );
    } on ContributionFailure catch (error) {
      state = ContributionPeriodEnrollState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning(
        'Failed to enroll member in contribution period',
        error,
        stackTrace,
      );
      state = const ContributionPeriodEnrollState(
        errorType: ContributionFailureType.unexpected,
      );
      return false;
    }

    state = const ContributionPeriodEnrollState();
    ref.invalidate(contributionPeriodDetailProvider(periodId));
    // Whole-family invalidation: contributionPeriodChargesProvider is
    // keyed on the viewer's own search/limit, which this controller has
    // no reason to know — invalidating every instance is what actually
    // refreshes a charges list the user already has open.
    ref.invalidate(contributionPeriodChargesProvider);
    return true;
  }
}

final contributionPeriodEnrollControllerProvider =
    NotifierProvider<
      ContributionPeriodEnrollController,
      ContributionPeriodEnrollState
    >(ContributionPeriodEnrollController.new);
