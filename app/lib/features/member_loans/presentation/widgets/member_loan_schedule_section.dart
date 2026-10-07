import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/umoja_spacing.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/widgets/umoja_card.dart';
import '../../../../core/widgets/umoja_status_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/member_loan.dart';
import '../../providers/member_loan_providers.dart';
import 'member_loan_labels.dart';
import 'member_loan_messages.dart';
import 'member_loan_retry_notice.dart';

/// Repayment Schedule. CURRENT installments and HISTORY are rendered in
/// separate groups. History is never merged into current, and its amounts
/// are never added to any position.
class MemberLoanScheduleSection extends ConsumerWidget {
  const MemberLoanScheduleSection({
    super.key,
    required this.groupId,
    required this.loanAccountId,
  });

  final String groupId;
  final String loanAccountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final request = (groupId: groupId, loanAccountId: loanAccountId);
    final scheduleAsync = ref.watch(memberLoanScheduleProvider(request));
    final theme = Theme.of(context);

    return Column(
      key: const Key('myLoanScheduleSection'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.myLoansScheduleTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: UmojaSpacing.sm),
        scheduleAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(UmojaSpacing.lg),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (error, _) => MemberLoanRetryNotice(
            message: memberLoansFailureMessage(l10n, error, isLoanScoped: true),
            retryLabel: l10n.retryButton,
            onRetry: () => ref.invalidate(memberLoanScheduleProvider(request)),
          ),
          data: (schedule) => _ScheduleBody(schedule: schedule),
        ),
      ],
    );
  }
}

class _ScheduleBody extends StatelessWidget {
  const _ScheduleBody({required this.schedule});

  final MemberLoanSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Prompt 09G-B5-C.3 §D: "Repayment Schedule" (the section title
    // above) is the one heading for the current installments — it is
    // never repeated as a second "Current Schedule" heading immediately
    // below it. "Schedule History" below remains the one place current
    // and history are actually distinguished, and only when history
    // exists at all.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (schedule.current.isEmpty)
          Text(l10n.myLoansScheduleEmpty, style: theme.textTheme.bodyMedium)
        else
          for (final row in schedule.current) ...[
            _CurrentRow(row: row),
            const SizedBox(height: UmojaSpacing.sm),
          ],
        if (schedule.history.isNotEmpty) ...[
          const SizedBox(height: UmojaSpacing.xl),
          Text(
            l10n.myLoansScheduleHistoryTitle,
            key: const Key('myLoanScheduleHistoryTitle'),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: UmojaSpacing.xs),
          Text(
            l10n.myLoansScheduleHistoryNotice,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: UmojaSpacing.sm),
          for (final row in schedule.history) ...[
            _HistoryRow(row: row),
            const SizedBox(height: UmojaSpacing.sm),
          ],
        ],
      ],
    );
  }
}

class _CurrentRow extends StatelessWidget {
  const _CurrentRow({required this.row});

  final MemberScheduleRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return UmojaCard(
      child: ExpansionTile(
        key: Key('myLoanScheduleRow_${row.installmentId}'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: UmojaSpacing.sm),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${l10n.myLoansInstallmentLabel(row.installmentNumber)} · ${formatMemberLoanDate(row.dueDate)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            UmojaStatusBadge(
              label: memberScheduleStatusLabel(l10n, row.status),
              semantic: memberScheduleStatusSemantic(row.status),
            ),
          ],
        ),
        subtitle: Text(
          '${l10n.myLoansOutstandingLabel}: ${formatAmount(row.currentTotalOutstanding)}',
          style: muted,
        ),
        children: [
          _Line(
            label: l10n.myLoansScheduledLabel,
            value: formatAmount(row.scheduledTotal),
          ),
          _Line(
            label: l10n.myLoansBreakdownPrincipal,
            value: formatAmount(row.paidPrincipal),
          ),
          _Line(
            label: l10n.myLoansBreakdownInterest,
            value: formatAmount(row.paidInterest),
          ),
          _Line(
            label: l10n.myLoansBreakdownPenalty,
            value: formatAmount(row.paidPenalty),
          ),
          _Line(
            label: l10n.myLoansPrincipalOutstandingLabel,
            value: formatAmount(row.currentPrincipalOutstanding),
          ),
          _Line(
            label: l10n.myLoansEarnedInterestOutstandingLabel,
            value: formatAmount(row.currentEarnedInterestOutstanding),
          ),
          _Line(
            label: l10n.myLoansPenaltyOutstandingLabel,
            value: formatAmount(row.currentPenaltyOutstanding),
          ),
          if (row.scheduledFutureInterestOutstanding > 0)
            _Line(
              label: l10n.myLoansFutureInterestLabel,
              value: formatAmount(row.scheduledFutureInterestOutstanding),
            ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.row});

  final MemberScheduleHistoryRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final replacement = memberScheduleReplacementLabel(
      l10n,
      row.replacementReason,
    );

    return UmojaCard(
      key: Key('myLoanHistoryRow_${row.installmentId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${l10n.myLoansInstallmentLabel(row.installmentNumber)} · ${formatMemberLoanDate(row.dueDate)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              UmojaStatusBadge(
                label: memberScheduleHistoryStatusLabel(l10n, row.status),
                semantic: UmojaStatusSemantic.neutral,
              ),
            ],
          ),
          if (replacement != null) ...[
            const SizedBox(height: UmojaSpacing.xs),
            Text(replacement, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: UmojaSpacing.xs),
          _Line(
            label: l10n.myLoansScheduledLabel,
            value: formatAmount(row.scheduledTotal),
          ),
          _Line(
            label:
                '${l10n.myLoansPaidLabel} · ${l10n.myLoansBreakdownPrincipal}',
            value: formatAmount(row.paidPrincipal),
          ),
          _Line(
            label:
                '${l10n.myLoansPaidLabel} · ${l10n.myLoansBreakdownInterest}',
            value: formatAmount(row.paidInterest),
          ),
          _Line(
            label: '${l10n.myLoansPaidLabel} · ${l10n.myLoansBreakdownPenalty}',
            value: formatAmount(row.paidPenalty),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: UmojaSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
          const SizedBox(width: UmojaSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
