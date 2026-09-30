import 'package:umoja/features/member_profile/data/member_profile_repository.dart';
import 'package:umoja/features/member_profile/domain/my_member_profile.dart';

MyMemberProfile fakeMyMemberProfile({
  String? accountFullName = 'Fredrick Mrema',
  String? accountPhone = '+255700000001',
  String membershipId = 'membership-self-1',
  String membershipDisplayName = 'Fredrick Mrema',
  String? memberNumber = 'UMJ-2026-0001',
  String membershipStatus = 'ACTIVE',
  String? joinedAt = '2025-01-01',
  String groupId = 'group-1',
  String groupName = 'Umoja Demo',
  String? groupCode = 'DEMO01',
  List<String> roleCodes = const ['MEMBER'],
}) {
  return MyMemberProfile(
    accountFullName: accountFullName,
    accountPhone: accountPhone,
    accountAvatarUrl: null,
    membershipId: membershipId,
    membershipDisplayName: membershipDisplayName,
    memberNumber: memberNumber,
    membershipStatus: membershipStatus,
    joinedAt: joinedAt,
    groupId: groupId,
    groupName: groupName,
    groupCode: groupCode,
    roleCodes: roleCodes,
  );
}

/// A benign fake for widget tests that only need `myMemberProfileProvider`
/// to resolve without hitting the real Supabase client — Home and the
/// desktop/mobile shell watch it on every app boot regardless of which
/// screen a test targets (same rationale as
/// `FakeMembershipInvitationRepository` in `pin_bypass_overrides.dart`).
class FakeMemberProfileRepository implements MemberProfileRepository {
  FakeMemberProfileRepository({MyMemberProfile? profile})
    : profile = profile ?? fakeMyMemberProfile();

  MyMemberProfile profile;
  Object? nextError;

  @override
  Future<MyMemberProfile> getMyProfile(String groupId) async {
    if (nextError != null) throw nextError!;
    return profile;
  }
}
