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
import 'package:umoja/features/membership_claim/providers/membership_claim_repository_provider.dart';

import 'fake_membership_claim_repository.dart';
import 'pin_bypass_overrides.dart';

/// An ACTIVE membership in an ACTIVE group — used by tests exercising
/// the officer-approves-elsewhere transition (Prompt 09G-B1-D2 §L),
/// where a formerly-unlinked user's [appContextProvider] refetch now
/// resolves exactly one eligible group.
MembershipContext membershipClaimEligibleMembership({
  String id = 'm-resolved',
}) {
  return MembershipContext(
    membershipId: id,
    group: GroupContext(
      groupId: 'g-$id',
      groupName: 'Umoja Wamama',
      groupStatus: 'ACTIVE',
    ),
    membershipStatus: 'ACTIVE',
    displayName: 'Claimant',
    roleCodes: const ['MEMBER'],
    permissionCodes: const ['group.view'],
  );
}

/// An ADMIN membership holding `member.claim.approve` (Prompt
/// 09G-B1-D3) — the exact permission `rpc_list_membership_claims`/
/// `rpc_approve_membership_claim`/`rpc_reject_membership_claim` enforce
/// server-side (never gated on the `ADMIN` role name itself).
MembershipContext membershipClaimOfficerMembership({
  String id = 'm-officer',
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
    displayName: 'Officer One',
    roleCodes: const ['ADMIN'],
    permissionCodes: const [
      'group.view',
      'member.view',
      'member.claim.approve',
    ],
  );
}

/// A plain MEMBER in the same group — holds no `member.claim.approve`
/// (Prompt 09G-B1-D3 §R items 17-21: role alone must never grant UI
/// access, and neither must holding the permission in a DIFFERENT
/// group).
MembershipContext membershipClaimPlainMemberMembership({
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

/// A mutable holder for the fixture [appContextProvider] override reads
/// on every (re)fetch — lets a test change what the *next* refetch
/// resolves to (e.g. simulating an officer approving the claim
/// elsewhere) without needing a second full app pump.
class MembershipContextFixture {
  MembershipContextFixture(this.memberships);

  List<MembershipContext> memberships;
}

/// Pumps the full [UmojaApp] signed in as a profile-complete user with
/// [memberships] (empty by default — the "no membership linked yet"
/// state D2 targets), with [membershipClaimRepositoryProvider]
/// overridden to [fakeRepo]. Returns the app's [GoRouter] so tests can
/// jump straight to any membership-claim screen via `.go(path)`.
Future<GoRouter> pumpMembershipClaimApp(
  WidgetTester tester, {
  required FakeMembershipClaimRepository fakeRepo,
  List<MembershipContext> memberships = const [],
  Size viewSize = const Size(390, 844),
  AppLanguage? language,
}) async {
  final (router, _, _) = await pumpMembershipClaimAppMutable(
    tester,
    fakeRepo: fakeRepo,
    fixture: MembershipContextFixture(memberships),
    viewSize: viewSize,
    language: language,
  );
  return router;
}

/// Same as [pumpMembershipClaimApp], but also returns the
/// [MembershipContextFixture] backing [appContextProvider] (so a test
/// can mutate [MembershipContextFixture.memberships] between actions —
/// e.g. to simulate an officer approving the claim elsewhere) and the
/// [ProviderContainer] itself, so a test can directly
/// `container.invalidate(appContextProvider)` to model "appContextProvider
/// is invalidated/refetched" (Prompt 09G-B1-D4 §N step 7) from
/// wherever the user currently is — not only from a screen that
/// happens to have its own refresh affordance.
Future<(GoRouter, MembershipContextFixture, ProviderContainer)>
pumpMembershipClaimAppMutable(
  WidgetTester tester, {
  required FakeMembershipClaimRepository fakeRepo,
  required MembershipContextFixture fixture,
  Size viewSize = const Size(390, 844),
  AppLanguage? language,
}) async {
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    // Riverpod 3.x auto-retries a thrown (non-Error) exception with
    // exponential backoff by default — a real `MembershipClaimFailure`
    // qualifies, so an error-state test would otherwise flicker back
    // to `loading` mid-`pumpAndSettle` (hiding the just-rendered error
    // text) and leave a background retry Timer pending past the
    // test's own teardown. Disabled here; production behavior is
    // unaffected since this only scopes this test's container.
    retry: (retryCount, error) => null,
    overrides: [
      ...pinBypassOverrides(),
      authSessionStatusProvider.overrideWithValue(AuthSessionStatus.signedIn),
      appContextProvider.overrideWith(
        (ref) async => AppContext(
          userId: 'u1',
          profile: const AppUserProfile(id: 'u1', fullName: 'Claimant'),
          memberships: fixture.memberships,
        ),
      ),
      membershipClaimRepositoryProvider.overrideWithValue(fakeRepo),
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
