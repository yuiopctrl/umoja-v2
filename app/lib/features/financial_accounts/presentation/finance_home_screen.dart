import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/widgets/umoja_card.dart';
import '../../../core/widgets/umoja_list_tile.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../auth/providers/selected_group_provider.dart';

/// `/finance`: Fedha — the Finance home (Prompt 08B, section 31). Kept
/// deliberately minimal (no excessive sidebar entries): Hali ya Fedha
/// (Financial Position) and Akaunti za Fedha (the existing Prompt 08A
/// Financial Accounts feature). Recording income/expense,
/// reconciliation, and adjustments all live per-account on Financial
/// Account Detail, since each of those needs an account context first
/// — matching how Record Payment needs a member and Wallet needs a
/// member, rather than a duplicate "pick an account" step here.
class FinanceHomeScreen extends ConsumerWidget {
  const FinanceHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedGroup = ref.watch(selectedGroupProvider);
    final l10n = context.l10n;

    final membership = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership
        : null;
    final canViewReport =
        membership?.hasPermission('financial_report.view') ?? false;
    final canViewAccounts =
        membership?.hasPermission('financial_account.view') ?? false;
    // Matches the backend's own gate on rpc_create_financial_category/
    // rpc_update_financial_category — UAT-FIX-05 follow-up: this screen
    // existed and was routed, but had no permanent navigation entry
    // point anywhere, only a one-off link shown from the manual entry
    // form's empty-categories state.
    final canManageCategories =
        membership?.hasPermission('financial_account.manage') ?? false;

    return UmojaPage(
      title: l10n.financeTitle,
      maxWidth: 900,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canViewReport) ...[
            UmojaCard(
              key: const Key('financialPositionEntry'),
              padding: EdgeInsets.zero,
              child: UmojaListTile(
                leading: const Icon(Icons.pie_chart_outline),
                title: l10n.financialPositionTitle,
                subtitle: Text(l10n.financialPositionEntrySubtitle),
                onTap: () => context.push(AppRoutes.financialPosition),
              ),
            ),
            const SizedBox(height: UmojaSpacing.lg),
          ],
          if (canViewAccounts) ...[
            UmojaCard(
              key: const Key('financialAccountsEntry'),
              padding: EdgeInsets.zero,
              child: UmojaListTile(
                leading: const Icon(Icons.account_balance_outlined),
                title: l10n.financialAccountsTitle,
                subtitle: Text(l10n.financeAccountsEntrySubtitle),
                onTap: () => context.push(AppRoutes.financialAccountsList),
              ),
            ),
            const SizedBox(height: UmojaSpacing.lg),
          ],
          if (canManageCategories)
            UmojaCard(
              key: const Key('financialCategoriesEntry'),
              padding: EdgeInsets.zero,
              child: UmojaListTile(
                leading: const Icon(Icons.category_outlined),
                title: l10n.financialCategoriesTitle,
                subtitle: Text(l10n.financeCategoriesEntrySubtitle),
                onTap: () => context.push(AppRoutes.financialCategoriesList),
              ),
            ),
        ],
      ),
    );
  }
}
