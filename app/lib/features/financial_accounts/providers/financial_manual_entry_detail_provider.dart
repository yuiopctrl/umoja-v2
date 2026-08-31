import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/financial_manual_entry.dart';
import 'financial_account_repository_provider.dart';

/// A single manual income/expense entry's full detail (Prompt 08B).
/// `.family` keyed on entryId. `.autoDispose` so re-entering after a
/// reversal always refetches rather than showing a stale POSTED state.
final financialManualEntryDetailProvider = FutureProvider.autoDispose
    .family<FinancialManualEntryDetail, String>((ref, entryId) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) {
        throw StateError('No resolved group context.');
      }

      final repository = ref.watch(financialAccountRepositoryProvider);
      return repository.getFinancialManualEntry(
        groupId: selectedGroup.membership.group.groupId,
        entryId: entryId,
      );
    });
