import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/loan_account.dart';
import '../domain/loan_historical_arrears_installment.dart';
import '../domain/loan_migration_preview.dart';
import '../domain/loan_obligation_adjustment.dart';
import '../domain/loan_penalty_charge.dart';
import '../domain/loan_product.dart';
import '../domain/loan_schedule_preview.dart';
import '../domain/loan_servicing.dart';
import '../domain/loan_write_off_recovery.dart';
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
    bool penaltyEnabled = false,
    String? penaltyType,
    String? penaltyFrequency,
    int? penaltyGraceDays,
    double? penaltyFixedAmount,
    double? penaltyRate,
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
          'p_penalty_enabled': penaltyEnabled,
          'p_penalty_type': penaltyType,
          'p_penalty_frequency': penaltyFrequency,
          'p_penalty_grace_days': penaltyGraceDays,
          'p_penalty_fixed_amount': penaltyFixedAmount,
          'p_penalty_rate': penaltyRate,
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
    bool? penaltyEnabled,
    String? penaltyType,
    String? penaltyFrequency,
    int? penaltyGraceDays,
    double? penaltyFixedAmount,
    double? penaltyRate,
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
          'p_penalty_enabled': penaltyEnabled,
          'p_penalty_type': penaltyType,
          'p_penalty_frequency': penaltyFrequency,
          'p_penalty_grace_days': penaltyGraceDays,
          'p_penalty_fixed_amount': penaltyFixedAmount,
          'p_penalty_rate': penaltyRate,
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

  @override
  Future<LoanPenaltyAssessmentResult> assessLoanPenalties({
    required String groupId,
    required DateTime assessmentDate,
    String? loanAccountId,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_assess_loan_penalties',
        params: {
          'p_group_id': groupId,
          'p_assessment_date': _dateOnly(assessmentDate),
          'p_loan_account_id': loanAccountId,
        },
      );
      return LoanPenaltyAssessmentResult.fromJson(
        result as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<List<LoanPenaltyCharge>> listLoanPenaltyCharges({
    required String groupId,
    required String loanAccountId,
    String? loanInstallmentId,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_list_loan_penalty_charges',
        params: {
          'p_group_id': groupId,
          'p_loan_account_id': loanAccountId,
          'p_loan_installment_id': loanInstallmentId,
        },
      );
      final json = result as Map<String, dynamic>;
      return (json['items'] as List<dynamic>)
          .map(
            (item) => LoanPenaltyCharge.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanAccount> createMigratedLoan({
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
    try {
      final result = await _client.rpc(
        'rpc_create_migrated_loan',
        params: {
          'p_group_id': groupId,
          'p_membership_id': membershipId,
          'p_loan_product_id': loanProductId,
          'p_original_principal': originalPrincipal,
          'p_original_disbursement_date': _dateOnly(originalDisbursementDate),
          'p_opening_as_of_date': _dateOnly(openingAsOfDate),
          'p_opening_principal_outstanding': openingPrincipalOutstanding,
          'p_historical_arrears_installments': _arrearsJson(
            historicalArrearsInstallments,
          ),
          'p_future_scheduled_interest': futureScheduledInterest,
          'p_remaining_installment_count': remainingInstallmentCount,
          'p_next_due_date': _dateOnlyOrNull(nextDueDate),
          'p_original_loan_number': originalLoanNumber,
          'p_notes': notes,
          'p_idempotency_key': idempotencyKey,
          'p_mode': mode,
          'p_contracted_interest_amount': contractedInterestAmount,
          'p_monthly_installment_amount': monthlyInstallmentAmount,
          'p_historical_unpaid_count': historicalUnpaidCount,
          'p_total_historical_arrears': totalHistoricalArrears,
          'p_original_term': originalTerm,
        },
      );
      return LoanAccount.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanMigrationPreview> previewMigratedLoan({
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
    try {
      final result = await _client.rpc(
        'rpc_preview_migrated_loan',
        params: {
          'p_group_id': groupId,
          'p_membership_id': membershipId,
          'p_loan_product_id': loanProductId,
          'p_original_principal': originalPrincipal,
          'p_opening_as_of_date': _dateOnly(openingAsOfDate),
          'p_opening_principal_outstanding': openingPrincipalOutstanding,
          'p_historical_arrears_installments': _arrearsJson(
            historicalArrearsInstallments,
          ),
          'p_future_scheduled_interest': futureScheduledInterest,
          'p_remaining_installment_count': remainingInstallmentCount,
          'p_next_due_date': _dateOnlyOrNull(nextDueDate),
          'p_mode': mode,
          'p_contracted_interest_amount': contractedInterestAmount,
          'p_monthly_installment_amount': monthlyInstallmentAmount,
          'p_historical_unpaid_count': historicalUnpaidCount,
          'p_total_historical_arrears': totalHistoricalArrears,
          'p_original_term': originalTerm,
        },
      );
      return LoanMigrationPreview.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  // -- Loan servicing (Prompt 09E) ----------------------------------------

  @override
  Future<LoanEarlySettlementQuote> previewLoanEarlySettlement({
    required String groupId,
    required String loanAccountId,
    DateTime? effectiveDate,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_preview_loan_early_settlement',
        params: {
          'p_group_id': groupId,
          'p_loan_account_id': loanAccountId,
          'p_effective_date': _dateOnlyOrNull(effectiveDate),
        },
      );
      return LoanEarlySettlementQuote.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanServicingPaymentResult> settleLoanEarly({
    required String groupId,
    required String loanAccountId,
    required String financialAccountId,
    required String paymentMethod,
    DateTime? effectiveDate,
    String? externalReference,
    String? notes,
    String? idempotencyKey,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_settle_loan_early',
        params: {
          'p_group_id': groupId,
          'p_loan_account_id': loanAccountId,
          'p_financial_account_id': financialAccountId,
          'p_payment_method': paymentMethod,
          'p_effective_date': _dateOnlyOrNull(effectiveDate),
          'p_external_reference': externalReference,
          'p_notes': notes,
          'p_idempotency_key': idempotencyKey,
        },
      );
      return LoanServicingPaymentResult.fromJson(
        result as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanPrepaymentPreview> previewLoanPrepayment({
    required String groupId,
    required String loanAccountId,
    required double amount,
    required String treatment,
    DateTime? effectiveDate,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_preview_loan_prepayment',
        params: {
          'p_group_id': groupId,
          'p_loan_account_id': loanAccountId,
          'p_amount': amount,
          'p_treatment': treatment,
          'p_effective_date': _dateOnlyOrNull(effectiveDate),
        },
      );
      return LoanPrepaymentPreview.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanServicingPaymentResult> prepayLoanPrincipal({
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
    try {
      final result = await _client.rpc(
        'rpc_prepay_loan_principal',
        params: {
          'p_group_id': groupId,
          'p_loan_account_id': loanAccountId,
          'p_amount': amount,
          'p_treatment': treatment,
          'p_financial_account_id': financialAccountId,
          'p_payment_method': paymentMethod,
          'p_effective_date': _dateOnlyOrNull(effectiveDate),
          'p_external_reference': externalReference,
          'p_notes': notes,
          'p_idempotency_key': idempotencyKey,
        },
      );
      return LoanServicingPaymentResult.fromJson(
        result as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanRestructurePreview> previewLoanRestructure({
    required String groupId,
    required String loanAccountId,
    required int newTerm,
    required DateTime newFirstInstallmentDate,
    double? newInterestRate,
    DateTime? effectiveDate,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_preview_loan_restructure',
        params: {
          'p_group_id': groupId,
          'p_loan_account_id': loanAccountId,
          'p_new_term': newTerm,
          'p_new_first_installment_date': _dateOnly(newFirstInstallmentDate),
          'p_new_interest_rate': newInterestRate,
          'p_effective_date': _dateOnlyOrNull(effectiveDate),
        },
      );
      return LoanRestructurePreview.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanAccount> restructureLoan({
    required String groupId,
    required String loanAccountId,
    required String reason,
    required int newTerm,
    required DateTime newFirstInstallmentDate,
    double? newInterestRate,
    DateTime? effectiveDate,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_restructure_loan',
        params: {
          'p_group_id': groupId,
          'p_loan_account_id': loanAccountId,
          'p_reason': reason,
          'p_new_term': newTerm,
          'p_new_first_installment_date': _dateOnly(newFirstInstallmentDate),
          'p_new_interest_rate': newInterestRate,
          'p_effective_date': _dateOnlyOrNull(effectiveDate),
        },
      );
      return LoanAccount.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanObligationWaiverPreview> previewLoanObligationWaiver({
    required String groupId,
    required String loanAccountId,
    required String targetType,
    required String targetId,
    required double amount,
    required String reasonCode,
    String? note,
    DateTime? effectiveDate,
  }) async {
    try {
      final params = <String, dynamic>{
        'p_group_id': groupId,
        'p_loan_account_id': loanAccountId,
        'p_target_type': targetType,
        'p_target_id': targetId,
        'p_amount': amount,
        'p_reason_code': reasonCode,
        'p_note': note,
      };
      final effectiveDateOnly = _dateOnlyOrNull(effectiveDate);
      if (effectiveDateOnly != null) {
        params['p_effective_date'] = effectiveDateOnly;
      }
      final result = await _client.rpc(
        'rpc_preview_loan_obligation_waiver',
        params: params,
      );
      return LoanObligationWaiverPreview.fromJson(
        result as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanObligationAdjustmentPostResult> postLoanObligationWaiver({
    required String groupId,
    required String loanAccountId,
    required String targetType,
    required String targetId,
    required double amount,
    required String reasonCode,
    String? note,
    DateTime? effectiveDate,
    String? idempotencyKey,
  }) async {
    try {
      final params = <String, dynamic>{
        'p_group_id': groupId,
        'p_loan_account_id': loanAccountId,
        'p_target_type': targetType,
        'p_target_id': targetId,
        'p_amount': amount,
        'p_reason_code': reasonCode,
        'p_note': note,
        'p_idempotency_key': idempotencyKey,
      };
      final effectiveDateOnly = _dateOnlyOrNull(effectiveDate);
      if (effectiveDateOnly != null) {
        params['p_effective_date'] = effectiveDateOnly;
      }
      final result = await _client.rpc(
        'rpc_post_loan_obligation_waiver',
        params: params,
      );
      return LoanObligationAdjustmentPostResult.fromJson(
        result as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanObligationCorrectionPreview> previewLoanObligationCorrection({
    required String groupId,
    required String loanAccountId,
    required String targetType,
    required String targetId,
    required String adjustmentType,
    required double amount,
    required String reasonCode,
    String? note,
    DateTime? effectiveDate,
  }) async {
    try {
      final params = <String, dynamic>{
        'p_group_id': groupId,
        'p_loan_account_id': loanAccountId,
        'p_target_type': targetType,
        'p_target_id': targetId,
        'p_adjustment_type': adjustmentType,
        'p_amount': amount,
        'p_reason_code': reasonCode,
        'p_note': note,
      };
      final effectiveDateOnly = _dateOnlyOrNull(effectiveDate);
      if (effectiveDateOnly != null) {
        params['p_effective_date'] = effectiveDateOnly;
      }
      final result = await _client.rpc(
        'rpc_preview_loan_obligation_correction',
        params: params,
      );
      return LoanObligationCorrectionPreview.fromJson(
        result as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanObligationAdjustmentPostResult> postLoanObligationCorrection({
    required String groupId,
    required String loanAccountId,
    required String targetType,
    required String targetId,
    required String adjustmentType,
    required double amount,
    required String reasonCode,
    String? note,
    DateTime? effectiveDate,
    String? idempotencyKey,
  }) async {
    try {
      final params = <String, dynamic>{
        'p_group_id': groupId,
        'p_loan_account_id': loanAccountId,
        'p_target_type': targetType,
        'p_target_id': targetId,
        'p_adjustment_type': adjustmentType,
        'p_amount': amount,
        'p_reason_code': reasonCode,
        'p_note': note,
        'p_idempotency_key': idempotencyKey,
      };
      final effectiveDateOnly = _dateOnlyOrNull(effectiveDate);
      if (effectiveDateOnly != null) {
        params['p_effective_date'] = effectiveDateOnly;
      }
      final result = await _client.rpc(
        'rpc_post_loan_obligation_correction',
        params: params,
      );
      return LoanObligationAdjustmentPostResult.fromJson(
        result as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanObligationAdjustmentReversalResult>
  reverseLoanObligationAdjustment({
    required String groupId,
    required String adjustmentId,
    required String reversalReason,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_reverse_loan_obligation_adjustment',
        params: {
          'p_group_id': groupId,
          'p_adjustment_id': adjustmentId,
          'p_reversal_reason': reversalReason,
        },
      );
      return LoanObligationAdjustmentReversalResult.fromJson(
        result as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanObligationAdjustmentPage> listLoanObligationAdjustments({
    required String groupId,
    required String loanAccountId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_list_loan_obligation_adjustments',
        params: {
          'p_group_id': groupId,
          'p_loan_account_id': loanAccountId,
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      return LoanObligationAdjustmentPage.fromJson(
        result as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanWriteOffPreview> previewLoanWriteOff({
    required String groupId,
    required String loanAccountId,
    required String reasonCode,
    String? note,
    DateTime? effectiveDate,
  }) async {
    try {
      final params = <String, dynamic>{
        'p_group_id': groupId,
        'p_loan_account_id': loanAccountId,
        'p_reason_code': reasonCode,
        'p_note': note,
      };
      final effectiveDateOnly = _dateOnlyOrNull(effectiveDate);
      if (effectiveDateOnly != null) {
        params['p_effective_date'] = effectiveDateOnly;
      }
      final result = await _client.rpc(
        'rpc_preview_loan_write_off',
        params: params,
      );
      return LoanWriteOffPreview.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanWriteOffPostResult> postLoanWriteOff({
    required String groupId,
    required String loanAccountId,
    required String reasonCode,
    String? note,
    DateTime? effectiveDate,
    String? idempotencyKey,
  }) async {
    try {
      final params = <String, dynamic>{
        'p_group_id': groupId,
        'p_loan_account_id': loanAccountId,
        'p_reason_code': reasonCode,
        'p_note': note,
        'p_idempotency_key': idempotencyKey,
      };
      final effectiveDateOnly = _dateOnlyOrNull(effectiveDate);
      if (effectiveDateOnly != null) {
        params['p_effective_date'] = effectiveDateOnly;
      }
      final result = await _client.rpc(
        'rpc_post_loan_write_off',
        params: params,
      );
      return LoanWriteOffPostResult.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanWriteOffReversalResult> reverseLoanWriteOff({
    required String groupId,
    required String writeOffEventId,
    required String reversalReason,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_reverse_loan_write_off',
        params: {
          'p_group_id': groupId,
          'p_write_off_event_id': writeOffEventId,
          'p_reversal_reason': reversalReason,
        },
      );
      return LoanWriteOffReversalResult.fromJson(
        result as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanRecoveryPreview> previewLoanRecovery({
    required String groupId,
    required String loanAccountId,
    required double amount,
    DateTime? effectiveDate,
  }) async {
    try {
      final params = <String, dynamic>{
        'p_group_id': groupId,
        'p_loan_account_id': loanAccountId,
        'p_amount': amount,
      };
      final effectiveDateOnly = _dateOnlyOrNull(effectiveDate);
      if (effectiveDateOnly != null) {
        params['p_effective_date'] = effectiveDateOnly;
      }
      final result = await _client.rpc(
        'rpc_preview_loan_recovery',
        params: params,
      );
      return LoanRecoveryPreview.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanRecoveryPostResult> postLoanRecovery({
    required String groupId,
    required String loanAccountId,
    required double amount,
    required String financialAccountId,
    required String paymentMethod,
    DateTime? effectiveDate,
    String? externalReference,
    String? notes,
    String? idempotencyKey,
  }) async {
    try {
      final params = <String, dynamic>{
        'p_group_id': groupId,
        'p_loan_account_id': loanAccountId,
        'p_amount': amount,
        'p_financial_account_id': financialAccountId,
        'p_payment_method': paymentMethod,
        'p_external_reference': externalReference,
        'p_notes': notes,
        'p_idempotency_key': idempotencyKey,
      };
      final effectiveDateOnly = _dateOnlyOrNull(effectiveDate);
      if (effectiveDateOnly != null) {
        params['p_effective_date'] = effectiveDateOnly;
      }
      final result = await _client.rpc(
        'rpc_post_loan_recovery',
        params: params,
      );
      return LoanRecoveryPostResult.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<LoanWriteOffSummary> getLoanWriteOffSummary({
    required String groupId,
    required String loanAccountId,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_get_loan_write_off_summary',
        params: {'p_group_id': groupId, 'p_loan_account_id': loanAccountId},
      );
      return LoanWriteOffSummary.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }
}

List<Map<String, dynamic>> _arrearsJson(
  List<LoanHistoricalArrearsInstallmentInput> installments,
) {
  return installments
      .map(
        (installment) => {
          'due_date': _dateOnly(installment.dueDate),
          'principal_outstanding': installment.principalOutstanding,
          'interest_outstanding': installment.interestOutstanding,
          'opening_penalty_outstanding': installment.openingPenaltyOutstanding,
        },
      )
      .toList(growable: false);
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
    if (message.contains('LOAN_PRODUCT_PENALTY_FIXED_AMOUNT_REQUIRED')) {
      return const LoanFailure(
        LoanFailureType.penaltyFixedAmountRequired,
        'A fixed penalty amount is required for a FIXED penalty type.',
      );
    }
    if (message.contains('LOAN_PRODUCT_PENALTY_RATE_REQUIRED')) {
      return const LoanFailure(
        LoanFailureType.penaltyRateRequired,
        'A penalty rate is required for a PERCENTAGE penalty type.',
      );
    }
    if (message.contains('LOAN_OPENING_ORIGINAL_PRINCIPAL_MUST_BE_POSITIVE')) {
      return const LoanFailure(
        LoanFailureType.openingOriginalPrincipalInvalid,
        'The original principal must be greater than zero.',
      );
    }
    if (message.contains(
      'LOAN_OPENING_PRINCIPAL_ARREARS_EXCEEDS_OUTSTANDING',
    )) {
      return const LoanFailure(
        LoanFailureType.openingPrincipalArrearsExceedsOutstanding,
        'Principal arrears cannot exceed the opening principal outstanding.',
      );
    }
    if (message.contains('LOAN_OPENING_ARREARS_DUE_DATE_REQUIRED') ||
        message.contains('LOAN_OPENING_ARREARS_DUE_DATE_AFTER_AS_OF')) {
      return const LoanFailure(
        LoanFailureType.openingArrearsDueDateInvalid,
        'Enter a valid arrears due date on or before the opening as-of date.',
      );
    }
    if (message.contains('LOAN_OPENING_ARREARS_INSTALLMENTS_INVALID') ||
        message.contains('LOAN_OPENING_ARREARS_COMPONENT_NEGATIVE') ||
        message.contains('LOAN_OPENING_ARREARS_ROW_EMPTY')) {
      return const LoanFailure(
        LoanFailureType.openingArrearsInstallmentInvalid,
        'Each historical arrears installment needs a due date and at least one positive amount.',
      );
    }
    if (message.contains('LOAN_OPENING_ARREARS_DUPLICATE_DUE_DATE')) {
      return const LoanFailure(
        LoanFailureType.openingArrearsDuplicateDueDate,
        'Two historical arrears installments cannot share the same due date.',
      );
    }
    if (message.contains('LOAN_OPENING_REMAINING_SCHEDULE_INCONSISTENT') ||
        message.contains('LOAN_OPENING_NEXT_DUE_DATE_REQUIRED')) {
      return const LoanFailure(
        LoanFailureType.openingRemainingScheduleInvalid,
        'The remaining schedule is inconsistent — check the installment count and next due date.',
      );
    }
    if (message.contains('LOAN_OPENING_SIMPLE_ARREARS_BELOW_CONTRACTUAL')) {
      return const LoanFailure(
        LoanFailureType.openingSimpleArrearsBelowContractual,
        'The total historical arrears entered is less than the contractual amount for these unpaid installments.',
      );
    }
    if (message.contains('LOAN_OPENING_SIMPLE_CONTRACTED_INTEREST_INVALID') ||
        message.contains('LOAN_OPENING_SIMPLE_INSTALLMENT_AMOUNT_INVALID') ||
        message.contains('LOAN_OPENING_SIMPLE_HISTORICAL_COUNT_INVALID') ||
        message.contains('LOAN_OPENING_SIMPLE_TOTAL_ARREARS_INVALID') ||
        message.contains('LOAN_OPENING_SIMPLE_ORIGINAL_TERM_INVALID') ||
        message.contains('LOAN_OPENING_SIMPLE_REMAINING_COUNT_INVALID') ||
        message.contains('LOAN_OPENING_SIMPLE_COUNTS_EXCEED_TERM') ||
        message.contains('LOAN_OPENING_SIMPLE_RECONSTRUCTION_INCONSISTENT') ||
        message.contains('LOAN_OPENING_MODE_INVALID')) {
      return const LoanFailure(
        LoanFailureType.openingSimpleInputInvalid,
        'Check the original loan terms entered for this Simple Import.',
      );
    }
    if (message.contains('LOAN_OPENING_NO_OUTSTANDING_POSITION')) {
      return const LoanFailure(
        LoanFailureType.openingNoOutstandingPosition,
        'There is no outstanding loan position to migrate.',
      );
    }
    if (message.contains('LOAN_PRODUCT_PENALTY_TYPE_REQUIRED') ||
        message.contains('LOAN_PRODUCT_PENALTY_FREQUENCY_REQUIRED') ||
        message.contains('LOAN_PRODUCT_PENALTY_GRACE_DAYS_INVALID')) {
      return const LoanFailure(
        LoanFailureType.penaltyConfigInvalid,
        'Complete the penalty type, frequency, and grace days.',
      );
    }
    if (message.contains('LOAN_NOT_ACTIVE')) {
      return const LoanFailure(
        LoanFailureType.loanNotActive,
        'This loan is not active.',
      );
    }
    if (message.contains('LOAN_ALREADY_FULLY_SETTLED')) {
      return const LoanFailure(
        LoanFailureType.alreadyFullySettled,
        'This loan is already fully settled.',
      );
    }
    if (message.contains('LOAN_PREPAYMENT_AMOUNT_MUST_BE_POSITIVE') ||
        message.contains('LOAN_PREPAYMENT_EXCEEDS_FUTURE_PRINCIPAL')) {
      return const LoanFailure(
        LoanFailureType.prepaymentAmountInvalid,
        'Enter a prepayment amount that does not exceed the remaining '
        'future principal.',
      );
    }
    if (message.contains('LOAN_PREPAYMENT_BLOCKED_OVERDUE_PENALTY')) {
      return const LoanFailure(
        LoanFailureType.prepaymentBlockedOverduePenalty,
        'Clear the outstanding overdue penalty with a normal payment '
        'before prepaying principal.',
      );
    }
    if (message.contains('LOAN_PREPAYMENT_BLOCKED_OVERDUE_INTEREST')) {
      return const LoanFailure(
        LoanFailureType.prepaymentBlockedOverdueInterest,
        'Clear the outstanding overdue interest with a normal payment '
        'before prepaying principal.',
      );
    }
    if (message.contains(
      'LOAN_PREPAYMENT_REVERSAL_BLOCKED_SUBSEQUENT_ACTIVITY',
    )) {
      return const LoanFailure(
        LoanFailureType.prepaymentReversalBlockedSubsequentActivity,
        'This prepayment cannot be reversed because later activity has '
        'already been recorded against its recomputed schedule.',
      );
    }
    if (message.contains('LOAN_RESTRUCTURE_REASON_REQUIRED')) {
      return const LoanFailure(
        LoanFailureType.restructureReasonRequired,
        'A restructure reason is required.',
      );
    }
    if (message.contains('LOAN_RESTRUCTURE_TERM_MUST_BE_POSITIVE') ||
        message.contains(
          'LOAN_RESTRUCTURE_FIRST_INSTALLMENT_DATE_MUST_BE_AFTER_EFFECTIVE_DATE',
        ) ||
        message.contains(
          'LOAN_RESTRUCTURE_INTEREST_RATE_MUST_BE_NON_NEGATIVE',
        )) {
      return const LoanFailure(
        LoanFailureType.restructureInputInvalid,
        'Check the proposed term, first installment date, and interest '
        'rate.',
      );
    }
    if (message.contains('LOAN_RESTRUCTURE_BLOCKED_OVERDUE_BALANCE')) {
      return const LoanFailure(
        LoanFailureType.restructureBlockedOverdueBalance,
        'Clear every overdue balance with a normal payment before '
        'restructuring this loan.',
      );
    }
    if (message.contains('LOAN_RESTRUCTURE_NOTHING_REMAINING')) {
      return const LoanFailure(
        LoanFailureType.restructureNothingRemaining,
        'There is nothing remaining on this loan to restructure.',
      );
    }
    if (message.contains('LOAN_WAIVER_EXCEEDS_OUTSTANDING')) {
      return const LoanFailure(
        LoanFailureType.waiverExceedsOutstanding,
        'The waiver amount exceeds the current outstanding amount.',
      );
    }
    if (message.contains('LOAN_ADJUSTMENT_TARGET_INVALID')) {
      return const LoanFailure(
        LoanFailureType.adjustmentTargetInvalid,
        'This obligation could not be found on this loan.',
      );
    }
    if (message.contains('LOAN_FUTURE_INTEREST_NOT_WAIVABLE')) {
      return const LoanFailure(
        LoanFailureType.futureInterestNotWaivable,
        'Future interest that is not yet due cannot be waived or corrected.',
      );
    }
    if (message.contains('LOAN_PRINCIPAL_ADJUSTMENT_PROHIBITED')) {
      return const LoanFailure(
        LoanFailureType.principalAdjustmentProhibited,
        'Principal cannot be waived or corrected.',
      );
    }
    if (message.contains('LOAN_CORRECTION_INCREASE_NOT_ALLOWED')) {
      return const LoanFailure(
        LoanFailureType.correctionIncreaseNotAllowed,
        'Interest correction increases are not allowed.',
      );
    }
    if (message.contains('LOAN_CORRECTION_INCREASE_EXCEEDS_BOUND')) {
      return const LoanFailure(
        LoanFailureType.correctionIncreaseExceedsBound,
        'This increase exceeds the maximum allowed for this penalty.',
      );
    }
    if (message.contains('LOAN_CORRECTION_INCREASE_POLICY_UNAVAILABLE')) {
      return const LoanFailure(
        LoanFailureType.correctionIncreasePolicyUnavailable,
        'This penalty has no recorded policy to base an increase on.',
      );
    }
    if (message.contains('LOAN_CORRECTION_DECREASE_EXCEEDS_OUTSTANDING')) {
      return const LoanFailure(
        LoanFailureType.correctionDecreaseExceedsOutstanding,
        'The correction amount exceeds the current outstanding amount.',
      );
    }
    if (message.contains('LOAN_FUTURE_INTEREST_NOT_CORRECTABLE')) {
      return const LoanFailure(
        LoanFailureType.futureInterestNotCorrectable,
        'Future interest that is not yet due cannot be corrected.',
      );
    }
    if (message.contains('Effective date is required')) {
      return const LoanFailure(
        LoanFailureType.adjustmentEffectiveDateRequired,
        'An effective date is required for this action.',
      );
    }
    if (message.contains('LOAN_ADJUSTMENT_AMOUNT_MUST_BE_POSITIVE')) {
      return const LoanFailure(
        LoanFailureType.adjustmentAmountInvalid,
        'Enter an amount greater than zero.',
      );
    }
    if (message.contains('LOAN_ADJUSTMENT_REASON_REQUIRED')) {
      return const LoanFailure(
        LoanFailureType.adjustmentReasonRequired,
        'Select a valid reason.',
      );
    }
    if (message.contains('LOAN_ADJUSTMENT_OTHER_NOTE_REQUIRED')) {
      return const LoanFailure(
        LoanFailureType.adjustmentOtherNoteRequired,
        'Enter a note explaining "Other".',
      );
    }
    if (message.contains('LOAN_ADJUSTMENT_ALREADY_REVERSED')) {
      return const LoanFailure(
        LoanFailureType.adjustmentAlreadyReversed,
        'This adjustment has already been reversed.',
      );
    }
    if (message.contains(
      'LOAN_ADJUSTMENT_REVERSAL_BLOCKED_SUBSEQUENT_ACTIVITY',
    )) {
      return const LoanFailure(
        LoanFailureType.adjustmentReversalBlockedSubsequentActivity,
        'This cannot be reversed because later activity has already been '
        'recorded against it.',
      );
    }
    if (message.contains('LOAN_ADJUSTMENT_REVERSAL_NOT_SUPPORTED')) {
      return const LoanFailure(
        LoanFailureType.adjustmentReversalNotSupported,
        'A reversal cannot itself be reversed.',
      );
    }
    if (message.contains('LOAN_WRITE_OFF_NOTHING_OUTSTANDING')) {
      return const LoanFailure(
        LoanFailureType.writeOffNothingOutstanding,
        'There is nothing outstanding on this loan to write off.',
      );
    }
    if (message.contains('LOAN_RECOVERY_TARGET_NOT_WRITTEN_OFF')) {
      return const LoanFailure(
        LoanFailureType.recoveryTargetNotWrittenOff,
        'This loan is not written off.',
      );
    }
    if (message.contains('LOAN_RECOVERY_EXCEEDS_REMAINING_BALANCE')) {
      return const LoanFailure(
        LoanFailureType.recoveryExceedsRemainingBalance,
        'This recovery amount exceeds the remaining recoverable balance.',
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
