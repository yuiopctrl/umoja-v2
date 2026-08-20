import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/group_member.dart';
import 'member_repository_provider.dart';

/// A single member's detail, scoped to the current selected group.
/// `.family` keyed on membershipId so the detail screen can watch just
/// its own record.
final memberDetailProvider = FutureProvider.family<GroupMember, String>((
  ref,
  membershipId,
) async {
  final selectedGroup = ref.watch(selectedGroupProvider);
  if (selectedGroup is! SelectedGroupResolved) {
    throw StateError('No resolved group context.');
  }

  final repository = ref.watch(memberRepositoryProvider);
  return repository.getMember(
    groupId: selectedGroup.membership.group.groupId,
    membershipId: membershipId,
  );
});
