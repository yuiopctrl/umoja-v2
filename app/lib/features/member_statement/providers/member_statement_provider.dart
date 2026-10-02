import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/member_financial_statement.dart';
import 'member_statement_query_provider.dart';
import 'member_statement_repository_provider.dart';

/// The caller's own financial statement for the CURRENTLY SELECTED
/// group (Prompt 09G-B3-C) — watches [selectedGroupProvider] directly
/// (same convention as `myMemberProfileProvider`), so switching group
/// naturally refetches the correct statement rather than ever risking
/// stale data from the previously selected group. Also watches
/// [memberStatementQueryProvider] so changing the date range or
/// loading more both trigger a natural refetch.
final myMemberStatementProvider =
    FutureProvider.autoDispose<MemberFinancialStatement>((ref) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) {
        // The route this provider is used on is only ever reachable
        // once a group is resolved (see route_guard.dart's operational
        // allowlist) — this is a safe, transient fallback rather than
        // a real reachable state.
        throw StateError('No selected group.');
      }

      final query = ref.watch(memberStatementQueryProvider);
      final repository = ref.watch(memberStatementRepositoryProvider);

      return repository.getMyStatement(
        groupId: selectedGroup.membership.group.groupId,
        fromDate: query.fromDate,
        toDate: query.toDate,
        limit: query.limit,
      );
    });
