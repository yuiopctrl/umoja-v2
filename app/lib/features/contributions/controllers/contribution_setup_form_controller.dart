import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../data/contribution_failure.dart';
import '../domain/contribution_setup.dart';
import '../providers/contribution_repository_provider.dart';
import '../providers/contribution_setup_detail_provider.dart';
import '../providers/contribution_setup_picker_provider.dart';
import '../providers/contribution_setups_list_provider.dart';

final _log = Logger('ContributionSetupFormController');

class ContributionSetupFormState {
  const ContributionSetupFormState({this.isSubmitting = false, this.errorType});

  final bool isSubmitting;

  /// `null` means no error. Localize via `contributionFailureMessage`.
  final ContributionFailureType? errorType;
}

/// Drives both contribution-setup creation and editing. Validates the
/// progressive-disclosure rules client-side before ever calling the
/// RPC, so a user never hits a raw Postgres CHECK-constraint error:
/// `fixedAmount` is required (and positive) for FIXED, forbidden for
/// CUSTOM_PER_MEMBER; penalty fields are required when `penaltyMode` is
/// not NONE, and cleared when it is.
class ContributionSetupFormController
    extends Notifier<ContributionSetupFormState> {
  @override
  ContributionSetupFormState build() => const ContributionSetupFormState();

  ContributionFailureType? _validate({
    required String name,
    required String amountMode,
    double? fixedAmount,
    required String penaltyMode,
    int? penaltyGraceDays,
    double? penaltyValue,
    double? penaltyCapAmount,
  }) {
    if (name.trim().isEmpty) return ContributionFailureType.nameRequired;

    if (amountMode == 'FIXED' && (fixedAmount == null || fixedAmount <= 0)) {
      return ContributionFailureType.invalidAmount;
    }

    if (penaltyMode != 'NONE' && (penaltyValue == null || penaltyValue <= 0)) {
      return ContributionFailureType.invalidAmount;
    }

    return null;
  }

  Future<ContributionSetup?> createSetup({
    required String groupId,
    required String contributionTypeId,
    required String name,
    required String scheduleMode,
    required String amountMode,
    String? description,
    double? fixedAmount,
    int? defaultDueDay,
    int? defaultDueMonthOffset,
    String penaltyMode = 'NONE',
    int? penaltyGraceDays,
    double? penaltyValue,
    double? penaltyCapAmount,
  }) async {
    if (state.isSubmitting) return null;

    final error = _validate(
      name: name,
      amountMode: amountMode,
      fixedAmount: fixedAmount,
      penaltyMode: penaltyMode,
      penaltyGraceDays: penaltyGraceDays,
      penaltyValue: penaltyValue,
      penaltyCapAmount: penaltyCapAmount,
    );
    if (error != null) {
      state = ContributionSetupFormState(errorType: error);
      return null;
    }

    state = const ContributionSetupFormState(isSubmitting: true);
    try {
      final setup = await ref
          .read(contributionRepositoryProvider)
          .createContributionSetup(
            groupId: groupId,
            contributionTypeId: contributionTypeId,
            name: name.trim(),
            scheduleMode: scheduleMode,
            amountMode: amountMode,
            description: _normalizeOptional(description),
            fixedAmount: amountMode == 'FIXED' ? fixedAmount : null,
            defaultDueDay: defaultDueDay,
            defaultDueMonthOffset: defaultDueMonthOffset,
            penaltyMode: penaltyMode,
            penaltyGraceDays: penaltyMode == 'NONE' ? null : penaltyGraceDays,
            penaltyValue: penaltyMode == 'NONE' ? null : penaltyValue,
            penaltyCapAmount: penaltyMode == 'NONE' ? null : penaltyCapAmount,
          );
      ref.invalidate(contributionSetupsListProvider);
      ref.invalidate(contributionActiveSetupsForPickerProvider);
      state = const ContributionSetupFormState();
      return setup;
    } on ContributionFailure catch (error) {
      state = ContributionSetupFormState(errorType: error.type);
      return null;
    } catch (error, stackTrace) {
      _log.warning('Failed to create contribution setup', error, stackTrace);
      state = const ContributionSetupFormState(
        errorType: ContributionFailureType.unexpected,
      );
      return null;
    }
  }

  Future<bool> updateSetup({
    required String groupId,
    required String setupId,
    required String name,
    required String amountMode,
    String? description,
    double? fixedAmount,
    int? defaultDueDay,
    int? defaultDueMonthOffset,
    required String penaltyMode,
    int? penaltyGraceDays,
    double? penaltyValue,
    double? penaltyCapAmount,
    bool? isActive,
  }) async {
    if (state.isSubmitting) return false;

    final error = _validate(
      name: name,
      amountMode: amountMode,
      fixedAmount: fixedAmount,
      penaltyMode: penaltyMode,
      penaltyGraceDays: penaltyGraceDays,
      penaltyValue: penaltyValue,
      penaltyCapAmount: penaltyCapAmount,
    );
    if (error != null) {
      state = ContributionSetupFormState(errorType: error);
      return false;
    }

    state = const ContributionSetupFormState(isSubmitting: true);
    try {
      await ref
          .read(contributionRepositoryProvider)
          .updateContributionSetup(
            groupId: groupId,
            setupId: setupId,
            name: name.trim(),
            description: _normalizeOptional(description),
            fixedAmount: amountMode == 'FIXED' ? fixedAmount : null,
            defaultDueDay: defaultDueDay,
            defaultDueMonthOffset: defaultDueMonthOffset,
            penaltyMode: penaltyMode,
            penaltyGraceDays: penaltyMode == 'NONE' ? null : penaltyGraceDays,
            penaltyValue: penaltyMode == 'NONE' ? null : penaltyValue,
            penaltyCapAmount: penaltyMode == 'NONE' ? null : penaltyCapAmount,
            isActive: isActive,
          );
      ref.invalidate(contributionSetupsListProvider);
      ref.invalidate(contributionSetupDetailProvider(setupId));
      ref.invalidate(contributionActiveSetupsForPickerProvider);
      state = const ContributionSetupFormState();
      return true;
    } on ContributionFailure catch (error) {
      state = ContributionSetupFormState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to update contribution setup', error, stackTrace);
      state = const ContributionSetupFormState(
        errorType: ContributionFailureType.unexpected,
      );
      return false;
    }
  }
}

String? _normalizeOptional(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

final contributionSetupFormControllerProvider =
    NotifierProvider<
      ContributionSetupFormController,
      ContributionSetupFormState
    >(ContributionSetupFormController.new);
