import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../domain/financial_category.dart';
import '../providers/financial_account_repository_provider.dart';
import '../providers/financial_categories_provider.dart';

/// `/finance/categories`: manage the group's INCOME/EXPENSE financial
/// categories (Prompt 08B, section 6) — never hardcoded in Flutter.
/// Deactivating a category never deletes it, so historical entries
/// keep their category identity.
class FinancialCategoriesScreen extends ConsumerStatefulWidget {
  const FinancialCategoriesScreen({super.key});

  @override
  ConsumerState<FinancialCategoriesScreen> createState() =>
      _FinancialCategoriesScreenState();
}

class _FinancialCategoriesScreenState
    extends ConsumerState<FinancialCategoriesScreen> {
  bool _seeding = false;

  Future<void> _seedDefaults(String groupId) async {
    setState(() => _seeding = true);
    try {
      await ref
          .read(financialAccountRepositoryProvider)
          .seedDefaultFinancialCategories(groupId: groupId);
      ref.invalidate(financialCategoriesProvider);
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  Future<void> _addCategory(String groupId, String categoryType) async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.addCategoryAction),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.l10n.categoryNameFieldLabel,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.cancelButton),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(nameController.text.trim()),
            child: Text(context.l10n.saveButton),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    await ref
        .read(financialAccountRepositoryProvider)
        .createFinancialCategory(
          groupId: groupId,
          name: name,
          categoryType: categoryType,
        );
    ref.invalidate(financialCategoriesProvider);
  }

  Future<void> _toggleActive(String groupId, FinancialCategory category) async {
    await ref
        .read(financialAccountRepositoryProvider)
        .updateFinancialCategory(
          groupId: groupId,
          categoryId: category.id,
          isActive: !category.isActive,
        );
    ref.invalidate(financialCategoriesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedGroup = ref.watch(selectedGroupProvider);
    final groupId = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership.group.groupId
        : null;
    final categoriesAsync = ref.watch(
      financialCategoriesProvider((categoryType: null, isActive: null)),
    );

    return UmojaPage(
      title: l10n.financialCategoriesTitle,
      maxWidth: 700,
      scrollable: false,
      body: categoriesAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 64),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => UmojaErrorState(
          message: l10n.refreshFailedMessage,
          retryLabel: l10n.retryButton,
          onRetry: () => ref.invalidate(financialCategoriesProvider),
        ),
        data: (categories) {
          final incomeCategories = categories.where((c) => c.isIncome).toList();
          final expenseCategories = categories
              .where((c) => c.isExpense)
              .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (categories.isEmpty && groupId != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: UmojaSpacing.lg),
                  child: UmojaSecondaryButton(
                    key: const Key('seedDefaultCategoriesAction'),
                    label: l10n.seedDefaultCategoriesAction,
                    isLoading: _seeding,
                    onPressed: () => _seedDefaults(groupId),
                  ),
                ),
              Expanded(
                child: ListView(
                  children: [
                    _CategorySection(
                      title: l10n.financialCategoryTypeIncome,
                      categories: incomeCategories,
                      onAdd: groupId == null
                          ? null
                          : () => _addCategory(groupId, 'INCOME'),
                      onToggleActive: groupId == null
                          ? null
                          : (category) => _toggleActive(groupId, category),
                    ),
                    const SizedBox(height: UmojaSpacing.xxl),
                    _CategorySection(
                      title: l10n.financialCategoryTypeExpense,
                      categories: expenseCategories,
                      onAdd: groupId == null
                          ? null
                          : () => _addCategory(groupId, 'EXPENSE'),
                      onToggleActive: groupId == null
                          ? null
                          : (category) => _toggleActive(groupId, category),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.title,
    required this.categories,
    required this.onAdd,
    required this.onToggleActive,
  });

  final String title;
  final List<FinancialCategory> categories;
  final VoidCallback? onAdd;
  final ValueChanged<FinancialCategory>? onToggleActive;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton(onPressed: onAdd, child: Text(l10n.addCategoryAction)),
          ],
        ),
        for (final category in categories)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(category.name),
            trailing: Switch(
              value: category.isActive,
              onChanged: onToggleActive == null
                  ? null
                  : (_) => onToggleActive!(category),
            ),
          ),
      ],
    );
  }
}
