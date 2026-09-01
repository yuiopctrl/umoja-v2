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

/// `/loans`: Mikopo — the Loans home (Prompt 09A). Kept deliberately
/// minimal, mirroring `FinanceHomeScreen`'s "no excessive sidebar
/// entries" precedent: Aina za Mikopo (Loan Products) and Akaunti za
/// Mikopo (Loan Accounts). No approval/disbursement/repayment entry
/// exists here — those belong to a later phase.
class LoansHomeScreen extends ConsumerWidget {
  const LoansHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedGroup = ref.watch(selectedGroupProvider);
    final l10n = context.l10n;

    final membership = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership
        : null;
    final canViewProducts =
        membership?.hasPermission('loan_product.view') ?? false;
    final canViewLoans = membership?.hasPermission('loan.view') ?? false;

    return UmojaPage(
      title: l10n.loansTitle,
      maxWidth: 900,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canViewLoans) ...[
            UmojaCard(
              key: const Key('loanAccountsEntry'),
              padding: EdgeInsets.zero,
              child: UmojaListTile(
                leading: const Icon(Icons.request_quote_outlined),
                title: l10n.loanAccountsTitle,
                subtitle: Text(l10n.loanAccountsEntrySubtitle),
                onTap: () => context.push(AppRoutes.loanAccountsList),
              ),
            ),
            const SizedBox(height: UmojaSpacing.lg),
          ],
          if (canViewProducts)
            UmojaCard(
              key: const Key('loanProductsEntry'),
              padding: EdgeInsets.zero,
              child: UmojaListTile(
                leading: const Icon(Icons.local_atm_outlined),
                title: l10n.loanProductsTitle,
                subtitle: Text(l10n.loanProductsEntrySubtitle),
                onTap: () => context.push(AppRoutes.loanProductsList),
              ),
            ),
        ],
      ),
    );
  }
}
