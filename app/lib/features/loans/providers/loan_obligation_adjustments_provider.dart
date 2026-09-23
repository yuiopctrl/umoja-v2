import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/loan_obligation_adjustment.dart';
import 'loan_repository_provider.dart';

/// The authoritative "Adjustments & Waivers" history for one loan
/// (Prompt 09F-A, section 23) — `.autoDispose` so leaving the screen
/// discards any stale snapshot, matching every other loan detail
/// provider's precedent (e.g. `loanPenaltyChargesProvider`).
final loanObligationAdjustmentsProvider = FutureProvider.autoDispose
    .family<LoanObligationAdjustmentPage, String>((ref, loanAccountId) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) {
        return const LoanObligationAdjustmentPage(totalCount: 0, items: []);
      }

      final repository = ref.watch(loanRepositoryProvider);
      return repository.listLoanObligationAdjustments(
        groupId: selectedGroup.membership.group.groupId,
        loanAccountId: loanAccountId,
      );
    });
