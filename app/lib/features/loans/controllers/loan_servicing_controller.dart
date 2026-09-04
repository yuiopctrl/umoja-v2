import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../financial_accounts/providers/financial_position_provider.dart';
import '../data/loan_failure.dart';
import '../domain/loan_servicing.dart';
import '../providers/loan_account_detail_provider.dart';
import '../providers/loan_accounts_provider.dart';
import '../providers/loan_repository_provider.dart';

final _log = Logger('LoanServicingController');

/// Prompt 09E: Early Settlement, Principal Prepayment, and Restructure
/// each follow the SAME mandatory shape — Input -> Server Preview ->
/// Review accounting impact -> Confirm/Post — so each controller below
/// holds a server-computed preview/quote that is cleared the instant
/// any input changes (stale-preview invalidation), and posting always
/// independently re-validates/recomputes server-side; nothing here is
/// ever trusted as authoritative input to the write RPC.

class LoanEarlySettlementState {
  const LoanEarlySettlementState({
    this.isPreviewing = false,
    this.isSubmitting = false,
    this.errorType,
    this.quote,
    this.result,
  });

  final bool isPreviewing;
  final bool isSubmitting;
  final LoanFailureType? errorType;
  final LoanEarlySettlementQuote? quote;
  final LoanServicingPaymentResult? result;
}

class LoanEarlySettlementController extends Notifier<LoanEarlySettlementState> {
  @override
  LoanEarlySettlementState build() => const LoanEarlySettlementState();

  /// Clears any previously fetched quote — call whenever an input the
  /// quote depends on changes, so a stale quote can never be confirmed
  /// against.
  void invalidateQuote() {
    if (state.quote == null) return;
    state = const LoanEarlySettlementState();
  }

  Future<bool> preview({
    required String groupId,
    required String loanAccountId,
    DateTime? effectiveDate,
  }) async {
    if (state.isPreviewing) return false;
    state = const LoanEarlySettlementState(isPreviewing: true);
    try {
      final quote = await ref
          .read(loanRepositoryProvider)
          .previewLoanEarlySettlement(
            groupId: groupId,
            loanAccountId: loanAccountId,
            effectiveDate: effectiveDate,
          );
      state = LoanEarlySettlementState(quote: quote);
      return true;
    } on LoanFailure catch (error) {
      state = LoanEarlySettlementState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to preview early settlement', error, stackTrace);
      state = const LoanEarlySettlementState(
        errorType: LoanFailureType.unexpected,
      );
      return false;
    }
  }

  Future<bool> confirm({
    required String groupId,
    required String loanAccountId,
    required String financialAccountId,
    required String paymentMethod,
    DateTime? effectiveDate,
    String? externalReference,
    String? notes,
    String? idempotencyKey,
  }) async {
    if (state.isSubmitting || state.quote == null) return false;
    state = LoanEarlySettlementState(isSubmitting: true, quote: state.quote);
    try {
      final result = await ref
          .read(loanRepositoryProvider)
          .settleLoanEarly(
            groupId: groupId,
            loanAccountId: loanAccountId,
            financialAccountId: financialAccountId,
            paymentMethod: paymentMethod,
            effectiveDate: effectiveDate,
            externalReference: externalReference,
            notes: notes,
            idempotencyKey: idempotencyKey,
          );
      ref.invalidate(loanAccountDetailProvider(loanAccountId));
      ref.invalidate(loanAccountsProvider);
      ref.invalidate(financialPositionProvider);
      state = LoanEarlySettlementState(result: result);
      return true;
    } on LoanFailure catch (error) {
      state = LoanEarlySettlementState(
        errorType: error.type,
        quote: state.quote,
      );
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to settle loan early', error, stackTrace);
      state = LoanEarlySettlementState(
        errorType: LoanFailureType.unexpected,
        quote: state.quote,
      );
      return false;
    }
  }
}

final loanEarlySettlementControllerProvider =
    NotifierProvider<LoanEarlySettlementController, LoanEarlySettlementState>(
      LoanEarlySettlementController.new,
    );

class LoanPrepaymentState {
  const LoanPrepaymentState({
    this.isPreviewing = false,
    this.isSubmitting = false,
    this.errorType,
    this.preview,
    this.result,
  });

  final bool isPreviewing;
  final bool isSubmitting;
  final LoanFailureType? errorType;
  final LoanPrepaymentPreview? preview;
  final LoanServicingPaymentResult? result;
}

class LoanPrepaymentController extends Notifier<LoanPrepaymentState> {
  @override
  LoanPrepaymentState build() => const LoanPrepaymentState();

  void invalidatePreview() {
    if (state.preview == null) return;
    state = const LoanPrepaymentState();
  }

