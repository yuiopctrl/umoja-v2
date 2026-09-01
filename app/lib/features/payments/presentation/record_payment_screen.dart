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
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../core/widgets/umoja_status_badge.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../../financial_accounts/domain/financial_account.dart';
import '../../financial_accounts/presentation/widgets/financial_account_labels.dart';
import '../../financial_accounts/providers/financial_accounts_list_provider.dart';
import '../../members/domain/group_member.dart';
import '../../members/providers/member_detail_provider.dart';
import '../controllers/payment_post_controller.dart';
import '../controllers/payment_preview_controller.dart';
import 'widgets/allocation_lines_list.dart';
import 'widgets/member_financial_summary_card.dart';
import 'widgets/member_search_picker.dart';
import 'widgets/payment_labels.dart';

enum _RecordPaymentStep { pickMember, form, preview, success }

const _paymentMethods = ['CASH', 'BANK_TRANSFER', 'MOBILE_MONEY', 'OTHER'];

/// `/payments/record`: the locked 5-step Record Payment flow (section
/// 60) as a single stateful screen — select member, enter amount/date
/// /method/account/reference/notes, preview, confirm, success/receipt.
/// Never posts before an explicit confirm on the preview step.
///
/// `/payments/record/:membershipId` ([membershipId] non-null) reuses
/// this exact flow with the member already selected — the "Rekodi
/// Malipo" shortcut from the member-centric Charges/Madeni view
/// (Prompt 07 UAT-FIX-03) — skipping the member-picker step entirely
/// rather than duplicating the payment flow.
class RecordPaymentScreen extends ConsumerStatefulWidget {
  const RecordPaymentScreen({super.key, this.membershipId});

  final String? membershipId;

