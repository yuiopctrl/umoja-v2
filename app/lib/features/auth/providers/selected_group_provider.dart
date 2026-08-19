import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/membership_context.dart';
import 'app_context_provider.dart';

/// The resolved state of "which group is the user currently working in".
///
/// No tenant-scoped query may run without a resolved
/// [SelectedGroupResolved] state. This is session-only (not persisted)
/// and derives automatically from [appContextProvider]:
/// - 0 memberships -> [SelectedGroupNone]
/// - 1 membership -> auto-selected [SelectedGroupResolved]
/// - >1 memberships -> [SelectedGroupPending] until [selectGroup] is called
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
        final memberships = context?.memberships ?? const [];
        if (memberships.isEmpty) return const SelectedGroupNone();
        if (memberships.length == 1) {
          return SelectedGroupResolved(memberships.first);
        }
        return SelectedGroupPending(memberships);
      },
      loading: () => const SelectedGroupLoading(),
      error: (_, _) => const SelectedGroupNone(),
    );
  }

  /// Resolves a pending multi-group selection. No-op if the state is not
  /// currently [SelectedGroupPending] or the membership id is unknown.
  void selectGroup(String membershipId) {
    final current = state;
    if (current is! SelectedGroupPending) return;

    for (final candidate in current.candidates) {
      if (candidate.membershipId == membershipId) {
        state = SelectedGroupResolved(candidate);
        return;
      }
    }
  }
}

final selectedGroupProvider =
    NotifierProvider<SelectedGroupNotifier, SelectedGroupState>(
      SelectedGroupNotifier.new,
    );
