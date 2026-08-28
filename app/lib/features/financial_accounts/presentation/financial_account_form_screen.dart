import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_form_section.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../controllers/financial_account_form_controller.dart';
import '../providers/financial_account_detail_provider.dart';
import 'widgets/financial_account_labels.dart';

/// `/financial-accounts/new` and `/financial-accounts/:accountId/edit`:
/// one form screen for both creating and editing a financial account
/// (Prompt 08A). Editing never touches anything balance-affecting —
/// account type and opening balance are create-only; a mistaken
/// opening balance is corrected via a transfer/future reversal, never
/// by re-editing this form.
class FinancialAccountFormScreen extends ConsumerStatefulWidget {
  const FinancialAccountFormScreen({super.key, this.accountId});

  /// `null` for create mode; set for edit mode.
  final String? accountId;

  bool get isEditing => accountId != null;

  @override
  ConsumerState<FinancialAccountFormScreen> createState() =>
      _FinancialAccountFormScreenState();
}

class _FinancialAccountFormScreenState
    extends ConsumerState<FinancialAccountFormScreen> {
  final _nameController = TextEditingController();
  final _openingBalanceController = TextEditingController();
  String _accountType = 'CASH';
  DateTime _openingBalanceDate = DateTime.now();
  bool _isActive = true;
  bool _prefilled = false;

  @override
  void dispose() {
    _nameController.dispose();
    _openingBalanceController.dispose();
    super.dispose();
  }

  Future<void> _pickOpeningBalanceDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _openingBalanceDate,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
    );
    if (picked != null) setState(() => _openingBalanceDate = picked);
  }

  Future<void> _submit(String groupId) async {
    FocusScope.of(context).unfocus();
    final controller = ref.read(
      financialAccountFormControllerProvider.notifier,
    );

    if (widget.isEditing) {
      final success = await controller.update(
        groupId: groupId,
        accountId: widget.accountId!,
        name: _nameController.text.trim(),
        isActive: _isActive,
      );
      if (success && mounted) context.pop();
      return;
    }

    final openingBalance = double.tryParse(
      _openingBalanceController.text.trim(),
    );
    final success = await controller.create(
      groupId: groupId,
      name: _nameController.text.trim(),
      accountType: _accountType,
      openingBalance: openingBalance,
      openingBalanceDate: openingBalance == null ? null : _openingBalanceDate,
    );
    if (success && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final selectedGroup = ref.watch(selectedGroupProvider);
    final groupId = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership.group.groupId
        : null;
    final formState = ref.watch(financialAccountFormControllerProvider);
    final l10n = context.l10n;

    if (widget.isEditing && !_prefilled) {
      final detailAsync = ref.watch(
        financialAccountDetailProvider(widget.accountId!),
      );
      final account = detailAsync.value;
      if (account != null) {
        _nameController.text = account.name;
        _accountType = account.accountType;
        _isActive = account.isActive;
        _prefilled = true;
      }
    }

    return UmojaPage(
      title: widget.isEditing
          ? l10n.financialAccountEditTitle
          : l10n.financialAccountNewTitle,
      maxWidth: 640,
      backTo: AppRoutes.financialAccountsList,
      backLabel: l10n.financialAccountsTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UmojaFormSection(
            title: l10n.sectionFinancialAccountDetails,
            fields: [
              TextField(
                key: const Key('financialAccountNameField'),
                controller: _nameController,
                enabled: !formState.isSubmitting,
                autofocus: !widget.isEditing,
                decoration: InputDecoration(
                  labelText: l10n.financialAccountNameFieldLabel,
                ),
              ),
              const SizedBox(height: UmojaSpacing.lg),
              if (widget.isEditing)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _isActive
                        ? l10n.financialAccountActiveBadge
                        : l10n.financialAccountInactiveBadge,
                  ),
                  value: _isActive,
                  onChanged: formState.isSubmitting
                      ? null
                      : (value) => setState(() => _isActive = value),
                )
              else ...[
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: const Key('financialAccountTypeField'),
                  initialValue: _accountType,
                  decoration: InputDecoration(
                    labelText: l10n.financialAccountTypeFieldLabel,
                  ),
                  onChanged: formState.isSubmitting
                      ? null
                      : (value) => setState(() => _accountType = value!),
                  items: [
                    for (final type in financialAccountTypeOptions)
                      DropdownMenuItem(
                        value: type,
                        child: Text(financialAccountTypeLabel(l10n, type)),
                      ),
                  ],
                ),
                const SizedBox(height: UmojaSpacing.lg),
                TextField(
                  key: const Key('financialAccountOpeningBalanceField'),
                  controller: _openingBalanceController,
                  enabled: !formState.isSubmitting,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.financialAccountOpeningBalanceFieldLabel,
                  ),
                ),
                const SizedBox(height: UmojaSpacing.lg),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.financialAccountOpeningBalanceDateLabel),
                  subtitle: Text(
                    '${_openingBalanceDate.toLocal()}'.split(' ').first,
                  ),
                  trailing: const Icon(Icons.calendar_today_outlined, size: 18),
                  onTap: _pickOpeningBalanceDate,
                ),
              ],
            ],
          ),
          if (formState.errorType != null) ...[
            Text(
              financialAccountFailureMessage(l10n, formState.errorType!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: UmojaSpacing.md),
          ],
          const SizedBox(height: UmojaSpacing.md),
          UmojaPrimaryButton(
            label: l10n.saveButton,
            expand: true,
            isLoading: formState.isSubmitting,
            onPressed: groupId == null ? null : () => _submit(groupId),
          ),
        ],
      ),
    );
  }
}
