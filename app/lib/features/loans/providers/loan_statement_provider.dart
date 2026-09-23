import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/loan_statement.dart';
import 'loan_repository_provider.dart';

/// The authoritative loan statement for one loan (Prompt 09G) —
/// `.autoDispose` so leaving the screen discards any stale snapshot,
/// matching every other loan detail provider's precedent (e.g.
/// [loanWriteOffSummaryProvider]/`loanAccountDetailProvider`). Purely a
/// read RPC, so no separate mutable controller is needed — `ref.watch`
/// gives loading/error/data states out of the box, and `ref.invalidate`
/// on the same provider gives retry/refresh.
final loanStatementProvider = FutureProvider.autoDispose
    .family<LoanStatement, String>((ref, loanAccountId) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) {
        throw StateError('No resolved group context.');
      }

      final repository = ref.watch(loanRepositoryProvider);
      return repository.getLoanStatement(
        groupId: selectedGroup.membership.group.groupId,
        loanAccountId: loanAccountId,
      );
    });
