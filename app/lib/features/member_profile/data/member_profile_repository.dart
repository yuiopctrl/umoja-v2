import '../domain/my_member_profile.dart';

/// Abstraction over the caller's own member profile
/// (`rpc_get_my_member_profile`) — a MY-profile read, never an officer
/// "view member" lookup. See [MyMemberProfile] for the identity-
/// separation invariants this preserves.
abstract class MemberProfileRepository {
  Future<MyMemberProfile> getMyProfile(String groupId);
}
