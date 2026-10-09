import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/kiswahili_date.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/umoja_card.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../core/widgets/umoja_status_badge.dart';
import '../domain/loan_statement.dart';
import '../providers/loan_statement_provider.dart';
import 'widgets/loan_labels.dart';

/// `/loans/accounts/:loanAccountId/statement`: the single authoritative
/// chronological statement for one loan (Prompt 09G). Every figure and
/// every timeline row is rendered exactly as `rpc_get_loan_statement`
/// returns it — never recomputed, never re-sorted, never filtered
/// client-side. Requires only the same `loan.view` access already
/// required to see the loan at all (no separate "statement" permission
/// exists).
class LoanStatementScreen extends ConsumerWidget {
  const LoanStatementScreen({super.key, required this.loanAccountId});

  final String loanAccountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final statementAsync = ref.watch(loanStatementProvider(loanAccountId));

    return UmojaPage(
      title: l10n.loanStatementTitle,
      backTo: AppRoutes.loanAccountDetailPath(loanAccountId),
      backLabel: l10n.loanAccountDetailTitle,
      maxWidth: 900,
      body: statementAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 64),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => UmojaErrorState(
          message: l10n.refreshFailedMessage,
          retryLabel: l10n.retryButton,
          onRetry: () => ref.invalidate(loanStatementProvider(loanAccountId)),
        ),
        data: (statement) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatementHeaderCard(header: statement.header),
              const SizedBox(height: UmojaSpacing.lg),
              _CurrentPositionSection(currentState: statement.currentState),
              const SizedBox(height: UmojaSpacing.xxl),
              _TimelineSection(timeline: statement.timeline),
              const SizedBox(height: UmojaSpacing.xxl),
              _ScheduleSection(schedule: statement.schedule),
            ],
          );
        },
      ),
    );
  }
}

class _StatementHeaderCard extends StatelessWidget {
  const _StatementHeaderCard({required this.header});

  final LoanStatementHeader header;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return UmojaCard(
      key: const Key('statementHeaderCard'),
      padding: const EdgeInsets.all(UmojaSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  header.borrowerDisplayName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              UmojaStatusBadge(
                key: const Key('statementStatusBadge'),
                label: loanAccountStatusLabel(l10n, header.status),
                semantic: loanAccountStatusSemantic(header.status),
              ),
            ],
          ),
          Text(header.loanNumber),
          const SizedBox(height: UmojaSpacing.md),
          _StatementRow(
            label: l10n.loanProductsTitle,
            value: header.loanProductName,
          ),
          if (header.borrowerMemberNumber != null)
            _StatementRow(
              label: l10n.loanBorrowerMemberNumberLabel,
              value: header.borrowerMemberNumber!,
            ),
          _StatementRow(
            label: l10n.loanOriginFieldLabel,
            value: loanOriginLabel(l10n, header.loanOrigin),
          ),
        ],
      ),
    );
  }
}

/// Current Position (section J-2). For an ordinary servicing loan, the
/// schedule-based outstanding figures; for WRITTEN_OFF, the ordinary
/// Outstanding block is suppressed entirely (0 schedule outstanding
/// beside a large remaining recoverable amount is an avoidable
/// semantic conflict — 09G-03 section I locked decision) and a
/// dedicated Write-Off Position is shown instead.
class _CurrentPositionSection extends StatelessWidget {
  const _CurrentPositionSection({required this.currentState});

  final LoanStatementCurrentState currentState;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final writeOff = currentState.writeOff;

