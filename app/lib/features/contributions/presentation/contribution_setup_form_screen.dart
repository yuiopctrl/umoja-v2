import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/amount_input_formatter.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_form_section.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../controllers/contribution_setup_form_controller.dart';
import '../domain/contribution_setup.dart';
import '../providers/contribution_setup_detail_provider.dart';
import '../providers/contribution_type_detail_provider.dart';
import '../providers/contribution_type_picker_provider.dart';
import 'widgets/contribution_setup_labels.dart';

/// `/contributions/setups/new` and
/// `/contributions/setups/:setupId/edit`: one form screen for both
/// creating and editing a contribution setup.
///
/// `contribution_type_id`/`schedule_mode`/`amount_mode` are only ever
/// set at creation — `rpc_update_contribution_setup` has no parameters
/// for them, so the edit form shows them read-only.
///
/// The backend locks `fixed_amount`/`default_due_day`/
/// `default_due_month_offset`/every `penalty_*` field
/// (`CONTRIBUTION_SETUP_CONFIG_LOCKED`) the moment *any* of them is
/// resent as non-null once a period under this setup has posted
/// charges — including resending the same unchanged value. Since the
/// read RPCs expose no "is this setup locked" flag to disable those
/// fields outright, this form instead only ever sends a config field to
/// the update RPC when the user actually changed it from what was
/// loaded (see [_submit]) — a plain name/description/active edit on a
/// locked setup therefore still succeeds, and only an actual attempt to
/// change locked configuration surfaces the friendly locked error.
class ContributionSetupFormScreen extends ConsumerStatefulWidget {
  const ContributionSetupFormScreen({super.key, this.setupId});

  /// `null` for create mode; set for edit mode.
  final String? setupId;

  bool get isEditing => setupId != null;

  @override
  ConsumerState<ContributionSetupFormScreen> createState() =>
      _ContributionSetupFormScreenState();
}

