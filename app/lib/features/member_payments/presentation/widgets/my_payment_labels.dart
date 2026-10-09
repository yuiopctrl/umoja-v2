import 'package:intl/intl.dart';

import '../../../../core/widgets/umoja_status_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/my_payment.dart';

final _dateFormat = DateFormat('d MMM yyyy');

/// Member-facing date. Dates are shown as the backend returned them,
/// with no timezone shift.
String formatMyPaymentDate(DateTime date) => _dateFormat.format(date);

/// Localized member-facing payment status. The backend's code is never
/// shown. `unknown` falls back to a neutral label rather than crashing.
String myPaymentStatusLabel(AppLocalizations l10n, MyPaymentStatus status) {
  return switch (status) {
    MyPaymentStatus.posted => l10n.myPaymentsStatusPosted,
    MyPaymentStatus.reversed => l10n.myPaymentsStatusReversed,
    MyPaymentStatus.unknown => l10n.myPaymentsStatusUnknown,
  };
}

/// REVERSED is visually distinct but not alarm-colored (Prompt 09G-B6-C
/// §J) — a neutral semantic, same treatment My Loans gives a written-off
/// loan.
UmojaStatusSemantic myPaymentStatusSemantic(MyPaymentStatus status) {
  return switch (status) {
    MyPaymentStatus.posted => UmojaStatusSemantic.success,
    MyPaymentStatus.reversed => UmojaStatusSemantic.neutral,
    MyPaymentStatus.unknown => UmojaStatusSemantic.neutral,
  };
}

/// Localized payment method. The backend's code is never shown directly.
String myPaymentMethodLabel(AppLocalizations l10n, MyPaymentMethod method) {
  return switch (method) {
    MyPaymentMethod.cash => l10n.myPaymentsMethodCash,
    MyPaymentMethod.bankTransfer => l10n.myPaymentsMethodBankTransfer,
    MyPaymentMethod.mobileMoney => l10n.myPaymentsMethodMobileMoney,
    MyPaymentMethod.other => l10n.myPaymentsMethodOther,
    MyPaymentMethod.unknown => l10n.myPaymentsMethodUnknown,
  };
}

/// Localized allocation target label — the concise member-facing
/// concept, never the raw backend code (Prompt 09G-B6-C §R). Principal
/// repayment is never called "income".
String myPaymentAllocationTargetLabel(
  AppLocalizations l10n,
  MyPaymentAllocationTargetType type,
) {
  return switch (type) {
    MyPaymentAllocationTargetType.contributionComponent =>
      l10n.myPaymentsTargetContribution,
    MyPaymentAllocationTargetType.loanPrincipal =>
      l10n.myPaymentsTargetLoanPrincipal,
    MyPaymentAllocationTargetType.loanInterest =>
      l10n.myPaymentsTargetLoanInterest,
    MyPaymentAllocationTargetType.loanPenalty =>
      l10n.myPaymentsTargetLoanPenalty,
    MyPaymentAllocationTargetType.loanPrincipalPrepayment =>
      l10n.myPaymentsTargetPrincipalPrepayment,
    MyPaymentAllocationTargetType.loanRecoveryPrincipal =>
      l10n.myPaymentsTargetRecoveryPrincipal,
    MyPaymentAllocationTargetType.loanRecoveryInterest =>
      l10n.myPaymentsTargetRecoveryInterest,
    MyPaymentAllocationTargetType.loanRecoveryPenalty =>
      l10n.myPaymentsTargetRecoveryPenalty,
    MyPaymentAllocationTargetType.unknown => l10n.myPaymentsTargetUnknown,
  };
}

/// Localized contribution component label (BASE/PENALTY/...). Falls
/// back to the raw code for a value this app version does not yet
/// recognize, rather than hiding it — never a raw charge/component id.
String myPaymentComponentLabel(AppLocalizations l10n, String? componentType) {
  return switch (componentType) {
    'BASE' => l10n.myPaymentsComponentBase,
    'PENALTY' => l10n.myPaymentsComponentPenalty,
    'ADJUSTMENT' => l10n.myPaymentsComponentAdjustment,
    'WAIVER' => l10n.myPaymentsComponentWaiver,
    'OPENING_BALANCE' => l10n.myPaymentsComponentOpeningBalance,
    null => l10n.myPaymentsTargetUnknown,
    _ => componentType,
  };
}
