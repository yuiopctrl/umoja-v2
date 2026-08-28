import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/financial_account_page.dart';
import 'financial_account_repository_provider.dart';

/// Query key for [financialAccountsListProvider] — the owning screen
/// holds its own search/pagination state locally, matching the
/// contributions charges-list precedent.
typedef FinancialAccountsQuery = ({String search, int limit});

/// `.autoDispose`: once no screen is watching this query anymore, its
/// cached result is discarded — so navigating away and back in later
/// creates a fresh instance and refetches, rather than resurfacing a
/// snapshot from whenever this query key was first read (UAT-FIX-01:
/// a plain, non-autoDispose `FutureProvider` here meant a newly
/// created account only ever became visible after a full app
/// restart). Screen re-entry additionally force-invalidates this on
/// `initState` (see `FinancialAccountsListScreen`) so re-entry always
/// refetches even when the previous instance is still alive
/// (e.g. reached via back-navigation rather than a fresh push).
final financialAccountsListProvider = FutureProvider.autoDispose
    .family<FinancialAccountPage, FinancialAccountsQuery>((ref, query) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) {
        return FinancialAccountPage.empty;
      }

      final repository = ref.watch(financialAccountRepositoryProvider);
      return repository.listFinancialAccounts(
        groupId: selectedGroup.membership.group.groupId,
        search: query.search,
        limit: query.limit,
      );
    });

/// Every *active* financial account, for use in a picker (e.g. the
/// transfer form) — deliberately separate from
/// [financialAccountsListProvider]/its query state. `.autoDispose` for
/// the same freshness reason as above — see `FinancialAccountTransferScreen`,
/// which also force-invalidates this on entry.
final financialAccountsActiveForPickerProvider = FutureProvider.autoDispose((
  ref,
) async {
  final selectedGroup = ref.watch(selectedGroupProvider);
  if (selectedGroup is! SelectedGroupResolved) return const [];

  final repository = ref.watch(financialAccountRepositoryProvider);
  final page = await repository.listFinancialAccounts(
    groupId: selectedGroup.membership.group.groupId,
    isActive: true,
    limit: 100,
  );
  return page.items;
});
