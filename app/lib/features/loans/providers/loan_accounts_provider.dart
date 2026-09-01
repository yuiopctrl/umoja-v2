import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/loan_account.dart';
import 'loan_repository_provider.dart';

/// Query key for [loanAccountsProvider] — the owning screen holds its
/// own filter/pagination state locally, matching the financial
/// accounts list precedent.
typedef LoanAccountsQuery = ({
  String? membershipId,
  String? loanProductId,
  String? status,
  int limit,
  int offset,
});

/// `.autoDispose`: once no screen is watching this query anymore, its
/// cached result is discarded, so re-entering the list after saving a
/// draft always refetches rather than resurfacing a stale snapshot.
final loanAccountsProvider = FutureProvider.autoDispose
    .family<LoanAccountPage, LoanAccountsQuery>((ref, query) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) {
        return LoanAccountPage.empty;
      }

      final repository = ref.watch(loanRepositoryProvider);
      return repository.listLoanAccounts(
        groupId: selectedGroup.membership.group.groupId,
        membershipId: query.membershipId,
        loanProductId: query.loanProductId,
        status: query.status,
        limit: query.limit,
        offset: query.offset,
      );
    });
