import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/amount_input_formatter.dart';
import '../../../core/utils/kiswahili_date.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_card.dart';
import '../../../core/widgets/umoja_empty_state.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_form_section.dart';
import '../../../core/widgets/umoja_loading_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../core/widgets/umoja_status_badge.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../../members/domain/group_member.dart';
import '../../payments/presentation/widgets/member_search_picker.dart';
import '../controllers/loan_migration_controller.dart';
import '../domain/loan_historical_arrears_installment.dart';
import '../domain/loan_migration_preview.dart';
import '../domain/loan_product.dart';
import '../providers/loan_products_provider.dart';
import 'widgets/loan_labels.dart';

enum _Step { pickMember, pickProduct, form, schedulePreview, review, success }

enum _ImportMode { simple, detailed }

/// `/loans/accounts/existing`: Ingiza Mkopo Uliopo (Prompt
/// 09D-UAT-BLOCKER-01, extended 09D-UAT-BLOCKER-03) — a deliberately
/// SEPARATE workflow from [NewLoanScreen]. Never a backdate checkbox
/// bolted onto ordinary loan creation: this posts an OPENING FINANCIAL
/// POSITION (zero cashbook movement, zero income/expense, zero
/// Financial Account) via the single atomic `rpc_create_migrated_loan`,
/// never the ordinary DRAFT->SUBMITTED->APPROVED->DISBURSE lifecycle.
///
/// Two import modes (section D): SIMPLE (default — original contract
/// terms + total historical arrears; the server reconstructs the
/// contractual schedule and separates the brought-forward penalty) and
/// DETAILED (the BLOCKER-02 repeatable per-installment list, for
/// statements with an exact historical breakdown). Flow: Member ->
/// Product -> Contract/Opening Position form -> **Schedule Preview**
/// (server-authoritative, non-persisting) -> **Review & Confirm** ->
/// Success. No loan is ever posted before the user has seen the full
/// reconstructed schedule (section J/L) — posting only happens from
/// the final Review step.
class NewExistingLoanScreen extends ConsumerStatefulWidget {
  const NewExistingLoanScreen({super.key});

  @override
  ConsumerState<NewExistingLoanScreen> createState() =>
      _NewExistingLoanScreenState();
}

class _NewExistingLoanScreenState extends ConsumerState<NewExistingLoanScreen> {
  _Step _step = _Step.pickMember;
  _ImportMode _importMode = _ImportMode.simple;
  GroupMember? _member;
  LoanProduct? _product;

  final _originalLoanNumberController = TextEditingController();
  final _originalPrincipalController = TextEditingController();
  final _openingPrincipalOutstandingController = TextEditingController();
  final _futureScheduledInterestController = TextEditingController();
  final _remainingInstallmentCountController = TextEditingController();
  final _notesController = TextEditingController();

  // SIMPLE mode only (section D).
  final _contractedInterestController = TextEditingController();
  final _monthlyInstallmentController = TextEditingController();
  final _originalTermController = TextEditingController();
  final _historicalUnpaidCountController = TextEditingController();
  final _totalHistoricalArrearsController = TextEditingController();

  final List<LoanHistoricalArrearsInstallmentInput> _arrearsInstallments = [];

  DateTime _originalDisbursementDate = DateTime.now().subtract(
    const Duration(days: 365),
  );
  DateTime _openingAsOfDate = DateTime.now();
  DateTime? _nextDueDate;
  String? _localValidationError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(loanMigrationControllerProvider.notifier).reset();
      ref.read(loanMigrationPreviewControllerProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _originalLoanNumberController.dispose();
    _originalPrincipalController.dispose();
    _openingPrincipalOutstandingController.dispose();
    _futureScheduledInterestController.dispose();
    _remainingInstallmentCountController.dispose();
    _notesController.dispose();
    _contractedInterestController.dispose();
    _monthlyInstallmentController.dispose();
    _originalTermController.dispose();
    _historicalUnpaidCountController.dispose();
    _totalHistoricalArrearsController.dispose();
    super.dispose();
  }

  double get _openingPrincipalOutstanding =>
      parseAmountInput(_openingPrincipalOutstandingController.text) ?? 0;

  double get _arrearsPrincipalTotal =>
      _arrearsInstallments.fold(0.0, (sum, a) => sum + a.principalOutstanding);
  double get _arrearsInterestTotal =>
      _arrearsInstallments.fold(0.0, (sum, a) => sum + a.interestOutstanding);
  double get _arrearsPenaltyTotal => _arrearsInstallments.fold(
    0.0,
    (sum, a) => sum + a.openingPenaltyOutstanding,
  );
  double get _arrearsGrandTotal =>
      _arrearsPrincipalTotal + _arrearsInterestTotal + _arrearsPenaltyTotal;

