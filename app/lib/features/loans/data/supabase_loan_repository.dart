import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/loan_account.dart';
import '../domain/loan_product.dart';
import '../domain/loan_schedule_preview.dart';
import 'loan_failure.dart';
import 'loan_repository.dart';

final _log = Logger('SupabaseLoanRepository');

class SupabaseLoanRepository implements LoanRepository {
  SupabaseLoanRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<LoanProductPage> listLoanProducts({
    required String groupId,
    bool? isActive,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_list_loan_products',
        params: {
          'p_group_id': groupId,
          'p_is_active': isActive,
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      return LoanProductPage.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanProduct> getLoanProduct({
    required String groupId,
    required String productId,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_get_loan_product',
        params: {'p_group_id': groupId, 'p_product_id': productId},
      );
      return LoanProduct.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanProduct> createLoanProduct({
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
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_create_loan_product',
        params: {
          'p_group_id': groupId,
          'p_code': code,
          'p_name': name,
          'p_minimum_principal': minimumPrincipal,
          'p_minimum_term': minimumTerm,
          'p_maximum_term': maximumTerm,
          'p_interest_rate': interestRate,
          'p_interest_rate_basis': interestRateBasis,
          'p_interest_method': interestMethod,
          'p_maximum_principal': maximumPrincipal,
          'p_description': description,
        },
      );
      return LoanProduct.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanProduct> updateLoanProduct({
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
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_update_loan_product',
        params: {
          'p_group_id': groupId,
          'p_product_id': productId,
          'p_name': name,
          'p_description': description,
          'p_minimum_principal': minimumPrincipal,
          'p_maximum_principal': maximumPrincipal,
          'p_minimum_term': minimumTerm,
          'p_maximum_term': maximumTerm,
          'p_interest_rate': interestRate,
          'p_interest_rate_basis': interestRateBasis,
          'p_interest_method': interestMethod,
          'p_is_active': isActive,
        },
      );
      return LoanProduct.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanAccountPage> listLoanAccounts({
    required String groupId,
    String? membershipId,
    String? loanProductId,
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_list_loan_accounts',
        params: {
          'p_group_id': groupId,
          'p_membership_id': membershipId,
          'p_loan_product_id': loanProductId,
          'p_status': status,
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      return LoanAccountPage.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanAccount> getLoanAccount({
    required String groupId,
    required String loanAccountId,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_get_loan_account',
        params: {'p_group_id': groupId, 'p_loan_account_id': loanAccountId},
      );
      return LoanAccount.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanSchedulePreview> previewLoanSchedule({
    required String groupId,
    required String loanProductId,
    required double principalAmount,
    required int term,
    required DateTime firstRepaymentDate,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_preview_loan_schedule',
        params: {
          'p_group_id': groupId,
          'p_loan_product_id': loanProductId,
          'p_principal_amount': principalAmount,
          'p_term': term,
          'p_first_repayment_date': _dateOnly(firstRepaymentDate),
        },
      );
      return LoanSchedulePreview.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanAccount> createDraftLoanAccount({
    required String groupId,
    required String membershipId,
    required String loanProductId,
    required double principalAmount,
    required int term,
    required DateTime firstRepaymentDate,
    DateTime? proposedDisbursementDate,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_create_draft_loan_account',
        params: {
          'p_group_id': groupId,
          'p_membership_id': membershipId,
          'p_loan_product_id': loanProductId,
          'p_principal_amount': principalAmount,
          'p_term': term,
          'p_first_repayment_date': _dateOnly(firstRepaymentDate),
          'p_proposed_disbursement_date': _dateOnlyOrNull(
            proposedDisbursementDate,
          ),
        },
      );
      return LoanAccount.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanAccount> updateDraftLoanTerms({
    required String groupId,
    required String loanAccountId,
    double? principalAmount,
    int? term,
    DateTime? firstRepaymentDate,
    DateTime? proposedDisbursementDate,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_update_draft_loan_terms',
        params: {
          'p_group_id': groupId,
          'p_loan_account_id': loanAccountId,
          'p_principal_amount': principalAmount,
          'p_term': term,
          'p_first_repayment_date': _dateOnlyOrNull(firstRepaymentDate),
          'p_proposed_disbursement_date': _dateOnlyOrNull(
            proposedDisbursementDate,
          ),
        },
      );
      return LoanAccount.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanAccount> regenerateLoanSchedule({
    required String groupId,
    required String loanAccountId,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_regenerate_loan_schedule',
        params: {'p_group_id': groupId, 'p_loan_account_id': loanAccountId},
      );
      return LoanAccount.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanAccount> cancelDraftLoanAccount({
    required String groupId,
    required String loanAccountId,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_cancel_draft_loan_account',
        params: {'p_group_id': groupId, 'p_loan_account_id': loanAccountId},
      );
      return LoanAccount.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanAccount> submitLoanAccount({
    required String groupId,
    required String loanAccountId,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_submit_loan_account',
        params: {'p_group_id': groupId, 'p_loan_account_id': loanAccountId},
      );
      return LoanAccount.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanAccount> approveLoanAccount({
    required String groupId,
    required String loanAccountId,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_approve_loan_account',
        params: {'p_group_id': groupId, 'p_loan_account_id': loanAccountId},
      );
      return LoanAccount.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanAccount> rejectLoanAccount({
    required String groupId,
    required String loanAccountId,
    required String reason,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_reject_loan_account',
        params: {
          'p_group_id': groupId,
          'p_loan_account_id': loanAccountId,
          'p_reason': reason,
        },
      );
      return LoanAccount.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanAccount> cancelLoanAccount({
    required String groupId,
    required String loanAccountId,
    required String reason,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_cancel_loan_account',
        params: {
          'p_group_id': groupId,
          'p_loan_account_id': loanAccountId,
          'p_reason': reason,
        },
      );
      return LoanAccount.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanAccount> disburseLoanAccount({
    required String groupId,
    required String loanAccountId,
    required String financialAccountId,
    required DateTime effectiveAt,
    String? reference,
    String? notes,
    String? idempotencyKey,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_disburse_loan_account',
        params: {
          'p_group_id': groupId,
          'p_loan_account_id': loanAccountId,
          'p_financial_account_id': financialAccountId,
          'p_effective_at': _dateOnly(effectiveAt),
          'p_reference': reference,
          'p_notes': notes,
          'p_idempotency_key': idempotencyKey,
        },
      );
      return LoanAccount.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }
}

String _dateOnly(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String? _dateOnlyOrNull(DateTime? date) =>
    date == null ? null : _dateOnly(date);

/// Maps a backend failure to a safe, user-presentable [LoanFailure].
/// Technical details are logged, never shown to the user.
LoanFailure _mapError(Object error, StackTrace stackTrace) {
  if (error is PostgrestException) {
    _log.warning('Loan RPC error (code=${error.code})', error, stackTrace);

    final message = error.message;
    final code = error.code;

    if (message.contains('LOAN_PRODUCT_MINIMUM_PRINCIPAL_MUST_BE_POSITIVE')) {
      return const LoanFailure(
        LoanFailureType.minimumPrincipalMustBePositive,
        'The minimum principal must be greater than zero.',
      );
    }
    if (message.contains('LOAN_PRODUCT_MAXIMUM_PRINCIPAL_BELOW_MINIMUM')) {
      return const LoanFailure(
        LoanFailureType.maximumPrincipalBelowMinimum,
        'The maximum principal cannot be below the minimum.',
      );
    }
    if (message.contains('LOAN_PRODUCT_MINIMUM_TERM_MUST_BE_POSITIVE')) {
      return const LoanFailure(
        LoanFailureType.minimumTermMustBePositive,
        'The minimum term must be greater than zero.',
      );
    }
    if (message.contains('LOAN_PRODUCT_MAXIMUM_TERM_BELOW_MINIMUM')) {
      return const LoanFailure(
        LoanFailureType.maximumTermBelowMinimum,
        'The maximum term cannot be below the minimum.',
      );
    }
    if (message.contains('LOAN_PRODUCT_INTEREST_RATE_INVALID')) {
      return const LoanFailure(
        LoanFailureType.interestRateInvalid,
        'Enter a valid interest rate.',
      );
    }
    if (message.contains('LOAN_PRODUCT_INACTIVE')) {
      return const LoanFailure(
        LoanFailureType.productInactive,
        'This loan product is no longer active.',
      );
    }
    if (message.contains('LOAN_ACCOUNT_PRINCIPAL_MUST_BE_POSITIVE')) {
      return const LoanFailure(
        LoanFailureType.principalMustBePositive,
        'The principal must be greater than zero.',
      );
    }
    if (message.contains('LOAN_ACCOUNT_PRINCIPAL_BELOW_PRODUCT_MINIMUM')) {
      return const LoanFailure(
        LoanFailureType.principalBelowProductMinimum,
        'The principal is below this product'
        's minimum.',
      );
    }
    if (message.contains('LOAN_ACCOUNT_PRINCIPAL_ABOVE_PRODUCT_MAXIMUM')) {
      return const LoanFailure(
        LoanFailureType.principalAboveProductMaximum,
        'The principal is above this product'
        's maximum.',
      );
    }
    if (message.contains('LOAN_ACCOUNT_TERM_OUT_OF_PRODUCT_RANGE')) {
      return const LoanFailure(
        LoanFailureType.termOutOfProductRange,
        'The term is outside this product'
        's allowed range.',
      );
    }
    if (message.contains('LOAN_ACCOUNT_BORROWER_NOT_ACTIVE')) {
      return const LoanFailure(
        LoanFailureType.borrowerNotActive,
        'This member is not an active member of the group.',
      );
    }
    if (message.contains('LOAN_ACCOUNT_NOT_DRAFT')) {
      return const LoanFailure(
        LoanFailureType.notDraft,
        'This loan is no longer a draft and can no longer be edited.',
      );
    }
    if (message.contains('LOAN_ACCOUNT_SCHEDULE_MISSING') ||
        message.contains('LOAN_ACCOUNT_SCHEDULE_MISMATCH')) {
      return const LoanFailure(
        LoanFailureType.scheduleMismatch,
        'This loan'
        's schedule is missing or does not match its terms. '
        'Try regenerating it first.',
      );
    }
    if (message.contains('LOAN_ACCOUNT_NOT_SUBMITTED')) {
      return const LoanFailure(
        LoanFailureType.notSubmitted,
        'This loan is not awaiting approval.',
      );
    }
    if (message.contains('LOAN_ACCOUNT_REJECTION_REASON_REQUIRED')) {
      return const LoanFailure(
        LoanFailureType.rejectionReasonRequired,
        'A rejection reason is required.',
      );
    }
    if (message.contains('LOAN_ACCOUNT_CANCELLATION_REASON_REQUIRED')) {
      return const LoanFailure(
        LoanFailureType.cancellationReasonRequired,
        'A cancellation reason is required.',
      );
    }
    if (message.contains('LOAN_ACCOUNT_NOT_CANCELLABLE')) {
      return const LoanFailure(
        LoanFailureType.notCancellable,
        'This loan can no longer be cancelled.',
      );
    }
    if (message.contains('LOAN_ACCOUNT_NOT_APPROVED')) {
      return const LoanFailure(
        LoanFailureType.notApproved,
        'This loan must be approved before it can be disbursed.',
      );
    }
    if (message.contains('LOAN_ACCOUNT_ALREADY_DISBURSED')) {
      return const LoanFailure(
        LoanFailureType.alreadyDisbursed,
        'This loan has already been disbursed.',
      );
    }
    if (message.contains('FINANCIAL_ACCOUNT_INACTIVE')) {
      return const LoanFailure(
        LoanFailureType.financialAccountInactive,
        'This financial account is inactive.',
      );
    }
    if (message.contains('LOAN_DISBURSEMENT_INSUFFICIENT_BALANCE')) {
      return const LoanFailure(
        LoanFailureType.insufficientBalance,
        'The selected financial account does not have enough balance '
        'for this disbursement.',
      );
    }
    if (message.contains('name is required') ||
        message.contains('code is required')) {
      return const LoanFailure(
        LoanFailureType.nameRequired,
        'A name/code is required.',
      );
    }
    if (code == '23505') {
      return const LoanFailure(
        LoanFailureType.duplicateCode,
        'That product code is already used in this group.',
      );
    }
    if (message.contains('not found')) {
      return const LoanFailure(LoanFailureType.notFound, 'Not found.');
    }
    if (code == '42501') {
      return const LoanFailure(
        LoanFailureType.permissionDenied,
        'You do not have permission to do that.',
      );
    }

    return const LoanFailure(
      LoanFailureType.unexpected,
      'Something went wrong. Please try again.',
    );
  }

  _log.severe('Unexpected loan repository error', error, stackTrace);

  final text = error.toString().toLowerCase();
  final looksLikeNetworkError =
      text.contains('socket') ||
      text.contains('network') ||
      text.contains('connection') ||
      text.contains('failed host lookup') ||
      text.contains('timeout');

  if (looksLikeNetworkError) {
    return const LoanFailure(
      LoanFailureType.network,
      'Network error. Check your connection and try again.',
    );
  }

  return const LoanFailure(
    LoanFailureType.unexpected,
    'Something went wrong. Please try again.',
  );
}
