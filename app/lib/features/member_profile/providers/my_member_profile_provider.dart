import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/my_member_profile.dart';
import 'member_profile_repository_provider.dart';

/// The caller's own member profile for the CURRENTLY SELECTED group
/// (Prompt 09G-B2) — watches [selectedGroupProvider] directly, so
/// switching group naturally refetches the correct self-profile rather
/// than ever risking stale data from the previously selected group.
/// `.autoDispose` — discarded once nothing is watching it, matching
/// [myMembershipInvitationsProvider]'s own lifecycle convention.
final myMemberProfileProvider = FutureProvider.autoDispose<MyMemberProfile>((
  ref,
) async {
  final selectedGroup = ref.watch(selectedGroupProvider);
  if (selectedGroup is! SelectedGroupResolved) {
    // The route this provider is used on is only ever reachable
    // once a group is resolved (see route_guard.dart's operational
    // allowlist) — this is a safe, transient fallback rather than
    // a real reachable state.
    throw StateError('No selected group.');
  }
  final repository = ref.watch(memberProfileRepositoryProvider);
  return repository.getMyProfile(selectedGroup.membership.group.groupId);
});