    if (currentState.isWrittenOff) {
      if (writeOff == null) return const SizedBox.shrink();
      return _WriteOffPositionSection(writeOff: writeOff);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.statementCurrentPositionTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: UmojaSpacing.sm),
        UmojaCard(
          key: const Key('statementCurrentPositionCard'),
          padding: const EdgeInsets.all(UmojaSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatementRow(
                label: l10n.statementPrincipalOutstandingLabel,
                value: formatAmount(currentState.principalOutstanding),
              ),
              _StatementRow(
                label: l10n.statementEarnedInterestOutstandingLabel,
                value: formatAmount(currentState.earnedInterestOutstanding),
              ),
              if (currentState.penaltyOutstanding > 0)
                _StatementRow(
                  label: l10n.statementPenaltyOutstandingLabel,
                  value: formatAmount(currentState.penaltyOutstanding),
                ),
              const Divider(),
              _StatementRow(
                label: l10n.statementTotalOutstandingLabel,
                value: formatAmount(currentState.totalOutstanding),
              ),
              const SizedBox(height: UmojaSpacing.sm),
              _StatementRow(
                label: l10n.statementScheduledUnearnedInterestLabel,
                value: formatAmount(currentState.scheduledUnearnedInterest),
              ),
              Text(
                l10n.statementScheduledUnearnedInterestHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (currentState.totalOverdue > 0) ...[
          const SizedBox(height: UmojaSpacing.lg),
          Text(
            l10n.statementOverduePositionTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: UmojaSpacing.sm),
          UmojaCard(
            key: const Key('statementOverduePositionCard'),
            padding: const EdgeInsets.all(UmojaSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (currentState.overduePrincipal > 0)
                  _StatementRow(
                    label: l10n.statementOverduePrincipalLabel,
                    value: formatAmount(currentState.overduePrincipal),
                  ),
                if (currentState.overdueInterest > 0)
                  _StatementRow(
                    label: l10n.statementOverdueInterestLabel,
                    value: formatAmount(currentState.overdueInterest),
                  ),
                if (currentState.overduePenalty > 0)
                  _StatementRow(
                    label: l10n.statementOverduePenaltyLabel,
                    value: formatAmount(currentState.overduePenalty),
                  ),
                const Divider(),
                _StatementRow(
                  label: l10n.statementTotalOverdueLabel,
                  value: formatAmount(currentState.totalOverdue),
                ),
              ],
            ),
          ),
        ],
        // A historical (reversed) write-off is truthfully represented
        // even though this loan is no longer WRITTEN_OFF now — never
        // silently dropped (09G-03 section J-2).
        if (writeOff != null) ...[
          const SizedBox(height: UmojaSpacing.xxl),
          _WriteOffPositionSection(writeOff: writeOff),
        ],
      ],
    );
  }
}

class _WriteOffPositionSection extends StatelessWidget {
  const _WriteOffPositionSection({required this.writeOff});