  Future<bool> preview({
    required String groupId,
    required String loanAccountId,
    required double amount,
    required String treatment,
    DateTime? effectiveDate,
  }) async {
    if (state.isPreviewing) return false;
    state = const LoanPrepaymentState(isPreviewing: true);
    try {
      final preview = await ref
          .read(loanRepositoryProvider)
          .previewLoanPrepayment(
            groupId: groupId,
            loanAccountId: loanAccountId,
            amount: amount,
            treatment: treatment,
            effectiveDate: effectiveDate,
          );
      state = LoanPrepaymentState(preview: preview);
      return true;
    } on LoanFailure catch (error) {
      state = LoanPrepaymentState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to preview prepayment', error, stackTrace);
      state = const LoanPrepaymentState(errorType: LoanFailureType.unexpected);
      return false;
    }
  }

  Future<bool> confirm({
    required String groupId,
    required String loanAccountId,
    required double amount,
    required String treatment,
    required String financialAccountId,
    required String paymentMethod,
    DateTime? effectiveDate,
    String? externalReference,
    String? notes,
    String? idempotencyKey,
  }) async {
    if (state.isSubmitting || state.preview == null) return false;
    state = LoanPrepaymentState(isSubmitting: true, preview: state.preview);
    try {
      final result = await ref
          .read(loanRepositoryProvider)
          .prepayLoanPrincipal(
            groupId: groupId,
            loanAccountId: loanAccountId,
            amount: amount,
            treatment: treatment,
            financialAccountId: financialAccountId,
            paymentMethod: paymentMethod,
            effectiveDate: effectiveDate,
            externalReference: externalReference,
            notes: notes,
            idempotencyKey: idempotencyKey,
          );
      ref.invalidate(loanAccountDetailProvider(loanAccountId));
      ref.invalidate(loanAccountsProvider);
      ref.invalidate(financialPositionProvider);
      state = LoanPrepaymentState(result: result);
      return true;
    } on LoanFailure catch (error) {
      state = LoanPrepaymentState(
        errorType: error.type,
        preview: state.preview,
      );
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to prepay loan principal', error, stackTrace);
      state = LoanPrepaymentState(
        errorType: LoanFailureType.unexpected,
        preview: state.preview,
      );
      return false;
    }
  }
}

final loanPrepaymentControllerProvider =
    NotifierProvider<LoanPrepaymentController, LoanPrepaymentState>(
      LoanPrepaymentController.new,
    );

class LoanRestructureState {
  const LoanRestructureState({
    this.isPreviewing = false,
    this.isSubmitting = false,
    this.errorType,
    this.preview,
    this.confirmed = false,
  });

  final bool isPreviewing;
  final bool isSubmitting;
  final LoanFailureType? errorType;
  final LoanRestructurePreview? preview;
  final bool confirmed;
}

class LoanRestructureController extends Notifier<LoanRestructureState> {
  @override
  LoanRestructureState build() => const LoanRestructureState();

  void invalidatePreview() {
    if (state.preview == null) return;
    state = const LoanRestructureState();
  }

  Future<bool> preview({
    required String groupId,
    required String loanAccountId,
    required int newTerm,
    required DateTime newFirstInstallmentDate,
    double? newInterestRate,
    DateTime? effectiveDate,
  }) async {
    if (state.isPreviewing) return false;
    state = const LoanRestructureState(isPreviewing: true);
    try {
      final preview = await ref
          .read(loanRepositoryProvider)
          .previewLoanRestructure(
            groupId: groupId,
            loanAccountId: loanAccountId,
            newTerm: newTerm,
            newFirstInstallmentDate: newFirstInstallmentDate,
            newInterestRate: newInterestRate,
            effectiveDate: effectiveDate,
          );
      state = LoanRestructureState(preview: preview);
      return true;
    } on LoanFailure catch (error) {
      state = LoanRestructureState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to preview restructure', error, stackTrace);
      state = const LoanRestructureState(errorType: LoanFailureType.unexpected);
      return false;
    }
  }

  Future<bool> confirm({
    required String groupId,
    required String loanAccountId,
    required String reason,
    required int newTerm,
    required DateTime newFirstInstallmentDate,
    double? newInterestRate,
    DateTime? effectiveDate,
  }) async {
    if (state.isSubmitting || state.preview == null) return false;
    state = LoanRestructureState(isSubmitting: true, preview: state.preview);
    try {
      await ref
          .read(loanRepositoryProvider)
          .restructureLoan(
            groupId: groupId,
            loanAccountId: loanAccountId,
            reason: reason,
            newTerm: newTerm,
            newFirstInstallmentDate: newFirstInstallmentDate,
            newInterestRate: newInterestRate,
            effectiveDate: effectiveDate,
          );
      ref.invalidate(loanAccountDetailProvider(loanAccountId));
      ref.invalidate(loanAccountsProvider);
      state = LoanRestructureState(preview: state.preview, confirmed: true);
      return true;
    } on LoanFailure catch (error) {
      state = LoanRestructureState(
        errorType: error.type,
        preview: state.preview,
      );
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to restructure loan', error, stackTrace);
      state = LoanRestructureState(
        errorType: LoanFailureType.unexpected,
        preview: state.preview,
      );
      return false;
    }
  }
}

final loanRestructureControllerProvider =
    NotifierProvider<LoanRestructureController, LoanRestructureState>(
      LoanRestructureController.new,
    );
