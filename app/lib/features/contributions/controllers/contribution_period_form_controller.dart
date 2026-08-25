import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../data/contribution_failure.dart';
import '../domain/contribution_period.dart';
import '../providers/contribution_period_detail_provider.dart';
import '../providers/contribution_period_open_preview_provider.dart';
import '../providers/contribution_periods_list_provider.dart';
import '../providers/contribution_repository_provider.dart';

final _log = Logger('ContributionPeriodFormController');

class ContributionPeriodFormState {
  const ContributionPeriodFormState({
    this.isSubmitting = false,
    this.errorType,
  });

  final bool isSubmitting;
  final ContributionFailureType? errorType;
}

/// Drives contribution-period creation and editing. Creation always
/// creates DRAFT or SCHEDULED (the only statuses the backend accepts
/// directly); OPEN only ever happens through the explicit
/// open-preview-and-confirm flow. Editing
/// (`rpc_update_contribution_period`) only ever succeeds while the
/// period is still DRAFT/SCHEDULED — `contribution_setup_id` can never
/// change, and no member charges are ever created or touched by an
/// edit.
class ContributionPeriodFormController
    extends Notifier<ContributionPeriodFormState> {
  @override
  ContributionPeriodFormState build() => const ContributionPeriodFormState();

  Future<ContributionPeriod?> createPeriod({
    required String groupId,
    required String contributionSetupId,
    required String label,
    required DateTime periodStart,
    required DateTime periodEnd,
    DateTime? obligationDate,
    DateTime? eligibilityDate,
    DateTime? dueDate,
    String status = 'DRAFT',
    DateTime? scheduledOpenDate,
  }) async {
    if (state.isSubmitting) return null;

    final trimmedLabel = label.trim();
    if (trimmedLabel.isEmpty) {
      state = const ContributionPeriodFormState(
        errorType: ContributionFailureType.nameRequired,
      );
      return null;
    }
    if (periodStart.isAfter(periodEnd)) {
      state = const ContributionPeriodFormState(
        errorType: ContributionFailureType.invalidDates,
      );
      return null;
    }

    state = const ContributionPeriodFormState(isSubmitting: true);
    try {
      final period = await ref
          .read(contributionRepositoryProvider)
          .createContributionPeriod(
            groupId: groupId,
            contributionSetupId: contributionSetupId,
            label: trimmedLabel,
            periodStart: periodStart,
            periodEnd: periodEnd,
            obligationDate: obligationDate,
            eligibilityDate: eligibilityDate,
            dueDate: dueDate,
            status: status,
            scheduledOpenDate: scheduledOpenDate,
          );
      ref.invalidate(contributionPeriodsListProvider);
      state = const ContributionPeriodFormState();
      return period;
    } on ContributionFailure catch (error) {
      state = ContributionPeriodFormState(errorType: error.type);
      return null;
    } catch (error, stackTrace) {
      _log.warning('Failed to create contribution period', error, stackTrace);
      state = const ContributionPeriodFormState(
        errorType: ContributionFailureType.unexpected,
      );
      return null;
    }
  }

  Future<bool> updatePeriod({
    required String groupId,
    required String periodId,
    required String label,
    required DateTime periodStart,
    required DateTime periodEnd,
    DateTime? obligationDate,
    DateTime? eligibilityDate,
    DateTime? dueDate,
    DateTime? scheduledOpenDate,
  }) async {
    if (state.isSubmitting) return false;

    final trimmedLabel = label.trim();
    if (trimmedLabel.isEmpty) {
      state = const ContributionPeriodFormState(
        errorType: ContributionFailureType.nameRequired,
      );
      return false;
    }
    if (periodStart.isAfter(periodEnd)) {
      state = const ContributionPeriodFormState(
        errorType: ContributionFailureType.invalidDates,
      );
      return false;
    }

    state = const ContributionPeriodFormState(isSubmitting: true);
    try {
      await ref
          .read(contributionRepositoryProvider)
          .updateContributionPeriod(
            groupId: groupId,
            periodId: periodId,
            label: trimmedLabel,
            periodStart: periodStart,
            periodEnd: periodEnd,
            obligationDate: obligationDate,
            eligibilityDate: eligibilityDate,
            dueDate: dueDate,
            scheduledOpenDate: scheduledOpenDate,
          );
      ref.invalidate(contributionPeriodsListProvider);
      ref.invalidate(contributionPeriodDetailProvider(periodId));
      ref.invalidate(contributionPeriodOpenPreviewProvider(periodId));
      state = const ContributionPeriodFormState();
      return true;
    } on ContributionFailure catch (error) {
      state = ContributionPeriodFormState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to update contribution period', error, stackTrace);
      state = const ContributionPeriodFormState(
        errorType: ContributionFailureType.unexpected,
      );
      return false;
    }
  }
}

final contributionPeriodFormControllerProvider =
    NotifierProvider<
      ContributionPeriodFormController,
      ContributionPeriodFormState
    >(ContributionPeriodFormController.new);
