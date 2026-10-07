import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/umoja_status_badge.dart';
import '../../domain/member_loan.dart';

final _dateFormat = DateFormat('d MMM yyyy');

/// Member-facing date. Dates are shown as the backend returned them, with
/// no timezone shift.
String formatMemberLoanDate(DateTime date) => _dateFormat.format(date);

/// Localized member-facing loan status. The backend's code is never shown.
/// `unknown` falls back to a neutral label rather than crashing.
String memberLoanStatusLabel(AppLocalizations l10n, MemberLoanStatus status) {
  return switch (status) {
    MemberLoanStatus.submitted => l10n.myLoansStatusSubmitted,
    MemberLoanStatus.approved => l10n.myLoansStatusApproved,
    MemberLoanStatus.rejected => l10n.myLoansStatusRejected,
    MemberLoanStatus.cancelled => l10n.myLoansStatusCancelled,
    MemberLoanStatus.active => l10n.myLoansStatusActive,
    MemberLoanStatus.closed => l10n.myLoansStatusClosed,
    MemberLoanStatus.writtenOff => l10n.myLoansStatusWrittenOff,
    MemberLoanStatus.unknown => l10n.myLoansStatusUnknown,
  };
}

/// Status semantics. Color is never the only signal: the label is always
/// shown beside the badge.
UmojaStatusSemantic memberLoanStatusSemantic(MemberLoanStatus status) {
  return switch (status) {
    MemberLoanStatus.active => UmojaStatusSemantic.info,
    MemberLoanStatus.closed => UmojaStatusSemantic.success,
    MemberLoanStatus.writtenOff => UmojaStatusSemantic.neutral,
    MemberLoanStatus.rejected ||
    MemberLoanStatus.cancelled => UmojaStatusSemantic.neutral,
    MemberLoanStatus.submitted ||
    MemberLoanStatus.approved => UmojaStatusSemantic.neutral,
    MemberLoanStatus.unknown => UmojaStatusSemantic.neutral,
  };
}

/// Localized current-schedule status. These are the backend codes only.
/// PAID is never shown.
String memberScheduleStatusLabel(
  AppLocalizations l10n,
  MemberScheduleStatus status,
) {
  return switch (status) {
    MemberScheduleStatus.settled => l10n.myLoansScheduleStatusSettled,
    MemberScheduleStatus.overdue => l10n.myLoansScheduleStatusOverdue,
    MemberScheduleStatus.partiallySettled =>
      l10n.myLoansScheduleStatusPartiallySettled,
    MemberScheduleStatus.due => l10n.myLoansScheduleStatusDue,
    MemberScheduleStatus.upcoming => l10n.myLoansScheduleStatusUpcoming,
    MemberScheduleStatus.writtenOff => l10n.myLoansScheduleStatusWrittenOff,
    MemberScheduleStatus.unknown => l10n.myLoansScheduleStatusUnknown,
  };
}

UmojaStatusSemantic memberScheduleStatusSemantic(MemberScheduleStatus status) {
  return switch (status) {
    MemberScheduleStatus.settled => UmojaStatusSemantic.success,
    MemberScheduleStatus.overdue => UmojaStatusSemantic.warning,
    MemberScheduleStatus.partiallySettled => UmojaStatusSemantic.info,
    MemberScheduleStatus.due => UmojaStatusSemantic.info,
    MemberScheduleStatus.upcoming => UmojaStatusSemantic.neutral,
    MemberScheduleStatus.writtenOff => UmojaStatusSemantic.neutral,
    MemberScheduleStatus.unknown => UmojaStatusSemantic.neutral,
  };
}

String memberScheduleHistoryStatusLabel(
  AppLocalizations l10n,
  MemberScheduleHistoryStatus status,
) {
  return switch (status) {
    MemberScheduleHistoryStatus.cancelled =>
      l10n.myLoansScheduleStatusCancelled,
    MemberScheduleHistoryStatus.replaced => l10n.myLoansScheduleStatusReplaced,
    MemberScheduleHistoryStatus.unknown => l10n.myLoansScheduleStatusUnknown,
  };
}

/// Replacement context, shown only for a REPLACED row whose persisted
/// reason code is known. Anything else gets no explanation.
String? memberScheduleReplacementLabel(AppLocalizations l10n, String? reason) {
  return switch (reason) {
    'RESTRUCTURE' => l10n.myLoansReplacedByRestructure,
    'PRINCIPAL_PREPAYMENT' => l10n.myLoansReplacedByPrepayment,
    _ => null,
  };
}

/// Localized activity title. The title is always the event meaning, never
/// the accounting cash direction.
String memberLoanEventLabel(AppLocalizations l10n, MemberLoanEventType type) {
  return switch (type) {
    MemberLoanEventType.loanSubmitted => l10n.myLoansEventLoanSubmitted,
    MemberLoanEventType.loanApproved => l10n.myLoansEventLoanApproved,
    MemberLoanEventType.loanRejected => l10n.myLoansEventLoanRejected,
    MemberLoanEventType.loanCancelled => l10n.myLoansEventLoanCancelled,
    MemberLoanEventType.loanDisbursed => l10n.myLoansEventLoanDisbursed,
    MemberLoanEventType.openingPosition => l10n.myLoansEventOpeningPosition,
    MemberLoanEventType.paymentPosted => l10n.myLoansEventPaymentPosted,
    MemberLoanEventType.recoveryPosted => l10n.myLoansEventRecoveryPosted,
    MemberLoanEventType.walletApplied => l10n.myLoansEventWalletApplied,
    MemberLoanEventType.penaltyAssessed => l10n.myLoansEventPenaltyAssessed,
    MemberLoanEventType.obligationWaiver => l10n.myLoansEventObligationWaiver,
    MemberLoanEventType.obligationCorrection =>
      l10n.myLoansEventObligationCorrection,
    MemberLoanEventType.obligationAdjustmentReversed =>
      l10n.myLoansEventObligationAdjustmentReversed,
    MemberLoanEventType.principalPrepayment =>
      l10n.myLoansEventPrincipalPrepayment,
    MemberLoanEventType.loanRestructured => l10n.myLoansEventLoanRestructured,
    MemberLoanEventType.loanEarlySettled => l10n.myLoansEventLoanEarlySettled,
    MemberLoanEventType.loanClosed => l10n.myLoansEventLoanClosed,
    MemberLoanEventType.loanReopened => l10n.myLoansEventLoanReopened,
    MemberLoanEventType.writeOff => l10n.myLoansEventWriteOff,
    MemberLoanEventType.writeOffReversed => l10n.myLoansEventWriteOffReversed,
    MemberLoanEventType.unknown => l10n.myLoansEventUnknown,
  };
}

/// Cash-classified events are PAYMENT_POSTED, RECOVERY_POSTED and
/// LOAN_DISBURSED. Every other event is shown as NON-cash, even when it
/// carries an amount. The backend's `is_cash` flag is authoritative.
bool memberLoanEventIsCash(MemberLoanTimelineEvent event) => event.isCash;

/// Localized treatment for a principal prepayment (REDUCE_TERM /
/// REDUCE_INSTALLMENT), or null when the backend did not return one.
String? memberLoanTreatmentLabel(AppLocalizations l10n, String? treatment) {
  return switch (treatment) {
    'REDUCE_TERM' => l10n.myLoansTreatmentReduceTerm,
    'REDUCE_INSTALLMENT' => l10n.myLoansTreatmentReduceInstallment,
    _ => null,
  };
}
