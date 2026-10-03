import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations_x.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/member_financial_statement.dart';

final _dateFormat = DateFormat('d MMM yyyy');

/// `summary.last_payment` — rendered exactly as B3-B returns it
/// (amount/effective date/receipt number only; no allocation detail,
/// which belongs to the full Financial Statement). `null` is a real,
/// honest state ("no payments yet"), never rendered as a fabricated
/// zero-amount payment.
///
/// Prompt 09G-B3-UX-01 §C3: a row within Home's single financial
/// summary surface (never its own nested card) — same label/amount
/// row shape as [StatementPositionMetrics], just below a divider.
class StatementLastPaymentSection extends StatelessWidget {
  const StatementLastPaymentSection({super.key, required this.lastPayment});

  final MemberStatementLastPayment? lastPayment;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lastPayment = this.lastPayment;

    return Column(
      key: const Key('homeLastPaymentCard'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lastPayment == null
          ? [
              Text(
                l10n.statementNoPaymentsYetMessage,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ]
          : [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      l10n.statementLastPaymentSectionTitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatAmount(lastPayment.amount),
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${_dateFormat.format(lastPayment.effectiveAt)} • '
                '${lastPayment.receiptNumber}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
    );
  }
}
