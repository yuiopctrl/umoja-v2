import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations_x.dart';
import '../../../../core/theme/umoja_spacing.dart';
import '../../domain/my_payment.dart';
import 'my_payment_labels.dart';

/// The filter selection returned by [showMyPaymentsFilterSheet]. `null`
/// status / dates mean "All" / no bound.
class MyPaymentsFilters {
  const MyPaymentsFilters({this.status, this.fromDate, this.toDate});

  final MyPaymentStatus? status;
  final DateTime? fromDate;
  final DateTime? toDate;
}

/// Compact bottom sheet for status and date-range filters (Prompt
/// 09G-B6-C §L), mirroring My Contributions' filter sheet. Works from a
/// draft: nothing applies until the member taps Apply. The only local
/// validation is the structural from <= to rule; no financial
/// validation happens here. Refetches from the backend on Apply —
/// never a client-side filter of the already-loaded page.
Future<MyPaymentsFilters?> showMyPaymentsFilterSheet(
  BuildContext context, {
  required MyPaymentsFilters current,
}) {
  return showModalBottomSheet<MyPaymentsFilters>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _MyPaymentsFilterSheet(current: current),
  );
}

class _MyPaymentsFilterSheet extends StatefulWidget {
  const _MyPaymentsFilterSheet({required this.current});

  final MyPaymentsFilters current;

  @override
  State<_MyPaymentsFilterSheet> createState() => _MyPaymentsFilterSheetState();
}

class _MyPaymentsFilterSheetState extends State<_MyPaymentsFilterSheet> {
  late MyPaymentStatus? _status = widget.current.status;
  late DateTime? _from = widget.current.fromDate;
  late DateTime? _to = widget.current.toDate;
  String? _error;

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _error = null;
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  void _apply() {
    final from = _from;
    final to = _to;
    if (from != null && to != null && from.isAfter(to)) {
      setState(() => _error = context.l10n.myPaymentsFromAfterToError);
      return;
    }
    Navigator.of(context)
        .pop(MyPaymentsFilters(status: _status, fromDate: from, toDate: to));
  }

  void _clearAll() {
    Navigator.of(context).pop(const MyPaymentsFilters());
  }

  String _dateText(DateTime? date, String label) {
    final l10n = context.l10n;
    return date == null
        ? '$label: ${l10n.myPaymentsDateNotSet}'
        : '$label: ${formatMyPaymentDate(date)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          UmojaSpacing.lg,
          0,
          UmojaSpacing.lg,
          UmojaSpacing.lg + bottomInset,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.myPaymentsFilterSheetTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: UmojaSpacing.lg),
            Text(
              l10n.myPaymentsStatusLabel,
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: UmojaSpacing.sm),
            Wrap(
              spacing: UmojaSpacing.sm,
              runSpacing: UmojaSpacing.sm,
              children: [
                _StatusChip(
                  key: const Key('myPaymentsStatusChip_all'),
                  label: l10n.myPaymentsAllStatuses,
                  selected: _status == null,
                  onSelected: () => setState(() => _status = null),
                ),
                for (final status in MyPaymentStatus.values)
                  if (status != MyPaymentStatus.unknown)
                    _StatusChip(
                      key: Key('myPaymentsStatusChip_${status.wire}'),
                      label: myPaymentStatusLabel(l10n, status),
                      selected: _status == status,
                      onSelected: () => setState(() => _status = status),
                    ),
              ],
            ),
            const SizedBox(height: UmojaSpacing.lg),
            Wrap(
              spacing: UmojaSpacing.sm,
              runSpacing: UmojaSpacing.sm,
              children: [
                OutlinedButton.icon(
                  key: const Key('myPaymentsFromDateAction'),
                  onPressed: () => _pickDate(isFrom: true),
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text(_dateText(_from, l10n.myPaymentsFromLabel)),
                ),
                OutlinedButton.icon(
                  key: const Key('myPaymentsToDateAction'),
                  onPressed: () => _pickDate(isFrom: false),
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text(_dateText(_to, l10n.myPaymentsToLabel)),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: UmojaSpacing.sm),
              Text(
                _error!,
                key: const Key('myPaymentsFilterError'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: UmojaSpacing.xl),
            Row(
              children: [
                TextButton(
                  key: const Key('myPaymentsClearFiltersSheetAction'),
                  onPressed: _clearAll,
                  child: Text(l10n.myPaymentsClearFiltersAction),
                ),
                const Spacer(),
                FilledButton(
                  key: const Key('myPaymentsApplyFiltersAction'),
                  onPressed: _apply,
                  child: Text(l10n.myPaymentsApplyAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}
