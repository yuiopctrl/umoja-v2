import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations_x.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/umoja_card.dart';
import '../../../core/widgets/umoja_loading_state.dart';
import '../../../app/shell/member_child_scaffold.dart';
import '../../../core/widgets/umoja_status_badge.dart';
import '../domain/member_loan.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../providers/member_loan_providers.dart';
import 'widgets/member_loan_labels.dart';
import 'widgets/member_loan_messages.dart';
import 'widgets/member_loan_position_card.dart';
import 'widgets/member_loan_retry_notice.dart';
import 'widgets/member_loan_schedule_section.dart';
import 'widgets/member_loan_timeline_section.dart';

/// `/me/loans/:loanAccountId`: one of the caller's own loans. Backed by
/// rpc_get_my_loan_detail, with the schedule and activity loaded by their
/// own providers, so a failure in either section never blanks the loan.
/// Never a call to an officer loan RPC.
class MyLoanDetailScreen extends ConsumerWidget {
  const MyLoanDetailScreen({super.key, required this.loanAccountId});

  final String loanAccountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selectedGroup = ref.watch(selectedGroupProvider);
    final groupId = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership.group.groupId
        : null;

    // Without a resolved group there is no request key, so nothing is shown.
    // This is never a previous group's data.
    if (groupId == null) {
      return MemberChildScaffold(
        title: l10n.myLoansDetailTitle,
        scrollable: false,
        body: const UmojaLoadingState(),
      );
    }

    final request = (groupId: groupId, loanAccountId: loanAccountId);
    final detailAsync = ref.watch(memberLoanDetailProvider(request));

    return MemberChildScaffold(
      title: l10n.myLoansDetailTitle,
      scrollable: false,
      body: detailAsync.when(
        loading: () => const UmojaLoadingState(),
        error: (error, _) => MemberLoanRetryNotice(
          message: memberLoansFailureMessage(l10n, error, isLoanScoped: true),
          retryLabel: l10n.retryButton,
          onRetry: () => ref.invalidate(memberLoanDetailProvider(request)),
        ),
        data: (detail) => _DetailContent(detail: detail, groupId: groupId),
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({required this.detail, required this.groupId});

  final MemberLoanDetail detail;
  final String groupId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final note = _positionNote(l10n, detail.status, detail.currentPosition);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: UmojaSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Identity and status.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.myLoansLoanNumberLabel} ${detail.loanNumber}',
                      key: const Key('myLoanDetailNumber'),
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      detail.product.productName,
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (detail.isOpeningPosition) ...[
                      const SizedBox(height: UmojaSpacing.xs),
                      Text(
                        l10n.myLoansOpeningPositionLabel,
                        key: const Key('myLoanDetailOpeningBadge'),
                        style: theme.textTheme.labelMedium,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: UmojaSpacing.sm),
              UmojaStatusBadge(
                key: const Key('myLoanDetailStatus'),
                label: memberLoanStatusLabel(l10n, detail.status),
                semantic: memberLoanStatusSemantic(detail.status),
              ),
            ],
          ),
          if (detail.isOpeningPosition) ...[
            const SizedBox(height: UmojaSpacing.sm),
            Text(
              l10n.myLoansOpeningPositionNotice,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],

          // 2. Current Position, exactly as the backend returned it.
          const SizedBox(height: UmojaSpacing.xl),
          Text(l10n.myLoansPositionTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: UmojaSpacing.sm),
          MemberLoanPositionCard(position: detail.currentPosition, note: note),
          if (detail.overdueAmount != null && detail.overdueAmount! > 0) ...[
            const SizedBox(height: UmojaSpacing.sm),
            Text(
              '${l10n.myLoansOverdueLabel}: ${formatAmount(detail.overdueAmount!)}',
              key: const Key('myLoanDetailOverdue'),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (detail.nextDueDate != null) ...[
            const SizedBox(height: UmojaSpacing.xs),
            Text(
              '${l10n.myLoansNextDueLabel}: ${formatMemberLoanDate(detail.nextDueDate!)}',
              key: const Key('myLoanDetailNextDue'),
              style: theme.textTheme.bodyMedium,
            ),
          ],

          // 3. Loan terms, only the persisted, member-safe ones.
          const SizedBox(height: UmojaSpacing.xl),
          Text(l10n.myLoansTermsTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: UmojaSpacing.sm),
          _TermsCard(detail: detail),

          // 4. Repayment schedule (current and history).
          const SizedBox(height: UmojaSpacing.xl),
          MemberLoanScheduleSection(
            groupId: groupId,
            loanAccountId: detail.loanAccountId,
          ),

          // 5. Activity timeline.
          const SizedBox(height: UmojaSpacing.xl),
          MemberLoanTimelineSection(
            groupId: groupId,
            loanAccountId: detail.loanAccountId,
          ),
        ],
      ),
    );
  }
}

/// Only the notes the backend status justifies. A zero position is never
/// explained by reconstructing debt from the original principal.
String? _positionNote(
  AppLocalizations l10n,
  MemberLoanStatus status,
  MemberLoanCurrentPosition position,
) {
  switch (status) {
    case MemberLoanStatus.writtenOff:
      return l10n.myLoansWrittenOffNote;
    case MemberLoanStatus.rejected:
    case MemberLoanStatus.cancelled:
    case MemberLoanStatus.submitted:
    case MemberLoanStatus.approved:
      return l10n.myLoansNeverDisbursedNote;
    default:
      return position.isAvailable
          ? null
          : l10n.myLoansPositionUnavailableNotice;
  }
}

class _TermsCard extends StatelessWidget {
  const _TermsCard({required this.detail});

  final MemberLoanDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final terms = detail.terms;
    final rows = <(String, String)>[
      if (detail.originalPrincipal != null)
        (
          l10n.myLoansOriginalPrincipalLabel,
          formatAmount(detail.originalPrincipal!),
        ),
      if (terms.interestRate != null)
        (
          l10n.myLoansTermInterestRateLabel,
          '${formatAmount(terms.interestRate!)}%',
        ),
      if (terms.term != null)
        (l10n.myLoansTermTermLabel, l10n.myLoansTermMonths(terms.term!)),
      if (terms.repaymentFrequency == 'MONTHLY')
        (l10n.myLoansTermRepaymentLabel, l10n.myLoansFrequencyMonthly),
      if (terms.firstRepaymentDate != null)
        (
          l10n.myLoansTermFirstRepaymentLabel,
          formatMemberLoanDate(terms.firstRepaymentDate!),
        ),
      if (detail.applicationDate != null)
        (
          l10n.myLoansApplicationDateLabel,
          formatMemberLoanDate(detail.applicationDate!),
        ),
      if (detail.originalDisbursementDate != null)
        (
          l10n.myLoansOriginalDisbursementLabel,
          formatMemberLoanDate(detail.originalDisbursementDate!),
        ),
      if (detail.openingAsOfDate != null)
        (
          l10n.myLoansOpeningAsOfLabel,
          formatMemberLoanDate(detail.openingAsOfDate!),
        ),
      if (detail.finalDueDate != null)
        (l10n.myLoansFinalDueLabel, formatMemberLoanDate(detail.finalDueDate!)),
    ];

    return UmojaCard(
      key: const Key('myLoanTermsCard'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, value) in rows) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: UmojaSpacing.sm),
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            if (label != rows.last.$1) const Divider(height: UmojaSpacing.lg),
          ],
        ],
      ),
    );
  }
}
