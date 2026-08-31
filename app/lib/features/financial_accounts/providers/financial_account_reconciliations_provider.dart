import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/financial_reconciliation.dart';
import 'financial_account_repository_provider.dart';

/// Query key for [financialAccountReconciliationsProvider].
typedef FinancialAccountReconciliationsQuery = ({String accountId, int limit});

/// One account's reconciliation history, newest first (section 19).
/// `.autoDispose` for the same freshness reason as every other Prompt
/// 08 list provider.
final financialAccountReconciliationsProvider = FutureProvider.autoDispose
    .family<FinancialReconciliationPage, FinancialAccountReconciliationsQuery>((
      ref,
      query,
    ) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) {
        return FinancialReconciliationPage.empty;
      }

      final repository = ref.watch(financialAccountRepositoryProvider);
      return repository.listFinancialAccountReconciliations(
        groupId: selectedGroup.membership.group.groupId,
        financialAccountId: query.accountId,
        limit: query.limit,
      );
    });
