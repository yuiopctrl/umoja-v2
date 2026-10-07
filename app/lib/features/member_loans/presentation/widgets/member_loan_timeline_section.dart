import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/umoja_spacing.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/widgets/umoja_status_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/member_loan.dart';
import '../../providers/member_loan_providers.dart';
import 'member_loan_labels.dart';
import 'member_loan_messages.dart';
import 'member_loan_retry_notice.dart';

/// Loan Activity. Effective-dated, newest first, in the backend's order. This
/// is an activity list, not a running-balance statement. Each payment
/// appears once, and history is paged by the backend.
class MemberLoanTimelineSection extends ConsumerStatefulWidget {
  const MemberLoanTimelineSection({
    super.key,
    required this.groupId,
    required this.loanAccountId,
  });

  final String groupId;
  final String loanAccountId;

  @override
  ConsumerState<MemberLoanTimelineSection> createState() =>
      _MemberLoanTimelineSectionState();
}

class _MemberLoanTimelineSectionState
    extends ConsumerState<MemberLoanTimelineSection> {
  /// Offsets of the timeline pages loaded so far.
  final List<int> _offsets = [0];

  MemberLoanTimelineRequest _request(int offset) => (
    groupId: widget.groupId,
    loanAccountId: widget.loanAccountId,
    offset: offset,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final items = <MemberLoanTimelineEvent>[];
    MemberLoanTimelinePage? lastPage;
    Object? firstError;

    for (final offset in _offsets) {
      final pageAsync = ref.watch(
        memberLoanTimelinePageProvider(_request(offset)),
      );
      final page = pageAsync.value;
      if (page != null) {
        items.addAll(page.items);
        lastPage = page;
      } else if (pageAsync.hasError && offset == 0) {
        firstError = pageAsync.error;
      }
    }

    Widget body;
    if (firstError != null) {
      body = MemberLoanRetryNotice(
        message: memberLoansFailureMessage(
          l10n,
          firstError,
          isLoanScoped: true,
        ),
        retryLabel: l10n.retryButton,
        onRetry: () =>
            ref.invalidate(memberLoanTimelinePageProvider(_request(0))),
      );
    } else if (lastPage == null) {
      body = const Padding(
        padding: EdgeInsets.all(UmojaSpacing.lg),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    } else if (items.isEmpty) {
      body = Text(l10n.myLoansActivityEmpty, style: theme.textTheme.bodyMedium);
    } else {
      final loaded = lastPage;
      final lastRequest = _request(_offsets.last);
      final lastAsync = ref.watch(memberLoanTimelinePageProvider(lastRequest));
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final event in items) ...[
            _TimelineTile(event: event),
            const Divider(height: UmojaSpacing.lg),
          ],
          if (lastAsync.hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: UmojaSpacing.sm),
              child: Text(
                l10n.myLoansActivityLoadFailedMessage,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          if (loaded.pagination.hasMore && !lastAsync.isLoading)
            Center(
              child: OutlinedButton(
                key: const Key('myLoanActivityLoadMore'),
                onPressed: () => setState(() {
                  _offsets.add(
                    loaded.pagination.offset + loaded.pagination.limit,
                  );
                }),
                child: Text(l10n.myLoansLoadMoreActivityAction),
              ),
            ),
        ],
      );
    }

    return Column(
      key: const Key('myLoanActivitySection'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.myLoansActivityTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: UmojaSpacing.sm),
        body,
      ],
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.event});

  final MemberLoanTimelineEvent event;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final isOpening = event.eventType == MemberLoanEventType.openingPosition;
    final isPayment =
        event.eventType == MemberLoanEventType.paymentPosted ||
        event.eventType == MemberLoanEventType.recoveryPosted;
    final amount = event.amount;
    final breakdown = event.componentBreakdown;

    return Column(
      key: Key('myLoanEvent_${event.eventId}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                memberLoanEventLabel(l10n, event.eventType),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (amount != null)
              Text(
                formatAmount(amount),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: UmojaSpacing.xs),
        Text(formatMemberLoanDate(event.effectiveAt), style: muted),
        const SizedBox(height: UmojaSpacing.xs),
        // Prompt 09G-B5-C.3 §B: the event title already says "Payment
        // received"/"Loan disbursed"/etc., so a separate "Money in"/"Money
        // out" line would only repeat it. `cash_direction` stays on the
        // model (it still distinguishes non-cash from cash below) — only
        // this redundant copy is removed.
        Wrap(
          spacing: UmojaSpacing.sm,
          runSpacing: UmojaSpacing.xs,
          children: [
            if (!event.isCash)
              UmojaStatusBadge(
                label: l10n.myLoansNonCashBadge,
                semantic: UmojaStatusSemantic.neutral,
              ),
            if (event.isReversed)
              UmojaStatusBadge(
                key: Key('myLoanReversed_${event.eventId}'),
                label: l10n.myLoansReversedBadge,
                semantic: UmojaStatusSemantic.neutral,
              ),
          ],
        ),
        if (isPayment && event.receiptNumber != null)
          Padding(
            padding: const EdgeInsets.only(top: UmojaSpacing.xs),
            child: Text(
              l10n.myLoansReceiptLabel(event.receiptNumber!),
              style: muted,
            ),
          ),
        if (event.eventType == MemberLoanEventType.principalPrepayment) ...[
          if (memberLoanTreatmentLabel(l10n, event.treatment) != null)
            Padding(
              padding: const EdgeInsets.only(top: UmojaSpacing.xs),
              child: Text(
                memberLoanTreatmentLabel(l10n, event.treatment)!,
                style: muted,
              ),
            ),
          if (event.principalReductionAmount != null)
            Padding(
              padding: const EdgeInsets.only(top: UmojaSpacing.xs),
              child: Text(
                '${l10n.myLoansPrincipalReductionLabel}: ${formatAmount(event.principalReductionAmount!)}',
                style: muted,
              ),
            ),
        ],
        if (isPayment && breakdown.isNotEmpty) ...[
          const SizedBox(height: UmojaSpacing.sm),
          Text(
            l10n.myLoansBreakdownTitle,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          _Breakdown(breakdown: breakdown),
        ],
        if (isOpening && breakdown.isNotEmpty) ...[
          const SizedBox(height: UmojaSpacing.xs),
          Text(l10n.myLoansOpeningSnapshotNote, style: muted),
          _Breakdown(breakdown: breakdown),
        ],
      ],
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.breakdown});

  final Map<String, double> breakdown;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final labels = {
      'principal': l10n.myLoansBreakdownPrincipal,
      'interest': l10n.myLoansBreakdownInterest,
      'penalty': l10n.myLoansBreakdownPenalty,
    };
    return Padding(
      padding: const EdgeInsets.only(top: UmojaSpacing.xs),
      child: Column(
        children: [
          for (final key in ['principal', 'interest', 'penalty'])
            if (breakdown.containsKey(key))
              Row(
                children: [
                  Expanded(
                    child: Text(labels[key]!, style: theme.textTheme.bodySmall),
                  ),
                  Text(
                    formatAmount(breakdown[key]!),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
        ],
      ),
    );
  }
}
