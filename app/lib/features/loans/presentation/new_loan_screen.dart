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
import '../../../core/widgets/umoja_loading_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../../members/domain/group_member.dart';
import '../../payments/presentation/widgets/member_search_picker.dart';
import '../controllers/loan_account_draft_controller.dart';
import '../domain/loan_product.dart';
import '../providers/loan_products_provider.dart';
import 'widgets/loan_labels.dart';

enum _NewLoanStep { pickMember, pickProduct, terms, preview, success }

/// `/loans/accounts/new`: the locked New Loan draft workflow (Prompt
/// 09A section W) as a single stateful screen — Borrower → Product →
/// Terms → Schedule Preview → Save Draft. No approve/disburse/receive-
/// payment action exists anywhere in this flow, not even disabled —
/// those belong to a later phase. Mirrors `RecordPaymentScreen`'s
/// locked-step pattern.
class NewLoanScreen extends ConsumerStatefulWidget {
  const NewLoanScreen({super.key});

  @override
  ConsumerState<NewLoanScreen> createState() => _NewLoanScreenState();
}

class _NewLoanScreenState extends ConsumerState<NewLoanScreen> {
  _NewLoanStep _step = _NewLoanStep.pickMember;
  GroupMember? _member;
  LoanProduct? _product;
  final _principalController = TextEditingController();
  final _termController = TextEditingController();
  DateTime _firstRepaymentDate = DateTime.now().add(const Duration(days: 30));
  String? _localValidationError;

  @override
  void initState() {
    super.initState();
    ref.invalidate(activeLoanProductsForPickerProvider);
    // Deferred to after this frame: calling `.reset()` synchronously here
    // modifies a provider mid-build, since this screen's own subtree
    // reads `loanAccountDraftControllerProvider` in the very same build
    // (the 08B UAT-FIX-01 "setState during build" lesson applies to
    // provider mutation too, not just `ref.invalidate`).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(loanAccountDraftControllerProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _principalController.dispose();
    _termController.dispose();
    super.dispose();
  }

  void _onMemberSelected(GroupMember member) {
    final l10n = context.l10n;
    if (!member.isActive) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.loanErrorBorrowerNotActive)));
      return;
    }
    setState(() {
      _member = member;
      _step = _NewLoanStep.pickProduct;
    });
  }

  void _onProductSelected(LoanProduct product) {
    setState(() {
      _product = product;
      _step = _NewLoanStep.terms;
    });
  }

  Future<void> _onPreview(String groupId) async {
    final product = _product;
    final principal = parseAmountInput(_principalController.text);
    final term = int.tryParse(_termController.text.trim());
    setState(() => _localValidationError = null);
    if (product == null ||
        principal == null ||
        principal <= 0 ||
        term == null ||
        term <= 0) {
      setState(() {
        _localValidationError = context.l10n.newLoanFormValidationError;
      });
      return;
    }

    await ref
        .read(loanAccountDraftControllerProvider.notifier)
        .preview(
          groupId: groupId,
          loanProductId: product.id,
          principalAmount: principal,
          term: term,
          firstRepaymentDate: _firstRepaymentDate,
        );
    if (!mounted) return;
    if (ref.read(loanAccountDraftControllerProvider).preview != null) {
      setState(() => _step = _NewLoanStep.preview);
    }
  }

  Future<void> _onSaveDraft(String groupId) async {
    final member = _member;
    final product = _product;
    final principal = parseAmountInput(_principalController.text);
    final term = int.tryParse(_termController.text.trim());
    if (member == null ||
        product == null ||
        principal == null ||
        term == null) {
      return;
    }

    final success = await ref
        .read(loanAccountDraftControllerProvider.notifier)
        .createDraft(
          groupId: groupId,
          membershipId: member.membershipId,
          loanProductId: product.id,
          principalAmount: principal,
          term: term,
          firstRepaymentDate: _firstRepaymentDate,
        );
    if (success && mounted) {
      setState(() => _step = _NewLoanStep.success);
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
      title: l10n.newLoanTitle,
      maxWidth: 700,
      backTo: AppRoutes.loanAccountsList,
      backLabel: l10n.loanAccountsTitle,
      // pickMember/pickProduct each render their own internal, bounded
      // scrolling list (MemberSearchPicker / _ProductPickerStep's
      // ListView) — wrapping them in another SingleChildScrollView gives
      // that inner ListView unbounded height and crashes.
      scrollable:
          _step != _NewLoanStep.pickMember && _step != _NewLoanStep.pickProduct,
      body: switch (_step) {
        _NewLoanStep.pickMember => MemberSearchPicker(
          hintText: l10n.memberPickerSearchHint,
          onSelected: _onMemberSelected,
        ),
        _NewLoanStep.pickProduct => _ProductPickerStep(
          onSelected: _onProductSelected,
        ),
        _NewLoanStep.terms => _TermsStep(
          member: _member!,
          product: _product!,
          principalController: _principalController,
          termController: _termController,
          firstRepaymentDate: _firstRepaymentDate,
          localValidationError: _localValidationError,
          onFirstRepaymentDateChanged: (value) =>
              setState(() => _firstRepaymentDate = value),
          onSubmit: groupId == null ? null : () => _onPreview(groupId),
        ),
        _NewLoanStep.preview => _PreviewStep(
          onBack: () => setState(() => _step = _NewLoanStep.terms),
          onConfirm: groupId == null ? null : () => _onSaveDraft(groupId),
        ),
        _NewLoanStep.success => const _SuccessStep(),
      },
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
              subtitle: Text(
                '${loanInterestRateBasisLabel(l10n, product.interestRateBasis)} · '
                '${loanInterestMethodLabel(l10n, product.interestMethod)}',
              ),
              onTap: () => onSelected(product),
            );
          },
        );
      },
    );
  }
}

