import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:umoja/app/app.dart';
import 'package:umoja/app/routing/app_router.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/auth/models/app_context.dart';
import 'package:umoja/features/auth/models/app_user_profile.dart';
import 'package:umoja/features/auth/models/group_context.dart';
import 'package:umoja/features/auth/models/membership_context.dart';
import 'package:umoja/features/auth/providers/app_context_provider.dart';
import 'package:umoja/features/auth/providers/auth_session_provider.dart';
import 'package:umoja/features/members/providers/member_repository_provider.dart';
import 'package:umoja/features/membership_invitations/providers/membership_invitation_repository_provider.dart';

import 'fake_member_repository.dart';
import 'fake_membership_invitation_repository.dart';
import 'pin_bypass_overrides.dart';

/// An ADMIN membership holding `member.invite` (Prompt 09G-B1-E2) — the
/// exact permission `rpc_create_membership_invitation`/
/// `rpc_list_membership_invitations`/`rpc_cancel_membership_invitation`
/// enforce server-side (never gated on the `ADMIN` role name itself).
MembershipContext membershipInvitationOfficerMembership({
  String id = 'm-officer',
  String groupId = 'g-officer',
  List<String> roleCodes = const ['ADMIN'],
}) {
  return MembershipContext(
    membershipId: id,
    group: GroupContext(
      groupId: groupId,
      groupName: 'Umoja Wamama',
      groupStatus: 'ACTIVE',
    ),
    membershipStatus: 'ACTIVE',
    displayName: 'Officer One',
    roleCodes: roleCodes,
    permissionCodes: const [
      'group.view',
      'member.view',
      'member.invite',
      'member.claim.approve',
    ],
  );
}

/// A plain MEMBER in the same group — holds neither `member.invite` nor
/// `member.claim.approve` (§O items 9/11: permission alone, never a
/// role name, must gate visibility).
MembershipContext membershipInvitationPlainMemberMembership({
  String id = 'm-plain',
  String groupId = 'g-officer',
}) {
  return MembershipContext(
    membershipId: id,
    group: GroupContext(
      groupId: groupId,
      groupName: 'Umoja Wamama',
      groupStatus: 'ACTIVE',
    ),
    membershipStatus: 'ACTIVE',
    displayName: 'Plain Member',
    roleCodes: const ['MEMBER'],
    permissionCodes: const ['group.view', 'member.view'],
  );
}

/// Pumps the full [UmojaApp] signed in with [membership] as the sole
/// resolved membership, with [membershipInvitationRepositoryProvider]/
/// [memberRepositoryProvider] overridden to the given fakes. Returns
/// the app's [GoRouter] so tests can jump straight to any
/// membership-invitation screen via `.go(path)`.
Future<(GoRouter, ProviderContainer)> pumpMembershipInvitationApp(
  WidgetTester tester, {
  required MembershipContext membership,
  required FakeMembershipInvitationRepository fakeInvitationRepo,
  required FakeMemberRepository fakeMemberRepo,
  Size viewSize = const Size(390, 844),
  AppLanguage? language,
}) async {
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    // See membership_claim_test_app.dart's identical rationale: avoid
    // Riverpod 3.x's default retry-on-throw flickering an error state
    // back to loading mid-pumpAndSettle.
    retry: (retryCount, error) => null,
    overrides: [
      ...pinBypassOverrides(),
      authSessionStatusProvider.overrideWithValue(AuthSessionStatus.signedIn),
      appContextProvider.overrideWith(
        (ref) async => AppContext(
          userId: 'u1',
          profile: const AppUserProfile(id: 'u1', fullName: 'Officer One'),
          memberships: [membership],
        ),
      ),
      membershipInvitationRepositoryProvider.overrideWithValue(
        fakeInvitationRepo,
      ),
      memberRepositoryProvider.overrideWithValue(fakeMemberRepo),
      if (language != null)
        languageProvider.overrideWith(() => _FixedLanguage(language)),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const UmojaApp()),
  );
  await tester.pumpAndSettle();

  return (container.read(routerProvider), container);
}