  @override
  ConsumerState<RecordPaymentScreen> createState() =>
      _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends ConsumerState<RecordPaymentScreen> {
  _RecordPaymentStep _step = _RecordPaymentStep.pickMember;
  GroupMember? _member;
  String? _financialAccountId;
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();
  String _paymentMethod = 'CASH';
  DateTime _effectiveAt = DateTime.now();
  String? _localAmountError;

  @override
  void initState() {
    super.initState();
    ref.invalidate(financialAccountsActiveForPickerProvider);
    final membershipId = widget.membershipId;
    if (membershipId != null) {
      ref.invalidate(memberDetailProvider(membershipId));
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onMemberSelected(GroupMember member) {
    setState(() {
      _member = member;
      _step = _RecordPaymentStep.form;
    });
  }

  Future<void> _onPreview(String groupId) async {
    final amount = parseAmountInput(_amountController.text);
    final accountId = _financialAccountId;
    final member = _member;
    setState(() => _localAmountError = null);
    if (member == null || accountId == null || amount == null || amount <= 0) {
      setState(() {
        _localAmountError = context.l10n.paymentAmountInvalidError;
      });
      return;
    }

    await ref
        .read(paymentPreviewControllerProvider.notifier)
        .preview(
          groupId: groupId,
          membershipId: member.membershipId,
          financialAccountId: accountId,
          amount: amount,
          effectiveAt: _effectiveAt,
        );
    if (!mounted) return;
    if (ref.read(paymentPreviewControllerProvider).preview != null) {
      setState(() => _step = _RecordPaymentStep.preview);
    }
  }

  Future<void> _onConfirm(String groupId) async {
    final member = _member;
    final accountId = _financialAccountId;
    final amount = parseAmountInput(_amountController.text);
    if (member == null || accountId == null || amount == null) return;

    final success = await ref
        .read(paymentPostControllerProvider.notifier)
        .post(
          groupId: groupId,
          membershipId: member.membershipId,
          financialAccountId: accountId,
          amount: amount,
          effectiveAt: _effectiveAt,
          paymentMethod: _paymentMethod,
          externalReference: _referenceController.text.trim().isEmpty
              ? null
              : _referenceController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );
    if (success && mounted) {
      setState(() => _step = _RecordPaymentStep.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedGroup = ref.watch(selectedGroupProvider);
    final groupId = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership.group.groupId
        : null;

    final preselectedMembershipId = widget.membershipId;
    if (preselectedMembershipId != null && _member == null) {
      final memberAsync = ref.watch(
        memberDetailProvider(preselectedMembershipId),
      );
      ref.listen<AsyncValue<GroupMember>>(
        memberDetailProvider(preselectedMembershipId),
        (previous, next) => next.whenData(_onMemberSelected),
      );
      return UmojaPage(
        title: l10n.recordPaymentTitle,
        maxWidth: 700,
        backTo: AppRoutes.paymentsList,
        backLabel: l10n.paymentsTitle,
        body: memberAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 64),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => UmojaErrorState(
            message: l10n.refreshFailedMessage,
            retryLabel: l10n.retryButton,
            onRetry: () =>
                ref.invalidate(memberDetailProvider(preselectedMembershipId)),
          ),
          data: (_) => const SizedBox.shrink(),
        ),
      );
    }

    return UmojaPage(
      title: l10n.recordPaymentTitle,
      maxWidth: 700,
      backTo: AppRoutes.paymentsList,
      backLabel: l10n.paymentsTitle,
      scrollable: _step != _RecordPaymentStep.pickMember,
      body: switch (_step) {
        _RecordPaymentStep.pickMember => MemberSearchPicker(
          hintText: l10n.memberPickerSearchHint,
          onSelected: _onMemberSelected,
        ),
        _RecordPaymentStep.form => _FormStep(
          member: _member!,
          amountController: _amountController,
          referenceController: _referenceController,
          notesController: _notesController,
          paymentMethod: _paymentMethod,
          effectiveAt: _effectiveAt,
          financialAccountId: _financialAccountId,
          localAmountError: _localAmountError,
          onPaymentMethodChanged: (value) =>
              setState(() => _paymentMethod = value),
          onEffectiveAtChanged: (value) => setState(() => _effectiveAt = value),
          onAccountChanged: (value) =>
              setState(() => _financialAccountId = value),
          onSubmit: groupId == null ? null : () => _onPreview(groupId),
        ),
        _RecordPaymentStep.preview => _PreviewStep(
          onBack: () => setState(() => _step = _RecordPaymentStep.form),
          onConfirm: groupId == null ? null : () => _onConfirm(groupId),
        ),
        _RecordPaymentStep.success => const _SuccessStep(),
      },
    );
  }
}

class _FormStep extends ConsumerWidget {
  const _FormStep({
    required this.member,
    required this.amountController,
    required this.referenceController,
    required this.notesController,
    required this.paymentMethod,
    required this.effectiveAt,
    required this.financialAccountId,
    required this.localAmountError,
    required this.onPaymentMethodChanged,
    required this.onEffectiveAtChanged,
    required this.onAccountChanged,
    required this.onSubmit,
  });

  final GroupMember member;
  final TextEditingController amountController;
  final TextEditingController referenceController;
  final TextEditingController notesController;
  final String paymentMethod;
  final DateTime effectiveAt;
  final String? financialAccountId;
  final String? localAmountError;
  final ValueChanged<String> onPaymentMethodChanged;
  final ValueChanged<DateTime> onEffectiveAtChanged;
  final ValueChanged<String?> onAccountChanged;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final accountsAsync = ref.watch(financialAccountsActiveForPickerProvider);
    final previewState = ref.watch(paymentPreviewControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UmojaCard(
          padding: const EdgeInsets.all(UmojaSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (member.memberNumber != null)
                      Text(
                        member.memberNumber!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                  ],
                ),
              ),
              if (!member.isActive)
                UmojaStatusBadge(
                  label: member.isSuspended
                      ? l10n.filterSuspended
                      : l10n.filterExited,
                  semantic: UmojaStatusSemantic.neutral,
                ),
            ],
          ),
        ),
        const SizedBox(height: UmojaSpacing.lg),
        // The authoritative "before payment" summary (UAT-FIX-01) —
        // Deni Lililobaki/Salio la Mwanachama and the specific
        // obligations making up that debt, shown before any amount is
        // entered. Never computed client-side.
        MemberFinancialSummaryCard(membershipId: member.membershipId),
        const SizedBox(height: UmojaSpacing.xxl),
        TextField(
          key: const Key('recordPaymentAmountField'),
          controller: amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [ThousandsInputFormatter()],
          decoration: InputDecoration(
            labelText: l10n.recordPaymentAmountLabel,
            errorText: localAmountError,
          ),
        ),
        const SizedBox(height: UmojaSpacing.lg),
        OutlinedButton(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: effectiveAt,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 1)),
            );
            if (picked != null) onEffectiveAtChanged(picked);
          },
          child: Text(
            '${l10n.recordPaymentDateLabel}: ${formatKiswahiliDate(effectiveAt)}',
          ),
        ),
        const SizedBox(height: UmojaSpacing.lg),
        DropdownButtonFormField<String>(
          initialValue: paymentMethod,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.recordPaymentMethodLabel),
          onChanged: (value) {
            if (value != null) onPaymentMethodChanged(value);
          },
          items: [
            for (final method in _paymentMethods)
              DropdownMenuItem(
                value: method,
                child: Text(paymentMethodLabel(l10n, method)),
              ),
          ],
        ),
        const SizedBox(height: UmojaSpacing.lg),
        accountsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: UmojaSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => Text(l10n.refreshFailedMessage),
          data: (accounts) => DropdownButtonFormField<String>(
            key: const Key('recordPaymentAccountField'),
            isExpanded: true,
            initialValue: financialAccountId,
            decoration: InputDecoration(
              labelText: l10n.recordPaymentAccountLabel,
            ),
            onChanged: onAccountChanged,
            items: [
              for (final FinancialAccount account in accounts)
                DropdownMenuItem(
                  value: account.id,
                  child: Text(
                    '${account.name} (${financialAccountTypeLabel(l10n, account.accountType)})',
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: UmojaSpacing.lg),
        TextField(
          controller: referenceController,
          decoration: InputDecoration(
            labelText: l10n.recordPaymentReferenceLabel,
          ),
        ),
        const SizedBox(height: UmojaSpacing.lg),
        TextField(
          controller: notesController,
          maxLines: 2,
          decoration: InputDecoration(labelText: l10n.recordPaymentNotesLabel),
        ),
        if (previewState.errorType != null) ...[
          const SizedBox(height: UmojaSpacing.sm),
          Text(
            paymentFailureMessage(context.l10n, previewState.errorType!),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: UmojaSpacing.xxl),
        UmojaPrimaryButton(
          key: const Key('recordPaymentPreviewAction'),
          label: l10n.recordPaymentPreviewAction,
          expand: true,
          isLoading: previewState.isLoading,
          onPressed: onSubmit,
        ),
      ],
    );
  }
}

