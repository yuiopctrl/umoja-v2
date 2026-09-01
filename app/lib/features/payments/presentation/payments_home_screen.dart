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

/// `/payments`: the shared Payments hub ("Malipo", Prompt 09C-UAT-FIX-01)
/// — Record Payment, Payment History, Receipts, and Member Wallet all
/// live here, since the Payment Engine settles obligations from
/// Contributions, Loans, AND the member wallet, and is no longer
/// conceptually owned by Contributions alone. This is navigation/
/// information architecture only — every entry below routes into the
/// exact same existing Prompt 07 Payment Engine screens/RPCs, never a
/// second implementation.
class PaymentsHomeScreen extends ConsumerWidget {
  const PaymentsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedGroup = ref.watch(selectedGroupProvider);
    final l10n = context.l10n;

    final membership = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership
        : null;
    final canCreatePayments =
        membership?.hasPermission('payment.create') ?? false;
    final canViewPayments = membership?.hasPermission('payment.view') ?? false;
    final canViewReceipts =
        membership?.hasPermission('payment.receipt.view') ?? false;
    final canViewWallets = membership?.hasPermission('wallet.view') ?? false;

    return UmojaPage(
      title: l10n.paymentsTitle,
      maxWidth: 900,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canCreatePayments) ...[
            UmojaCard(
              key: const Key('paymentsHomeRecordPaymentEntry'),
              padding: EdgeInsets.zero,
              child: UmojaListTile(
                leading: const Icon(Icons.add_card_outlined),
                title: l10n.recordPaymentEntryTitle,
                subtitle: Text(l10n.recordPaymentEntrySubtitle),
                onTap: () => context.push(AppRoutes.paymentRecord),
              ),
            ),
            const SizedBox(height: UmojaSpacing.lg),
          ],
          if (canViewPayments) ...[
            UmojaCard(
              key: const Key('paymentsHomeHistoryEntry'),
              padding: EdgeInsets.zero,
              child: UmojaListTile(
                leading: const Icon(Icons.history_outlined),
                title: l10n.paymentHistoryTitle,
                subtitle: Text(l10n.paymentsEntrySubtitle),
                onTap: () => context.push(AppRoutes.paymentsHistory),
              ),
            ),
            const SizedBox(height: UmojaSpacing.lg),
          ],
          if (canViewReceipts) ...[
            UmojaCard(
              key: const Key('paymentsHomeReceiptsEntry'),
              padding: EdgeInsets.zero,
              child: UmojaListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: l10n.receiptsEntryTitle,
                subtitle: Text(l10n.receiptsEntrySubtitle),
                onTap: () => context.push(AppRoutes.paymentsHistory),
              ),
            ),
            const SizedBox(height: UmojaSpacing.lg),
          ],
          if (canViewWallets)
            UmojaCard(
              key: const Key('paymentsHomeWalletEntry'),
              padding: EdgeInsets.zero,
              child: UmojaListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: l10n.memberWalletEntryTitle,
                subtitle: Text(l10n.memberWalletEntrySubtitle),
                onTap: () => context.push(AppRoutes.walletMemberPicker),
              ),
            ),
        ],
      ),
    );
  }
}
