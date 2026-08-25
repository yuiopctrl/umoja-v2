/// Coarse, user-presentable classification of a Contributions-management
/// failure — either from the backend, or (for the `*Required`/
/// `memberSavingsNotAvailable` local-validation cases) a purely local
/// check that never reaches it. UI code should switch on
/// [ContributionFailure.type] (or this enum directly), never
/// pattern-match [ContributionFailure.message] strings — see
/// `core/localization/failure_messages.dart` for the localized text per
/// case.
enum ContributionFailureType {
  /// Local + backend: a contribution type/setup name, or a period
  /// label, was blank.
  nameRequired,

  /// Local + backend (`MEMBER_SAVINGS_NOT_AVAILABLE`): MEMBER_SAVINGS is
  /// reserved/deferred and must never be selectable, but the backend
  /// still rejects it defensively.
  memberSavingsNotAvailable,

  /// `CONTRIBUTION_TYPE_ACCOUNTING_LOCKED`: category/accounting
  /// treatment cannot change once a period under this type has posted
  /// charges (OPEN/CLOSED).
  accountingLocked,

  /// `CONTRIBUTION_SETUP_CONFIG_LOCKED`: amount/due-day/penalty
  /// configuration cannot change once a period under this setup has
  /// posted charges (OPEN/CLOSED).
  setupConfigLocked,

  /// `CONTRIBUTION_TYPE_INACTIVE`: cannot create a setup under an
  /// inactive contribution type.
  typeInactive,

  /// `CONTRIBUTION_SETUP_INACTIVE`: cannot create a period under, or
  /// open a period whose, setup is inactive.
  setupInactive,

  /// A duplicate contribution type name within the group (23505 /
  /// `contribution_types_group_name_unique`).
  duplicateName,

  /// Invalid period start/end dates.
  invalidDates,

  /// `DUE_DATE_REQUIRED`: no explicit due date and the setup has no
  /// default due day configured.
  dueDateRequired,

  /// `DUPLICATE_MONTHLY_PERIOD`: a MONTHLY setup already has a
  /// non-cancelled period for that calendar month.
  duplicateMonthlyPeriod,

  /// `CONTRIBUTION_PERIOD_NOT_EDITABLE`: the period is no longer
  /// DRAFT/SCHEDULED, so member amounts/exclusions cannot change.
  periodNotEditable,

  /// `CONTRIBUTION_SETUP_NOT_CUSTOM_AMOUNT`: per-member amounts only
  /// apply to a CUSTOM_PER_MEMBER setup.
  setupNotCustomAmount,

  /// A membership id did not resolve inside this group.
  membershipNotFound,

  /// A submitted per-member amount was not a positive number.
  invalidAmount,

  /// `CONTRIBUTION_PERIOD_NOT_PREVIEWABLE`: the period is no longer
  /// DRAFT/SCHEDULED, so it cannot be previewed for opening.
  periodNotPreviewable,

  /// `CONTRIBUTION_PERIOD_NOT_OPENABLE`: the period is no longer
  /// DRAFT/SCHEDULED, so it cannot be opened.
  periodNotOpenable,

  /// `MISSING_CUSTOM_AMOUNTS`: a CUSTOM_PER_MEMBER period still has
  /// eligible members without a configured amount.
  missingCustomAmounts,

  /// `CONTRIBUTION_PERIOD_NOT_OPEN`: enroll/close attempted on a period
  /// that is not currently OPEN.
  periodNotOpen,

  /// `MEMBER_ALREADY_CHARGED_FOR_PERIOD`: enrollment attempted for a
  /// member who already has a charge in this period.
  memberAlreadyCharged,

  /// `AMOUNT_REQUIRED`: enrollment into a CUSTOM_PER_MEMBER period
  /// without a positive amount.
  amountRequired,

  /// `CONTRIBUTION_PERIOD_NOT_CANCELLABLE`: the period is no longer
  /// DRAFT/SCHEDULED, so it cannot be cancelled.
  periodNotCancellable,

  /// A type/setup/period/membership id did not resolve in this group.
  notFound,

  /// `CONTRIBUTION_PERIOD_NO_PENALTY_POLICY`: penalty assessment
  /// attempted on a period whose frozen snapshot has no penalty policy
  /// (`NONE`) configured.
  noPenaltyPolicy,

  permissionDenied,
  network,
  unexpected,
}

/// A safe-to-display Contributions-management failure. Never wraps a raw
/// PostgREST/Postgres exception message or stack trace — technical
/// details are logged separately, not shown to the user. [message] is
/// an English fallback for logging; UI code should localize from
/// [type] instead (see `core/localization/failure_messages.dart`).
class ContributionFailure implements Exception {
  const ContributionFailure(this.type, this.message);

  final ContributionFailureType type;
  final String message;

  @override
  String toString() => message;
}
