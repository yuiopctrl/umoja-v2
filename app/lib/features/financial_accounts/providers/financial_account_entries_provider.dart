import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/financial_account_entry_page.dart';
import 'financial_account_repository_provider.dart';

typedef FinancialAccountEntriesQuery = ({String accountId, int limit});

/// `.autoDispose` for the same freshness reason as
/// [financialAccountDetailProvider] (see UAT-FIX-01).
final financialAccountEntriesProvider = FutureProvider.autoDispose
    .family<FinancialAccountEntryPage, FinancialAccountEntriesQuery>((
      ref,
      query,
    ) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) {
        return FinancialAccountEntryPage.empty;
      }

      final repository = ref.watch(financialAccountRepositoryProvider);
      return repository.listFinancialAccountEntries(
        groupId: selectedGroup.membership.group.groupId,
        accountId: query.accountId,
        limit: query.limit,
      );
    });
