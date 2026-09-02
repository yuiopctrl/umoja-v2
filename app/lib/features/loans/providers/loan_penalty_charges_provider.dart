import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/loan_penalty_charge.dart';
import 'loan_repository_provider.dart';

/// The authoritative penalty history for one loan (Prompt 09D, section
/// 32) — `.autoDispose` so leaving the screen discards any stale
/// snapshot, matching every other loan detail provider's precedent.
final loanPenaltyChargesProvider = FutureProvider.autoDispose
    .family<List<LoanPenaltyCharge>, String>((ref, loanAccountId) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) {
        return const [];
      }

      final repository = ref.watch(loanRepositoryProvider);
      return repository.listLoanPenaltyCharges(
        groupId: selectedGroup.membership.group.groupId,
        loanAccountId: loanAccountId,
      );
    });
