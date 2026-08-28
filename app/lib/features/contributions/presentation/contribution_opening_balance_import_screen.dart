import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../core/widgets/umoja_search_field.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../../members/domain/group_member.dart';
import '../../members/providers/member_repository_provider.dart';
import '../controllers/contribution_opening_balance_import_controller.dart';
import '../data/contribution_opening_balance_entry_input.dart';
import '../domain/contribution_opening_balance_preview.dart';
import '../providers/contribution_type_picker_provider.dart';

/// `/contributions/opening-balances/import`: batch pre-Umoja opening
/// balance import (Prompt 06C) — choose contribution type → effective
/// date → search and add members → enter amounts → server-authoritative
/// preview → confirm. Atomic on the backend: either every entry posts,
/// or none do. Never creates a cash/payment/receipt row of any kind,
/// and never computes the batch total or duplicate-import flag itself
/// — [ContributionOpeningBalanceImportController.preview] always
/// supplies both.
class ContributionOpeningBalanceImportScreen extends ConsumerStatefulWidget {
  const ContributionOpeningBalanceImportScreen({super.key});

  @override
  ConsumerState<ContributionOpeningBalanceImportScreen> createState() =>
      _ContributionOpeningBalanceImportScreenState();
}

class _ContributionOpeningBalanceImportScreenState
    extends ConsumerState<ContributionOpeningBalanceImportScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String? _typeId;
  DateTime? _effectiveAt;
  final Map<String, GroupMember> _selected = {};
  final Map<String, TextEditingController> _amountControllers = {};
  List<GroupMember> _searchResults = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    for (final controller in _amountControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _amountControllerFor(String membershipId) {
    return _amountControllers.putIfAbsent(
      membershipId,
      () => TextEditingController(),
    );
  }

  void _addMember(GroupMember member) {
    setState(() {
      _selected[member.membershipId] = member;
      _amountControllerFor(member.membershipId);
    });
  }

  void _removeMember(String membershipId) {
    setState(() {
      _selected.remove(membershipId);
      _amountControllers.remove(membershipId)?.dispose();
    });
    ref
        .read(contributionOpeningBalanceImportControllerProvider.notifier)
        .reset();
  }

  void _onSearchChanged(String value, String groupId) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _searchResults = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final page = await ref
          .read(memberRepositoryProvider)
          .listMembers(
            groupId: groupId,
            search: value,
            status: 'ACTIVE',
            limit: 20,
          );
      if (mounted) setState(() => _searchResults = page.items);
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveAt ?? now,
      firstDate: DateTime(now.year - 20),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _effectiveAt = picked);
      ref
          .read(contributionOpeningBalanceImportControllerProvider.notifier)
          .reset();
    }
  }

  List<ContributionOpeningBalanceEntryInput> _entries() {
    return _selected.keys
        .map(
          (membershipId) => ContributionOpeningBalanceEntryInput(
            membershipId: membershipId,
            amount: double.tryParse(
              _amountControllerFor(membershipId).text.trim(),
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<void> _preview(String groupId) async {
    final typeId = _typeId;
    final effectiveAt = _effectiveAt;
    if (typeId == null || effectiveAt == null || _selected.isEmpty) return;
    await ref
        .read(contributionOpeningBalanceImportControllerProvider.notifier)
        .preview(
          groupId: groupId,
          contributionTypeId: typeId,
          effectiveAt: effectiveAt,
          entries: _entries(),
        );
  }

  Future<void> _confirm(String groupId) async {
    final typeId = _typeId;
    final effectiveAt = _effectiveAt;
    if (typeId == null || effectiveAt == null) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final success = await ref
        .read(contributionOpeningBalanceImportControllerProvider.notifier)
        .confirmImport(
          groupId: groupId,
          contributionTypeId: typeId,
          effectiveAt: effectiveAt,
          entries: _entries(),
        );
    if (success && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.openingBalanceImportSuccessMessage)),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedGroup = ref.watch(selectedGroupProvider);
    final typesAsync = ref.watch(contributionActiveTypesForPickerProvider);
    final importState = ref.watch(
      contributionOpeningBalanceImportControllerProvider,
    );

    final groupId = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership.group.groupId
        : null;

    return UmojaPage(
      title: l10n.openingBalanceImportTitle,
      maxWidth: 700,
      backTo: AppRoutes.contributionOpeningBalancesList,
      backLabel: l10n.openingBalancesTitle,
      body: groupId == null
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                typesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stackTrace) => Text(l10n.refreshFailedMessage),
                  data: (types) => DropdownButtonFormField<String>(
                    key: const Key('openingBalanceTypeField'),
                    isExpanded: true,
                    initialValue: _typeId,
                    decoration: InputDecoration(
                      labelText: l10n.openingBalanceContributionTypeLabel,
                    ),
                    items: [
                      for (final type in types)
                        DropdownMenuItem(
                          value: type.id,
                          child: Text(type.name),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() => _typeId = value);
                      ref
                          .read(
                            contributionOpeningBalanceImportControllerProvider
                                .notifier,
                          )
                          .reset();
                    },
                  ),
                ),
                const SizedBox(height: UmojaSpacing.lg),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.openingBalanceEffectiveDateLabel),
                  subtitle: Text(
                    _effectiveAt == null
                        ? ''
                        : '${_effectiveAt!.toLocal()}'.split(' ').first,
                  ),
                  trailing: const Icon(Icons.calendar_today_outlined, size: 18),
                  onTap: _pickDate,
                ),
                const SizedBox(height: UmojaSpacing.lg),
                UmojaSearchField(
                  controller: _searchController,
                  hintText: l10n.openingBalanceSearchHint,
                  onChanged: (value) => _onSearchChanged(value, groupId),
                ),
                if (_searchResults.isNotEmpty)
                  ..._searchResults.map(
                    (member) => ListTile(
                      dense: true,
                      title: Text(member.displayName),
                      subtitle: member.memberNumber == null
                          ? null
                          : Text(member.memberNumber!),
                      trailing: _selected.containsKey(member.membershipId)
                          ? const Icon(Icons.check_circle, size: 18)
                          : const Icon(Icons.add_circle_outline, size: 18),
                      onTap: () => _addMember(member),
                    ),
                  ),
                const SizedBox(height: UmojaSpacing.lg),
                for (final member in _selected.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: UmojaSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(member.displayName)),
                        const SizedBox(width: UmojaSpacing.md),
                        SizedBox(
                          width: 140,
                          child: TextField(
                            key: Key(
                              'openingBalanceAmount_${member.membershipId}',
                            ),
                            controller: _amountControllerFor(
                              member.membershipId,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: l10n.openingBalanceAmountFieldLabel,
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => _removeMember(member.membershipId),
                        ),
                      ],
                    ),
                  ),
                if (importState.errorType != null) ...[
                  const SizedBox(height: UmojaSpacing.sm),
                  Text(
                    contributionFailureMessage(l10n, importState.errorType!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                if (importState.preview != null) ...[
                  const SizedBox(height: UmojaSpacing.lg),
                  _PreviewSummary(preview: importState.preview!),
                ],
                const SizedBox(height: UmojaSpacing.xxl),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            (_typeId == null ||
                                _effectiveAt == null ||
                                _selected.isEmpty ||
                                importState.isPreviewing)
                            ? null
                            : () => _preview(groupId),
                        child: Text(l10n.openingBalancePreviewAction),
                      ),
                    ),
                    const SizedBox(width: UmojaSpacing.md),
                    Expanded(
                      child: UmojaPrimaryButton(
                        label: l10n.openingBalanceConfirmImportAction,
                        isLoading: importState.isImporting,
                        onPressed: (importState.preview?.canImport ?? false)
                            ? () => _confirm(groupId)
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _PreviewSummary extends StatelessWidget {
  const _PreviewSummary({required this.preview});

  final ContributionOpeningBalancePreview preview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(UmojaSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.openingBalanceMemberCountLabel),
              Text('${preview.memberCount}'),
            ],
          ),
          const SizedBox(height: UmojaSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.openingBalanceTotalLabel),
              Text(formatAmount(preview.totalOpeningObligation)),
            ],
          ),
          if (!preview.canImport) ...[
            const SizedBox(height: UmojaSpacing.sm),
            Text(
              l10n.openingBalanceCannotImportMessage,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
