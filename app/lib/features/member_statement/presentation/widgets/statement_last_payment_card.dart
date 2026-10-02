import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations_x.dart';
import '../../../../core/theme/umoja_spacing.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/widgets/umoja_card.dart';
import '../../../../core/widgets/umoja_section.dart';
import '../../domain/member_financial_statement.dart';

final _dateFormat = DateFormat('d MMM yyyy');

/// `summary.last_payment` — rendered exactly as B3-B returns it
/// (amount/effective date/receipt number only; no allocation detail,
/// which belongs to the full Financial Statement). `null` is a real,
/// honest state ("no payments yet"), never rendered as a fabricated
/// zero-amount payment.
class StatementLastPaymentSection extends StatelessWidget {
  const StatementLastPaymentSection({super.key, required this.lastPayment});

  final MemberStatementLastPayment? lastPayment;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lastPayment = this.lastPayment;

    return UmojaSection(
      title: l10n.statementLastPaymentSectionTitle,
      child: UmojaCard(
        key: const Key('homeLastPaymentCard'),
        child: lastPayment == null
            ? Text(
                l10n.statementNoPaymentsYetMessage,
                style: Theme.of(context).textTheme.bodyMedium,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatAmount(lastPayment.amount),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: UmojaSpacing.xs),
                  Text(
                    _dateFormat.format(lastPayment.effectiveAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    lastPayment.receiptNumber,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
      ),
    );
  }
}