  final LoanStatementWriteOffState writeOff;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      key: const Key('statementWriteOffPositionSection'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.statementWriteOffPositionTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (!writeOff.isActive) ...[
          const SizedBox(height: UmojaSpacing.xs),
          Text(
            l10n.statementWriteOffHistoricalLabel,
            key: const Key('statementWriteOffHistoricalNote'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: UmojaSpacing.sm),
        UmojaCard(
          key: const Key('statementOriginalWrittenOffCard'),
          padding: const EdgeInsets.all(UmojaSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.statementOriginalWrittenOffTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: UmojaSpacing.xs),
              _StatementRow(
                label: l10n.loanComponentPrincipal,
                value: formatAmount(writeOff.principalWrittenOff),
              ),
              _StatementRow(
                label: l10n.loanComponentInterest,
                value: formatAmount(writeOff.interestWrittenOff),
              ),
              _StatementRow(
                label: l10n.loanComponentPenalty,
                value: formatAmount(writeOff.penaltyWrittenOff),
              ),
              const Divider(),
              _StatementRow(
                label: l10n.statementTotalLabel,
                value: formatAmount(writeOff.amountWrittenOff),
              ),
            ],
          ),
        ),
        const SizedBox(height: UmojaSpacing.md),
        UmojaCard(
          key: const Key('statementRecoveredCard'),
          padding: const EdgeInsets.all(UmojaSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.statementRecoveredTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: UmojaSpacing.xs),
              _StatementRow(
                label: l10n.loanComponentPrincipal,
                value: formatAmount(writeOff.recoveredPrincipal),
              ),
              _StatementRow(
                label: l10n.loanComponentInterest,
                value: formatAmount(writeOff.recoveredInterest),
              ),
              _StatementRow(
                label: l10n.loanComponentPenalty,
                value: formatAmount(writeOff.recoveredPenalty),
              ),
              const Divider(),
              _StatementRow(
                label: l10n.statementTotalLabel,
                value: formatAmount(writeOff.totalRecovered),
              ),
            ],
          ),
        ),
        const SizedBox(height: UmojaSpacing.md),
        UmojaCard(
          key: const Key('statementRemainingRecoverableCard'),
          padding: const EdgeInsets.all(UmojaSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.statementRemainingRecoverableTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: UmojaSpacing.xs),
              _StatementRow(
                label: l10n.loanComponentPrincipal,
                value: formatAmount(writeOff.remainingRecoverablePrincipal),
              ),
              _StatementRow(
                label: l10n.loanComponentInterest,
                value: formatAmount(writeOff.remainingRecoverableInterest),
              ),
              _StatementRow(
                label: l10n.loanComponentPenalty,
                value: formatAmount(writeOff.remainingRecoverablePenalty),
              ),
              const Divider(),
              _StatementRow(
                key: const Key('statementRemainingRecoverableTotalRow'),
                label: l10n.statementTotalLabel,
                value: formatAmount(writeOff.remainingRecoverable),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Timeline (section J-3). Rendered in the EXACT order [timeline]
/// arrives in — never client-sorted (see [LoanStatement.timeline]'s
/// own doc).
class _TimelineSection extends StatelessWidget {
  const _TimelineSection({required this.timeline});

  final List<LoanStatementEvent> timeline;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      key: const Key('statementTimelineSection'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.statementTimelineTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: UmojaSpacing.sm),
        UmojaCard(
          padding: const EdgeInsets.all(UmojaSpacing.lg),
          child: Column(
            children: [
              for (final event in timeline)
                _TimelineEventTile(
                  key: Key('statementEvent_${event.eventId}'),
                  event: event,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineEventTile extends StatelessWidget {
  const _TimelineEventTile({super.key, required this.event});

  final LoanStatementEvent event;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final components = event.components;
    final receiptNumber = event.references['receipt_number'] as String?;

    return Opacity(
      opacity: event.isReversed ? 0.6 : 1.0,
      child: Padding(
        padding: const EdgeInsets.only(bottom: UmojaSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loanStatementEventTitle(l10n, event.eventType),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    formatKiswahiliDate(event.effectiveAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (receiptNumber != null)
                    Text(
                      receiptNumber,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (components != null) ...[
                    if (components.principal > 0)
                      Text(
                        '${l10n.loanComponentPrincipal}: '
                        '${formatAmount(components.principal)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (components.interest > 0)
                      Text(
                        '${l10n.loanComponentInterest}: '
                        '${formatAmount(components.interest)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (components.penalty > 0)
                      Text(
                        '${l10n.loanComponentPenalty}: '
                        '${formatAmount(components.penalty)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                  if (event.isReversed)
                    Text(
                      l10n.loanObligationHistoryReversedLabel,
                      key: const Key('statementEventReversedTag'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
            if (event.amount != null) Text(formatAmount(event.amount!)),
          ],
        ),
      ),
    );
  }
}

/// Schedule (section J-4). [LoanStatementSchedule.history] is rendered
/// only when non-empty — a cancelled/replaced installment is never
/// presented as a current obligation.
class _ScheduleSection extends StatelessWidget {
  const _ScheduleSection({required this.schedule});

  final LoanStatementSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.loanScheduleTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: UmojaSpacing.sm),
        UmojaCard(
          key: const Key('statementScheduleCurrentSection'),
          padding: const EdgeInsets.all(UmojaSpacing.lg),
          child: Column(
            children: [
              for (final installment in schedule.current)
                Padding(
                  key: Key('statementScheduleRow_${installment.id}'),
                  padding: const EdgeInsets.only(bottom: UmojaSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.loanInstallmentNumberLabel(
                                installment.installmentNumber,
                              ),
                            ),
                            Text(
                              formatKiswahiliDate(installment.dueDate),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (installment.penaltyOutstanding > 0)
                              Text(
                                '${l10n.loanComponentPenalty}: '
                                '${formatAmount(installment.penaltyOutstanding)}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(formatAmount(installment.totalDue)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (schedule.history.isNotEmpty) ...[
          const SizedBox(height: UmojaSpacing.xxl),
          Text(
            l10n.statementScheduleHistoryTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: UmojaSpacing.sm),
          UmojaCard(
            key: const Key('statementScheduleHistorySection'),
            padding: const EdgeInsets.all(UmojaSpacing.lg),
            child: Column(
              children: [
                for (final installment in schedule.history)
                  Padding(
                    key: Key('statementScheduleHistoryRow_${installment.id}'),
                    padding: const EdgeInsets.only(bottom: UmojaSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.loanInstallmentNumberLabel(
                                  installment.installmentNumber,
                                ),
                              ),
                              Text(
                                formatKiswahiliDate(installment.dueDate),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (installment.cancellationReason != null)
                                Text(
                                  installment.cancellationReason!,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        Text(
                          formatAmount(
                            installment.principalDue + installment.interestDue,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatementRow extends StatelessWidget {
  const _StatementRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: UmojaSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: UmojaSpacing.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}
