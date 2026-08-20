import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/group_member_page.dart';
import 'member_repository_provider.dart';
import 'members_query_provider.dart';

/// The current page of the Members list, scoped to the app's existing
/// selected-group context (never a parallel "current group" concept —
/// see docs/product/members.md). Watching [selectedGroupProvider]
/// means this refetches automatically whenever the resolved group
/// changes (including across a sign-out/sign-in identity change, where
/// [selectedGroupProvider] itself already resets first) — old member
/// data is never shown against a new group.
final membersListProvider = FutureProvider<GroupMemberPage>((ref) async {
  final selectedGroup = ref.watch(selectedGroupProvider);
  if (selectedGroup is! SelectedGroupResolved) {
    return GroupMemberPage.empty;
  }

  final query = ref.watch(membersQueryProvider);
  final repository = ref.watch(memberRepositoryProvider);

  return repository.listMembers(
    groupId: selectedGroup.membership.group.groupId,
    search: query.search,
    status: query.status,
    limit: query.limit,
  );
});
