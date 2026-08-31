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
import 'package:umoja/features/financial_accounts/providers/financial_account_repository_provider.dart';

import 'fake_financial_account_repository.dart';
import 'pin_bypass_overrides.dart';

/// Default full-access financial account permission set (matches
/// ADMIN's grants from `20260826090000_create_financial_accounts_schema.sql`).
const financialAccountAdminPermissions = [
  'group.view',
  'financial_account.view',
  'financial_account.manage',
  'financial_account.transfer.create',
  'financial_entry.view',
  'financial_income.create',
  'financial_expense.create',
  'financial_entry.reverse',
  'financial_reconciliation.view',
  'financial_reconciliation.create',
  'financial_adjustment.create',
  'financial_report.view',
];

MembershipContext financialAccountMembership({
  List<String> roles = const ['ADMIN'],
  List<String> permissions = financialAccountAdminPermissions,
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
/// [financialAccountRepositoryProvider] overridden to [fakeRepo], and
/// returns the app's [GoRouter] so tests can jump straight to any
/// financial accounts screen via `.go(path)`/`.push(path)`.
Future<GoRouter> pumpFinancialAccountsApp(
  WidgetTester tester, {
  required FakeFinancialAccountRepository fakeRepo,
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
          memberships: [membership ?? financialAccountMembership()],
        ),
      ),
      financialAccountRepositoryProvider.overrideWithValue(fakeRepo),
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
