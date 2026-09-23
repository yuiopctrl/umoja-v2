import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/loan_write_off_recovery.dart';
import 'loan_repository_provider.dart';

/// The authoritative write-off summary + recovery history for one loan
/// (Prompt 09F-B) — `.autoDispose` so leaving the screen discards any
/// stale snapshot, matching every other loan detail provider's
/// precedent (e.g. `loanObligationAdjustmentsProvider`).
final loanWriteOffSummaryProvider = FutureProvider.autoDispose
    .family<LoanWriteOffSummary, String>((ref, loanAccountId) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) {
        return const LoanWriteOffSummary(
          loanAccountId: '',
          loanStatus: '',
          recoveries: [],
        );
      }

      final repository = ref.watch(loanRepositoryProvider);
      return repository.getLoanWriteOffSummary(
        groupId: selectedGroup.membership.group.groupId,
        loanAccountId: loanAccountId,
      );
    });
