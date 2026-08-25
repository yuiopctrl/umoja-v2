import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../data/contribution_failure.dart';
import '../domain/contribution_type.dart';
import '../providers/contribution_repository_provider.dart';
import '../providers/contribution_type_detail_provider.dart';
import '../providers/contribution_type_picker_provider.dart';
import '../providers/contribution_types_list_provider.dart';

final _log = Logger('ContributionTypeFormController');

class ContributionTypeFormState {
  const ContributionTypeFormState({this.isSubmitting = false, this.errorType});

  final bool isSubmitting;

  /// `null` means no error. Localize via `contributionFailureMessage`
  /// (see `core/localization/failure_messages.dart`).
  final ContributionFailureType? errorType;
}

/// Drives both contribution-type creation and editing. MEMBER_SAVINGS is
/// rejected here — before the RPC is ever called — so the disabled
/// picker state in the form is backed by real validation, not just a
/// hope that the backend's `MEMBER_SAVINGS_NOT_AVAILABLE` error never
/// surfaces.
class ContributionTypeFormController
    extends Notifier<ContributionTypeFormState> {
  @override
  ContributionTypeFormState build() => const ContributionTypeFormState();

  Future<ContributionType?> createType({
    required String groupId,
    required String name,
    required String category,
    required String accountingTreatment,
    String? description,
    int displayOrder = 0,
  }) async {
    if (state.isSubmitting) return null;

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      state = const ContributionTypeFormState(
        errorType: ContributionFailureType.nameRequired,
      );
      return null;
    }
    if (accountingTreatment == 'MEMBER_SAVINGS') {
      state = const ContributionTypeFormState(
        errorType: ContributionFailureType.memberSavingsNotAvailable,
      );
      return null;
    }

    state = const ContributionTypeFormState(isSubmitting: true);
    try {
      final type = await ref
          .read(contributionRepositoryProvider)
          .createContributionType(
            groupId: groupId,
            name: trimmedName,
            category: category,
            accountingTreatment: accountingTreatment,
            description: _normalizeOptional(description),
            displayOrder: displayOrder,
          );
      ref.invalidate(contributionTypesListProvider);
      ref.invalidate(contributionActiveTypesForPickerProvider);
      state = const ContributionTypeFormState();
      return type;
    } on ContributionFailure catch (error) {
      state = ContributionTypeFormState(errorType: error.type);
      return null;
    } catch (error, stackTrace) {
      _log.warning('Failed to create contribution type', error, stackTrace);
      state = const ContributionTypeFormState(
        errorType: ContributionFailureType.unexpected,
      );
      return null;
    }
  }

  Future<bool> updateType({
    required String groupId,
    required String typeId,
    required String name,
    required String category,
    required String accountingTreatment,
    String? description,
    int? displayOrder,
    bool? isActive,
  }) async {
    if (state.isSubmitting) return false;

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      state = const ContributionTypeFormState(
        errorType: ContributionFailureType.nameRequired,
      );
      return false;
    }
    if (accountingTreatment == 'MEMBER_SAVINGS') {
      state = const ContributionTypeFormState(
        errorType: ContributionFailureType.memberSavingsNotAvailable,
      );
      return false;
    }

    state = const ContributionTypeFormState(isSubmitting: true);
    try {
      await ref
          .read(contributionRepositoryProvider)
          .updateContributionType(
            groupId: groupId,
            typeId: typeId,
            name: trimmedName,
            category: category,
            accountingTreatment: accountingTreatment,
            description: _normalizeOptional(description),
            displayOrder: displayOrder,
            isActive: isActive,
          );
      ref.invalidate(contributionTypesListProvider);
      ref.invalidate(contributionTypeDetailProvider(typeId));
      ref.invalidate(contributionActiveTypesForPickerProvider);
      state = const ContributionTypeFormState();
      return true;
    } on ContributionFailure catch (error) {
      state = ContributionTypeFormState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to update contribution type', error, stackTrace);
      state = const ContributionTypeFormState(
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

final contributionTypeFormControllerProvider =
    NotifierProvider<ContributionTypeFormController, ContributionTypeFormState>(
      ContributionTypeFormController.new,
    );
