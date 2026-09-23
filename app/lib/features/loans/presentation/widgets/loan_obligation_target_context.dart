import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations_x.dart';
import '../../../../core/theme/umoja_spacing.dart';
import '../../../../core/utils/kiswahili_date.dart';
import '../../../../core/utils/money_format.dart';
import '../../providers/loan_account_detail_provider.dart';
import '../../providers/loan_penalty_charges_provider.dart';

/// Prompt 09F-A-12: identifies exactly which installment/component a
/// Waive or Correct screen is about to act on — installment number, due
/// date, component (Interest/Penalty), and current effective
/// outstanding — so the review is never ambiguous about the target
/// (09F-A-11 Blocker-03: a physical tester lost track of which
/// installment they had actually acted on). Reads from the same cached
/// loan-detail/penalty-charge data the user just came from; shows
/// nothing (never an error) if that data isn't available yet, since
/// this is purely informational and never gates the action itself —
/// the server-computed preview remains the authoritative figures.
class LoanObligationTargetContext extends ConsumerWidget {
  const LoanObligationTargetContext({
    super.key,
    required this.loanAccountId,
    required this.targetType,
    required this.targetId,
  });

  final String loanAccountId;

  /// 'LOAN_PENALTY' or 'LOAN_INTEREST'.
  final String targetType;
  final String targetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final loanAsync = ref.watch(loanAccountDetailProvider(loanAccountId));

    return loanAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (loan) {
        if (targetType == 'LOAN_PENALTY') {
          final chargesAsync = ref.watch(
            loanPenaltyChargesProvider(loanAccountId),
          );
          return chargesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (charges) {
              final charge = charges.where((c) => c.id == targetId).firstOrNull;
              if (charge == null) return const SizedBox.shrink();
              final installment = loan.installments
                  .where((i) => i.id == charge.loanInstallmentId)
                  .firstOrNull;
              return _TargetContextCard(
                key: const Key('loanObligationTargetContext'),
                installmentNumber: charge.installmentNumber,
                dueDate: installment?.dueDate,
                componentLabel: l10n.loanComponentPenalty,
                outstanding: charge.outstandingAmount,
              );
            },
          );
        }

        final installment = loan.installments
            .where((i) => i.id == targetId)
            .firstOrNull;
        if (installment == null) return const SizedBox.shrink();
        return _TargetContextCard(
          key: const Key('loanObligationTargetContext'),
          installmentNumber: installment.installmentNumber,
          dueDate: installment.dueDate,
          componentLabel: l10n.loanComponentInterest,
          outstanding: installment.interestOutstanding ?? 0,
        );
      },
    );
  }
}

class _TargetContextCard extends StatelessWidget {
  const _TargetContextCard({
    super.key,
    required this.installmentNumber,
    required this.dueDate,
    required this.componentLabel,
    required this.outstanding,
  });

  final int installmentNumber;
  final DateTime? dueDate;
  final String componentLabel;
  final double outstanding;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final summary = dueDate == null
        ? '${l10n.loanInstallmentNumberLabel(installmentNumber)} · '
              '$componentLabel'
        : '${l10n.loanInstallmentNumberLabel(installmentNumber)} · '
              '${formatKiswahiliDate(dueDate!)} · $componentLabel';

    return Padding(
      padding: const EdgeInsets.only(bottom: UmojaSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(summary, style: theme.textTheme.titleSmall),
          const SizedBox(height: UmojaSpacing.xs),
          Text(
            '${l10n.loanObligationCurrentOutstandingLabel}: '
            '${formatAmount(outstanding)}',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