class _TermsStep extends ConsumerWidget {
  const _TermsStep({
    required this.member,
    required this.product,
    required this.principalController,
    required this.termController,
    required this.firstRepaymentDate,
    required this.localValidationError,
    required this.onFirstRepaymentDateChanged,
    required this.onSubmit,
  });

  final GroupMember member;
  final LoanProduct product;
  final TextEditingController principalController;
  final TextEditingController termController;
  final DateTime firstRepaymentDate;
  final String? localValidationError;
  final ValueChanged<DateTime> onFirstRepaymentDateChanged;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final draftState = ref.watch(loanAccountDraftControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UmojaCard(
          padding: const EdgeInsets.all(UmojaSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.displayName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(product.name, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        const SizedBox(height: UmojaSpacing.xxl),
        TextField(
          key: const Key('newLoanPrincipalField'),
          controller: principalController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [ThousandsInputFormatter()],
          decoration: InputDecoration(
            labelText: l10n.loanAccountPrincipalFieldLabel,
          ),
        ),
        const SizedBox(height: UmojaSpacing.lg),
        TextField(
          key: const Key('newLoanTermField'),
          controller: termController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.loanAccountTermFieldLabel,
          ),
        ),
        const SizedBox(height: UmojaSpacing.lg),
        OutlinedButton(
          key: const Key('newLoanFirstRepaymentDateField'),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: firstRepaymentDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 3650)),
            );
            if (picked != null) onFirstRepaymentDateChanged(picked);
          },
          child: Text(
            '${l10n.loanAccountFirstRepaymentDateFieldLabel}: '
            '${formatKiswahiliDate(firstRepaymentDate)}',
          ),
        ),
        if (localValidationError != null) ...[
          const SizedBox(height: UmojaSpacing.sm),
          Text(
            localValidationError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (draftState.errorType != null) ...[
          const SizedBox(height: UmojaSpacing.sm),
          Text(
            loanFailureMessage(l10n, draftState.errorType!),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: UmojaSpacing.xxl),
        UmojaPrimaryButton(
          key: const Key('newLoanPreviewAction'),
          label: l10n.loanSchedulePreviewAction,
          expand: true,
          isLoading: draftState.isPreviewing,
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
    final draftState = ref.watch(loanAccountDraftControllerProvider);
    final preview = draftState.preview;

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
                l10n.loanScheduleTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: UmojaSpacing.sm),
              for (final installment in preview.installments)
                Padding(
                  padding: const EdgeInsets.only(bottom: UmojaSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.loanInstallmentNumberLabel(
                            installment.installmentNumber,
                          ),
                        ),
                      ),
                      Text(formatKiswahiliDate(installment.dueDate)),
                      const SizedBox(width: UmojaSpacing.md),
                      Text(formatAmount(installment.totalDue)),
                    ],
                  ),
                ),
              const Divider(height: UmojaSpacing.xxl),
              _PreviewSummaryRow(
                label: l10n.loanTotalInterestLabel,
                value: formatAmount(preview.totalInterest),
              ),
              _PreviewSummaryRow(
                key: const Key('loanTotalRepayableRow'),
                label: l10n.loanTotalRepayableLabel,
                value: formatAmount(preview.totalRepayable),
              ),
            ],
          ),
        ),
        if (draftState.errorType != null) ...[
          const SizedBox(height: UmojaSpacing.sm),
          Text(
            loanFailureMessage(l10n, draftState.errorType!),
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
                key: const Key('newLoanSaveDraftAction'),
                label: l10n.loanSaveDraftAction,
                isLoading: draftState.isSubmitting,
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
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: UmojaSpacing.md),
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
    final result = ref.watch(loanAccountDraftControllerProvider).lastResult;

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
            key: const Key('newLoanViewDetailAction'),
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
