import 'package:umoja/features/membership_invitations/data/membership_invitation_repository.dart';
import 'package:umoja/features/membership_invitations/providers/membership_invitation_repository_provider.dart';
import 'package:umoja/features/security/providers/has_pin_credential_provider.dart';

import 'fake_membership_invitation_repository.dart';

/// Standard overrides for widget tests that need to reach past the PIN
/// gate to exercise operational screens — "PIN already configured
/// server-side" for every signed-in fixture, so existing
/// profile/group/member-screen tests don't need to know or care about
/// PIN credential state. Dedicated PIN-flow/login tests override this
/// provider themselves instead of using this helper.
///
/// Also includes a [MembershipInvitationRepository] override, defaulting
/// to a benign empty [FakeMembershipInvitationRepository]: Home's
/// pending-invitation banner and the More screen's badge (Prompt
/// 09G-B1-F2 §L) watch `myMembershipInvitationsProvider` on every app
/// boot regardless of which screen a test is targeting — an unfaked
/// repository here would hit the real Supabase client, throw, and leave
/// a Riverpod retry Timer pending past the test's own teardown. Tests
/// exercising the invitation feature itself pass their own configured
/// fake via [membershipInvitationRepository] instead of overriding the
/// provider a second time — Riverpod 3.x throws on a duplicate override
/// within the same container.
///
/// No explicit return type: `Override` isn't part of riverpod 3.x's
/// public export surface, so this relies on type inference rather than
/// naming it.
// ignore: strict_top_level_inference
pinBypassOverrides({
  MembershipInvitationRepository? membershipInvitationRepository,
}) => [
  hasPinCredentialProvider.overrideWith((ref) async => true),
  membershipInvitationRepositoryProvider.overrideWithValue(
    membershipInvitationRepository ?? FakeMembershipInvitationRepository(),
  ),
];
