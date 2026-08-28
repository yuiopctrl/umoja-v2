import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/contribution_charge_detail.dart';
import '../domain/contribution_correction_result.dart';
import '../domain/contribution_opening_balance_import_result.dart';
import '../domain/contribution_opening_balance_page.dart';
import '../domain/contribution_opening_balance_preview.dart';
import '../domain/contribution_penalty_assessment_result.dart';
import '../domain/contribution_period.dart';
import '../domain/contribution_period_open_preview.dart';
import '../domain/contribution_period_page.dart';
import '../domain/contribution_setup.dart';
import '../domain/contribution_setup_page.dart';
import '../domain/contribution_type.dart';
import '../domain/contribution_type_page.dart';
import '../domain/member_contribution_charge_page.dart';
import '../domain/member_contribution_summary.dart';
import 'contribution_failure.dart';
import 'contribution_member_amount_input.dart';
import 'contribution_opening_balance_entry_input.dart';
import 'contribution_repository.dart';

final _log = Logger('SupabaseContributionRepository');

/// [ContributionRepository] backed by the Contribution Engine RPCs.
/// Never inserts/updates the underlying tables directly — those direct
/// grants are revoked server-side (see
/// `20260823120000_create_contribution_engine_schema.sql`), so this is
/// enforced at both layers.
class SupabaseContributionRepository implements ContributionRepository {
  SupabaseContributionRepository(this._client);

  final SupabaseClient _client;

  // -- Contribution Types -------------------------------------------------

