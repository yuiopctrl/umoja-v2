import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations_x.dart';
import '../../../../core/theme/umoja_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../contributions/presentation/widgets/contribution_type_labels.dart';
import '../../domain/my_contribution.dart';
import 'my_contribution_labels.dart';

/// The filter selection returned by [showMyContributionsFilterSheet].
/// `null` status / type / dates mean "All" / no bound.
class MyContributionsFilters {
  const MyContributionsFilters({
    this.status,
    this.contributionTypeId,
    this.fromDate,
    this.toDate,
  });

  final MyContributionStatus? status;
  final String? contributionTypeId;
  final DateTime? fromDate;
  final DateTime? toDate;
}

/// Compact bottom sheet for status, contribution type, and date filters
/// (Prompt 09G-B4-C §K). Works from a draft: nothing applies until the
/// member taps Apply. The only local validation is the structural
/// from <= to rule; no financial validation happens here.
Future<MyContributionsFilters?> showMyContributionsFilterSheet(
  BuildContext context, {
  required MyContributionsFilters current,
  required List<MyContributionTypeOption> contributionTypes,
}) {
  return showModalBottomSheet<MyContributionsFilters>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _MyContributionsFilterSheet(
      current: current,
      contributionTypes: contributionTypes,
    ),
  );
}

class _MyContributionsFilterSheet extends StatefulWidget {
  const _MyContributionsFilterSheet({
    required this.current,
    required this.contributionTypes,
  });

  final MyContributionsFilters current;
  final List<MyContributionTypeOption> contributionTypes;

  @override
  State<_MyContributionsFilterSheet> createState() =>
      _MyContributionsFilterSheetState();
}

class _MyContributionsFilterSheetState
    extends State<_MyContributionsFilterSheet> {
  late MyContributionStatus? _status = widget.current.status;
  late String? _typeId = widget.current.contributionTypeId;
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
      setState(() => _error = context.l10n.myContributionsFromAfterToError);
      return;
    }
    Navigator.of(context).pop(
      MyContributionsFilters(
        status: _status,
        contributionTypeId: _typeId,
        fromDate: from,
        toDate: to,
      ),
    );
  }

  void _clearAll() {
    Navigator.of(context).pop(const MyContributionsFilters());
  }

  String _dateText(DateTime? date, String label) {
    final l10n = context.l10n;
    return date == null
        ? '$label: ${l10n.myContributionsDateNotSet}'
        : '$label: ${formatMyContributionDate(date)}';
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
              l10n.myContributionsFilterSheetTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: UmojaSpacing.lg),
            Text(
              l10n.myContributionsStatusLabel,
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: UmojaSpacing.sm),
            Wrap(
              spacing: UmojaSpacing.sm,
              runSpacing: UmojaSpacing.sm,
              children: [
                _StatusChip(
                  key: const Key('myContributionsStatusChip_all'),
                  label: l10n.myContributionsAllStatuses,
                  selected: _status == null,
                  onSelected: () => setState(() => _status = null),
                ),
                for (final status in MyContributionStatus.values)
                  _StatusChip(
                    key: Key('myContributionsStatusChip_${status.wire}'),
                    label: myContributionStatusLabel(l10n, status),
                    selected: _status == status,
                    onSelected: () => setState(() => _status = status),
                  ),
              ],
            ),
            const SizedBox(height: UmojaSpacing.lg),
            Text(
              l10n.myContributionsTypeLabel,
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: UmojaSpacing.sm),
            _TypeOptionTile(
              key: const Key('myContributionsTypeOption_all'),
              title: l10n.myContributionsAllTypes,
              selected: _typeId == null,
              onTap: () => setState(() => _typeId = null),
            ),
            for (final option in widget.contributionTypes)
              _TypeOptionTile(
                key: Key('myContributionsTypeOption_${option.id}'),
                title: option.name,
                subtitle: _typeSubtitle(l10n, option),
                selected: _typeId == option.id,
                onTap: () => setState(() => _typeId = option.id),
              ),
            const SizedBox(height: UmojaSpacing.lg),
            Wrap(
              spacing: UmojaSpacing.sm,
              runSpacing: UmojaSpacing.sm,
              children: [
                OutlinedButton.icon(
                  key: const Key('myContributionsFromDateAction'),
                  onPressed: () => _pickDate(isFrom: true),
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text(_dateText(_from, l10n.myContributionsFromLabel)),
                ),
                OutlinedButton.icon(
                  key: const Key('myContributionsToDateAction'),
                  onPressed: () => _pickDate(isFrom: false),
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text(_dateText(_to, l10n.myContributionsToLabel)),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: UmojaSpacing.sm),
              Text(
                _error!,
                key: const Key('myContributionsFilterError'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: UmojaSpacing.xl),
            Row(
              children: [
                TextButton(
                  key: const Key('myContributionsClearFiltersSheetAction'),
                  onPressed: _clearAll,
                  child: Text(l10n.myContributionsClearFiltersAction),
                ),
                const Spacer(),
                FilledButton(
                  key: const Key('myContributionsApplyFiltersAction'),
                  onPressed: _apply,
                  child: Text(l10n.myContributionsApplyAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _typeSubtitle(AppLocalizations l10n, MyContributionTypeOption option) {
    final category = contributionCategoryLabel(l10n, option.category);
    final previous = option.previouslyRecordedNames;
    if (previous.isEmpty) return category;
    return '$category\n${l10n.myContributionsPreviouslyRecordedAs(previous.join(', '))}';
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

class _TypeOptionTile extends StatelessWidget {
  const _TypeOptionTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      selected: selected,
      trailing: selected ? const Icon(Icons.check) : null,
      onTap: onTap,
    );
  }
}
