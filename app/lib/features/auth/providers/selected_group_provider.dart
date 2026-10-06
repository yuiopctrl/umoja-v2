import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../member_statement/providers/member_statement_query_provider.dart';
import '../../my_contributions/providers/my_contributions_query_provider.dart';
import '../../members/providers/members_query_provider.dart';
import '../models/membership_context.dart';
import 'app_context_provider.dart';

/// The resolved state of "which group is the user currently working in".
///
/// No tenant-scoped query may run without a resolved
/// [SelectedGroupResolved] state. This is session-only (not persisted)
/// and derives automatically from [appContextProvider], considering
/// only *eligible* memberships — [MembershipContext.isEligibleOperational]
/// (ACTIVE membership in an ACTIVE group). SUSPENDED/EXITED memberships
/// and memberships in a SUSPENDED/CLOSED group are never auto-selected:
/// - 0 eligible memberships -> [SelectedGroupNone]
/// - 1 eligible membership -> auto-selected [SelectedGroupResolved]
/// - >1 eligible memberships -> [SelectedGroupPending] until [selectGroup]
sealed class SelectedGroupState {
  const SelectedGroupState();
}

class SelectedGroupLoading extends SelectedGroupState {
  const SelectedGroupLoading();
}

class SelectedGroupNone extends SelectedGroupState {
  const SelectedGroupNone();
}

class SelectedGroupPending extends SelectedGroupState {
  const SelectedGroupPending(this.candidates);

  final List<MembershipContext> candidates;
}

class SelectedGroupResolved extends SelectedGroupState {
  const SelectedGroupResolved(this.membership);

  final MembershipContext membership;
}

class SelectedGroupNotifier extends Notifier<SelectedGroupState> {
  @override
  SelectedGroupState build() {
    final contextAsync = ref.watch(appContextProvider);

    return contextAsync.when(
      data: (context) {
        final eligible = (context?.memberships ?? const [])
            .where((m) => m.isEligibleOperational)
            .toList(growable: false);
        if (eligible.isEmpty) return const SelectedGroupNone();
        if (eligible.length == 1) {
          return SelectedGroupResolved(eligible.first);
        }
        return SelectedGroupPending(eligible);
      },
      loading: () => const SelectedGroupLoading(),
      error: (_, _) => const SelectedGroupNone(),
    );
  }

  /// Resolves a pending multi-group selection. No-op if the state is not
  /// currently [SelectedGroupPending] or the membership id is unknown.
  ///
  /// Invalidates [membersQueryProvider] so a previously-loaded page
  /// count/search/filter from the old group is never carried into the
  /// newly-selected one (prompt 05C §11 — "changing group clears
  /// previous group's loaded pages").
  void selectGroup(String membershipId) {
    final current = state;
    if (current is! SelectedGroupPending) return;

    for (final candidate in current.candidates) {
      if (candidate.membershipId == membershipId) {
        state = SelectedGroupResolved(candidate);
        ref.invalidate(membersQueryProvider);
        // Prompt 09G-B3-C §P/§Q: a previously-loaded page count/date
        // filter from the old group must never carry into the newly-
        // selected one — same rationale as membersQueryProvider above.
        ref.invalidate(memberStatementQueryProvider);
        // Prompt 09G-B4-C §G: My Contributions filters/page size from the
        // old group must never query the new one; its list and detail
        // providers already rebuild from selectedGroupProvider.
        ref.invalidate(myContributionsQueryProvider);
        return;
      }
    }
  }

  /// "Change Group": explicitly returns to a pending multi-selection
  /// state so the router sends the user back to `/select-group`. A
  /// no-op if fewer than two eligible groups are available.
  void requireReselection(List<MembershipContext> eligibleCandidates) {
    if (eligibleCandidates.length > 1) {
      state = SelectedGroupPending(eligibleCandidates);
      ref.invalidate(myContributionsQueryProvider);
    }
  }
}

final selectedGroupProvider =
    NotifierProvider<SelectedGroupNotifier, SelectedGroupState>(
      SelectedGroupNotifier.new,
    );
