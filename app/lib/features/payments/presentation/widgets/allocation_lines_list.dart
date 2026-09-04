import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations_x.dart';
import '../../../../core/theme/umoja_spacing.dart';
import '../../../../core/utils/kiswahili_date.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../contributions/presentation/widgets/contribution_component_labels.dart';
import '../../../loans/presentation/widgets/loan_labels.dart';
import '../../domain/payment_allocation_line.dart';
import 'payment_labels.dart';

/// Renders a list of allocation lines (payment OR wallet preview,
/// posted payment detail, or receipt) with full semantic context —
/// shared by every screen that shows an allocation, so a user never
/// sees rich context in one place and a bare "Interest — 20,000" in
/// another (Prompt 09C-UAT-FIX-02).
///
/// Contribution lines render individually, unchanged from before.
/// Loan lines (interest/principal for the SAME installment, which the
/// server always emits contiguously — see
/// `payment_compute_combined_allocation_plan`) are grouped under one
/// shared header naming the loan PRODUCT, loan NUMBER, installment, and
/// due date — the piece that was previously missing entirely, making
/// two ACTIVE loans indistinguishable before confirming an allocation.
class AllocationLinesList extends StatelessWidget {
  const AllocationLinesList({super.key, required this.lines});

  final List<PaymentAllocationLine> lines;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final groups = _groupAllocationLines(lines);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in groups) ...[
          _AllocationGroupTile(group: group, l10n: l10n),
          const SizedBox(height: UmojaSpacing.sm),
        ],
      ],
    );
  }
}

sealed class _AllocationGroup {}

class _ContributionLineGroup extends _AllocationGroup {
  _ContributionLineGroup(this.line);
  final PaymentAllocationLine line;
}

class _LoanInstallmentGroup extends _AllocationGroup {
  _LoanInstallmentGroup({
    required this.loanNumber,
    required this.loanProductName,
    required this.installmentNumber,
    required this.dueDate,
    required this.componentLines,
  });

  final String? loanNumber;
  final String? loanProductName;
  final int? installmentNumber;
  final DateTime? dueDate;
  final List<PaymentAllocationLine> componentLines;
}

/// A 09E lump-sum principal prepayment — never tied to a specific
/// installment (no due date/installment number to group by), so it
/// gets its own dedicated group rather than being folded into either
/// [_ContributionLineGroup] or [_LoanInstallmentGroup].
class _PrincipalPrepaymentGroup extends _AllocationGroup {
  _PrincipalPrepaymentGroup(this.line);
  final PaymentAllocationLine line;
}

/// Interest and principal for the same loan installment are always
/// emitted contiguously by the server's allocation walk, so a simple
/// adjacent-run grouping is correct and complete — never a client-side
/// reordering of what the server returned.
List<_AllocationGroup> _groupAllocationLines(
  List<PaymentAllocationLine> lines,
) {
  final groups = <_AllocationGroup>[];
  var i = 0;
  while (i < lines.length) {
    final line = lines[i];
    if (line.isPrincipalPrepayment) {
      groups.add(_PrincipalPrepaymentGroup(line));
      i++;
      continue;
    }
    if (!line.isLoan) {
      groups.add(_ContributionLineGroup(line));
      i++;
      continue;
    }

    // Keyed on loanNumber (always populated whenever a row is a loan
    // row) rather than loanAccountId — a receipt/preview line always
    // carries the human-meaningful loan number, so this is both the
    // more robust key and what actually needs to be distinguished
    // on-screen (two different loans must never merge into one group
    // merely because they happen to share the same installment number).
    final loanNumber = line.loanNumber;
    final installmentNumber = line.installmentNumber;
    final component = <PaymentAllocationLine>[line];
    var j = i + 1;
    while (j < lines.length &&
        lines[j].isLoan &&
        lines[j].loanNumber == loanNumber &&
        lines[j].installmentNumber == installmentNumber) {
      component.add(lines[j]);
      j++;
    }
    groups.add(
      _LoanInstallmentGroup(
        loanNumber: line.loanNumber,
        loanProductName: line.loanProductName,
        installmentNumber: installmentNumber,
        dueDate: line.dueDate,
        componentLines: component,
      ),
    );
    i = j;
  }
  return groups;
}

class _AllocationGroupTile extends StatelessWidget {
  const _AllocationGroupTile({required this.group, required this.l10n});

  final _AllocationGroup group;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final group = this.group;
    if (group is _ContributionLineGroup) {
      final line = group.line;
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  obligationContextLabel(
                    contributionTypeName: line.contributionTypeName,
                    periodLabel: line.periodLabel,
                    periodPurpose: line.periodPurpose,
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(contributionComponentTypeLabel(l10n, line.componentType)),
              ],
            ),
          ),
          const SizedBox(width: UmojaSpacing.sm),
          Text(formatAmount(line.amount)),
        ],
      );
    }

    if (group is _PrincipalPrepaymentGroup) {
      final line = group.line;
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.loanPrepaymentTitle,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (line.loanProductName != null) Text(line.loanProductName!),
                if (line.loanNumber != null)
                  Text(
                    line.loanNumber!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          const SizedBox(width: UmojaSpacing.sm),
          Text(formatAmount(line.amount)),
        ],
      );
    }

    group as _LoanInstallmentGroup;
    final dueDate = group.dueDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (group.loanProductName != null)
          Text(
            group.loanProductName!,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        if (group.loanNumber != null)
          Text(group.loanNumber!, style: Theme.of(context).textTheme.bodySmall),
        Text(
          [
            if (group.installmentNumber != null)
              l10n.loanInstallmentNumberLabel(group.installmentNumber!),
            if (dueDate != null)
              '${l10n.loanAllocationDueDateLabel} ${formatKiswahiliDate(dueDate)}',
          ].join(' • '),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: UmojaSpacing.xs),
        for (final componentLine in group.componentLines)
          Padding(
            padding: const EdgeInsets.only(bottom: UmojaSpacing.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    loanComponentTypeLabel(l10n, componentLine.componentType),
                  ),
                ),
                const SizedBox(width: UmojaSpacing.sm),
                Text(formatAmount(componentLine.amount)),
              ],
            ),
          ),
      ],
    );
  }
}
