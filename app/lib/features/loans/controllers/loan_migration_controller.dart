import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../data/loan_failure.dart';
import '../domain/loan_account.dart';
import '../domain/loan_historical_arrears_installment.dart';
import '../domain/loan_migration_preview.dart';
import '../providers/loan_accounts_provider.dart';
import '../providers/loan_repository_provider.dart';

final _log = Logger('LoanMigrationController');

class LoanMigrationState {
  const LoanMigrationState({
    this.isSubmitting = false,
    this.errorType,
    this.lastResult,
  });

  final bool isSubmitting;
  final LoanFailureType? errorType;
  final LoanAccount? lastResult;
}

/// Drives `rpc_create_migrated_loan()` (Prompt 09D-UAT-BLOCKER-01) —
/// the ONE atomic way to onboard a loan already funded before the
/// group started using Umoja. Never computes accounting figures
/// itself; only forwards what the Review step already displayed.
class LoanMigrationController extends Notifier<LoanMigrationState> {
  @override
  LoanMigrationState build() => const LoanMigrationState();

  void reset() {
    state = const LoanMigrationState();
  }

  Future<bool> post({
    required String groupId,
    required String membershipId,
    required String loanProductId,
    required double originalPrincipal,
    required DateTime originalDisbursementDate,
    required DateTime openingAsOfDate,
    required double openingPrincipalOutstanding,
    List<LoanHistoricalArrearsInstallmentInput> historicalArrearsInstallments =
        const [],
    required double futureScheduledInterest,
    required int remainingInstallmentCount,
    DateTime? nextDueDate,
    String? originalLoanNumber,
    String? notes,
    String? idempotencyKey,
    String mode = 'DETAILED',
    double? contractedInterestAmount,
    double? monthlyInstallmentAmount,
    int? historicalUnpaidCount,
    double? totalHistoricalArrears,
    int? originalTerm,
  }) async {
    if (state.isSubmitting) return false;
    state = const LoanMigrationState(isSubmitting: true);
    try {
      final result = await ref
          .read(loanRepositoryProvider)
          .createMigratedLoan(
            groupId: groupId,
            membershipId: membershipId,
            loanProductId: loanProductId,
            originalPrincipal: originalPrincipal,
            originalDisbursementDate: originalDisbursementDate,
            openingAsOfDate: openingAsOfDate,
            openingPrincipalOutstanding: openingPrincipalOutstanding,
            historicalArrearsInstallments: historicalArrearsInstallments,
            futureScheduledInterest: futureScheduledInterest,
            remainingInstallmentCount: remainingInstallmentCount,
            nextDueDate: nextDueDate,
            originalLoanNumber: originalLoanNumber,
            notes: notes,
            idempotencyKey: idempotencyKey,
            mode: mode,
            contractedInterestAmount: contractedInterestAmount,
            monthlyInstallmentAmount: monthlyInstallmentAmount,
            historicalUnpaidCount: historicalUnpaidCount,
            totalHistoricalArrears: totalHistoricalArrears,
            originalTerm: originalTerm,
          );
      ref.invalidate(loanAccountsProvider);
      state = LoanMigrationState(lastResult: result);
      return true;
    } on LoanFailure catch (error) {
      state = LoanMigrationState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to post migrated loan', error, stackTrace);
      state = const LoanMigrationState(errorType: LoanFailureType.unexpected);
      return false;
    }
  }
}

final loanMigrationControllerProvider =
    NotifierProvider<LoanMigrationController, LoanMigrationState>(
      LoanMigrationController.new,
    );

class LoanMigrationPreviewState {
  const LoanMigrationPreviewState({
    this.isLoading = false,
    this.errorType,
    this.preview,
  });

  final bool isLoading;
  final LoanFailureType? errorType;
  final LoanMigrationPreview? preview;
}

/// Drives `rpc_preview_migrated_loan()` (Prompt 09D-UAT-BLOCKER-03) — a
/// server-authoritative, non-persisting preview required before Post.
/// Never itself computes principal/interest/penalty figures; it only
/// forwards raw contract inputs and displays whatever the server
/// returns.
class LoanMigrationPreviewController
    extends Notifier<LoanMigrationPreviewState> {
  @override
  LoanMigrationPreviewState build() => const LoanMigrationPreviewState();

  void reset() {
    state = const LoanMigrationPreviewState();
  }

  Future<bool> preview({
    required String groupId,
    required String membershipId,
    required String loanProductId,
    required double originalPrincipal,
    required DateTime openingAsOfDate,
    double? openingPrincipalOutstanding,
    List<LoanHistoricalArrearsInstallmentInput> historicalArrearsInstallments =
        const [],
    double futureScheduledInterest = 0,
    int remainingInstallmentCount = 0,
    DateTime? nextDueDate,
    String mode = 'DETAILED',
    double? contractedInterestAmount,
    double? monthlyInstallmentAmount,
    int? historicalUnpaidCount,
    double? totalHistoricalArrears,
    int? originalTerm,
  }) async {
    if (state.isLoading) return false;
    state = const LoanMigrationPreviewState(isLoading: true);
    try {
      final result = await ref
          .read(loanRepositoryProvider)
          .previewMigratedLoan(
            groupId: groupId,
            membershipId: membershipId,
            loanProductId: loanProductId,
            originalPrincipal: originalPrincipal,
            openingAsOfDate: openingAsOfDate,
            openingPrincipalOutstanding: openingPrincipalOutstanding,
            historicalArrearsInstallments: historicalArrearsInstallments,
            futureScheduledInterest: futureScheduledInterest,
            remainingInstallmentCount: remainingInstallmentCount,
            nextDueDate: nextDueDate,
            mode: mode,
            contractedInterestAmount: contractedInterestAmount,
            monthlyInstallmentAmount: monthlyInstallmentAmount,
            historicalUnpaidCount: historicalUnpaidCount,
            totalHistoricalArrears: totalHistoricalArrears,
            originalTerm: originalTerm,
          );
      state = LoanMigrationPreviewState(preview: result);
      return true;
    } on LoanFailure catch (error) {
      state = LoanMigrationPreviewState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to preview migrated loan', error, stackTrace);
      state = const LoanMigrationPreviewState(
        errorType: LoanFailureType.unexpected,
      );
      return false;
    }
  }
}

final loanMigrationPreviewControllerProvider =
    NotifierProvider<LoanMigrationPreviewController, LoanMigrationPreviewState>(
      LoanMigrationPreviewController.new,
    );