  double get _futureScheduledPrincipal =>
      (_openingPrincipalOutstanding - _arrearsPrincipalTotal).clamp(
        0,
        double.infinity,
      );

  // Live, informational-only derivation for the Simple Import form
  // (section X) — never submitted as authoritative input; the server
  // recomputes all of this independently both at preview and at post.
  int get _simpleHistoricalUnpaidCount =>
      int.tryParse(_historicalUnpaidCountController.text.trim()) ?? 0;
  double get _simpleMonthlyInstallment =>
      parseAmountInput(_monthlyInstallmentController.text) ?? 0;
  double get _simpleContractualArrears =>
      _simpleHistoricalUnpaidCount * _simpleMonthlyInstallment;
  double get _simpleTotalHistoricalArrears =>
      parseAmountInput(_totalHistoricalArrearsController.text) ?? 0;
  double get _simpleLegacyPenalty =>
      _simpleTotalHistoricalArrears - _simpleContractualArrears;

  // Section D/N (Prompt 09D-UAT-BLOCKER-04): the original loan term and
  // the derived paid-before-Umoja count — live, informational only; the
  // server independently recomputes and validates this at both preview
  // and post.
  int? get _simpleOriginalTerm =>
      int.tryParse(_originalTermController.text.trim());
  int get _simpleRemainingFutureCount =>
      int.tryParse(_remainingInstallmentCountController.text.trim()) ?? 0;
  int? get _simplePaidBeforeUmojaCount {
    final term = _simpleOriginalTerm;
    if (term == null) return null;
    return term - _simpleHistoricalUnpaidCount - _simpleRemainingFutureCount;
  }

  bool get _simpleCountsReconcile {
    final paid = _simplePaidBeforeUmojaCount;
    return paid != null && paid >= 0;
  }

