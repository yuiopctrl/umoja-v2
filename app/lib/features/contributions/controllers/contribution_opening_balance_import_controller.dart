import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../data/contribution_failure.dart';
import '../data/contribution_opening_balance_entry_input.dart';
import '../domain/contribution_opening_balance_import_result.dart';
import '../domain/contribution_opening_balance_preview.dart';
import '../providers/contribution_opening_balances_list_provider.dart';
import '../providers/contribution_repository_provider.dart';

final _log = Logger('ContributionOpeningBalanceImportController');

class ContributionOpeningBalanceImportState {
  const ContributionOpeningBalanceImportState({
    this.isPreviewing = false,
    this.isImporting = false,
    this.errorType,
    this.preview,
    this.lastImportResult,
  });

  final bool isPreviewing;
  final bool isImporting;
  final ContributionFailureType? errorType;

  /// Server-authoritative preview — the batch screen shows
  /// member_count/total/already_imported flags exactly as returned
  /// here, never recomputed client-side.
  final ContributionOpeningBalancePreview? preview;
  final ContributionOpeningBalanceImportResult? lastImportResult;
}

/// Drives Prompt 06C's opening-balance batch import: preview
/// (`rpc_preview_contribution_opening_balance_import`, read-only) then
/// confirm (`rpc_import_contribution_opening_balances`, atomic
/// all-or-nothing). Never computes a batch total or duplicate-import
/// flag client-side.
class ContributionOpeningBalanceImportController
    extends Notifier<ContributionOpeningBalanceImportState> {
  @override
  ContributionOpeningBalanceImportState build() =>
      const ContributionOpeningBalanceImportState();

  void reset() {
    state = const ContributionOpeningBalanceImportState();
  }

  Future<bool> preview({
    required String groupId,
    required String contributionTypeId,
    required DateTime effectiveAt,
    required List<ContributionOpeningBalanceEntryInput> entries,
  }) async {
    if (state.isPreviewing || state.isImporting) return false;

    state = const ContributionOpeningBalanceImportState(isPreviewing: true);
    try {
      final preview = await ref
          .read(contributionRepositoryProvider)
          .previewContributionOpeningBalanceImport(
            groupId: groupId,
            contributionTypeId: contributionTypeId,
            effectiveAt: effectiveAt,
            entries: entries,
          );
      state = ContributionOpeningBalanceImportState(preview: preview);
      return true;
    } on ContributionFailure catch (error) {
      state = ContributionOpeningBalanceImportState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning(
        'Failed to preview contribution opening balance import',
        error,
        stackTrace,
      );
      state = const ContributionOpeningBalanceImportState(
        errorType: ContributionFailureType.unexpected,
      );
      return false;
    }
  }

  Future<bool> confirmImport({
    required String groupId,
    required String contributionTypeId,
    required DateTime effectiveAt,
    required List<ContributionOpeningBalanceEntryInput> entries,
  }) async {
    if (state.isPreviewing || state.isImporting) return false;

    state = ContributionOpeningBalanceImportState(
      isImporting: true,
      preview: state.preview,
    );
    try {
      final result = await ref
          .read(contributionRepositoryProvider)
          .importContributionOpeningBalances(
            groupId: groupId,
            contributionTypeId: contributionTypeId,
            effectiveAt: effectiveAt,
            entries: entries,
          );
      ref.invalidate(contributionOpeningBalancesListProvider);
      state = ContributionOpeningBalanceImportState(lastImportResult: result);
      return true;
    } on ContributionFailure catch (error) {
      state = ContributionOpeningBalanceImportState(
        errorType: error.type,
        preview: state.preview,
      );
      return false;
    } catch (error, stackTrace) {
      _log.warning(
        'Failed to import contribution opening balances',
        error,
        stackTrace,
      );
      state = ContributionOpeningBalanceImportState(
        errorType: ContributionFailureType.unexpected,
        preview: state.preview,
      );
      return false;
    }
  }
}

final contributionOpeningBalanceImportControllerProvider =
    NotifierProvider<
      ContributionOpeningBalanceImportController,
      ContributionOpeningBalanceImportState
    >(ContributionOpeningBalanceImportController.new);
