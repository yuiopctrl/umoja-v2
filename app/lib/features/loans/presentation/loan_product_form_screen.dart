import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/amount_input_formatter.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_form_section.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../controllers/loan_product_form_controller.dart';
import '../providers/loan_product_detail_provider.dart';
import 'widgets/loan_labels.dart';

/// `/loans/products/new` and `/loans/products/:productId/edit`: one
/// form screen for both creating and editing a loan product (Prompt
/// 09A) — code/minimum-term/maximum-term/interest-rate-basis are
/// create-only, matching the financial account form's precedent that
/// certain fields freeze once real records may reference them (loan
/// accounts snapshot these terms at creation time, so an edit here
/// never rewrites history — see docs/product/loans.md).
class LoanProductFormScreen extends ConsumerStatefulWidget {
  const LoanProductFormScreen({super.key, this.productId});

  /// `null` for create mode; set for edit mode.
  final String? productId;

  bool get isEditing => productId != null;

  @override
  ConsumerState<LoanProductFormScreen> createState() =>
      _LoanProductFormScreenState();
}

class _LoanProductFormScreenState extends ConsumerState<LoanProductFormScreen> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _minimumPrincipalController = TextEditingController();
  final _maximumPrincipalController = TextEditingController();
  final _minimumTermController = TextEditingController();
  final _maximumTermController = TextEditingController();
  final _interestRateController = TextEditingController();
  String _interestRateBasis = 'MONTHLY';
  String _interestMethod = 'FLAT';
  bool _isActive = true;
  bool _prefilled = false;

  bool _penaltyEnabled = false;
  String _penaltyType = 'FIXED';
  String _penaltyFrequency = 'ONCE';
  final _penaltyGraceDaysController = TextEditingController();
  final _penaltyFixedAmountController = TextEditingController();
  final _penaltyRateController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _minimumPrincipalController.dispose();
    _maximumPrincipalController.dispose();
    _minimumTermController.dispose();
    _maximumTermController.dispose();
    _interestRateController.dispose();
    _penaltyGraceDaysController.dispose();
    _penaltyFixedAmountController.dispose();
    _penaltyRateController.dispose();
    super.dispose();
  }

  Future<void> _submit(String groupId) async {
    FocusScope.of(context).unfocus();
    final controller = ref.read(loanProductFormControllerProvider.notifier);

    if (widget.isEditing) {
      final success = await controller.update(
        groupId: groupId,
        productId: widget.productId!,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        minimumPrincipal: parseAmountInput(_minimumPrincipalController.text),
        maximumPrincipal: parseAmountInput(_maximumPrincipalController.text),
        interestRate: double.tryParse(_interestRateController.text.trim()),
        isActive: _isActive,
        penaltyEnabled: _penaltyEnabled,
        penaltyType: _penaltyEnabled ? _penaltyType : null,
        penaltyFrequency: _penaltyEnabled ? _penaltyFrequency : null,
        penaltyGraceDays: _penaltyEnabled
            ? int.tryParse(_penaltyGraceDaysController.text.trim())
            : null,
        penaltyFixedAmount: _penaltyEnabled && _penaltyType == 'FIXED'
            ? parseAmountInput(_penaltyFixedAmountController.text)
            : null,
        penaltyRate: _penaltyEnabled && _penaltyType == 'PERCENTAGE'
            ? double.tryParse(_penaltyRateController.text.trim())
            : null,
      );
      if (success && mounted) context.pop();
      return;
    }

    final success = await controller.create(
      groupId: groupId,
      code: _codeController.text.trim(),
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      minimumPrincipal: parseAmountInput(_minimumPrincipalController.text) ?? 0,
      maximumPrincipal: parseAmountInput(_maximumPrincipalController.text),
      minimumTerm: int.tryParse(_minimumTermController.text.trim()) ?? 0,
      maximumTerm: int.tryParse(_maximumTermController.text.trim()) ?? 0,
      interestRate: double.tryParse(_interestRateController.text.trim()) ?? 0,
      interestRateBasis: _interestRateBasis,
      interestMethod: _interestMethod,
      penaltyEnabled: _penaltyEnabled,
      penaltyType: _penaltyEnabled ? _penaltyType : null,
      penaltyFrequency: _penaltyEnabled ? _penaltyFrequency : null,
      penaltyGraceDays: _penaltyEnabled
          ? (int.tryParse(_penaltyGraceDaysController.text.trim()) ?? 0)
          : null,
      penaltyFixedAmount: _penaltyEnabled && _penaltyType == 'FIXED'
          ? parseAmountInput(_penaltyFixedAmountController.text)
          : null,
      penaltyRate: _penaltyEnabled && _penaltyType == 'PERCENTAGE'
          ? double.tryParse(_penaltyRateController.text.trim())
          : null,
    );
    if (success && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final selectedGroup = ref.watch(selectedGroupProvider);
    final groupId = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership.group.groupId
        : null;
    final formState = ref.watch(loanProductFormControllerProvider);
    final l10n = context.l10n;

    if (widget.isEditing && !_prefilled) {
      final detailAsync = ref.watch(
        loanProductDetailProvider(widget.productId!),
      );
      final product = detailAsync.value;
      if (product != null) {
        _codeController.text = product.code;
        _nameController.text = product.name;
        _descriptionController.text = product.description ?? '';
        _minimumPrincipalController.text = product.minimumPrincipal
            .toStringAsFixed(0);
        _maximumPrincipalController.text =
            product.maximumPrincipal?.toStringAsFixed(0) ?? '';
        _minimumTermController.text = product.minimumTerm.toString();
        _maximumTermController.text = product.maximumTerm.toString();
        _interestRateController.text = product.interestRate.toString();
        _interestRateBasis = product.interestRateBasis;
        _interestMethod = product.interestMethod;
        _isActive = product.isActive;
        _penaltyEnabled = product.penaltyEnabled;
        _penaltyType = product.penaltyType ?? 'FIXED';
        _penaltyFrequency = product.penaltyFrequency ?? 'ONCE';
        _penaltyGraceDaysController.text =
            product.penaltyGraceDays?.toString() ?? '';
        _penaltyFixedAmountController.text =
            product.penaltyFixedAmount?.toStringAsFixed(0) ?? '';
        _penaltyRateController.text = product.penaltyRate?.toString() ?? '';
        _prefilled = true;
      }
    }

    return UmojaPage(
      title: widget.isEditing
          ? l10n.loanProductEditTitle
          : l10n.loanProductNewTitle,
      maxWidth: 640,
      backTo: AppRoutes.loanProductsList,
      backLabel: l10n.loanProductsTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UmojaFormSection(
            title: l10n.sectionLoanProductDetails,
            fields: [
              if (!widget.isEditing)
                TextField(
                  key: const Key('loanProductCodeField'),
                  controller: _codeController,
                  enabled: !formState.isSubmitting,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.loanProductCodeFieldLabel,
                  ),
                ),
              if (!widget.isEditing) const SizedBox(height: UmojaSpacing.lg),
              TextField(
                key: const Key('loanProductNameField'),
                controller: _nameController,
                enabled: !formState.isSubmitting,
                decoration: InputDecoration(
                  labelText: l10n.loanProductNameFieldLabel,
                ),
              ),
              const SizedBox(height: UmojaSpacing.lg),
              TextField(
                key: const Key('loanProductDescriptionField'),
                controller: _descriptionController,
                enabled: !formState.isSubmitting,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.loanProductDescriptionFieldLabel,
                ),
              ),
              if (widget.isEditing)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _isActive
                        ? l10n.loanProductActiveBadge
                        : l10n.loanProductInactiveBadge,
                  ),
                  value: _isActive,
                  onChanged: formState.isSubmitting
                      ? null
                      : (value) => setState(() => _isActive = value),
                ),
            ],
          ),
          UmojaFormSection(
            title: l10n.sectionLoanProductTerms,
            fields: [
              TextField(
                key: const Key('loanProductMinimumPrincipalField'),
                controller: _minimumPrincipalController,
                enabled: !formState.isSubmitting,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: const [ThousandsInputFormatter()],
                decoration: InputDecoration(
                  labelText: l10n.loanProductMinimumPrincipalFieldLabel,
                ),
              ),
              const SizedBox(height: UmojaSpacing.lg),
              TextField(
                key: const Key('loanProductMaximumPrincipalField'),
                controller: _maximumPrincipalController,
                enabled: !formState.isSubmitting,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: const [ThousandsInputFormatter()],
                decoration: InputDecoration(
                  labelText: l10n.loanProductMaximumPrincipalFieldLabel,
                ),
              ),
              const SizedBox(height: UmojaSpacing.lg),
              if (!widget.isEditing) ...[
                TextField(
                  key: const Key('loanProductMinimumTermField'),
                  controller: _minimumTermController,
                  enabled: !formState.isSubmitting,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.loanProductMinimumTermFieldLabel,
                  ),
                ),
                const SizedBox(height: UmojaSpacing.lg),
                TextField(
                  key: const Key('loanProductMaximumTermField'),
                  controller: _maximumTermController,
                  enabled: !formState.isSubmitting,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.loanProductMaximumTermFieldLabel,
                  ),
                ),
                const SizedBox(height: UmojaSpacing.lg),
              ],
              TextField(
                key: const Key('loanProductInterestRateField'),
                controller: _interestRateController,
                enabled: !formState.isSubmitting,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.loanProductInterestRateFieldLabel,
                ),
              ),
              const SizedBox(height: UmojaSpacing.lg),
              if (!widget.isEditing)
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: const Key('loanProductInterestRateBasisField'),
                  initialValue: _interestRateBasis,
                  decoration: InputDecoration(
                    labelText: l10n.loanProductInterestRateBasisFieldLabel,
                  ),
                  onChanged: formState.isSubmitting
                      ? null
                      : (value) => setState(() => _interestRateBasis = value!),
                  items: [
                    for (final basis in loanInterestRateBasisOptions)
                      DropdownMenuItem(
                        value: basis,
                        child: Text(loanInterestRateBasisLabel(l10n, basis)),
                      ),
                  ],
                ),
              if (!widget.isEditing) const SizedBox(height: UmojaSpacing.lg),
              if (!widget.isEditing)
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: const Key('loanProductInterestMethodField'),
                  initialValue: _interestMethod,
                  decoration: InputDecoration(
                    labelText: l10n.loanProductInterestMethodFieldLabel,
                  ),
                  onChanged: formState.isSubmitting
                      ? null
                      : (value) => setState(() => _interestMethod = value!),
                  items: [
                    for (final method in loanInterestMethodOptions)
                      DropdownMenuItem(
                        value: method,
                        child: Text(loanInterestMethodLabel(l10n, method)),
                      ),
                  ],
                ),
            ],
          ),
          UmojaFormSection(
            title: l10n.sectionLoanProductPenalty,
            fields: [
              SwitchListTile(
                key: const Key('loanProductPenaltyEnabledField'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.loanProductPenaltyEnabledFieldLabel),
                value: _penaltyEnabled,
                onChanged: formState.isSubmitting
                    ? null
                    : (value) => setState(() => _penaltyEnabled = value),
              ),
              if (_penaltyEnabled) ...[
                const SizedBox(height: UmojaSpacing.sm),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: const Key('loanProductPenaltyTypeField'),
                  initialValue: _penaltyType,
                  decoration: InputDecoration(
                    labelText: l10n.loanProductPenaltyTypeFieldLabel,
                  ),
                  onChanged: formState.isSubmitting
                      ? null
                      : (value) => setState(() => _penaltyType = value!),
                  items: [
                    for (final type in loanPenaltyTypeOptions)
                      DropdownMenuItem(
                        value: type,
                        child: Text(loanPenaltyTypeLabel(l10n, type)),
                      ),
                  ],
                ),
                const SizedBox(height: UmojaSpacing.lg),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: const Key('loanProductPenaltyFrequencyField'),
                  initialValue: _penaltyFrequency,
                  decoration: InputDecoration(
                    labelText: l10n.loanProductPenaltyFrequencyFieldLabel,
                  ),
                  onChanged: formState.isSubmitting
                      ? null
                      : (value) => setState(() => _penaltyFrequency = value!),
                  items: [
                    for (final frequency in loanPenaltyFrequencyOptions)
                      DropdownMenuItem(
                        value: frequency,
                        child: Text(loanPenaltyFrequencyLabel(l10n, frequency)),
                      ),
                  ],
                ),
                const SizedBox(height: UmojaSpacing.lg),
                TextField(
                  key: const Key('loanProductPenaltyGraceDaysField'),
                  controller: _penaltyGraceDaysController,
                  enabled: !formState.isSubmitting,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.loanProductPenaltyGraceDaysFieldLabel,
                  ),
                ),
                const SizedBox(height: UmojaSpacing.lg),
                if (_penaltyType == 'FIXED')
                  TextField(
                    key: const Key('loanProductPenaltyFixedAmountField'),
                    controller: _penaltyFixedAmountController,
                    enabled: !formState.isSubmitting,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: const [ThousandsInputFormatter()],
                    decoration: InputDecoration(
                      labelText: l10n.loanProductPenaltyFixedAmountFieldLabel,
                    ),
                  )
                else
                  TextField(
                    key: const Key('loanProductPenaltyRateField'),
                    controller: _penaltyRateController,
                    enabled: !formState.isSubmitting,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.loanProductPenaltyRateFieldLabel,
                    ),
                  ),
                const SizedBox(height: UmojaSpacing.sm),
                Text(
                  loanPenaltyPolicyDescription(
                    l10n,
                    penaltyType: _penaltyType,
                    penaltyFrequency: _penaltyFrequency,
                    graceDays:
                        int.tryParse(_penaltyGraceDaysController.text.trim()) ??
                        0,
                    fixedAmount: parseAmountInput(
                      _penaltyFixedAmountController.text,
                    ),
                    rate: double.tryParse(_penaltyRateController.text.trim()),
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ] else
                Text(
                  l10n.loanPenaltyPolicyDisabledLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
          if (formState.errorType != null) ...[
            Text(
              loanFailureMessage(l10n, formState.errorType!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: UmojaSpacing.md),
          ],
          const SizedBox(height: UmojaSpacing.md),
          UmojaPrimaryButton(
            key: const Key('loanProductSaveAction'),
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
