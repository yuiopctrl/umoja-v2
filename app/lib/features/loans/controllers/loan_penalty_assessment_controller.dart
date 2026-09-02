import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../financial_accounts/providers/financial_position_provider.dart';
import '../data/loan_failure.dart';
import '../domain/loan_penalty_charge.dart';
import '../providers/loan_account_detail_provider.dart';
import '../providers/loan_accounts_provider.dart';
import '../providers/loan_penalty_charges_provider.dart';
import '../providers/loan_repository_provider.dart';

final _log = Logger('LoanPenaltyAssessmentController');

class LoanPenaltyAssessmentState {
  const LoanPenaltyAssessmentState({
    this.isSubmitting = false,
    this.errorType,
    this.lastResult,
  });

  final bool isSubmitting;
  final LoanFailureType? errorType;
  final LoanPenaltyAssessmentResult? lastResult;
}

/// Drives `rpc_assess_loan_penalties()` (Prompt 09D) — the ONE
/// server-authoritative penalty assessment action. Flutter never
/// computes or posts a penalty amount itself; this controller only
/// triggers the run and surfaces its structured result.
class LoanPenaltyAssessmentController
    extends Notifier<LoanPenaltyAssessmentState> {
  @override
  LoanPenaltyAssessmentState build() => const LoanPenaltyAssessmentState();

  Future<bool> assess({
    required String groupId,
    required DateTime assessmentDate,
    String? loanAccountId,
  }) async {
    if (state.isSubmitting) return false;
    state = const LoanPenaltyAssessmentState(isSubmitting: true);
    try {
      final result = await ref
          .read(loanRepositoryProvider)
          .assessLoanPenalties(
            groupId: groupId,
            assessmentDate: assessmentDate,
            loanAccountId: loanAccountId,
          );
      ref.invalidate(loanAccountsProvider);
      if (loanAccountId != null) {
        ref.invalidate(loanAccountDetailProvider(loanAccountId));
        ref.invalidate(loanPenaltyChargesProvider(loanAccountId));
      }
      ref.invalidate(financialPositionProvider);
      state = LoanPenaltyAssessmentState(lastResult: result);
      return true;
    } on LoanFailure catch (error) {
      state = LoanPenaltyAssessmentState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to assess loan penalties', error, stackTrace);
      state = const LoanPenaltyAssessmentState(
        errorType: LoanFailureType.unexpected,
      );
      return false;
    }
  }
}

final loanPenaltyAssessmentControllerProvider =
    NotifierProvider<
      LoanPenaltyAssessmentController,
      LoanPenaltyAssessmentState
    >(LoanPenaltyAssessmentController.new);
