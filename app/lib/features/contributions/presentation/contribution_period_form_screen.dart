import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/kiswahili_date.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_form_section.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../controllers/contribution_period_form_controller.dart';
import '../domain/contribution_period.dart';
import '../providers/contribution_period_detail_provider.dart';
import '../providers/contribution_setup_detail_provider.dart';
import '../providers/contribution_setup_picker_provider.dart';
import 'widgets/contribution_month_label.dart';
import 'widgets/contribution_setup_labels.dart';

/// `/contributions/periods/new` and
/// `/contributions/periods/:periodId/edit`: one form screen for both
/// creating and editing a contribution period.
///
/// **Create** — for a MONTHLY setup, the user picks a month/year (never
/// raw start/end dates) and the period's calendar-month boundaries plus
/// its due date are entirely server-derived
/// (`contribution_compute_due_date` via
/// `rpc_create_contribution_period`'s own defaulting). For
/// ON_DEMAND/ONE_TIME, the label and explicit start/end dates are
/// entered directly, with an optional explicit due-date override. There
/// is no client-side due-date preview computation here by design: the
/// created DRAFT period's own returned `due_date` is shown immediately
/// after creation instead, which is the authoritative value, not a
/// duplicated approximation of the backend's day-capping rule.
///
/// **Edit** — only reachable for a DRAFT/SCHEDULED period (see
/// `ContributionPeriodDetailScreen`); `rpc_update_contribution_period`
/// itself also refuses any other status
/// (`CONTRIBUTION_PERIOD_NOT_EDITABLE`). `contribution_setup_id` can
/// never change, so the setup is shown read-only. Unlike create, every
/// key date (including `obligation_date`/`eligibility_date`, which
/// create never exposes directly) is editable via a plain date picker —
/// changing `eligibility_date` changes the open-preview roster
/// immediately since no charges exist yet.
class ContributionPeriodFormScreen extends ConsumerStatefulWidget {
  const ContributionPeriodFormScreen({super.key, this.periodId});

  /// `null` for create mode; set for edit mode.
  final String? periodId;

  bool get isEditing => periodId != null;

  @override
  ConsumerState<ContributionPeriodFormScreen> createState() =>
      _ContributionPeriodFormScreenState();
}

