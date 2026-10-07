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
import 'package:umoja/features/member_loans/data/member_loans_repository.dart';
import 'package:umoja/features/member_loans/providers/member_loans_repository_provider.dart';

import 'pin_bypass_overrides.dart';

/// Member self-service permission set for an ordinary linked member after
/// the 09G-B5-B.1 correction: MEMBER baseline only, no member.view.
const memberBaselinePermissions = [
  'group.view',
  'contribution.self_view',
  'loan.self_view',
];

MembershipContext memberLoansMembership({
  List<String> roles = const ['MEMBER'],
  List<String> permissions = memberBaselinePermissions,
}) {
  return MembershipContext(
    membershipId: 'm-member',
    group: const GroupContext(
      groupId: 'g1',
      groupName: 'Umoja Wamama',
      groupStatus: 'ACTIVE',
    ),
    membershipStatus: 'ACTIVE',
    displayName: 'Member Caller',
    roleCodes: roles,
    permissionCodes: permissions,
  );
}

/// Pumps the full app signed in with [membership] and the loans repository
/// overridden, then returns the [GoRouter] so a test can jump to any screen.
Future<GoRouter> pumpMemberLoansApp(
  WidgetTester tester, {
  required MemberLoansRepository repository,
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
          profile: const AppUserProfile(id: 'u1', fullName: 'Member Caller'),
          memberships: [membership ?? memberLoansMembership()],
        ),
      ),
      memberLoansRepositoryProvider.overrideWithValue(repository),
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

class _FixedLanguage extends LanguageNotifier {
  _FixedLanguage(this._language);

  final AppLanguage _language;

  @override
  AppLanguage build() => _language;
}