class _PreviewStep extends ConsumerWidget {
  const _PreviewStep({required this.onBack, required this.onConfirm});

  final VoidCallback onBack;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final previewState = ref.watch(paymentPreviewControllerProvider);
    final preview = previewState.preview;
    final postState = ref.watch(paymentPostControllerProvider);

    if (preview == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UmojaCard(
          padding: const EdgeInsets.all(UmojaSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.paymentPreviewWillSettleLabel,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: UmojaSpacing.sm),
              if (preview.allocations.isNotEmpty)
                AllocationLinesList(lines: preview.allocations)
              else
                Text(l10n.paymentPreviewNoOutstandingMessage),
              const Divider(height: UmojaSpacing.xxl),
              _PreviewSummaryRow(
                label: l10n.paymentPreviewAmountLabel,
                value: formatAmount(preview.amount),
              ),
              _PreviewSummaryRow(
                key: const Key('paymentPreviewTotalAllocatedRow'),
                label: l10n.paymentPreviewTotalAllocatedLabel,
                value: formatAmount(preview.totalAllocated),
              ),
              _PreviewSummaryRow(
                key: const Key('paymentPreviewWalletRemainingRow'),
                label: l10n.paymentPreviewWalletRemainingLabel,
                value: formatAmount(preview.walletCreditAmount),
              ),
              const SizedBox(height: UmojaSpacing.md),
              Text(
                '${l10n.paymentPreviewAccountLabel}: ${preview.financialAccountName}',
              ),
            ],
          ),
        ),
        if (postState.errorType != null) ...[
          const SizedBox(height: UmojaSpacing.sm),
          Text(
            paymentFailureMessage(context.l10n, postState.errorType!),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: UmojaSpacing.xxl),
        Row(
          children: [
            Expanded(
              child: UmojaSecondaryButton(
                label: l10n.backAction,
                onPressed: onBack,
              ),
            ),
            const SizedBox(width: UmojaSpacing.md),
            Expanded(
              child: UmojaPrimaryButton(
                key: const Key('recordPaymentConfirmAction'),
                label: l10n.recordPaymentConfirmAction,
                isLoading: postState.isSubmitting,
                onPressed: onConfirm,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PreviewSummaryRow extends StatelessWidget {
  const _PreviewSummaryRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: UmojaSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: UmojaSpacing.sm),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
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
    final result = ref.watch(paymentPostControllerProvider).result;

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
          l10n.recordPaymentSuccessMessage,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (result != null) ...[
          const SizedBox(height: UmojaSpacing.sm),
          Text(result.receiptNumber),
        ],
        const SizedBox(height: UmojaSpacing.xxl),
        if (result != null)
          UmojaPrimaryButton(
            key: const Key('recordPaymentViewReceiptAction'),
            label: l10n.viewReceiptAction,
            expand: true,
            onPressed: () => context.pushReplacement(
              AppRoutes.paymentReceiptPath(result.paymentId),
            ),
          ),
        const SizedBox(height: UmojaSpacing.md),
        UmojaSecondaryButton(
          label: l10n.doneAction,
          onPressed: () => context.go(AppRoutes.paymentsList),
        ),
      ],
    );
  }
}
