import 'package:umoja/features/auth/data/group_repository.dart';

/// In-memory [GroupRepository] fake. Records every call so tests can
/// assert group creation went through this abstraction (i.e.
/// `rpc_create_group`) and not a direct table insert.
class FakeGroupRepository implements GroupRepository {
  Object? failure;
  Map<String, dynamic> nextResult = const {'user_id': 'u1', 'memberships': []};

  final List<({String name, String? description})> createGroupCalls = [];

  @override
  Future<Map<String, dynamic>> createGroup({
    required String name,
    String? description,
  }) async {
    createGroupCalls.add((name: name, description: description));
    final f = failure;
    if (f != null) throw f;
    return nextResult;
  }
}
