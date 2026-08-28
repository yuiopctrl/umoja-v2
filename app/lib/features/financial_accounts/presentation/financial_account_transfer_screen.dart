import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../controllers/financial_account_transfer_controller.dart';
import '../providers/financial_accounts_list_provider.dart';
import 'widgets/financial_account_labels.dart';

/// `/financial-accounts/transfer`: a simple internal movement between
/// two of the group's own accounts (Prompt 08A) — never an external
/// payment; money never leaves the group. Kept deliberately minimal
/// (no advanced scheduling/batch transfer UI) — just enough to
/// exercise the cashbook's TRANSFER_IN/TRANSFER_OUT semantics.
class FinancialAccountTransferScreen extends ConsumerStatefulWidget {
  const FinancialAccountTransferScreen({super.key});

  @override
  ConsumerState<FinancialAccountTransferScreen> createState() =>
      _FinancialAccountTransferScreenState();
}

class _FinancialAccountTransferScreenState
    extends ConsumerState<FinancialAccountTransferScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _fromAccountId;
  String? _toAccountId;

  // `DropdownButtonFormField.initialValue` (like `TextFormField`'s) is
  // only honored on the field's first build — later changes made
  // programmatically (not via its own `onChanged`) are otherwise
  // invisible. These generations give each field a dedicated `Key`
  // that only changes when *we* clear a stale selection, forcing a
  // clean remount that picks the new `initialValue` back up, without
  // remounting on every ordinary user-driven selection.
  int _fromFieldGeneration = 0;
  int _toFieldGeneration = 0;

  @override
  void initState() {
    super.initState();
    // Force a refetch every time the transfer screen is entered — the
    // picker must never show a stale snapshot from an earlier read
    // (e.g. only the one account that existed when this provider was
    // first resolved elsewhere in the session). See UAT-FIX-01.
    ref.invalidate(financialAccountsActiveForPickerProvider);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onFromChanged(String? value) {
    setState(() {
      _fromAccountId = value;
      // The previously chosen destination may no longer be valid if
      // it's now the same as the new source — cleared programmatically
      // here (not via the destination field's own onChanged), so it
      // needs a fresh generation to actually show as cleared.
      if (_toAccountId == value) {
        _toAccountId = null;
        _toFieldGeneration++;
      }
    });
  }

  void _onToChanged(String? value) {
    setState(() => _toAccountId = value);
  }

  Future<void> _submit(String groupId) async {
    FocusScope.of(context).unfocus();
    final fromId = _fromAccountId;
    final toId = _toAccountId;
    final amount = double.tryParse(_amountController.text.trim());
    if (fromId == null || toId == null || amount == null || amount <= 0) {
      return;
    }

    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final success = await ref
        .read(financialAccountTransferControllerProvider.notifier)
        .transfer(
          groupId: groupId,
          fromAccountId: fromId,
          toAccountId: toId,
          amount: amount,
          // The RPC's own `default current_date` never applies once
          // PostgREST sends an explicit JSON `null` for an
          // omitted-here argument (same lesson as Prompt 06B's
          // penalty-assessment date) — so this screen must always
          // supply today's local date itself rather than leaving
          // `effectiveAt` unset. UAT-DIAG-02: omitting this made
          // every transfer fail with "Effective date is required"
          // (22023), surfaced to the user as a generic
          // "Something went wrong" error.
          effectiveAt: DateTime.now(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
        );
    if (success && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.financialAccountTransferSuccessMessage)),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedGroup = ref.watch(selectedGroupProvider);
    final accountsAsync = ref.watch(financialAccountsActiveForPickerProvider);
    final transferState = ref.watch(financialAccountTransferControllerProvider);

    final groupId = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership.group.groupId
        : null;

    return UmojaPage(
      title: l10n.financialAccountTransferTitle,
      maxWidth: 600,
      backTo: AppRoutes.financialAccountsList,
      backLabel: l10n.financialAccountsTitle,
      body: accountsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 64),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => Text(l10n.refreshFailedMessage),
        data: (accounts) {
          // A refreshed account list may no longer contain a
          // previously selected id (e.g. deactivated since); clear it
          // rather than leaving a dangling selection the dropdown
          // can't render and the backend would reject anyway.
          final fromStillValid = accounts.any((a) => a.id == _fromAccountId);
          final toStillValid = accounts.any((a) => a.id == _toAccountId);
          if (_fromAccountId != null && !fromStillValid ||
              _toAccountId != null && !toStillValid) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                if (!fromStillValid) {
                  _fromAccountId = null;
                  _fromFieldGeneration++;
                }
                if (!toStillValid) {
                  _toAccountId = null;
                  _toFieldGeneration++;
                }
              });
            });
          }
          final effectiveFromId = fromStillValid ? _fromAccountId : null;
          final effectiveToId = toStillValid ? _toAccountId : null;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'financialAccountTransferFromField-$_fromFieldGeneration',
                ),
                isExpanded: true,
                initialValue: effectiveFromId,
                decoration: InputDecoration(
                  labelText: l10n.financialAccountTransferFromLabel,
                ),
                onChanged: _onFromChanged,
                items: [
                  for (final account in accounts)
                    DropdownMenuItem(
                      value: account.id,
                      child: Text(
                        '${account.name} (${financialAccountTypeLabel(l10n, account.accountType)})',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: UmojaSpacing.lg),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'financialAccountTransferToField-$_toFieldGeneration',
                ),
                isExpanded: true,
                initialValue: effectiveToId,
                decoration: InputDecoration(
                  labelText: l10n.financialAccountTransferToLabel,
                ),
                onChanged: _onToChanged,
                items: [
                  // The destination never includes the currently
                  // selected source — it may exclude only that one
                  // account, never a whole account type.
                  for (final account in accounts)
                    if (account.id != effectiveFromId)
                      DropdownMenuItem(
                        value: account.id,
                        child: Text(
                          '${account.name} (${financialAccountTypeLabel(l10n, account.accountType)})',
                        ),
                      ),
                ],
              ),
              const SizedBox(height: UmojaSpacing.lg),
              TextField(
                key: const Key('financialAccountTransferAmountField'),
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.financialAccountTransferAmountLabel,
                ),
              ),
              const SizedBox(height: UmojaSpacing.lg),
              TextField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.financialAccountTransferDescriptionFieldLabel,
                ),
              ),
              if (transferState.errorType != null) ...[
                const SizedBox(height: UmojaSpacing.sm),
                Text(
                  financialAccountFailureMessage(
                    l10n,
                    transferState.errorType!,
                  ),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: UmojaSpacing.xxl),
              UmojaPrimaryButton(
                label: l10n.financialAccountTransferSubmitAction,
                expand: true,
                isLoading: transferState.isSubmitting,
                onPressed: groupId == null ? null : () => _submit(groupId),
              ),
            ],
          );
        },
      ),
    );
  }
}