/// Pumps the full [UmojaApp] for E3 acceptance-flow tests, with full
/// control over [sessionStatus] and [memberships] (including empty, or
/// signed-out) — the E2 harness above always assumes a signed-in
/// officer with one membership, which the member-facing acceptance
/// screen tests need to vary freely (signed out, zero eligible
/// memberships, an already-resolved unrelated group, ...).
Future<(GoRouter, ProviderContainer)> pumpMembershipInvitationAcceptanceApp(
  WidgetTester tester, {
  required AuthSessionStatus sessionStatus,
  List<MembershipContext> memberships = const [],
  required FakeMembershipInvitationRepository fakeInvitationRepo,
  Size viewSize = const Size(390, 844),
  AppLanguage? language,
}) async {
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    retry: (retryCount, error) => null,
    overrides: [
      ...pinBypassOverrides(),
      authSessionStatusProvider.overrideWithValue(sessionStatus),
      appContextProvider.overrideWith(
        (ref) async => sessionStatus == AuthSessionStatus.signedOut
            ? null
            : AppContext(
                userId: 'u1',
                profile: const AppUserProfile(id: 'u1', fullName: 'Invitee'),
                memberships: memberships,
              ),
      ),
      membershipInvitationRepositoryProvider.overrideWithValue(
        fakeInvitationRepo,
      ),
      if (language != null)
        languageProvider.overrideWith(() => _FixedLanguage(language)),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const UmojaApp()),
  );
  await tester.pumpAndSettle();

  return (container.read(routerProvider), container);
}

/// A mutable holder for the fixture [appContextProvider] override reads
/// on every (re)fetch — lets a test change what the *next* refetch
/// resolves to (e.g. simulating a successful invitation acceptance)
/// without needing a second full app pump. Mirrors
/// `MembershipContextFixture` in `membership_claim_test_app.dart`
/// (Prompt 09G-B1-D4) exactly.
class InvitationAcceptanceContextFixture {
  InvitationAcceptanceContextFixture(this.memberships);

  List<MembershipContext> memberships;
}

/// Same as [pumpMembershipInvitationAcceptanceApp], but backed by a
/// mutable [InvitationAcceptanceContextFixture] so a test can simulate
/// "acceptance succeeded, appContextProvider now resolves the newly
/// linked membership" and assert the router transitions exactly like
/// the D4 claim-approval transition — never by fabricating
/// `MembershipContext` client-side.
Future<(GoRouter, InvitationAcceptanceContextFixture, ProviderContainer)>
pumpMembershipInvitationAcceptanceAppMutable(
  WidgetTester tester, {
  required InvitationAcceptanceContextFixture fixture,
  required FakeMembershipInvitationRepository fakeInvitationRepo,
  Size viewSize = const Size(390, 844),
  AppLanguage? language,
}) async {
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    retry: (retryCount, error) => null,
    overrides: [
      ...pinBypassOverrides(),
      authSessionStatusProvider.overrideWithValue(AuthSessionStatus.signedIn),
      appContextProvider.overrideWith(
        (ref) async => AppContext(
          userId: 'u1',
          profile: const AppUserProfile(id: 'u1', fullName: 'Invitee'),
          memberships: fixture.memberships,
        ),
      ),
      membershipInvitationRepositoryProvider.overrideWithValue(
        fakeInvitationRepo,
      ),
      if (language != null)
        languageProvider.overrideWith(() => _FixedLanguage(language)),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const UmojaApp()),
  );
  await tester.pumpAndSettle();

  return (container.read(routerProvider), fixture, container);
}

class _FixedLanguage extends LanguageNotifier {
  _FixedLanguage(this._language);

  final AppLanguage _language;

  @override
  AppLanguage build() => _language;
}