  Future<void> _addOrEditArrearsInstallment({int? index}) async {
    final initial = index == null ? null : _arrearsInstallments[index];
    final result = await showDialog<LoanHistoricalArrearsInstallmentInput>(
      context: context,
      builder: (context) => _ArrearsInstallmentDialog(initial: initial),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (index == null) {
        _arrearsInstallments.add(result);
      } else {
        _arrearsInstallments[index] = result;
      }
      _arrearsInstallments.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    });
  }

  void _removeArrearsInstallment(int index) {
    setState(() => _arrearsInstallments.removeAt(index));
  }

  Future<void> _previewSchedule(String groupId) async {
    final member = _member;
    final product = _product;
    final originalPrincipal = parseAmountInput(
      _originalPrincipalController.text,
    );
    if (member == null || product == null || originalPrincipal == null) {
      setState(() => _localValidationError = 'Enter the original principal.');
      return;
    }
    setState(() => _localValidationError = null);

    final remainingCount =
        int.tryParse(_remainingInstallmentCountController.text.trim()) ?? 0;

    final success = _importMode == _ImportMode.simple
        ? await ref
              .read(loanMigrationPreviewControllerProvider.notifier)
              .preview(
                groupId: groupId,
                membershipId: member.membershipId,
                loanProductId: product.id,
                originalPrincipal: originalPrincipal,
                openingAsOfDate: _openingAsOfDate,
                remainingInstallmentCount: remainingCount,
                nextDueDate: _nextDueDate,
                mode: 'SIMPLE',
                contractedInterestAmount:
                    parseAmountInput(_contractedInterestController.text) ?? 0,
                monthlyInstallmentAmount: _simpleMonthlyInstallment,
                historicalUnpaidCount: _simpleHistoricalUnpaidCount,
                totalHistoricalArrears: _simpleTotalHistoricalArrears,
                originalTerm: _simpleOriginalTerm,
              )
        : await ref
              .read(loanMigrationPreviewControllerProvider.notifier)
              .preview(
                groupId: groupId,
                membershipId: member.membershipId,
                loanProductId: product.id,
                originalPrincipal: originalPrincipal,
                openingAsOfDate: _openingAsOfDate,
                openingPrincipalOutstanding: _openingPrincipalOutstanding,
                historicalArrearsInstallments: _arrearsInstallments,
                futureScheduledInterest:
                    parseAmountInput(_futureScheduledInterestController.text) ??
                    0,
                remainingInstallmentCount: remainingCount,
                nextDueDate: _nextDueDate,
                mode: 'DETAILED',
              );
    if (success && mounted) {
      setState(() => _step = _Step.schedulePreview);
    }
  }

  Future<void> _post(String groupId) async {
    final member = _member;
    final product = _product;
    final originalPrincipal = parseAmountInput(
      _originalPrincipalController.text,
    );
    if (member == null || product == null || originalPrincipal == null) {
      return;
    }

    final originalLoanNumber = _originalLoanNumberController.text.trim().isEmpty
        ? null
        : _originalLoanNumberController.text.trim();
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();
    final remainingCount =
        int.tryParse(_remainingInstallmentCountController.text.trim()) ?? 0;

    final success = _importMode == _ImportMode.simple
        ? await ref
              .read(loanMigrationControllerProvider.notifier)
              .post(
                groupId: groupId,
                membershipId: member.membershipId,
                loanProductId: product.id,
                originalPrincipal: originalPrincipal,
                originalDisbursementDate: _originalDisbursementDate,
                openingAsOfDate: _openingAsOfDate,
                // Ignored/overwritten server-side in SIMPLE mode.
                openingPrincipalOutstanding: originalPrincipal,
                futureScheduledInterest: 0,
                remainingInstallmentCount: remainingCount,
                nextDueDate: _nextDueDate,
                originalLoanNumber: originalLoanNumber,
                notes: notes,
                mode: 'SIMPLE',
                contractedInterestAmount:
                    parseAmountInput(_contractedInterestController.text) ?? 0,
                monthlyInstallmentAmount: _simpleMonthlyInstallment,
                historicalUnpaidCount: _simpleHistoricalUnpaidCount,
                totalHistoricalArrears: _simpleTotalHistoricalArrears,
                originalTerm: _simpleOriginalTerm,
              )
        : await ref
              .read(loanMigrationControllerProvider.notifier)
              .post(
                groupId: groupId,
                membershipId: member.membershipId,
                loanProductId: product.id,
                originalPrincipal: originalPrincipal,
                originalDisbursementDate: _originalDisbursementDate,
                openingAsOfDate: _openingAsOfDate,
                openingPrincipalOutstanding: _openingPrincipalOutstanding,
                historicalArrearsInstallments: _arrearsInstallments,
                futureScheduledInterest:
                    parseAmountInput(_futureScheduledInterestController.text) ??
                    0,
                remainingInstallmentCount: remainingCount,
                nextDueDate: _nextDueDate,
                originalLoanNumber: originalLoanNumber,
                notes: notes,
                mode: 'DETAILED',
              );
    if (success && mounted) {
      setState(() => _step = _Step.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedGroup = ref.watch(selectedGroupProvider);
    final groupId = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership.group.groupId
        : null;

    return UmojaPage(
      title: l10n.migratedLoanFormTitle,
      maxWidth: 700,
      backTo: AppRoutes.loanAccountsList,
      backLabel: l10n.loanAccountsTitle,
      scrollable: _step != _Step.pickMember && _step != _Step.pickProduct,
      body: switch (_step) {
        _Step.pickMember => MemberSearchPicker(
          hintText: l10n.memberPickerSearchHint,
          onSelected: (member) => setState(() {
            _member = member;
            _step = _Step.pickProduct;
          }),
        ),
        _Step.pickProduct => _ProductPickerStep(
          onSelected: (product) => setState(() {
            _product = product;
            _step = _Step.form;
          }),
        ),
        _Step.form => _buildForm(l10n, groupId),
        _Step.schedulePreview => _buildSchedulePreview(l10n),
        _Step.review => _buildReview(l10n, groupId),
        _Step.success => const _SuccessStep(),
      },
    );
  }

  Widget _buildForm(dynamic l10n, String? groupId) {
    final previewState = ref.watch(loanMigrationPreviewControllerProvider);
    final isSimple = _importMode == _ImportMode.simple;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UmojaCard(
          padding: const EdgeInsets.all(UmojaSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _member!.displayName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(_product!.name),
            ],
          ),
        ),
        const SizedBox(height: UmojaSpacing.lg),
        UmojaCard(
          padding: const EdgeInsets.all(UmojaSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<_ImportMode>(
                key: const Key('migratedLoanImportModeSelector'),
                segments: [
                  ButtonSegment(
                    value: _ImportMode.simple,
                    label: Text(l10n.simpleImportModeLabel),
                  ),
                  ButtonSegment(
                    value: _ImportMode.detailed,
                    label: Text(l10n.detailedImportModeLabel),
                  ),
                ],
                selected: {_importMode},
                onSelectionChanged: (selection) =>
                    setState(() => _importMode = selection.first),
              ),
              if (isSimple) ...[
                const SizedBox(height: UmojaSpacing.sm),
                Text(
                  l10n.simpleImportModeDescription,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        UmojaFormSection(
          title: l10n.sectionMigratedLoanDetails,
          fields: [
            TextField(
              key: const Key('migratedLoanOriginalLoanNumberField'),
              controller: _originalLoanNumberController,
              decoration: InputDecoration(
                labelText: l10n.originalLoanNumberFieldLabel,
              ),
            ),
            const SizedBox(height: UmojaSpacing.lg),
            TextField(
              key: const Key('migratedLoanOriginalPrincipalField'),
              controller: _originalPrincipalController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: const [ThousandsInputFormatter()],
              decoration: InputDecoration(
                labelText: l10n.originalPrincipalFieldLabel,
              ),
            ),
            const SizedBox(height: UmojaSpacing.lg),
            OutlinedButton(
              key: const Key('migratedLoanOriginalDisbursementDateField'),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _originalDisbursementDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _originalDisbursementDate = picked);
                }
              },
              child: Text(
                '${l10n.originalDisbursementDateFieldLabel}: '
                '${formatKiswahiliDate(_originalDisbursementDate)}',
              ),
            ),
            const SizedBox(height: UmojaSpacing.lg),
            OutlinedButton(
              key: const Key('migratedLoanOpeningAsOfDateField'),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _openingAsOfDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );
                if (picked != null) setState(() => _openingAsOfDate = picked);
              },
              child: Text(
                '${l10n.openingAsOfDateFieldLabel}: '
                '${formatKiswahiliDate(_openingAsOfDate)}',
              ),
            ),
            if (isSimple) ...[
              const SizedBox(height: UmojaSpacing.lg),
              TextField(
                key: const Key('migratedLoanContractedInterestField'),
                controller: _contractedInterestController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: const [ThousandsInputFormatter()],
                decoration: InputDecoration(
                  labelText: l10n.contractedInterestFieldLabel,
                ),
              ),
              const SizedBox(height: UmojaSpacing.lg),
              TextField(
                key: const Key('migratedLoanMonthlyInstallmentField'),
                controller: _monthlyInstallmentController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: const [ThousandsInputFormatter()],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.monthlyInstallmentAmountFieldLabel,
                ),
              ),
              const SizedBox(height: UmojaSpacing.lg),
              TextField(
                key: const Key('migratedLoanOriginalTermField'),
                controller: _originalTermController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.originalLoanTermFieldLabel,
                  helperText: l10n.originalLoanTermHelperText,
                ),
              ),
            ],
          ],
        ),
        if (isSimple)
          UmojaFormSection(
            title: l10n.sectionMigratedLoanArrears,
            fields: [
              TextField(
                key: const Key('migratedLoanHistoricalUnpaidCountField'),
                controller: _historicalUnpaidCountController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.historicalUnpaidCountFieldLabel,
                ),
              ),
              const SizedBox(height: UmojaSpacing.lg),
              TextField(
                key: const Key('migratedLoanTotalHistoricalArrearsField'),
                controller: _totalHistoricalArrearsController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: const [ThousandsInputFormatter()],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.totalHistoricalArrearsFieldLabel,
                ),
              ),
              const SizedBox(height: UmojaSpacing.lg),
              _ReadOnlyRow(
                key: const Key('migratedLoanSimpleContractualArrearsRow'),
                label: l10n.contractualArrearsLabel,
                value: formatAmount(_simpleContractualArrears),
              ),
              _ReadOnlyRow(
                key: const Key('migratedLoanSimpleLegacyPenaltyRow'),
                label: l10n.openingLegacyPenaltyLabel,
                value: formatAmount(_simpleLegacyPenalty),
              ),
              _ReadOnlyRow(
                key: const Key('migratedLoanSimplePaidBeforeUmojaRow'),
                label: l10n.paidBeforeUmojaLabel,
                value: _simplePaidBeforeUmojaCount?.toString() ?? '—',
              ),
              if (_simpleOriginalTerm != null && !_simpleCountsReconcile)
                Padding(
                  padding: const EdgeInsets.only(top: UmojaSpacing.xs),
                  child: Text(
                    l10n.loanErrorOpeningSimpleInputInvalid,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          )
        else
          UmojaFormSection(
            title: l10n.sectionMigratedLoanOpeningPosition,
            fields: [
              TextField(
                key: const Key('migratedLoanOpeningPrincipalOutstandingField'),
                controller: _openingPrincipalOutstandingController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: const [ThousandsInputFormatter()],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.openingPrincipalOutstandingFieldLabel,
                ),
              ),
            ],
          ),
        if (!isSimple)
          UmojaFormSection(
            title: l10n.sectionMigratedLoanArrears,
            fields: [
              for (var i = 0; i < _arrearsInstallments.length; i++)
                _ArrearsInstallmentRow(
                  key: Key('migratedLoanArrearsRow_$i'),
                  index: i,
                  installment: _arrearsInstallments[i],
                  onEdit: () => _addOrEditArrearsInstallment(index: i),
                  onRemove: () => _removeArrearsInstallment(i),
                ),
              if (_arrearsInstallments.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: UmojaSpacing.sm),
                  child: Text(
                    l10n.historicalArrearsEmptyMessage,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              OutlinedButton.icon(
                key: const Key('migratedLoanAddArrearsInstallmentAction'),
                onPressed: () => _addOrEditArrearsInstallment(),
                icon: const Icon(Icons.add),
                label: Text(l10n.addArrearsInstallmentAction),
              ),
              const SizedBox(height: UmojaSpacing.lg),
              _ReadOnlyRow(
                key: const Key('migratedLoanArrearsPrincipalTotalRow'),
                label: l10n.openingPrincipalArrearsFieldLabel,
                value: formatAmount(_arrearsPrincipalTotal),
              ),
              _ReadOnlyRow(
                key: const Key('migratedLoanArrearsInterestTotalRow'),
                label: l10n.openingInterestArrearsFieldLabel,
                value: formatAmount(_arrearsInterestTotal),
              ),
              _ReadOnlyRow(
                key: const Key('migratedLoanArrearsPenaltyTotalRow'),
                label: l10n.openingPenaltyArrearsFieldLabel,
                value: formatAmount(_arrearsPenaltyTotal),
              ),
              _ReadOnlyRow(
                key: const Key('migratedLoanArrearsGrandTotalRow'),
                label: l10n.totalHistoricalArrearsLabel,
                value: formatAmount(_arrearsGrandTotal),
              ),
            ],
          ),
        UmojaFormSection(
          title: l10n.sectionMigratedLoanRemainingSchedule,
          fields: [
            if (!isSimple) ...[
              _ReadOnlyRow(
                label: l10n.futureScheduledPrincipalLabel,
                value: formatAmount(_futureScheduledPrincipal),
              ),
              const SizedBox(height: UmojaSpacing.lg),
              TextField(
                key: const Key('migratedLoanFutureScheduledInterestField'),
                controller: _futureScheduledInterestController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: const [ThousandsInputFormatter()],
                decoration: InputDecoration(
                  labelText: l10n.futureScheduledInterestFieldLabel,
                ),
              ),
              const SizedBox(height: UmojaSpacing.lg),
            ],
            TextField(
              key: const Key('migratedLoanRemainingInstallmentCountField'),
              controller: _remainingInstallmentCountController,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.remainingInstallmentCountFieldLabel,
              ),
            ),
            const SizedBox(height: UmojaSpacing.lg),
            OutlinedButton(
              key: const Key('migratedLoanNextDueDateField'),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _nextDueDate ?? _openingAsOfDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );
                if (picked != null) setState(() => _nextDueDate = picked);
              },
              child: Text(
                _nextDueDate == null
                    ? l10n.nextDueDateFieldLabel
                    : '${l10n.nextDueDateFieldLabel}: '
                          '${formatKiswahiliDate(_nextDueDate!)}',
              ),
            ),
            const SizedBox(height: UmojaSpacing.lg),
            TextField(
              key: const Key('migratedLoanNotesField'),
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l10n.migratedLoanNotesFieldLabel,
              ),
            ),
          ],
        ),
        if (_localValidationError != null) ...[
          const SizedBox(height: UmojaSpacing.sm),
          Text(
            _localValidationError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (previewState.errorType != null) ...[
          const SizedBox(height: UmojaSpacing.sm),
          Text(
            loanFailureMessage(l10n, previewState.errorType!),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: UmojaSpacing.xxl),
        UmojaPrimaryButton(
          key: const Key('migratedLoanPreviewScheduleAction'),
          label: l10n.previewScheduleAction,
          expand: true,
          isLoading: previewState.isLoading,
          onPressed: groupId == null || (isSimple && !_simpleCountsReconcile)
              ? null
              : () => _previewSchedule(groupId),
        ),
      ],
    );
  }

  Widget _buildSchedulePreview(dynamic l10n) {
    final preview = ref.watch(loanMigrationPreviewControllerProvider).preview;
    if (preview == null) {
      return const UmojaLoadingState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.sectionSchedulePreview,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (preview.paidBeforeUmojaCount != null) ...[
          const SizedBox(height: UmojaSpacing.sm),
          _ReadOnlyRow(
            key: const Key('schedulePreviewPaidBeforeUmojaRow'),
            label: l10n.paidBeforeUmojaLabel,
            value: '${preview.paidBeforeUmojaCount}',
          ),
        ],
        const SizedBox(height: UmojaSpacing.lg),
        Text(
          l10n.historicalOverdueInstallmentsTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: UmojaSpacing.sm),
        if (preview.historicalInstallments.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: UmojaSpacing.sm),
            child: Text(l10n.historicalArrearsEmptyMessage),
          )
        else
          for (var i = 0; i < preview.historicalInstallments.length; i++)
            _PreviewInstallmentCard(
              key: Key('schedulePreviewHistoricalRow_$i'),
              installment: preview.historicalInstallments[i],
            ),
        const SizedBox(height: UmojaSpacing.xxl),
        Text(
          l10n.futureRemainingInstallmentsTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: UmojaSpacing.sm),
        for (var i = 0; i < preview.futureInstallments.length; i++)
          _PreviewInstallmentCard(
            key: Key('schedulePreviewFutureRow_$i'),
            installment: preview.futureInstallments[i],
          ),
        const SizedBox(height: UmojaSpacing.xxl),
        Row(
          children: [
            Expanded(
              child: UmojaSecondaryButton(
                key: const Key('schedulePreviewEditAction'),
                label: l10n.editScheduleInputsAction,
                onPressed: () => setState(() => _step = _Step.form),
              ),
            ),
            const SizedBox(width: UmojaSpacing.md),
            Expanded(
              child: UmojaPrimaryButton(
                key: const Key('schedulePreviewContinueAction'),
                label: l10n.continueToReviewAction,
                onPressed: () => setState(() => _step = _Step.review),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReview(dynamic l10n, String? groupId) {
    final migrationState = ref.watch(loanMigrationControllerProvider);
    final preview = ref.watch(loanMigrationPreviewControllerProvider).preview;
    if (preview == null) {
      return const UmojaLoadingState();
    }
    final isSimple = preview.mode == 'SIMPLE';
    final originalPrincipal =
        parseAmountInput(_originalPrincipalController.text) ?? 0;
    final contractedInterest =
        parseAmountInput(_contractedInterestController.text) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UmojaCard(
          key: const Key('migratedLoanReviewCard'),
          padding: const EdgeInsets.all(UmojaSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.sectionReviewAndConfirm,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: UmojaSpacing.sm),
              _ReadOnlyRow(
                label: l10n.loanOriginLabel,
                value: l10n.loanOriginMigratedLabel,
              ),
              const Divider(height: UmojaSpacing.xxl),
              if (isSimple) ...[
                _ReadOnlyRow(
                  label: l10n.originalPrincipalSummaryLabel,
                  value: formatAmount(originalPrincipal),
                ),
                _ReadOnlyRow(
                  label: l10n.contractedInterestSummaryLabel,
                  value: formatAmount(contractedInterest),
                ),
                _ReadOnlyRow(
                  label: l10n.contractualTotalSummaryLabel,
                  value: formatAmount(originalPrincipal + contractedInterest),
                ),
                _ReadOnlyRow(
                  label: l10n.historicalUnpaidInstallmentsSummaryLabel,
                  value: '${preview.historicalInstallments.length}',
                ),
                _ReadOnlyRow(
                  label: l10n.historicalContractualDebtSummaryLabel,
                  value: formatAmount(
                    preview.contractualHistoricalArrears ?? 0,
                  ),
                ),
                _ReadOnlyRow(
                  label: l10n.openingLegacyPenaltyLabel,
                  value: formatAmount(preview.legacyPenaltyTotal ?? 0),
                ),
              ] else ...[
                _ReadOnlyRow(
                  label: l10n.openingPrincipalArrearsFieldLabel,
                  value: formatAmount(preview.historicalPrincipalTotal),
                ),
                _ReadOnlyRow(
                  label: l10n.openingInterestArrearsFieldLabel,
                  value: formatAmount(preview.historicalInterestTotal),
                ),
                _ReadOnlyRow(
                  label: l10n.openingPenaltyArrearsFieldLabel,
                  value: formatAmount(preview.historicalPenaltyTotal),
                ),
              ],
              _ReadOnlyRow(
                key: const Key('migratedLoanReviewHistoricalArrearsTotalRow'),
                label: l10n.totalHistoricalArrearsLabel,
                value: formatAmount(preview.totalHistoricalArrears),
              ),
              const Divider(height: UmojaSpacing.xxl),
              Text(
                l10n.sectionMigratedLoanRemainingSchedule,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: UmojaSpacing.xs),
              _ReadOnlyRow(
                label: l10n.remainingFutureInstallmentsSummaryLabel,
                value: '${preview.futureInstallments.length}',
              ),
              if (_nextDueDate != null)
                _ReadOnlyRow(
                  label: l10n.nextDueDateFieldLabel,
                  value: formatKiswahiliDate(_nextDueDate!),
                ),
              _ReadOnlyRow(
                label: l10n.futureContractualTotalSummaryLabel,
                value: formatAmount(preview.futureContractualTotal),
              ),
              const Divider(height: UmojaSpacing.xxl),
              Text(
                l10n.accountingImpactTitle,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: UmojaSpacing.xs),
              _ReadOnlyRow(
                label: l10n.financialAccountLabel,
                value: l10n.financialAccountNoneLabel,
              ),
              _ReadOnlyRow(
                key: const Key('migratedLoanCashbookImpactRow'),
                label: l10n.cashbookImpactLabel,
                value: formatAmount(0),
              ),
              _ReadOnlyRow(
                key: const Key('migratedLoanIncomeImpactRow'),
                label: l10n.incomeRecognizedNowLabel,
                value: formatAmount(0),
              ),
              _ReadOnlyRow(
                label: l10n.expenseRecognizedNowLabel,
                value: formatAmount(0),
              ),
              _ReadOnlyRow(
                key: const Key('migratedLoanReceivableImpactRow'),
                label: l10n.fundedPrincipalReceivableChangeLabel,
                value: '+${formatAmount(preview.openingPrincipalOutstanding)}',
              ),
            ],
          ),
        ),
        const SizedBox(height: UmojaSpacing.lg),
        UmojaCard(
          key: const Key('migratedLoanConfirmationSafetyCard'),
          padding: const EdgeInsets.all(UmojaSpacing.lg),
          child: Text(l10n.migratedLoanConfirmationSafetyMessage),
        ),
        if (migrationState.errorType != null) ...[
          const SizedBox(height: UmojaSpacing.sm),
          Text(
            loanFailureMessage(l10n, migrationState.errorType!),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: UmojaSpacing.xxl),
        UmojaPrimaryButton(
          key: const Key('migratedLoanPostAction'),
          label: l10n.confirmAndAddExistingLoanAction,
          expand: true,
          isLoading: migrationState.isSubmitting,
          onPressed: groupId == null ? null : () => _post(groupId),
        ),
        const SizedBox(height: UmojaSpacing.md),
        UmojaSecondaryButton(
          key: const Key('migratedLoanReviewBackAction'),
          label: l10n.editScheduleInputsAction,
          onPressed: () => setState(() => _step = _Step.schedulePreview),
        ),
      ],
    );
  }
}

class _ProductPickerStep extends ConsumerWidget {
  const _ProductPickerStep({required this.onSelected});

  final ValueChanged<LoanProduct> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final productsAsync = ref.watch(activeLoanProductsForPickerProvider);

    return productsAsync.when(
      loading: () => const UmojaLoadingState(),
      error: (error, stackTrace) => UmojaErrorState(
        message: l10n.refreshFailedMessage,
        retryLabel: l10n.retryButton,
        onRetry: () => ref.invalidate(activeLoanProductsForPickerProvider),
      ),
      data: (products) {
        if (products.isEmpty) {
          return UmojaEmptyState(
            icon: Icons.local_atm_outlined,
            title: l10n.loanProductsEmptyTitle,
            message: l10n.loanProductsEmptyMessage,
          );
        }
        return ListView.separated(
          itemCount: products.length,
          separatorBuilder: (context, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final product = products[index];
            return ListTile(
              title: Text(product.name),
              onTap: () => onSelected(product),
            );
          },
        );
      },
    );
  }
}

