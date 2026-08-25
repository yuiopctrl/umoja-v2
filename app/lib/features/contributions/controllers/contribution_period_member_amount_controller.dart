import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../data/contribution_failure.dart';
import '../data/contribution_member_amount_input.dart';
import '../providers/contribution_period_detail_provider.dart';
import '../providers/contribution_period_open_preview_provider.dart';
import '../providers/contribution_repository_provider.dart';

final _log = Logger('ContributionPeriodMemberAmountController');

class ContributionPeriodMemberAmountState {
  const ContributionPeriodMemberAmountState({
    this.isSubmitting = false,
    this.errorType,
  });

  final bool isSubmitting;
  final ContributionFailureType? errorType;
}

/// Drives the custom per-member amount editor
/// (`rpc_set_contribution_period_member_amounts`) for a DRAFT/SCHEDULED
/// CUSTOM_PER_MEMBER period — batches every edited row into one atomic
/// call rather than one RPC call per member.
class ContributionPeriodMemberAmountController
    extends Notifier<ContributionPeriodMemberAmountState> {
  @override
  ContributionPeriodMemberAmountState build() =>
      const ContributionPeriodMemberAmountState();

  Future<bool> setAmounts({
    required String groupId,
    required String periodId,
    required List<ContributionMemberAmountInput> amounts,
  }) async {
    if (state.isSubmitting) return false;

    state = const ContributionPeriodMemberAmountState(isSubmitting: true);
    try {
      await ref
          .read(contributionRepositoryProvider)
          .setContributionPeriodMemberAmounts(
            groupId: groupId,
            periodId: periodId,
            amounts: amounts,
          );
    } on ContributionFailure catch (error) {
      state = ContributionPeriodMemberAmountState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning(
        'Failed to set contribution period member amounts',
        error,
        stackTrace,
      );
      state = const ContributionPeriodMemberAmountState(
        errorType: ContributionFailureType.unexpected,
      );
      return false;
    }

    state = const ContributionPeriodMemberAmountState();
    ref.invalidate(contributionPeriodDetailProvider(periodId));
    ref.invalidate(contributionPeriodOpenPreviewProvider(periodId));
    return true;
  }
}

final contributionPeriodMemberAmountControllerProvider =
    NotifierProvider<
      ContributionPeriodMemberAmountController,
      ContributionPeriodMemberAmountState
    >(ContributionPeriodMemberAmountController.new);
