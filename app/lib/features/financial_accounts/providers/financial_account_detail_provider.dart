import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/financial_account.dart';
import 'financial_account_repository_provider.dart';

/// A single financial account's detail (including its server-derived
/// balance). `.family` keyed on accountId. `.autoDispose` so leaving
/// the detail screen and returning later refetches rather than
/// showing a possibly stale balance/active-state snapshot (see
/// UAT-FIX-01).
final financialAccountDetailProvider = FutureProvider.autoDispose
    .family<FinancialAccount, String>((ref, accountId) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) {
        throw StateError('No resolved group context.');
      }

      final repository = ref.watch(financialAccountRepositoryProvider);
      return repository.getFinancialAccount(
        groupId: selectedGroup.membership.group.groupId,
        accountId: accountId,
      );
    });