/// One installment row in the Schedule Preview step (Prompt
/// 09D-UAT-BLOCKER-03, section K) — read-only, server-computed.
class _PreviewInstallmentCard extends StatelessWidget {
  const _PreviewInstallmentCard({super.key, required this.installment});

  final LoanMigrationPreviewInstallment installment;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: UmojaSpacing.sm),
      child: UmojaCard(
        padding: const EdgeInsets.all(UmojaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatKiswahiliDate(installment.dueDate),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                UmojaStatusBadge(
                  label: loanInstallmentStatusLabel(l10n, installment.status),
                  semantic: loanInstallmentStatusSemantic(installment.status),
                ),
              ],
            ),
            _ReadOnlyRow(
              label: l10n.arrearsRowPrincipalLabel,
              value: formatAmount(installment.principalOutstanding),
            ),
            _ReadOnlyRow(
              label: l10n.arrearsRowInterestLabel,
              value: formatAmount(installment.interestOutstanding),
            ),
            if (installment.openingPenaltyOutstanding > 0)
              _ReadOnlyRow(
                label: l10n.arrearsRowPenaltyLabel,
                value: formatAmount(installment.openingPenaltyOutstanding),
              ),
            _ReadOnlyRow(
              label: l10n.arrearsRowTotalLabel,
              value: formatAmount(installment.totalContractualAmount),
            ),
          ],
        ),
      ),
    );
  }
}

