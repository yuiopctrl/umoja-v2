import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../data/loan_failure.dart';
import '../domain/loan_product.dart';
import '../providers/loan_product_detail_provider.dart';
import '../providers/loan_products_provider.dart';
import '../providers/loan_repository_provider.dart';

final _log = Logger('LoanProductFormController');

class LoanProductFormState {
  const LoanProductFormState({
    this.isSubmitting = false,
    this.errorType,
    this.lastResult,
  });

  final bool isSubmitting;
  final LoanFailureType? errorType;
  final LoanProduct? lastResult;
}

/// Drives create/update for Prompt 09A loan products. Editing a
/// product never affects loan accounts already created from it — see
/// docs/product/loans.md's snapshot rule; only the product's own
/// future eligibility (and its `isActive` gate) changes here.
class LoanProductFormController extends Notifier<LoanProductFormState> {
  @override
  LoanProductFormState build() => const LoanProductFormState();

  Future<bool> create({
    required String groupId,
    required String code,
    required String name,
    required double minimumPrincipal,
    required int minimumTerm,
    required int maximumTerm,
    required double interestRate,
    required String interestRateBasis,
    required String interestMethod,
    double? maximumPrincipal,
    String? description,
    bool penaltyEnabled = false,
    String? penaltyType,
    String? penaltyFrequency,
    int? penaltyGraceDays,
    double? penaltyFixedAmount,
    double? penaltyRate,
  }) async {
    if (state.isSubmitting) return false;

    state = const LoanProductFormState(isSubmitting: true);
    try {
      final result = await ref
          .read(loanRepositoryProvider)
          .createLoanProduct(
            groupId: groupId,
            code: code,
            name: name,
            minimumPrincipal: minimumPrincipal,
            minimumTerm: minimumTerm,
            maximumTerm: maximumTerm,
            interestRate: interestRate,
            interestRateBasis: interestRateBasis,
            interestMethod: interestMethod,
            maximumPrincipal: maximumPrincipal,
            description: description,
            penaltyEnabled: penaltyEnabled,
            penaltyType: penaltyType,
            penaltyFrequency: penaltyFrequency,
            penaltyGraceDays: penaltyGraceDays,
            penaltyFixedAmount: penaltyFixedAmount,
            penaltyRate: penaltyRate,
          );
      ref.invalidate(loanProductsProvider);
      ref.invalidate(activeLoanProductsForPickerProvider);
      state = LoanProductFormState(lastResult: result);
      return true;
    } on LoanFailure catch (error) {
      state = LoanProductFormState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to create loan product', error, stackTrace);
      state = const LoanProductFormState(errorType: LoanFailureType.unexpected);
      return false;
    }
  }

  Future<bool> update({
    required String groupId,
    required String productId,
    String? name,
    String? description,
    double? minimumPrincipal,
    double? maximumPrincipal,
    int? minimumTerm,
    int? maximumTerm,
    double? interestRate,
    String? interestRateBasis,
    String? interestMethod,
    bool? isActive,
    bool? penaltyEnabled,
    String? penaltyType,
    String? penaltyFrequency,
    int? penaltyGraceDays,
    double? penaltyFixedAmount,
    double? penaltyRate,
  }) async {
    if (state.isSubmitting) return false;

    state = const LoanProductFormState(isSubmitting: true);
    try {
      final result = await ref
          .read(loanRepositoryProvider)
          .updateLoanProduct(
            groupId: groupId,
            productId: productId,
            name: name,
            description: description,
            minimumPrincipal: minimumPrincipal,
            maximumPrincipal: maximumPrincipal,
            minimumTerm: minimumTerm,
            maximumTerm: maximumTerm,
            interestRate: interestRate,
            interestRateBasis: interestRateBasis,
            interestMethod: interestMethod,
            isActive: isActive,
            penaltyEnabled: penaltyEnabled,
            penaltyType: penaltyType,
            penaltyFrequency: penaltyFrequency,
            penaltyGraceDays: penaltyGraceDays,
            penaltyFixedAmount: penaltyFixedAmount,
            penaltyRate: penaltyRate,
          );
      ref.invalidate(loanProductsProvider);
      ref.invalidate(activeLoanProductsForPickerProvider);
      ref.invalidate(loanProductDetailProvider(productId));
      state = LoanProductFormState(lastResult: result);
      return true;
    } on LoanFailure catch (error) {
      state = LoanProductFormState(errorType: error.type);
      return false;
    } catch (error, stackTrace) {
      _log.warning('Failed to update loan product', error, stackTrace);
      state = const LoanProductFormState(errorType: LoanFailureType.unexpected);
      return false;
    }
  }
}

final loanProductFormControllerProvider =
    NotifierProvider<LoanProductFormController, LoanProductFormState>(
      LoanProductFormController.new,
    );
