import '../domain/contribution_penalty_assessment_result.dart';
import '../domain/contribution_period.dart';
import '../domain/contribution_period_open_preview.dart';
import '../domain/contribution_period_page.dart';
import '../domain/contribution_setup.dart';
import '../domain/contribution_setup_page.dart';
import '../domain/contribution_type.dart';
import '../domain/contribution_type_page.dart';
import '../domain/member_contribution_charge_page.dart';
import 'contribution_member_amount_input.dart';

/// Abstraction over the Contribution Engine backend RPCs. UI/controllers
/// depend on this, never on the Supabase SDK directly — every mutation
/// and read goes through the SECURITY DEFINER RPCs added by the
/// `2026082312*`/`2026082313*`/`2026082314*` migrations; this
/// abstraction never performs a direct table read/insert/update.
///
/// Obligation side only — no payments, allocations, wallet, or cashbook
/// concept exists here or anywhere below this interface.
///
/// Implementations must throw [ContributionFailure] (never a raw SDK
/// exception) for anything that should be shown to the user.
abstract class ContributionRepository {
  // -- Contribution Types ---------------------------------------------

  Future<ContributionTypePage> listContributionTypes({
    required String groupId,
    String? search,
    bool? isActive,
    int limit = 10,
    int offset = 0,
  });

  Future<ContributionType> getContributionType({
    required String groupId,
    required String typeId,
  });

  /// [accountingTreatment] of `MEMBER_SAVINGS` must never reach this
  /// call — reject it in the form before submitting (see
  /// `ContributionTypeFormController`).
  Future<ContributionType> createContributionType({
    required String groupId,
    required String name,
    required String category,
    required String accountingTreatment,
    String? description,
    int displayOrder = 0,
  });

  Future<ContributionType> updateContributionType({
    required String groupId,
    required String typeId,
    String? name,
    String? description,
    String? category,
    String? accountingTreatment,
    int? displayOrder,
    bool? isActive,
  });

  // -- Contribution Setups ----------------------------------------------

  Future<ContributionSetupPage> listContributionSetups({
    required String groupId,
    String? contributionTypeId,
    bool? isActive,
    int limit = 10,
    int offset = 0,
  });

  Future<ContributionSetup> getContributionSetup({
    required String groupId,
    required String setupId,
  });

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
  });

  /// Amount/due-day/penalty fields are rejected server-side
  /// (`CONTRIBUTION_SETUP_CONFIG_LOCKED`) once a period under this setup
  /// has posted charges — the form should disable those fields rather
  /// than let the user hit that error, but this call still surfaces it
  /// if reached.
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
  });

  // -- Contribution Periods ---------------------------------------------

  Future<ContributionPeriodPage> listContributionPeriods({
    required String groupId,
    String? contributionSetupId,
    String? status,
    int limit = 10,
    int offset = 0,
  });

  Future<ContributionPeriod> getContributionPeriod({
    required String groupId,
    required String periodId,
  });

  /// Creates a DRAFT or SCHEDULED period only — the backend rejects any
  /// other [status]. Never creates member charges (only
  /// [openContributionPeriod] does). The returned period's [due_date]
  /// is the authoritative due date to show immediately after creation —
  /// Flutter never re-derives it.
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
  });

  /// Updates a DRAFT/SCHEDULED period's pre-open configuration
  /// (`rpc_update_contribution_period`; `CONTRIBUTION_PERIOD_NOT_EDITABLE`
  /// once OPEN/CLOSED/CANCELLED). `contributionSetupId` can never
  /// change — there is no parameter for it, matching
  /// [updateContributionSetup]/[updateContributionType]'s precedent of
  /// simply omitting the immutable parent reference. A `null` argument
  /// leaves that field unchanged; no charges are ever created or
  /// touched by this call.
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
  });

  /// Batches the whole [amounts] array into one call, atomic on the
  /// backend. Only valid while the period is DRAFT/SCHEDULED and its
  /// setup is CUSTOM_PER_MEMBER.
  Future<void> setContributionPeriodMemberAmounts({
    required String groupId,
    required String periodId,
    required List<ContributionMemberAmountInput> amounts,
  });

  /// Pre-open exclusion only — no charge exists yet to forgive, so this
  /// is never described as a "waiver" anywhere in the UI. Only valid
  /// while the period is DRAFT/SCHEDULED.
  Future<void> excludeContributionPeriodMember({
    required String groupId,
    required String periodId,
    required String membershipId,
    String? reason,
  });

  Future<void> removeContributionPeriodMemberExclusion({
    required String groupId,
    required String periodId,
    required String membershipId,
  });

  /// Server-authoritative, read-only preview of what
  /// [openContributionPeriod] would post — no mutation.
  Future<ContributionPeriodOpenPreview> previewContributionPeriodOpen({
    required String groupId,
    required String periodId,
  });

  /// Atomic, idempotent: posts `member_contribution_charges` for every
  /// eligible member and freezes the type/setup configuration snapshot.
  /// Returns `void` — the caller re-reads via [getContributionPeriod]
  /// (its own provider is invalidated by the calling controller) rather
  /// than trusting this call's summary shape, matching
  /// `MemberRepository.changeStatus`'s reasoning.
  Future<void> openContributionPeriod({
    required String groupId,
    required String periodId,
  });

  /// Explicit post-open enrollment for one member into an already-OPEN
  /// period. [amount] is required (and must be positive) for a
  /// CUSTOM_PER_MEMBER setup; ignored (the setup's fixed amount is used)
  /// for a FIXED setup.
  Future<void> enrollMemberInContributionPeriod({
    required String groupId,
    required String periodId,
    required String membershipId,
    double? amount,
  });

  Future<void> closeContributionPeriod({
    required String groupId,
    required String periodId,
  });

  /// Only valid while the period is DRAFT/SCHEDULED — an OPEN period can
  /// never become CANCELLED (it can only be closed).
  Future<void> cancelContributionPeriod({
    required String groupId,
    required String periodId,
  });

  // -- Penalty assessment (Prompt 06B) -----------------------------------

  /// Atomic, idempotent, server-authoritative penalty assessment for one
  /// OPEN period as of [assessmentDate] (defaults to today — deterministic
  /// and auditable rather than an implicit `now()`). Uses only the
  /// period's frozen snapshot penalty configuration; a later edit to the
  /// live setup can never affect an already-OPEN period's penalties.
  /// Rejects a period with no penalty policy configured, or one that is
  /// not currently OPEN. Never calculates an amount client-side — this
  /// only reports what the backend actually posted.
  Future<ContributionPenaltyAssessmentResult>
  assessContributionPeriodPenalties({
    required String groupId,
    required String periodId,
    DateTime? assessmentDate,
  });

  // -- Charges -----------------------------------------------------------

  /// Base amount only — deliberately no paid/unpaid/balance field
  /// anywhere in this shape or its callers; there is no payments module
  /// yet.
  Future<MemberContributionChargePage> listContributionPeriodCharges({
    required String groupId,
    required String periodId,
    String? search,
    int limit = 10,
    int offset = 0,
  });
}