/// One historical overdue installment card in the repeatable arrears
/// list (Prompt 09D-UAT-BLOCKER-02, section 19) — never one synthetic
/// combined arrears row. Detailed Import only.
class _ArrearsInstallmentRow extends StatelessWidget {
  const _ArrearsInstallmentRow({
    super.key,
    required this.index,
    required this.installment,
    required this.onEdit,
    required this.onRemove,
  });

  final int index;
  final LoanHistoricalArrearsInstallmentInput installment;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: UmojaSpacing.sm),
      child: UmojaCard(
        padding: const EdgeInsets.all(UmojaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatKiswahiliDate(installment.dueDate),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  key: Key('migratedLoanArrearsRowEditAction_$index'),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: l10n.editAction,
                  onPressed: onEdit,
                ),
                IconButton(
                  key: Key('migratedLoanArrearsRowRemoveAction_$index'),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.removeAction,
                  onPressed: onRemove,
                ),
              ],
            ),
            _ReadOnlyRow(
              label: l10n.arrearsRowPrincipalLabel,
              value: formatAmount(installment.principalOutstanding),
            ),
            _ReadOnlyRow(
              label: l10n.arrearsRowInterestLabel,
              value: formatAmount(installment.interestOutstanding),
            ),
            if (installment.openingPenaltyOutstanding > 0)
              _ReadOnlyRow(
                label: l10n.arrearsRowPenaltyLabel,
                value: formatAmount(installment.openingPenaltyOutstanding),
              ),
            _ReadOnlyRow(
              key: Key('migratedLoanArrearsRowTotal_$index'),
              label: l10n.arrearsRowTotalLabel,
              value: formatAmount(installment.total),
            ),
          ],
        ),
      ),
    );
  }
}

