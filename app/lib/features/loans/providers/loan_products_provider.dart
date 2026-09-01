import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/loan_product.dart';
import 'loan_repository_provider.dart';

/// Query key for [loanProductsProvider] — the owning screen holds its
/// own filter/pagination state locally, matching the financial
/// accounts list precedent.
typedef LoanProductsQuery = ({bool? isActive, int limit, int offset});

/// `.autoDispose`: once no screen is watching this query anymore, its
/// cached result is discarded, so re-entering the list after a
/// create/edit always refetches rather than resurfacing a stale
/// snapshot (same lesson as `financialAccountsListProvider`).
final loanProductsProvider = FutureProvider.autoDispose
    .family<LoanProductPage, LoanProductsQuery>((ref, query) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) {
        return LoanProductPage.empty;
      }

      final repository = ref.watch(loanRepositoryProvider);
      return repository.listLoanProducts(
        groupId: selectedGroup.membership.group.groupId,
        isActive: query.isActive,
        limit: query.limit,
        offset: query.offset,
      );
    });

/// Every *active* loan product, for use in the New Loan product
/// picker (Prompt 09A section W step 2) — deliberately separate from
/// [loanProductsProvider]/its query state, `.autoDispose` for the
/// same freshness reason as above.
final activeLoanProductsForPickerProvider = FutureProvider.autoDispose((
  ref,
) async {
  final selectedGroup = ref.watch(selectedGroupProvider);
  if (selectedGroup is! SelectedGroupResolved) return const [];

  final repository = ref.watch(loanRepositoryProvider);
  final page = await repository.listLoanProducts(
    groupId: selectedGroup.membership.group.groupId,
    isActive: true,
    limit: 100,
  );
  return page.items;
});
