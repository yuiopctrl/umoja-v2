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
import 'package:umoja/features/contributions/data/contribution_repository.dart';
import 'package:umoja/features/contributions/providers/contribution_repository_provider.dart';

import 'fake_contribution_repository.dart';
import 'pin_bypass_overrides.dart';

/// Default full-access contribution permission set (matches ADMIN's
/// grants from `20260823120000_create_contribution_engine_schema.sql`).
const contributionAdminPermissions = [
  'group.view',
  'contribution.view',
  'contribution.type.manage',
  'contribution.setup.manage',
  'contribution.period.manage',
  'contribution.period.open',
  'contribution.period.close',
  'contribution.member_amount.manage',
  'contribution.member_exclude',
  'contribution.member_enroll',
  'contribution.penalty.assess',
  'contribution.self_view',
  'contribution.adjustment.create',
  'contribution.waiver.create',
  'contribution.opening_balance.manage',
];

MembershipContext contributionMembership({
  List<String> roles = const ['ADMIN'],
  List<String> permissions = contributionAdminPermissions,
}) {
  return MembershipContext(
    membershipId: 'm-admin',
    group: const GroupContext(
      groupId: 'g1',
      groupName: 'Umoja Wamama',
      groupStatus: 'ACTIVE',
    ),
    membershipStatus: 'ACTIVE',
    displayName: 'Admin Caller',
    roleCodes: roles,
    permissionCodes: permissions,
  );
}

/// Pumps the full [UmojaApp] signed in with [membership], with
/// [contributionRepositoryProvider] overridden to [fakeRepo], and
/// returns the app's [GoRouter] so tests can jump straight to any
/// contribution screen via `.go(path)` instead of tapping through every
/// intermediate screen.
Future<GoRouter> pumpContributionsApp(
  WidgetTester tester, {
  required FakeContributionRepository fakeRepo,
  MembershipContext? membership,
  AppLanguage? language,
}) {
  return pumpContributionsAppWithRepository(
    tester,
    repository: fakeRepo,
    membership: membership,
    language: language,
  );
}

/// Same as [pumpContributionsApp], but accepts any [ContributionRepository]
/// implementation — for tests that need a repository fake other than
/// [FakeContributionRepository] (e.g. a real in-memory paginated one).
Future<GoRouter> pumpContributionsAppWithRepository(
  WidgetTester tester, {
  required ContributionRepository repository,
  MembershipContext? membership,
  AppLanguage? language,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      ...pinBypassOverrides(),
      authSessionStatusProvider.overrideWithValue(AuthSessionStatus.signedIn),
      appContextProvider.overrideWith(
        (ref) async => AppContext(
          userId: 'u1',
          profile: const AppUserProfile(id: 'u1', fullName: 'Admin Caller'),
          memberships: [membership ?? contributionMembership()],
        ),
      ),
      contributionRepositoryProvider.overrideWithValue(repository),
      if (language != null)
        languageProvider.overrideWith(() => _FixedLanguage(language)),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const UmojaApp()),
  );
  await tester.pumpAndSettle();

  return container.read(routerProvider);
}

/// A [LanguageNotifier] override that stays pinned to one [AppLanguage] —
/// tests use this to render the app in English without depending on the
/// real `SharedPreferences`-backed load in [LanguageNotifier.build].
class _FixedLanguage extends LanguageNotifier {
  _FixedLanguage(this._language);

  final AppLanguage _language;

  @override
  AppLanguage build() => _language;
}
