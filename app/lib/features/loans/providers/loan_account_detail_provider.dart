import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/loan_account.dart';
import 'loan_repository_provider.dart';

/// A single loan account's detail (including its installment
/// schedule). `.family` keyed on loanAccountId. `.autoDispose` so
/// leaving the detail screen and returning later refetches rather
/// than showing a stale snapshot (e.g. after editing terms or
/// regenerating the schedule).
final loanAccountDetailProvider = FutureProvider.autoDispose
    .family<LoanAccount, String>((ref, loanAccountId) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) {
        throw StateError('No resolved group context.');
      }

      final repository = ref.watch(loanRepositoryProvider);
      return repository.getLoanAccount(
        groupId: selectedGroup.membership.group.groupId,
        loanAccountId: loanAccountId,
      );
    });
