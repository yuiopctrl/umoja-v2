import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/member_financial_statement.dart';
import 'member_statement_repository_provider.dart';

/// Home's own financial snapshot (Prompt 09G-B3-D) — the SAME
/// [MemberStatementRepository]/`rpc_get_my_member_statement` B3-C
/// already uses, but deliberately NOT wired to
/// [memberStatementQueryProvider] at all: Home always means the
/// CURRENT position, so this provider hard-codes `fromDate: null,
/// toDate: null, offset: 0` and the RPC's own minimum valid `limit`
/// (1 — Home never needs the activity timeline, only `summary`/
/// `period`). A previously-applied date filter, an expanded page
/// size, or any other transient Statement-screen UI state can never
/// leak into what Home shows, because this provider never reads that
/// state in the first place.
///
/// `.autoDispose` and watches [selectedGroupProvider] directly (same
/// convention as `myMemberProfileProvider`/`myMemberStatementProvider`)
/// so switching group naturally refetches Home's own summary — no
/// Group A figure can ever remain visible once Group B is selected.
final homeFinancialSummaryProvider =
    FutureProvider.autoDispose<MemberFinancialStatement>((ref) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) {
        // Home itself only ever renders once a group is resolved (see
        // HomeScreen's own membership==null fallback) — this is a
        // safe, transient guard rather than a reachable state.
        throw StateError('No selected group.');
      }

      final repository = ref.watch(memberStatementRepositoryProvider);
      return repository.getMyStatement(
        groupId: selectedGroup.membership.group.groupId,
        limit: 1,
      );
    });
