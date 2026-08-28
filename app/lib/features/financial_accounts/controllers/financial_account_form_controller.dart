import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../data/financial_account_failure.dart';
import '../domain/financial_account.dart';
import '../providers/financial_account_detail_provider.dart';
import '../providers/financial_account_repository_provider.dart';
import '../providers/financial_accounts_list_provider.dart';

final _log = Logger('FinancialAccountFormController');

class FinancialAccountFormState {
  const FinancialAccountFormState({
    this.isSubmitting = false,
    this.errorType,
    this.lastResult,
  });

  final bool isSubmitting;
  final FinancialAccountFailureType? errorType;
  final FinancialAccount? lastResult;
}

/// Drives create/update for Prompt 08A financial accounts. Update
/// never touches anything balance-affecting (rename/activate-
/// deactivate only) — a mistaken opening balance is never editable
/// here, matching the "correction, not edit" philosophy of the
/// ledgers this account will post against.
class FinancialAccountFormController
    extends Notifier<FinancialAccountFormState> {
  @override
  FinancialAccountFormState build() => const FinancialAccountFormState();

  Future<bool> create({
    required String groupId,
    required String name,
    required String accountType,
    double? openingBalance,
    DateTime? openingBalanceDate,
  }) async {
    if (state.isSubmitting) return false;

    state = const FinancialAccountFormState(isSubmitting: true);
    try {
      final result = await ref
          .read(financialAccountRepositoryProvider)
          .createFinancialAccount(
            groupId: groupId,
            name: name,
            accountType: accountType,
            openingBalance: openingBalance,
            openingBalanceDate: openingBalanceDate,
          );
      // Whole-family invalidation — this controller has no reason to
      // know the viewer's own search/limit state for the accounts
      // list (same lesson as the Contributions charges list). The
      // active-accounts picker must also be invalidated explicitly:
      // it is a separate provider from the list, and a newly created
      // account never appeared in it otherwise (UAT-FIX-01).
      ref.invalidate(financialAccountsListProvider);
      ref.invalidate(financialAccountsActiveForPickerProvider);
      state = FinancialAccountFormState(lastResult: result);
      return true;
    } on FinancialAccountFailure catch (error) {
      state = FinancialAccountFormState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to create financial account', error, stackTrace);
      state = const FinancialAccountFormState(
        errorType: FinancialAccountFailureType.unexpected,
      );
      return false;
    }
  }

  Future<bool> update({
    required String groupId,
    required String accountId,
    String? name,
    bool? isActive,
  }) async {
    if (state.isSubmitting) return false;

    state = const FinancialAccountFormState(isSubmitting: true);
    try {
      final result = await ref
          .read(financialAccountRepositoryProvider)
          .updateFinancialAccount(
            groupId: groupId,
            accountId: accountId,
            name: name,
            isActive: isActive,
          );
      // Rename and (especially) activate/deactivate both change what
      // the active-accounts picker should show, so it must be
      // invalidated here too — not only on create (UAT-FIX-01).
      ref.invalidate(financialAccountsListProvider);
      ref.invalidate(financialAccountsActiveForPickerProvider);
      ref.invalidate(financialAccountDetailProvider(accountId));
      state = FinancialAccountFormState(lastResult: result);
      return true;
    } on FinancialAccountFailure catch (error) {
      state = FinancialAccountFormState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to update financial account', error, stackTrace);
      state = const FinancialAccountFormState(
        errorType: FinancialAccountFailureType.unexpected,
      );
      return false;
    }
  }
}

final financialAccountFormControllerProvider =
    NotifierProvider<FinancialAccountFormController, FinancialAccountFormState>(
      FinancialAccountFormController.new,
    );