class _ContributionPeriodFormScreenState
    extends ConsumerState<ContributionPeriodFormScreen> {
  final _labelController = TextEditingController();
  String? _setupId;
  String? _scheduleMode;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  DateTime? _periodStart;
  DateTime? _periodEnd;
  DateTime? _dueDate;
  bool _isScheduled = false;
  DateTime? _scheduledOpenDate;

  // Edit-mode only.
  DateTime? _obligationDate;
  DateTime? _eligibilityDate;
  bool _prefilled = false;
  ContributionPeriod? _original;

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  void _onSetupChanged(String? setupId, String? scheduleMode) {
    setState(() {
      _setupId = setupId;
      _scheduleMode = scheduleMode;
    });
  }

  Future<void> _pickDate({
    required DateTime? initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _submitEdit(String groupId) async {
    FocusScope.of(context).unfocus();
    final periodId = widget.periodId;
    if (periodId == null || _periodStart == null || _periodEnd == null) {
      return;
    }

    final controller = ref.read(
      contributionPeriodFormControllerProvider.notifier,
    );

    final success = await controller.updatePeriod(
      groupId: groupId,
      periodId: periodId,
      label: _labelController.text,
      periodStart: _periodStart!,
      periodEnd: _periodEnd!,
      obligationDate: _obligationDate,
      eligibilityDate: _eligibilityDate,
      dueDate: _dueDate,
      scheduledOpenDate: _scheduledOpenDate,
    );

    if (success && mounted) context.pop();
  }

  Future<void> _submit(String groupId) async {
    FocusScope.of(context).unfocus();
    final setupId = _setupId;
    final scheduleMode = _scheduleMode;
    if (setupId == null || scheduleMode == null) return;

    final controller = ref.read(
      contributionPeriodFormControllerProvider.notifier,
    );

    late final DateTime periodStart;
    late final DateTime periodEnd;
    late final String label;

    if (scheduleMode == 'MONTHLY') {
      periodStart = DateTime(_year, _month, 1);
      periodEnd = DateTime(_year, _month + 1, 0);
      label = _labelController.text.trim().isEmpty
          ? '${contributionMonthLabel(context.l10n, _month)} $_year'
          : _labelController.text.trim();
    } else {
      if (_periodStart == null || _periodEnd == null) return;
      periodStart = _periodStart!;
      periodEnd = _periodEnd!;
      label = _labelController.text.trim();
    }

    final period = await controller.createPeriod(
      groupId: groupId,
      contributionSetupId: setupId,
      label: label,
      periodStart: periodStart,
      periodEnd: periodEnd,
      dueDate: scheduleMode == 'MONTHLY' ? null : _dueDate,
      status: _isScheduled ? 'SCHEDULED' : 'DRAFT',
      scheduledOpenDate: _isScheduled ? _scheduledOpenDate : null,
    );

    if (period != null && mounted) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.contributionPeriodCreatedTitle),
          content: Text(
            context.l10n.contributionPeriodCreatedDueDateMessage(
              formatKiswahiliDate(period.dueDate),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.closeButton),
            ),
          ],
        ),
      );
      if (mounted) {
        context.go(AppRoutes.contributionPeriodDetailPath(period.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing) return _buildEditScreen(context);

    final selectedGroup = ref.watch(selectedGroupProvider);
    final groupId = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership.group.groupId
        : null;
    final formState = ref.watch(contributionPeriodFormControllerProvider);
    final setupsAsync = ref.watch(contributionActiveSetupsForPickerProvider);
    final l10n = context.l10n;

    final isMonthly = _scheduleMode == 'MONTHLY';
    final canSubmit =
        groupId != null &&
        _setupId != null &&
        (isMonthly
            ? true
            : (_labelController.text.trim().isNotEmpty &&
                  _periodStart != null &&
                  _periodEnd != null));

    return UmojaPage(
      title: l10n.newContributionPeriodTitle,
      maxWidth: 640,
      backTo: AppRoutes.contributionPeriodsList,
      backLabel: l10n.contributionPeriodsTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UmojaFormSection(
            title: l10n.contributionPeriodSetupLabel,
            fields: [
              setupsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, stackTrace) => Text(l10n.refreshFailedMessage),
                data: (setups) => DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: const Key('contributionPeriodSetupField'),
                  initialValue: _setupId,
                  decoration: InputDecoration(
                    labelText: l10n.contributionPeriodSetupLabel,
                  ),
                  onChanged: formState.isSubmitting
                      ? null
                      : (value) {
                          String? scheduleMode;
                          for (final setup in setups) {
                            if (setup.id == value) {
                              scheduleMode = setup.scheduleMode;
                              break;
                            }
                          }
                          _onSetupChanged(value, scheduleMode);
                        },
                  items: [
                    for (final setup in setups)
                      DropdownMenuItem(
                        value: setup.id,
                        child: Text(
                          '${setup.name} (${contributionScheduleModeLabel(l10n, setup.scheduleMode)})',
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (_scheduleMode != null) ...[
            if (isMonthly)
              UmojaFormSection(
                title: l10n.contributionPeriodMonthLabel,
                fields: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          isExpanded: true,
                          key: const Key('contributionPeriodMonthField'),
                          initialValue: _month,
                          decoration: InputDecoration(
                            labelText: l10n.contributionPeriodMonthLabel,
                          ),
                          onChanged: formState.isSubmitting
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() => _month = value);
                                  }
                                },
                          items: [
                            for (var m = 1; m <= 12; m++)
                              DropdownMenuItem(
                                value: m,
                                child: Text(contributionMonthLabel(l10n, m)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: UmojaSpacing.md),
                      Expanded(
                        child: TextField(
                          key: const Key('contributionPeriodYearField'),
                          enabled: !formState.isSubmitting,
                          keyboardType: TextInputType.number,
                          controller: TextEditingController(
                            text: _year.toString(),
                          ),
                          decoration: InputDecoration(
                            labelText: l10n.contributionPeriodYearLabel,
                          ),
                          onChanged: (value) {
                            final parsed = int.tryParse(value);
                            if (parsed != null) _year = parsed;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: UmojaSpacing.lg),
                  TextField(
                    controller: _labelController,
                    enabled: !formState.isSubmitting,
                    decoration: InputDecoration(
                      labelText: l10n.contributionPeriodLabelLabel,
                      hintText:
                          '${contributionMonthLabel(l10n, _month)} $_year',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              )
            else
              UmojaFormSection(
                title: l10n.contributionPeriodLabelLabel,
                fields: [
                  TextField(
                    key: const Key('contributionPeriodLabelField'),
                    controller: _labelController,
                    enabled: !formState.isSubmitting,
                    decoration: InputDecoration(
                      labelText: l10n.contributionPeriodLabelLabel,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: UmojaSpacing.lg),
                  _DatePickerField(
                    label: l10n.contributionPeriodStartLabel,
                    value: _periodStart,
                    onTap: () => _pickDate(
                      initial: _periodStart,
                      onPicked: (date) => setState(() => _periodStart = date),
                    ),
                  ),
                  const SizedBox(height: UmojaSpacing.lg),
                  _DatePickerField(
                    label: l10n.contributionPeriodEndLabel,
                    value: _periodEnd,
                    onTap: () => _pickDate(
                      initial: _periodEnd,
                      onPicked: (date) => setState(() => _periodEnd = date),
                    ),
                  ),
                  const SizedBox(height: UmojaSpacing.lg),
                  _DatePickerField(
                    label: l10n.contributionDueDateLabel,
                    value: _dueDate,
                    onTap: () => _pickDate(
                      initial: _dueDate,
                      onPicked: (date) => setState(() => _dueDate = date),
                    ),
                  ),
                ],
              ),
            UmojaFormSection(
              title: l10n.contributionPeriodStatusScheduled,
              fields: [
                SwitchListTile(
                  key: const Key('contributionPeriodScheduledSwitch'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.contributionPeriodStatusScheduled),
                  value: _isScheduled,
                  onChanged: formState.isSubmitting
                      ? null
                      : (value) => setState(() => _isScheduled = value),
                ),
                if (_isScheduled) ...[
                  const SizedBox(height: UmojaSpacing.sm),
                  _DatePickerField(
                    label: l10n.contributionScheduledOpenDateLabel,
                    value: _scheduledOpenDate,
                    onTap: () => _pickDate(
                      initial: _scheduledOpenDate,
                      onPicked: (date) =>
                          setState(() => _scheduledOpenDate = date),
                    ),
                  ),
                ],
              ],
            ),
          ],
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
            onPressed: canSubmit ? () => _submit(groupId) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildEditScreen(BuildContext context) {
    final periodId = widget.periodId!;
    final selectedGroup = ref.watch(selectedGroupProvider);
    final groupId = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership.group.groupId
        : null;
    final formState = ref.watch(contributionPeriodFormControllerProvider);
    final l10n = context.l10n;

    if (!_prefilled) {
      final periodAsync = ref.watch(contributionPeriodDetailProvider(periodId));
      final period = periodAsync.value;
      if (period != null) {
        _labelController.text = period.label;
        _periodStart = period.periodStart;
        _periodEnd = period.periodEnd;
        _obligationDate = period.obligationDate;
        _eligibilityDate = period.eligibilityDate;
        _dueDate = period.dueDate;
        _scheduledOpenDate = period.scheduledOpenDate;
        _original = period;
        _prefilled = true;
      }
    }

    if (!_prefilled) {
      return UmojaPage(
        title: l10n.editContributionPeriodTitle,
        maxWidth: 640,
        backTo: AppRoutes.contributionPeriodDetailPath(periodId),
        backLabel: l10n.contributionPeriodDetailTitle,
        body: const Padding(
          padding: EdgeInsets.symmetric(vertical: 64),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final original = _original!;
    final setupAsync = ref.watch(
      contributionSetupDetailProvider(original.contributionSetupId),
    );

    final canSubmit =
        groupId != null &&
        _labelController.text.trim().isNotEmpty &&
        _periodStart != null &&
        _periodEnd != null;

    return UmojaPage(
      title: l10n.editContributionPeriodTitle,
      maxWidth: 640,
      backTo: AppRoutes.contributionPeriodDetailPath(periodId),
      backLabel: l10n.contributionPeriodDetailTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UmojaFormSection(
            title: l10n.contributionPeriodSetupLabel,
            fields: [
              TextField(
                enabled: false,
                controller: TextEditingController(
                  text: setupAsync.value?.name ?? '…',
                ),
                decoration: InputDecoration(
                  labelText: l10n.contributionPeriodSetupLabel,
                ),
              ),
            ],
          ),
          UmojaFormSection(
            title: l10n.contributionPeriodLabelLabel,
            fields: [
              TextField(
                key: const Key('contributionPeriodLabelField'),
                controller: _labelController,
                enabled: !formState.isSubmitting,
                decoration: InputDecoration(
                  labelText: l10n.contributionPeriodLabelLabel,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: UmojaSpacing.lg),
              _DatePickerField(
                label: l10n.contributionPeriodStartLabel,
                value: _periodStart,
                onTap: () => _pickDate(
                  initial: _periodStart,
                  onPicked: (date) => setState(() => _periodStart = date),
                ),
              ),
              const SizedBox(height: UmojaSpacing.lg),
              _DatePickerField(
                label: l10n.contributionPeriodEndLabel,
                value: _periodEnd,
                onTap: () => _pickDate(
                  initial: _periodEnd,
                  onPicked: (date) => setState(() => _periodEnd = date),
                ),
              ),
              const SizedBox(height: UmojaSpacing.lg),
              _DatePickerField(
                label: l10n.contributionObligationDateLabel,
                value: _obligationDate,
                onTap: () => _pickDate(
                  initial: _obligationDate,
                  onPicked: (date) => setState(() => _obligationDate = date),
                ),
              ),
              const SizedBox(height: UmojaSpacing.lg),
              _DatePickerField(
                label: l10n.contributionEligibilityDateLabel,
                value: _eligibilityDate,
                onTap: () => _pickDate(
                  initial: _eligibilityDate,
                  onPicked: (date) => setState(() => _eligibilityDate = date),
                ),
              ),
              const SizedBox(height: UmojaSpacing.lg),
              _DatePickerField(
                label: l10n.contributionDueDateLabel,
                value: _dueDate,
                onTap: () => _pickDate(
                  initial: _dueDate,
                  onPicked: (date) => setState(() => _dueDate = date),
                ),
              ),
              if (original.isScheduled) ...[
                const SizedBox(height: UmojaSpacing.lg),
                _DatePickerField(
                  label: l10n.contributionScheduledOpenDateLabel,
                  value: _scheduledOpenDate,
                  onTap: () => _pickDate(
                    initial: _scheduledOpenDate,
                    onPicked: (date) =>
                        setState(() => _scheduledOpenDate = date),
                  ),
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
            onPressed: canSubmit ? () => _submitEdit(groupId) : null,
          ),
        ],
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value == null ? '—' : formatKiswahiliDate(value!)),
      ),
    );
  }
}