/// Add/edit dialog for one historical arrears installment.
class _ArrearsInstallmentDialog extends StatefulWidget {
  const _ArrearsInstallmentDialog({this.initial});

  final LoanHistoricalArrearsInstallmentInput? initial;

  @override
  State<_ArrearsInstallmentDialog> createState() =>
      _ArrearsInstallmentDialogState();
}

class _ArrearsInstallmentDialogState extends State<_ArrearsInstallmentDialog> {
  late DateTime _dueDate;
  final _principalController = TextEditingController();
  final _interestController = TextEditingController();
  final _penaltyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _dueDate = initial?.dueDate ?? DateTime.now();
    if (initial != null) {
      _principalController.text = formatAmount(initial.principalOutstanding);
      _interestController.text = formatAmount(initial.interestOutstanding);
      _penaltyController.text = formatAmount(initial.openingPenaltyOutstanding);
    }
  }

  @override
  void dispose() {
    _principalController.dispose();
    _interestController.dispose();
    _penaltyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.addArrearsInstallmentAction),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton(
              key: const Key('migratedLoanArrearsDialogDueDateField'),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dueDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );
                if (picked != null) setState(() => _dueDate = picked);
              },
              child: Text(
                '${l10n.arrearsDueDateFieldLabel}: '
                '${formatKiswahiliDate(_dueDate)}',
              ),
            ),
            const SizedBox(height: UmojaSpacing.md),
            TextField(
              key: const Key('migratedLoanArrearsDialogPrincipalField'),
              controller: _principalController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: const [ThousandsInputFormatter()],
              decoration: InputDecoration(
                labelText: l10n.arrearsRowPrincipalLabel,
              ),
            ),
            const SizedBox(height: UmojaSpacing.md),
            TextField(
              key: const Key('migratedLoanArrearsDialogInterestField'),
              controller: _interestController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: const [ThousandsInputFormatter()],
              decoration: InputDecoration(
                labelText: l10n.arrearsRowInterestLabel,
              ),
            ),
            const SizedBox(height: UmojaSpacing.md),
            TextField(
              key: const Key('migratedLoanArrearsDialogPenaltyField'),
              controller: _penaltyController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: const [ThousandsInputFormatter()],
              decoration: InputDecoration(
                labelText: l10n.arrearsRowPenaltyLabel,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelAction),
        ),
        FilledButton(
          key: const Key('migratedLoanArrearsDialogSaveAction'),
          onPressed: () {
            Navigator.of(context).pop(
              LoanHistoricalArrearsInstallmentInput(
                dueDate: _dueDate,
                principalOutstanding:
                    parseAmountInput(_principalController.text) ?? 0,
                interestOutstanding:
                    parseAmountInput(_interestController.text) ?? 0,
                openingPenaltyOutstanding:
                    parseAmountInput(_penaltyController.text) ?? 0,
              ),
            );
          },
          child: Text(l10n.saveAction),
        ),
      ],
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: UmojaSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: UmojaSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessStep extends ConsumerWidget {
  const _SuccessStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final result = ref.watch(loanMigrationControllerProvider).lastResult;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.check_circle_outline,
          color: Theme.of(context).colorScheme.primary,
          size: 64,
        ),
        const SizedBox(height: UmojaSpacing.lg),
        Text(
          l10n.loanDraftSavedMessage,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (result != null) ...[
          const SizedBox(height: UmojaSpacing.sm),
          Text(result.loanNumber),
        ],
        const SizedBox(height: UmojaSpacing.xxl),
        if (result != null)
          UmojaPrimaryButton(
            key: const Key('migratedLoanViewDetailAction'),
            label: l10n.loanAccountDetailTitle,
            expand: true,
            onPressed: () => context.pushReplacement(
              AppRoutes.loanAccountDetailPath(result.id),
            ),
          ),
        const SizedBox(height: UmojaSpacing.md),
        UmojaSecondaryButton(
          label: l10n.doneAction,
          onPressed: () => context.go(AppRoutes.loanAccountsList),
        ),
      ],
    );
  }
}