  @override
  Future<ContributionTypePage> listContributionTypes({
    required String groupId,
    String? search,
    bool? isActive,
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_list_contribution_types',
        params: {
          'p_group_id': groupId,
          'p_search': (search == null || search.trim().isEmpty)
              ? null
              : search.trim(),
          'p_is_active': isActive,
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      return ContributionTypePage.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<ContributionType> getContributionType({
    required String groupId,
    required String typeId,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_get_contribution_type',
        params: {'p_group_id': groupId, 'p_type_id': typeId},
      );
      return ContributionType.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<ContributionType> createContributionType({
    required String groupId,
    required String name,
    required String category,
    required String accountingTreatment,
    String? description,
    int displayOrder = 0,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_create_contribution_type',
        params: {
          'p_group_id': groupId,
          'p_name': name,
          'p_category': category,
          'p_accounting_treatment': accountingTreatment,
          'p_description': description,
          'p_display_order': displayOrder,
        },
      );
      return ContributionType.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<ContributionType> updateContributionType({
    required String groupId,
    required String typeId,
    String? name,
    String? description,
    String? category,
    String? accountingTreatment,
    int? displayOrder,
    bool? isActive,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_update_contribution_type',
        params: {
          'p_group_id': groupId,
          'p_type_id': typeId,
          'p_name': name,
          'p_description': description,
          'p_category': category,
          'p_accounting_treatment': accountingTreatment,
          'p_display_order': displayOrder,
          'p_is_active': isActive,
        },
      );
      return ContributionType.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  // -- Contribution Setups --------------------------------------------------

  @override
  Future<ContributionSetupPage> listContributionSetups({
    required String groupId,
    String? contributionTypeId,
    bool? isActive,
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_list_contribution_setups',
        params: {
          'p_group_id': groupId,
          'p_contribution_type_id': contributionTypeId,
          'p_is_active': isActive,
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      return ContributionSetupPage.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<ContributionSetup> getContributionSetup({
    required String groupId,
    required String setupId,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_get_contribution_setup',
        params: {'p_group_id': groupId, 'p_setup_id': setupId},
      );
      return ContributionSetup.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<ContributionSetup> createContributionSetup({
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
    try {
      final result = await _client.rpc(
        'rpc_create_contribution_setup',
        params: {
          'p_group_id': groupId,
          'p_contribution_type_id': contributionTypeId,
          'p_name': name,
          'p_schedule_mode': scheduleMode,
          'p_amount_mode': amountMode,
          'p_description': description,
          'p_fixed_amount': fixedAmount,
          'p_default_due_day': defaultDueDay,
          'p_default_due_month_offset': defaultDueMonthOffset,
          'p_penalty_mode': penaltyMode,
          'p_penalty_grace_days': penaltyGraceDays,
          'p_penalty_value': penaltyValue,
          'p_penalty_cap_amount': penaltyCapAmount,
        },
      );
      return ContributionSetup.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<ContributionSetup> updateContributionSetup({
    required String groupId,
    required String setupId,
    String? name,
    String? description,
    double? fixedAmount,
    int? defaultDueDay,
    int? defaultDueMonthOffset,
    String? penaltyMode,
    int? penaltyGraceDays,
    double? penaltyValue,
    double? penaltyCapAmount,
    bool? isActive,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_update_contribution_setup',
        params: {
          'p_group_id': groupId,
          'p_setup_id': setupId,
          'p_name': name,
          'p_description': description,
          'p_fixed_amount': fixedAmount,
          'p_default_due_day': defaultDueDay,
          'p_default_due_month_offset': defaultDueMonthOffset,
          'p_penalty_mode': penaltyMode,
          'p_penalty_grace_days': penaltyGraceDays,
          'p_penalty_value': penaltyValue,
          'p_penalty_cap_amount': penaltyCapAmount,
          'p_is_active': isActive,
        },
      );
      return ContributionSetup.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  // -- Contribution Periods ---------------------------------------------

  @override
  Future<ContributionPeriodPage> listContributionPeriods({
    required String groupId,
    String? contributionSetupId,
    String? status,
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_list_contribution_periods',
        params: {
          'p_group_id': groupId,
          'p_contribution_setup_id': contributionSetupId,
          'p_status': status,
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      return ContributionPeriodPage.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<ContributionPeriod> getContributionPeriod({
    required String groupId,
    required String periodId,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_get_contribution_period',
        params: {'p_group_id': groupId, 'p_period_id': periodId},
      );
      return ContributionPeriod.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<ContributionPeriod> createContributionPeriod({
    required String groupId,
    required String contributionSetupId,
    required String label,
    required DateTime periodStart,
    required DateTime periodEnd,
    DateTime? obligationDate,
    DateTime? eligibilityDate,
    DateTime? dueDate,
    String status = 'DRAFT',
    DateTime? scheduledOpenDate,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_create_contribution_period',
        params: {
          'p_group_id': groupId,
          'p_contribution_setup_id': contributionSetupId,
          'p_label': label,
          'p_period_start': _dateOnly(periodStart),
          'p_period_end': _dateOnly(periodEnd),
          'p_obligation_date': _dateOnlyOrNull(obligationDate),
          'p_eligibility_date': _dateOnlyOrNull(eligibilityDate),
          'p_due_date': _dateOnlyOrNull(dueDate),
          'p_status': status,
          'p_scheduled_open_date': _dateOnlyOrNull(scheduledOpenDate),
        },
      );
      return ContributionPeriod.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<ContributionPeriod> updateContributionPeriod({
    required String groupId,
    required String periodId,
    String? label,
    DateTime? periodStart,
    DateTime? periodEnd,
    DateTime? obligationDate,
    DateTime? eligibilityDate,
    DateTime? dueDate,
    DateTime? scheduledOpenDate,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_update_contribution_period',
        params: {
          'p_group_id': groupId,
          'p_period_id': periodId,
          'p_label': label,
          'p_period_start': _dateOnlyOrNull(periodStart),
          'p_period_end': _dateOnlyOrNull(periodEnd),
          'p_obligation_date': _dateOnlyOrNull(obligationDate),
          'p_eligibility_date': _dateOnlyOrNull(eligibilityDate),
          'p_due_date': _dateOnlyOrNull(dueDate),
          'p_scheduled_open_date': _dateOnlyOrNull(scheduledOpenDate),
        },
      );
      return ContributionPeriod.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<void> setContributionPeriodMemberAmounts({
    required String groupId,
    required String periodId,
    required List<ContributionMemberAmountInput> amounts,
  }) async {
    try {
      await _client.rpc(
        'rpc_set_contribution_period_member_amounts',
        params: {
          'p_group_id': groupId,
          'p_period_id': periodId,
          'p_amounts': amounts
              .map((a) => {'membership_id': a.membershipId, 'amount': a.amount})
              .toList(growable: false),
        },
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<void> excludeContributionPeriodMember({
    required String groupId,
    required String periodId,
    required String membershipId,
    String? reason,
  }) async {
    try {
      await _client.rpc(
        'rpc_exclude_contribution_period_member',
        params: {
          'p_group_id': groupId,
          'p_period_id': periodId,
          'p_membership_id': membershipId,
          'p_reason': (reason == null || reason.trim().isEmpty)
              ? null
              : reason.trim(),
        },
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<void> removeContributionPeriodMemberExclusion({
    required String groupId,
    required String periodId,
    required String membershipId,
  }) async {
    try {
      await _client.rpc(
        'rpc_remove_contribution_period_member_exclusion',
        params: {
          'p_group_id': groupId,
          'p_period_id': periodId,
          'p_membership_id': membershipId,
        },
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<ContributionPeriodOpenPreview> previewContributionPeriodOpen({
    required String groupId,
    required String periodId,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_preview_contribution_period_open',
        params: {'p_group_id': groupId, 'p_period_id': periodId},
      );
      return ContributionPeriodOpenPreview.fromJson(
        result as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<void> openContributionPeriod({
    required String groupId,
    required String periodId,
  }) async {
    try {
      // The RPC's jsonb result is a posting summary, not a full period
      // shape — deliberately not parsed here; the caller re-reads via
      // the (invalidated) period detail provider.
      await _client.rpc(
        'rpc_open_contribution_period',
        params: {'p_group_id': groupId, 'p_period_id': periodId},
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<void> enrollMemberInContributionPeriod({
    required String groupId,
    required String periodId,
    required String membershipId,
    double? amount,
  }) async {
    try {
      await _client.rpc(
        'rpc_enroll_member_in_contribution_period',
        params: {
          'p_group_id': groupId,
          'p_period_id': periodId,
          'p_membership_id': membershipId,
          'p_amount': amount,
        },
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<void> closeContributionPeriod({
    required String groupId,
    required String periodId,
  }) async {
    try {
      await _client.rpc(
        'rpc_close_contribution_period',
        params: {'p_group_id': groupId, 'p_period_id': periodId},
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<void> cancelContributionPeriod({
    required String groupId,
    required String periodId,
  }) async {
    try {
      await _client.rpc(
        'rpc_cancel_contribution_period',
        params: {'p_group_id': groupId, 'p_period_id': periodId},
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  // -- Penalty assessment (Prompt 06B) -----------------------------------

  @override
  Future<ContributionPenaltyAssessmentResult>
  assessContributionPeriodPenalties({
    required String groupId,
    required String periodId,
    DateTime? assessmentDate,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_assess_contribution_penalties',
        params: {
          'p_group_id': groupId,
          'p_period_id': periodId,
          'p_assessment_date': _dateOnlyOrNull(assessmentDate),
        },
      );
      return ContributionPenaltyAssessmentResult.fromJson(
        result as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  // -- Charges -----------------------------------------------------------

  @override
  Future<MemberContributionChargePage> listContributionPeriodCharges({
    required String groupId,
    required String periodId,
    String? search,
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_list_contribution_period_charges',
        params: {
          'p_group_id': groupId,
          'p_period_id': periodId,
          'p_search': (search == null || search.trim().isEmpty)
              ? null
              : search.trim(),
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      return MemberContributionChargePage.fromJson(
        result as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<ContributionChargeDetail> getContributionChargeDetail({
    required String groupId,
    required String chargeId,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_get_contribution_charge_detail',
        params: {'p_group_id': groupId, 'p_charge_id': chargeId},
      );
      return ContributionChargeDetail.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<MemberContributionSummary> getMemberContributionSummary({
    required String groupId,
    required String membershipId,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_get_member_contribution_summary',
        params: {'p_group_id': groupId, 'p_membership_id': membershipId},
      );
      return MemberContributionSummary.fromJson(result as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  // -- Corrections (Prompt 06C) -------------------------------------------

  @override
  Future<ContributionCorrectionResult> createContributionAdjustment({
    required String groupId,
    required String chargeId,
    required double amount,
    required String reason,
    required DateTime effectiveAt,
    String? idempotencyKey,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_create_contribution_adjustment',
        params: {
          'p_group_id': groupId,
          'p_charge_id': chargeId,
          'p_amount': amount,
          'p_reason': reason,
          'p_effective_at': _dateOnly(effectiveAt),
          'p_idempotency_key': idempotencyKey,
        },
      );
      return ContributionCorrectionResult.fromJson(
        result as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<ContributionCorrectionResult> waiveContributionCharge({
    required String groupId,
    required String chargeId,
    required double amount,
    required String reason,
    required DateTime effectiveAt,
    String? idempotencyKey,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_waive_contribution_charge',
        params: {
          'p_group_id': groupId,
          'p_charge_id': chargeId,
          'p_amount': amount,
          'p_reason': reason,
          'p_effective_at': _dateOnly(effectiveAt),
          'p_idempotency_key': idempotencyKey,
        },
      );
      return ContributionCorrectionResult.fromJson(
        result as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  // -- Opening balances (Prompt 06C) ---------------------------------------

  @override
  Future<ContributionOpeningBalancePreview>
  previewContributionOpeningBalanceImport({
    required String groupId,
    required String contributionTypeId,
    required DateTime effectiveAt,
    required List<ContributionOpeningBalanceEntryInput> entries,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_preview_contribution_opening_balance_import',
        params: {
          'p_group_id': groupId,
          'p_contribution_type_id': contributionTypeId,
          'p_effective_at': _dateOnly(effectiveAt),
          'p_entries': _entriesJson(entries),
        },
      );
      return ContributionOpeningBalancePreview.fromJson(
        result as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<ContributionOpeningBalanceImportResult>
  importContributionOpeningBalances({
    required String groupId,
    required String contributionTypeId,
    required DateTime effectiveAt,
    required List<ContributionOpeningBalanceEntryInput> entries,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_import_contribution_opening_balances',
        params: {
          'p_group_id': groupId,
          'p_contribution_type_id': contributionTypeId,
          'p_effective_at': _dateOnly(effectiveAt),
          'p_entries': _entriesJson(entries),
        },
      );
      return ContributionOpeningBalanceImportResult.fromJson(
        result as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<ContributionOpeningBalancePage> listContributionOpeningBalances({
    required String groupId,
    String? contributionTypeId,
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final result = await _client.rpc(
        'rpc_list_contribution_opening_balances',
        params: {
          'p_group_id': groupId,
          'p_contribution_type_id': contributionTypeId,
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      return ContributionOpeningBalancePage.fromJson(
        result as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }
}

List<Map<String, dynamic>> _entriesJson(
  List<ContributionOpeningBalanceEntryInput> entries,
) {
  return entries
      .map((e) => {'membership_id': e.membershipId, 'amount': e.amount})
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

/// Maps a backend failure to a safe, user-presentable
/// [ContributionFailure]. Technical details are logged, never shown to
/// the user. Classifies by the stable message/errcode contract the
/// Contribution Engine RPCs raise (see the migration files under
/// `supabase/migrations/2026082312*`–`2026082314*`): specific `P0001`
/// codes as distinct raised messages, plus standard SQLSTATEs (42501
/// permission denied, 22023 not found/invalid input, 23505 duplicate).
ContributionFailure _mapError(Object error, StackTrace stackTrace) {
  if (error is PostgrestException) {
    _log.warning(
      'Contribution RPC error (code=${error.code})',
      error,
      stackTrace,
    );

    final message = error.message;
    final code = error.code;

    if (message.contains('MEMBER_SAVINGS_NOT_AVAILABLE')) {
      return const ContributionFailure(
        ContributionFailureType.memberSavingsNotAvailable,
        'MEMBER_SAVINGS is not available yet.',
      );
    }
    if (message.contains('CONTRIBUTION_TYPE_ACCOUNTING_LOCKED')) {
      return const ContributionFailure(
        ContributionFailureType.accountingLocked,
        'Category/accounting treatment is locked once a period has posted charges.',
      );
    }
    if (message.contains('CONTRIBUTION_SETUP_CONFIG_LOCKED')) {
      return const ContributionFailure(
        ContributionFailureType.setupConfigLocked,
        'This configuration is locked once a period has posted charges.',
      );
    }
    if (message.contains('CONTRIBUTION_TYPE_INACTIVE')) {
      return const ContributionFailure(
        ContributionFailureType.typeInactive,
        'This contribution type is inactive.',
      );
    }
    if (message.contains('CONTRIBUTION_SETUP_INACTIVE')) {
      return const ContributionFailure(
        ContributionFailureType.setupInactive,
        'This contribution setup is inactive.',
      );
    }
    if (message.contains('DUE_DATE_REQUIRED')) {
      return const ContributionFailure(
        ContributionFailureType.dueDateRequired,
        'A due date is required.',
      );
    }
    if (message.contains('DUPLICATE_MONTHLY_PERIOD')) {
      return const ContributionFailure(
        ContributionFailureType.duplicateMonthlyPeriod,
        'A period already exists for this month.',
      );
    }
    if (message.contains('CONTRIBUTION_PERIOD_NOT_EDITABLE')) {
      return const ContributionFailure(
        ContributionFailureType.periodNotEditable,
        'This period can no longer be edited.',
      );
    }
    if (message.contains('CONTRIBUTION_SETUP_NOT_CUSTOM_AMOUNT')) {
      return const ContributionFailure(
        ContributionFailureType.setupNotCustomAmount,
        'This setup does not use per-member amounts.',
      );
    }
    if (message.contains('CONTRIBUTION_PERIOD_NOT_PREVIEWABLE')) {
      return const ContributionFailure(
        ContributionFailureType.periodNotPreviewable,
        'This period can no longer be previewed for opening.',
      );
    }
    if (message.contains('MISSING_CUSTOM_AMOUNTS')) {
      return const ContributionFailure(
        ContributionFailureType.missingCustomAmounts,
        'Some eligible members are missing a configured amount.',
      );
    }
    if (message.contains('CONTRIBUTION_PERIOD_NOT_OPENABLE')) {
      return const ContributionFailure(
        ContributionFailureType.periodNotOpenable,
        'This period can no longer be opened.',
      );
    }
    if (message.contains('CONTRIBUTION_PERIOD_NOT_OPEN')) {
      return const ContributionFailure(
        ContributionFailureType.periodNotOpen,
        'This period is not open.',
      );
    }
    if (message.contains('CONTRIBUTION_PERIOD_NO_PENALTY_POLICY')) {
      return const ContributionFailure(
        ContributionFailureType.noPenaltyPolicy,
        'This period has no penalty policy configured.',
      );
    }
    if (message.contains('ADJUSTMENT_AMOUNT_REQUIRED')) {
      return const ContributionFailure(
        ContributionFailureType.adjustmentAmountRequired,
        'An adjustment amount is required and cannot be zero.',
      );
    }
    if (message.contains('ADJUSTMENT_REASON_REQUIRED')) {
      return const ContributionFailure(
        ContributionFailureType.adjustmentReasonRequired,
        'A reason is required for this adjustment.',
      );
    }
    if (message.contains('ADJUSTMENT_WOULD_MAKE_OBLIGATION_NEGATIVE')) {
      return const ContributionFailure(
        ContributionFailureType.adjustmentWouldMakeObligationNegative,
        'This adjustment would make the obligation negative.',
      );
    }
    if (message.contains('WAIVER_AMOUNT_MUST_BE_POSITIVE')) {
      return const ContributionFailure(
        ContributionFailureType.waiverAmountMustBePositive,
        'The waiver amount must be a positive number.',
      );
    }
    if (message.contains('WAIVER_REASON_REQUIRED')) {
      return const ContributionFailure(
        ContributionFailureType.waiverReasonRequired,
        'A reason is required for this waiver.',
      );
    }
    if (message.contains('WAIVER_EXCEEDS_NET_ASSESSED')) {
      return const ContributionFailure(
        ContributionFailureType.waiverExceedsNetAssessed,
        'This waiver exceeds the current net assessed obligation.',
      );
    }
    if (message.contains('OPENING_BALANCE_AMOUNT_MUST_BE_POSITIVE')) {
      return const ContributionFailure(
        ContributionFailureType.openingBalanceAmountMustBePositive,
        'Opening balance amounts must be positive.',
      );
    }
    if (message.contains('OPENING_BALANCE_ALREADY_IMPORTED')) {
      return const ContributionFailure(
        ContributionFailureType.openingBalanceAlreadyImported,
        'An opening balance for this member has already been imported.',
      );
    }
    if (message.contains('MEMBER_ALREADY_CHARGED_FOR_PERIOD')) {
      return const ContributionFailure(
        ContributionFailureType.memberAlreadyCharged,
        'This member already has a charge for this period.',
      );
    }
    if (message.contains('AMOUNT_REQUIRED')) {
      return const ContributionFailure(
        ContributionFailureType.amountRequired,
        'An amount is required.',
      );
    }
    if (message.contains('CONTRIBUTION_PERIOD_NOT_CANCELLABLE')) {
      return const ContributionFailure(
        ContributionFailureType.periodNotCancellable,
        'This period can no longer be cancelled.',
      );
    }
    if (message.contains('Invalid period dates')) {
      return const ContributionFailure(
        ContributionFailureType.invalidDates,
        'Invalid period dates.',
      );
    }
    if (message.contains('Amount must be greater than zero')) {
      return const ContributionFailure(
        ContributionFailureType.invalidAmount,
        'Amount must be greater than zero.',
      );
    }
    if (message.contains('Membership not found in group')) {
      return const ContributionFailure(
        ContributionFailureType.membershipNotFound,
        'Member not found.',
      );
    }
    if (code == '23505') {
      return const ContributionFailure(
        ContributionFailureType.duplicateName,
        'That name is already used in this group.',
      );
    }
    if (message.contains('name is required') ||
        message.contains('cannot be blank') ||
        message.contains('label is required')) {
      return const ContributionFailure(
        ContributionFailureType.nameRequired,
        'A name is required.',
      );
    }
    if (message.contains('not found')) {
      return const ContributionFailure(
        ContributionFailureType.notFound,
        'Not found.',
      );
    }
    if (code == '42501') {
      return const ContributionFailure(
        ContributionFailureType.permissionDenied,
        'You do not have permission to do that.',
      );
    }

    return const ContributionFailure(
      ContributionFailureType.unexpected,
      'Something went wrong. Please try again.',
    );
  }

  _log.severe('Unexpected contribution repository error', error, stackTrace);

  final text = error.toString().toLowerCase();
  final looksLikeNetworkError =
      text.contains('socket') ||
      text.contains('network') ||
      text.contains('connection') ||
      text.contains('failed host lookup') ||
      text.contains('timeout');

  if (looksLikeNetworkError) {
    return const ContributionFailure(
      ContributionFailureType.network,
      'Network error. Check your connection and try again.',
    );
  }

  return const ContributionFailure(
    ContributionFailureType.unexpected,
    'Something went wrong. Please try again.',
  );
}
