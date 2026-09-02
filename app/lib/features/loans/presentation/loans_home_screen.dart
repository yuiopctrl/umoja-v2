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

/// `/loans`: Mikopo — the Loans home (Prompt 09A, extended 09D). Kept
/// deliberately minimal, mirroring `FinanceHomeScreen`'s "no excessive
/// sidebar entries" precedent: Aina za Mikopo (Loan Products), Akaunti
/// za Mikopo (Loan Accounts), and Adhabu (Penalties). Payment/wallet
/// consumption of obligations lives under the Malipo hub, never here —
/// this screen only ever creates or configures obligations.
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
    final canViewPenalties =
        membership?.hasPermission('loan_penalty.view') ?? false;
    final canAddExistingLoan =
        membership?.hasPermission('loan_opening.create') ?? false;

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
          if (canViewProducts) ...[
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
            const SizedBox(height: UmojaSpacing.lg),
          ],
          if (canViewPenalties) ...[
            UmojaCard(
              key: const Key('loanPenaltiesEntry'),
              padding: EdgeInsets.zero,
              child: UmojaListTile(
                leading: const Icon(Icons.gpp_maybe_outlined),
                title: l10n.loanPenaltiesEntryTitle,
                subtitle: Text(l10n.loanPenaltiesEntrySubtitle),
                onTap: () => context.push(AppRoutes.loanPenalties),
              ),
            ),
            const SizedBox(height: UmojaSpacing.lg),
          ],
          // Prompt 09D-UAT-BLOCKER-01: a clearly SEPARATE entry from
          // ordinary loan creation — never a checkbox bolted onto the
          // New Loan flow (section 44).
          if (canAddExistingLoan)
            UmojaCard(
              key: const Key('addExistingLoanEntry'),
              padding: EdgeInsets.zero,
              child: UmojaListTile(
                leading: const Icon(Icons.history_edu_outlined),
                title: l10n.addExistingLoanAction,
                subtitle: Text(l10n.existingLoanEntrySubtitle),
                onTap: () => context.push(AppRoutes.newExistingLoanAccount),
              ),
            ),
        ],
      ),
    );
  }
}
