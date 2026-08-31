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
import '../../auth/providers/selected_group_provider.dart';
import '../controllers/manual_entry_post_controller.dart';
import '../providers/financial_account_detail_provider.dart';
import '../providers/financial_categories_provider.dart';

/// `/financial-accounts/:accountId/income/record` and
/// `/financial-accounts/:accountId/expense/record` (Prompt 08B,
/// sections 4/5/32/33) — one shared screen for both flows (they are
/// the same "post a manual cashbook entry" concern with only the
/// category-type filter/RPC/permission/labels differing). Never posts
/// before an explicit confirm; the backend remains authoritative for
/// the resulting balance shown after posting — nothing here predicts
/// it client-side.
class ManualEntryFormScreen extends ConsumerStatefulWidget {
  const ManualEntryFormScreen({
    super.key,
    required this.accountId,
    required this.entryKind,
  });

  final String accountId;

  /// 'INCOME' or 'EXPENSE'.
  final String entryKind;

  @override
  ConsumerState<ManualEntryFormScreen> createState() =>
      _ManualEntryFormScreenState();
}

class _ManualEntryFormScreenState extends ConsumerState<ManualEntryFormScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _referenceController = TextEditingController();
  String? _categoryId;
  DateTime _effectiveAt = DateTime.now();
  bool _confirmed = false;

  /// Set when Confirm is tapped with a missing/invalid amount or no
  /// category selected — UAT-FIX-05: this validation previously failed
  /// silently (a bare `return`), so tapping Confirm with an incomplete
  /// form looked identical to a dead button. This screen has no
  /// separate preview step (unlike Record Payment) to catch that
  /// earlier, so it must surface the problem itself.
  String? _localValidationError;

  bool get _isIncome => widget.entryKind == 'INCOME';

  @override
  void initState() {
    super.initState();
    // Deferred to a post-frame callback: at the moment this screen is
    // pushed, the Account Detail screen underneath is still watching
    // this same `financialAccountDetailProvider(accountId)` mid-
    // transition — invalidating it synchronously here would call
    // setState on that still-building widget.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(financialAccountDetailProvider(widget.accountId));
      ref.invalidate(
        financialCategoriesProvider((
          categoryType: widget.entryKind,
          isActive: true,
        )),
      );
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveAt,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) setState(() => _effectiveAt = picked);
  }

  Future<void> _confirm(String groupId) async {
    final amount = parseAmountInput(_amountController.text);
    final categoryId = _categoryId;
    // UAT-FIX-05 follow-up: a single combined validation message ("enter
    // an amount and select a category") misled a tester whose category
    // really was already selected — it named both fields regardless of
    // which one actually failed. Report the precise field(s) at fault
    // instead, and log the raw values so a real device/desktop failure
    // is diagnosable from the terminal without guessing.
    debugPrint(
      'ManualEntryFormScreen._confirm: rawAmountText='
      '"${_amountController.text}" parsedAmount=$amount categoryId=$categoryId '
      'description="${_descriptionController.text}" '
      'reference="${_referenceController.text}"',
    );
    if (amount == null || amount <= 0 || categoryId == null) {
      final l10n = context.l10n;
      final amountInvalid = amount == null || amount <= 0;
      final categoryMissing = categoryId == null;
      setState(() {
        _localValidationError = switch ((amountInvalid, categoryMissing)) {
          (true, true) => l10n.manualEntryValidationError,
          (true, false) => l10n.manualEntryAmountRequiredError,
          (false, true) => l10n.manualEntryCategoryRequiredError,
          (false, false) => null,
        };
      });
      return;
    }
    setState(() => _localValidationError = null);

    final controller = ref.read(manualEntryPostControllerProvider.notifier);
    final success = _isIncome
        ? await controller.postIncome(
            groupId: groupId,
            financialAccountId: widget.accountId,
            categoryId: categoryId,
            amount: amount,
            effectiveAt: _effectiveAt,
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            reference: _referenceController.text.trim().isEmpty
                ? null
                : _referenceController.text.trim(),
          )
        : await controller.postExpense(
            groupId: groupId,
            financialAccountId: widget.accountId,
            categoryId: categoryId,
            amount: amount,
            effectiveAt: _effectiveAt,
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            reference: _referenceController.text.trim().isEmpty
                ? null
                : _referenceController.text.trim(),
          );
    if (success && mounted) setState(() => _confirmed = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedGroup = ref.watch(selectedGroupProvider);
    final groupId = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership.group.groupId
        : null;
    final accountAsync = ref.watch(
      financialAccountDetailProvider(widget.accountId),
    );
    final categoriesQuery = (categoryType: widget.entryKind, isActive: true);
    final categoriesAsync = ref.watch(
      financialCategoriesProvider(categoriesQuery),
    );
    // UAT-FIX-05 follow-up: with only one category to pick from, a
    // tester read the field as already showing that category and never
    // realized a tap-to-select was still required — the field looked
    // "readonly" with nothing to actually choose. Auto-selecting the
    // sole option removes that ambiguity entirely.
    ref.listen(financialCategoriesProvider(categoriesQuery), (previous, next) {
      final categories = next.value;
      if (_categoryId == null && categories != null && categories.length == 1) {
        setState(() => _categoryId = categories.single.id);
      }
    });
    final postState = ref.watch(manualEntryPostControllerProvider);

    return UmojaPage(
      title: _isIncome ? l10n.recordIncomeTitle : l10n.recordExpenseTitle,
      maxWidth: 700,
      backTo: AppRoutes.financialAccountDetailPath(widget.accountId),
      backLabel: l10n.financialAccountsTitle,
      body: accountAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 64),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => UmojaErrorState(
          message: l10n.refreshFailedMessage,
          retryLabel: l10n.retryButton,
          onRetry: () =>
              ref.invalidate(financialAccountDetailProvider(widget.accountId)),
        ),
        data: (account) {
          if (_confirmed) {
            final result = postState.result;
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
                  _isIncome
                      ? l10n.recordIncomeSuccessMessage
                      : l10n.recordExpenseSuccessMessage,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (result != null) ...[
                  const SizedBox(height: UmojaSpacing.sm),
                  Text(
                    '${l10n.financialAccountBalanceLabel}: '
                    '${formatAmount(result.financialAccountBalance)}',
                  ),
                ],
                const SizedBox(height: UmojaSpacing.xxl),
                UmojaSecondaryButton(
                  label: l10n.doneAction,
                  onPressed: () => context.go(
                    AppRoutes.financialAccountDetailPath(widget.accountId),
                  ),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UmojaCard(
                padding: const EdgeInsets.all(UmojaSpacing.lg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            l10n.financialAccountBalanceLabel,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatAmount(account.balance),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: UmojaSpacing.xxl),
              categoriesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: UmojaSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stackTrace) => Text(l10n.refreshFailedMessage),
                data: (categories) {
                  // UAT-FIX-05 follow-up: with zero active categories of
                  // this type, the dropdown has nothing to show and
                  // Flutter correctly disables it (`onChanged` is only
                  // wired when `items.isNotEmpty`) — which read to a
                  // tester as an unexplained "read only" field, when the
                  // real issue is that the group has no category set up
                  // to select at all. Say so directly and offer a way
                  // to fix it, instead of leaving a silently-inert field.
                  if (categories.isEmpty) {
                    return UmojaCard(
                      padding: const EdgeInsets.all(UmojaSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isIncome
                                ? l10n.manualEntryNoIncomeCategoriesMessage
                                : l10n.manualEntryNoExpenseCategoriesMessage,
                          ),
                          const SizedBox(height: UmojaSpacing.sm),
                          UmojaSecondaryButton(
                            label: l10n.manualEntryManageCategoriesAction,
                            onPressed: () =>
                                context.push(AppRoutes.financialCategoriesList),
                          ),
                        ],
                      ),
                    );
                  }
                  return DropdownButtonFormField<String>(
                    key: const Key('manualEntryCategoryField'),
                    isExpanded: true,
                    initialValue: _categoryId,
                    hint: Text(l10n.manualEntryCategoryRequiredError),
                    decoration: InputDecoration(
                      labelText: _isIncome
                          ? l10n.incomeCategoryFieldLabel
                          : l10n.expenseCategoryFieldLabel,
                    ),
                    onChanged: (value) => setState(() => _categoryId = value),
                    items: [
                      for (final category in categories)
                        DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: UmojaSpacing.lg),
              TextField(
                key: const Key('manualEntryAmountField'),
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: const [ThousandsInputFormatter()],
                decoration: InputDecoration(labelText: l10n.amountFieldLabel),
              ),
              const SizedBox(height: UmojaSpacing.lg),
              OutlinedButton(
                onPressed: _pickDate,
                child: Text(
                  '${l10n.effectiveDateFieldLabel}: '
                  '${formatKiswahiliDate(_effectiveAt)}',
                ),
              ),
              const SizedBox(height: UmojaSpacing.lg),
              TextField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.descriptionFieldLabel,
                ),
              ),
              const SizedBox(height: UmojaSpacing.lg),
              TextField(
                controller: _referenceController,
                decoration: InputDecoration(
                  labelText: l10n.referenceFieldLabel,
                ),
              ),
              if (_localValidationError != null) ...[
                const SizedBox(height: UmojaSpacing.sm),
                Text(
                  _localValidationError!,
                  key: const Key('manualEntryLocalValidationError'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (postState.errorType != null) ...[
                const SizedBox(height: UmojaSpacing.sm),
                Text(
                  financialAccountFailureMessage(l10n, postState.errorType!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: UmojaSpacing.xxl),
              UmojaPrimaryButton(
                key: const Key('manualEntryConfirmAction'),
                label: _isIncome
                    ? l10n.recordIncomeConfirmAction
                    : l10n.recordExpenseConfirmAction,
                expand: true,
                isLoading: postState.isSubmitting,
                onPressed: groupId == null ? null : () => _confirm(groupId),
              ),
            ],
          );
        },
      ),
    );
  }
}