class _ContributionSetupFormScreenState
    extends ConsumerState<ContributionSetupFormScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _fixedAmountController = TextEditingController();
  final _dueDayController = TextEditingController();
  final _dueMonthOffsetController = TextEditingController();
  final _penaltyGraceDaysController = TextEditingController();
  final _penaltyValueController = TextEditingController();
  final _penaltyCapAmountController = TextEditingController();

  String? _contributionTypeId;
  String _scheduleMode = 'MONTHLY';
  String _amountMode = 'FIXED';
  String _penaltyMode = 'NONE';
  bool _isActive = true;
  bool _prefilled = false;
  ContributionSetup? _original;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _fixedAmountController.dispose();
    _dueDayController.dispose();
    _dueMonthOffsetController.dispose();
    _penaltyGraceDaysController.dispose();
    _penaltyValueController.dispose();
    _penaltyCapAmountController.dispose();
    super.dispose();
  }

  double? _parseAmount(String text) => parseAmountInput(text);

  int? _parseInt(String text) {
    final t = text.trim();
    return t.isEmpty ? null : int.tryParse(t);
  }

  Future<void> _submit(String groupId) async {
    FocusScope.of(context).unfocus();
    final controller = ref.read(
      contributionSetupFormControllerProvider.notifier,
    );

    if (widget.isEditing) {
      final original = _original!;
      final fixedAmount = _parseAmount(_fixedAmountController.text);
      final dueDay = _parseInt(_dueDayController.text);
      final dueMonthOffset = _parseInt(_dueMonthOffsetController.text);
      final penaltyGraceDays = _parseInt(_penaltyGraceDaysController.text);
      final penaltyValue = _parseAmount(_penaltyValueController.text);
      final penaltyCapAmount = _parseAmount(_penaltyCapAmountController.text);

      final fixedAmountChanged = fixedAmount != original.fixedAmount;
      final dueDayChanged = dueDay != original.defaultDueDay;
      final dueMonthOffsetChanged =
          dueMonthOffset != original.defaultDueMonthOffset;
      final penaltyModeChanged = _penaltyMode != original.penaltyMode;
      final penaltyGraceDaysChanged =
          penaltyGraceDays != original.penaltyGraceDays;
      final penaltyValueChanged = penaltyValue != original.penaltyValue;
      final penaltyCapAmountChanged =
          penaltyCapAmount != original.penaltyCapAmount;
      final penaltyFieldsChanged =
          penaltyModeChanged ||
          penaltyGraceDaysChanged ||
          penaltyValueChanged ||
          penaltyCapAmountChanged;

      final success = await controller.updateSetup(
        groupId: groupId,
        setupId: widget.setupId!,
        name: _nameController.text,
        amountMode: _amountMode,
        description: _descriptionController.text,
        fixedAmount: fixedAmountChanged ? fixedAmount : null,
        defaultDueDay: dueDayChanged ? dueDay : null,
        defaultDueMonthOffset: dueMonthOffsetChanged ? dueMonthOffset : null,
        penaltyMode: penaltyFieldsChanged ? _penaltyMode : original.penaltyMode,
        penaltyGraceDays: penaltyFieldsChanged ? penaltyGraceDays : null,
        penaltyValue: penaltyFieldsChanged ? penaltyValue : null,
        penaltyCapAmount: penaltyFieldsChanged ? penaltyCapAmount : null,
        isActive: _isActive,
      );
      if (success && mounted) context.pop();
      return;
    }

    final typeId = _contributionTypeId;
    if (typeId == null) return;

    final setup = await controller.createSetup(
      groupId: groupId,
      contributionTypeId: typeId,
      name: _nameController.text,
      scheduleMode: _scheduleMode,
      amountMode: _amountMode,
      description: _descriptionController.text,
      fixedAmount: _parseAmount(_fixedAmountController.text),
      defaultDueDay: _parseInt(_dueDayController.text),
      defaultDueMonthOffset: _parseInt(_dueMonthOffsetController.text),
      penaltyMode: _penaltyMode,
      penaltyGraceDays: _parseInt(_penaltyGraceDaysController.text),
      penaltyValue: _parseAmount(_penaltyValueController.text),
      penaltyCapAmount: _parseAmount(_penaltyCapAmountController.text),
    );
    if (setup != null && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final selectedGroup = ref.watch(selectedGroupProvider);
    final groupId = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership.group.groupId
        : null;
    final formState = ref.watch(contributionSetupFormControllerProvider);
    final l10n = context.l10n;

    if (widget.isEditing && !_prefilled) {
      final detailAsync = ref.watch(
        contributionSetupDetailProvider(widget.setupId!),
      );
      final setup = detailAsync.value;
      if (setup != null) {
        _nameController.text = setup.name;
        _descriptionController.text = setup.description ?? '';
        _contributionTypeId = setup.contributionTypeId;
        _scheduleMode = setup.scheduleMode;
        _amountMode = setup.amountMode;
        _fixedAmountController.text = setup.fixedAmount == null
            ? ''
            : formatAmount(setup.fixedAmount!);
        _dueDayController.text = setup.defaultDueDay?.toString() ?? '';
        _dueMonthOffsetController.text =
            setup.defaultDueMonthOffset?.toString() ?? '';
        _penaltyMode = setup.penaltyMode;
        _penaltyGraceDaysController.text =
            setup.penaltyGraceDays?.toString() ?? '';
        _penaltyValueController.text = setup.penaltyValue == null
            ? ''
            : formatAmount(setup.penaltyValue!);
        _penaltyCapAmountController.text = setup.penaltyCapAmount == null
            ? ''
            : formatAmount(setup.penaltyCapAmount!);
        _isActive = setup.isActive;
        _original = setup;
        _prefilled = true;
      }
    }

    if (widget.isEditing && !_prefilled) {
      return UmojaPage(
        title: l10n.editContributionSetupTitle,
        maxWidth: 640,
        backTo: AppRoutes.contributionSetupsList,
        backLabel: l10n.contributionSetupsTitle,
        body: const Padding(
          padding: EdgeInsets.symmetric(vertical: 64),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return UmojaPage(
      title: widget.isEditing
          ? l10n.editContributionSetupTitle
          : l10n.addContributionSetupAction,
      maxWidth: 640,
      backTo: AppRoutes.contributionSetupsList,
      backLabel: l10n.contributionSetupsTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UmojaFormSection(
            title: l10n.contributionSetupTypeLabel,
            fields: [
              if (widget.isEditing)
                _ReadOnlyTypeField(typeId: _contributionTypeId!)
              else
                _TypePickerField(
                  value: _contributionTypeId,
                  enabled: !formState.isSubmitting,
                  onChanged: (value) =>
                      setState(() => _contributionTypeId = value),
                ),
            ],
          ),
          UmojaFormSection(
            title: l10n.sectionContributionSetupDetails,
            fields: [
              TextField(
                controller: _nameController,
                enabled: !formState.isSubmitting,
                autofocus: !widget.isEditing,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.contributionSetupNameLabel,
                ),
              ),
              const SizedBox(height: UmojaSpacing.lg),
              TextField(
                controller: _descriptionController,
                enabled: !formState.isSubmitting,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.contributionSetupDescriptionLabel,
                ),
              ),
            ],
          ),
          UmojaFormSection(
            title: l10n.sectionContributionChargingRules,
            fields: [
              if (widget.isEditing)
                TextField(
                  enabled: false,
                  controller: TextEditingController(
                    text: contributionScheduleModeLabel(l10n, _scheduleMode),
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.contributionScheduleModeLabel,
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: const Key('contributionSetupScheduleModeField'),
                  initialValue: _scheduleMode,
                  decoration: InputDecoration(
                    labelText: l10n.contributionScheduleModeLabel,
                  ),
                  onChanged: formState.isSubmitting
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _scheduleMode = value);
                          }
                        },
                  items: [
                    for (final mode in contributionScheduleModeOptions)
                      DropdownMenuItem(
                        value: mode,
                        child: Text(contributionScheduleModeLabel(l10n, mode)),
                      ),
                  ],
                ),
              const SizedBox(height: UmojaSpacing.lg),
              if (widget.isEditing)
                TextField(
                  enabled: false,
                  controller: TextEditingController(
                    text: contributionAmountModeLabel(l10n, _amountMode),
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.contributionAmountModeLabel,
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: const Key('contributionSetupAmountModeField'),
                  initialValue: _amountMode,
                  decoration: InputDecoration(
                    labelText: l10n.contributionAmountModeLabel,
                  ),
                  onChanged: formState.isSubmitting
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _amountMode = value);
                          }
                        },
                  items: [
                    for (final mode in contributionAmountModeOptions)
                      DropdownMenuItem(
                        value: mode,
                        child: Text(contributionAmountModeLabel(l10n, mode)),
                      ),
                  ],
                ),
              // Progressive disclosure: the fixed-amount field only
              // appears for a FIXED setup.
              if (_amountMode == 'FIXED') ...[
                const SizedBox(height: UmojaSpacing.lg),
                TextField(
                  key: const Key('contributionSetupFixedAmountField'),
                  controller: _fixedAmountController,
                  enabled: !formState.isSubmitting,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: const [ThousandsInputFormatter()],
                  decoration: InputDecoration(
                    labelText: l10n.contributionFixedAmountLabel,
                  ),
                ),
              ],
            ],
          ),
          UmojaFormSection(
            title: l10n.sectionContributionDueDateRules,
            fields: [
              TextField(
                controller: _dueDayController,
                enabled: !formState.isSubmitting,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.contributionDefaultDueDayLabel,
                ),
              ),
              const SizedBox(height: UmojaSpacing.lg),
              TextField(
                controller: _dueMonthOffsetController,
                enabled: !formState.isSubmitting,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.contributionDefaultDueMonthOffsetLabel,
                ),
              ),
            ],
          ),
          UmojaFormSection(
            title: l10n.sectionContributionPenaltyRules,
            fields: [
              DropdownButtonFormField<String>(
                isExpanded: true,
                key: const Key('contributionSetupPenaltyModeField'),
                initialValue: _penaltyMode,
                decoration: InputDecoration(
                  labelText: l10n.contributionPenaltyModeLabel,
                ),
                onChanged: formState.isSubmitting
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _penaltyMode = value);
                        }
                      },
                items: [
                  for (final mode in contributionPenaltyModeOptions)
                    DropdownMenuItem(
                      value: mode,
                      child: Text(contributionPenaltyModeLabel(l10n, mode)),
                    ),
                ],
              ),
              // Progressive disclosure: penalty detail fields are
              // hidden entirely when penaltyMode is NONE.
              if (_penaltyMode != 'NONE') ...[
                const SizedBox(height: UmojaSpacing.lg),
                TextField(
                  key: const Key('contributionSetupPenaltyGraceDaysField'),
                  controller: _penaltyGraceDaysController,
                  enabled: !formState.isSubmitting,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.contributionPenaltyGraceDaysLabel,
                  ),
                ),
                const SizedBox(height: UmojaSpacing.lg),
                TextField(
                  key: const Key('contributionSetupPenaltyValueField'),
                  controller: _penaltyValueController,
                  enabled: !formState.isSubmitting,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: const [ThousandsInputFormatter()],
                  decoration: InputDecoration(
                    labelText: l10n.contributionPenaltyValueLabel,
                  ),
                ),
                const SizedBox(height: UmojaSpacing.lg),
                TextField(
                  key: const Key('contributionSetupPenaltyCapAmountField'),
                  controller: _penaltyCapAmountController,
                  enabled: !formState.isSubmitting,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: const [ThousandsInputFormatter()],
                  decoration: InputDecoration(
                    labelText: l10n.contributionPenaltyCapAmountLabel,
                  ),
                ),
              ],
              if (widget.isEditing) ...[
                const SizedBox(height: UmojaSpacing.lg),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.contributionSetupActiveLabel),
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
            onPressed:
                (groupId == null ||
                    (!widget.isEditing && _contributionTypeId == null))
                ? null
                : () => _submit(groupId),
          ),
        ],
      ),
    );
  }
}

class _TypePickerField extends ConsumerWidget {
  const _TypePickerField({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typesAsync = ref.watch(contributionActiveTypesForPickerProvider);
    final l10n = context.l10n;

    return typesAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, stackTrace) => Text(l10n.refreshFailedMessage),
      data: (types) => DropdownButtonFormField<String>(
        isExpanded: true,
        key: const Key('contributionSetupTypeField'),
        initialValue: value,
        decoration: InputDecoration(labelText: l10n.contributionSetupTypeLabel),
        onChanged: enabled ? onChanged : null,
        items: [
          for (final type in types)
            DropdownMenuItem(value: type.id, child: Text(type.name)),
        ],
      ),
    );
  }
}

class _ReadOnlyTypeField extends ConsumerWidget {
  const _ReadOnlyTypeField({required this.typeId});

  final String typeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeAsync = ref.watch(contributionTypeDetailProvider(typeId));
    final l10n = context.l10n;

    return TextField(
      enabled: false,
      controller: TextEditingController(text: typeAsync.value?.name ?? '…'),
      decoration: InputDecoration(labelText: l10n.contributionSetupTypeLabel),
    );
  }
}
