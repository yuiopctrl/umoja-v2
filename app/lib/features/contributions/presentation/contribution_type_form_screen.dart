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
import '../controllers/contribution_type_form_controller.dart';
import '../providers/contribution_type_detail_provider.dart';
import 'widgets/contribution_type_labels.dart';

/// `/contributions/types/new` and `/contributions/types/:typeId/edit`:
/// one form screen for both creating and editing a contribution type.
/// MEMBER_SAVINGS is never a selectable accounting treatment here — it
/// is filtered out of the picker entirely (see
/// `contributionAccountingTreatmentOptions`/[ContributionTypeFormController]).
class ContributionTypeFormScreen extends ConsumerStatefulWidget {
  const ContributionTypeFormScreen({super.key, this.typeId});

  /// `null` for create mode; set for edit mode.
  final String? typeId;

  bool get isEditing => typeId != null;

  @override
  ConsumerState<ContributionTypeFormScreen> createState() =>
      _ContributionTypeFormScreenState();
}

class _ContributionTypeFormScreenState
    extends ConsumerState<ContributionTypeFormScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _category = 'GENERAL';
  String _accountingTreatment = 'GROUP_INCOME';
  bool _isActive = true;
  bool _prefilled = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onCategoryChanged(String? value) {
    if (value == null) return;
    setState(() {
      _category = value;
      final allowed = contributionAllowedTreatmentsForCategory(value);
      if (!allowed.contains(_accountingTreatment)) {
        _accountingTreatment = allowed.first;
      }
    });
  }

  Future<void> _submit(String groupId) async {
    FocusScope.of(context).unfocus();
    final controller = ref.read(
      contributionTypeFormControllerProvider.notifier,
    );

    if (widget.isEditing) {
      final success = await controller.updateType(
        groupId: groupId,
        typeId: widget.typeId!,
        name: _nameController.text,
        category: _category,
        accountingTreatment: _accountingTreatment,
        description: _descriptionController.text,
        isActive: _isActive,
      );
      if (success && mounted) context.pop();
      return;
    }

    final type = await controller.createType(
      groupId: groupId,
      name: _nameController.text,
      category: _category,
      accountingTreatment: _accountingTreatment,
      description: _descriptionController.text,
    );
    if (type != null && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final selectedGroup = ref.watch(selectedGroupProvider);
    final groupId = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership.group.groupId
        : null;
    final formState = ref.watch(contributionTypeFormControllerProvider);
    final l10n = context.l10n;

    if (widget.isEditing && !_prefilled) {
      final detailAsync = ref.watch(
        contributionTypeDetailProvider(widget.typeId!),
      );
      final type = detailAsync.value;
      if (type != null) {
        _nameController.text = type.name;
        _descriptionController.text = type.description ?? '';
        _category = type.category;
        _accountingTreatment = type.accountingTreatment;
        _isActive = type.isActive;
        _prefilled = true;
      }
    }

    final allowedTreatments = contributionAllowedTreatmentsForCategory(
      _category,
    );

    return UmojaPage(
      title: widget.isEditing
          ? l10n.editContributionTypeTitle
          : l10n.addContributionTypeAction,
      maxWidth: 640,
      backTo: AppRoutes.contributionTypesList,
      backLabel: l10n.contributionTypesTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UmojaFormSection(
            title: l10n.sectionContributionTypeDetails,
            fields: [
              TextField(
                controller: _nameController,
                enabled: !formState.isSubmitting,
                autofocus: !widget.isEditing,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.contributionTypeNameLabel,
                ),
              ),
              const SizedBox(height: UmojaSpacing.lg),
              TextField(
                controller: _descriptionController,
                enabled: !formState.isSubmitting,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.contributionTypeDescriptionLabel,
                ),
              ),
            ],
          ),
          UmojaFormSection(
            title: l10n.sectionContributionClassification,
            fields: [
              DropdownButtonFormField<String>(
                isExpanded: true,
                key: const Key('contributionTypeCategoryField'),
                initialValue: _category,
                decoration: InputDecoration(
                  labelText: l10n.contributionCategoryLabel,
                ),
                onChanged: formState.isSubmitting ? null : _onCategoryChanged,
                items: [
                  for (final category in contributionCategoryOptions)
                    DropdownMenuItem(
                      value: category,
                      child: Text(contributionCategoryLabel(l10n, category)),
                    ),
                ],
              ),
              const SizedBox(height: UmojaSpacing.lg),
              DropdownButtonFormField<String>(
                isExpanded: true,
                key: const Key('contributionTypeTreatmentField'),
                initialValue: _accountingTreatment,
                decoration: InputDecoration(
                  labelText: l10n.contributionAccountingTreatmentLabel,
                ),
                onChanged: formState.isSubmitting
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _accountingTreatment = value);
                      },
                items: [
                  for (final treatment
                      in contributionAccountingTreatmentOptions)
                    DropdownMenuItem(
                      // MEMBER_SAVINGS is always rendered but never
                      // enabled — see class doc.
                      enabled:
                          treatment != 'MEMBER_SAVINGS' &&
                          allowedTreatments.contains(treatment),
                      value: treatment,
                      child: Text(
                        contributionAccountingTreatmentLabel(l10n, treatment),
                        style: treatment == 'MEMBER_SAVINGS'
                            ? TextStyle(color: Theme.of(context).disabledColor)
                            : null,
                      ),
                    ),
                ],
              ),
              // PASS_THROUGH's own accounting meaning ("not ordinary
              // group income") isn't self-evident from its label alone
              // — see docs/product/contributions.md's Accounting
              // treatments section.
              if (_accountingTreatment == 'PASS_THROUGH') ...[
                const SizedBox(height: UmojaSpacing.sm),
                Text(
                  l10n.contributionTreatmentPassThroughHelp,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (widget.isEditing) ...[
                const SizedBox(height: UmojaSpacing.lg),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.contributionTypeActiveLabel),
                  value: _isActive,
                  onChanged: formState.isSubmitting
                      ? null
                      : (value) => setState(() => _isActive = value),
                ),
              ],
            ],
          ),
          if (formState.errorType != null) ...[
            Text(
              contributionFailureMessage(l10n, formState.errorType!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: UmojaSpacing.lg),
          ],
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
