import 'package:umoja/features/members/data/member_repository.dart';
import 'package:umoja/features/members/domain/group_member.dart';
import 'package:umoja/features/members/domain/group_member_page.dart';

GroupMember _fakeMember({
  String membershipId = 'm1',
  String groupId = 'g1',
  String displayName = 'Test Member',
  String status = 'ACTIVE',
  bool isLoginLinked = false,
}) {
  return GroupMember(
    membershipId: membershipId,
    groupId: groupId,
    displayName: displayName,
    status: status,
    createdAt: DateTime.utc(2026, 1, 15),
    isLoginLinked: isLoginLinked,
    roleCodes: const [],
  );
}

/// In-memory [MemberRepository] fake for tests. Records every call so
/// tests can assert controllers/providers call the right repository
/// method with the right arguments, and can be configured to throw a
/// specific failure to test error-surfacing.
class FakeMemberRepository implements MemberRepository {
  Object? failure;
  GroupMemberPage nextListResult = GroupMemberPage.empty;
  GroupMember nextMemberResult = _fakeMember();

  final List<
    ({String groupId, String? search, String? status, int limit, int offset})
  >
  listMembersCalls = [];
  final List<({String groupId, String membershipId})> getMemberCalls = [];
  final List<
    ({String groupId, String displayName, String? phone, String? memberNumber})
  >
  createMemberCalls = [];
  final List<({String groupId, String membershipId, String? displayName})>
  updateMemberCalls = [];
  final List<({String groupId, String membershipId, String status})>
  changeStatusCalls = [];
  final List<({String groupId, String membershipId, String roleCode})>
  assignRoleCalls = [];
  final List<({String groupId, String membershipId, String roleCode})>
  removeRoleCalls = [];

  void _maybeThrow() {
    final f = failure;
    if (f != null) throw f;
  }

  @override
  Future<GroupMemberPage> listMembers({
    required String groupId,
    String? search,
    String? status,
    int limit = 25,
    int offset = 0,
  }) async {
    listMembersCalls.add((
      groupId: groupId,
      search: search,
      status: status,
      limit: limit,
      offset: offset,
    ));
    _maybeThrow();
    return nextListResult;
  }

  @override
  Future<GroupMember> getMember({
    required String groupId,
    required String membershipId,
  }) async {
    getMemberCalls.add((groupId: groupId, membershipId: membershipId));
    _maybeThrow();
    return nextMemberResult;
  }

  @override
  Future<GroupMember> createMember({
    required String groupId,
    required String displayName,
    String? phone,
    String? memberNumber,
    DateTime? joinedAt,
  }) async {
    createMemberCalls.add((
      groupId: groupId,
      displayName: displayName,
      phone: phone,
      memberNumber: memberNumber,
    ));
    _maybeThrow();
    return nextMemberResult;
  }

  @override
  Future<GroupMember> updateMember({
    required String groupId,
    required String membershipId,
    String? displayName,
    String? phone,
    String? memberNumber,
  }) async {
    updateMemberCalls.add((
      groupId: groupId,
      membershipId: membershipId,
      displayName: displayName,
    ));
    _maybeThrow();
    return nextMemberResult;
  }

  @override
  Future<GroupMember> changeStatus({
    required String groupId,
    required String membershipId,
    required String status,
    DateTime? exitedAt,
  }) async {
    changeStatusCalls.add((
      groupId: groupId,
      membershipId: membershipId,
      status: status,
    ));
    _maybeThrow();
    return nextMemberResult;
  }

  @override
  Future<void> assignRole({
    required String groupId,
    required String membershipId,
    required String roleCode,
  }) async {
    assignRoleCalls.add((
      groupId: groupId,
      membershipId: membershipId,
      roleCode: roleCode,
    ));
    _maybeThrow();
  }

  @override
  Future<void> removeRole({
    required String groupId,
    required String membershipId,
    required String roleCode,
  }) async {
    removeRoleCalls.add((
      groupId: groupId,
      membershipId: membershipId,
      roleCode: roleCode,
    ));
    _maybeThrow();
  }
}
