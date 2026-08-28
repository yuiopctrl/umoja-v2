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

/// `/contributions`: entry point for the Contribution Engine — Michango
/// (contribution) obligation ledger, plus the Prompt 07 payments/wallet
/// entries (Malipo, Rekodi Malipo, Salio la Mwanachama) added under
/// the same existing workflow rather than a separate top-level home.
class ContributionsHomeScreen extends ConsumerWidget {
  const ContributionsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedGroup = ref.watch(selectedGroupProvider);
    final l10n = context.l10n;

    final membership = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership
        : null;
    final canView = membership?.hasPermission('contribution.view') ?? false;
    final canManageOpeningBalances =
        membership?.hasPermission('contribution.opening_balance.manage') ??
        false;
    final canViewPayments = membership?.hasPermission('payment.view') ?? false;
    final canCreatePayments =
        membership?.hasPermission('payment.create') ?? false;
    final canViewWallets = membership?.hasPermission('wallet.view') ?? false;

    return UmojaPage(
      title: l10n.contributionsTitle,
      maxWidth: 900,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canView) ...[
            UmojaCard(
              key: const Key('contributionTypesEntry'),
              padding: EdgeInsets.zero,
              child: UmojaListTile(
                leading: const Icon(Icons.category_outlined),
                title: l10n.contributionTypesEntryTitle,
                subtitle: Text(l10n.contributionTypesEntrySubtitle),
                onTap: () => context.push(AppRoutes.contributionTypesList),
              ),
            ),
            const SizedBox(height: UmojaSpacing.lg),
            UmojaCard(
              key: const Key('contributionSetupsEntry'),
              padding: EdgeInsets.zero,
              child: UmojaListTile(
                leading: const Icon(Icons.tune_outlined),
                title: l10n.contributionSetupsEntryTitle,
                subtitle: Text(l10n.contributionSetupsEntrySubtitle),
                onTap: () => context.push(AppRoutes.contributionSetupsList),
              ),
            ),
            const SizedBox(height: UmojaSpacing.lg),
            UmojaCard(
              key: const Key('contributionPeriodsEntry'),
              padding: EdgeInsets.zero,
              child: UmojaListTile(
                leading: const Icon(Icons.event_note_outlined),
                title: l10n.contributionPeriodsEntryTitle,
                subtitle: Text(l10n.contributionPeriodsEntrySubtitle),
                onTap: () => context.push(AppRoutes.contributionPeriodsList),
              ),
            ),
          ],
          if (canManageOpeningBalances) ...[
            const SizedBox(height: UmojaSpacing.lg),
            UmojaCard(
              key: const Key('contributionOpeningBalancesEntry'),
              padding: EdgeInsets.zero,
              child: UmojaListTile(
                leading: const Icon(Icons.history_edu_outlined),
                title: l10n.openingBalancesEntryTitle,
                subtitle: Text(l10n.openingBalancesEntrySubtitle),
                onTap: () =>
                    context.push(AppRoutes.contributionOpeningBalancesList),
              ),
            ),
          ],
          if (canViewPayments) ...[
            const SizedBox(height: UmojaSpacing.lg),
            UmojaCard(
              key: const Key('paymentsEntry'),
              padding: EdgeInsets.zero,
              child: UmojaListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: l10n.paymentsEntryTitle,
                subtitle: Text(l10n.paymentsEntrySubtitle),
                onTap: () => context.push(AppRoutes.paymentsList),
              ),
            ),
          ],
          if (canCreatePayments) ...[
            const SizedBox(height: UmojaSpacing.lg),
            UmojaCard(
              key: const Key('recordPaymentEntry'),
              padding: EdgeInsets.zero,
              child: UmojaListTile(
                leading: const Icon(Icons.add_card_outlined),
                title: l10n.recordPaymentEntryTitle,
                subtitle: Text(l10n.recordPaymentEntrySubtitle),
                onTap: () => context.push(AppRoutes.paymentRecord),
              ),
            ),
          ],
          if (canViewWallets) ...[
            const SizedBox(height: UmojaSpacing.lg),
            UmojaCard(
              key: const Key('memberWalletEntry'),
              padding: EdgeInsets.zero,
              child: UmojaListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: l10n.memberWalletEntryTitle,
                subtitle: Text(l10n.memberWalletEntrySubtitle),
                onTap: () => context.push(AppRoutes.walletMemberPicker),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
