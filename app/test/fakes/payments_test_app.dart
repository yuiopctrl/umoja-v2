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
import 'package:umoja/features/financial_accounts/domain/financial_account_page.dart';
import 'package:umoja/features/financial_accounts/providers/financial_account_repository_provider.dart';
import 'package:umoja/features/members/providers/member_repository_provider.dart';
import 'package:umoja/features/payments/providers/payment_repository_provider.dart';

import 'fake_financial_account_repository.dart';
import 'fake_member_repository.dart';
import 'fake_payment_repository.dart';
import 'pin_bypass_overrides.dart';

/// Default full-access payments/wallet permission set (matches
/// TREASURER's grants from `20260828090000_create_payments_schema.sql`).
const paymentTreasurerPermissions = [
  'group.view',
  'contribution.view',
  'payment.view',
  'payment.create',
  'payment.reverse',
  'payment.receipt.view',
  'wallet.view',
  'wallet.allocate',
];

MembershipContext paymentMembership({
  List<String> roles = const ['TREASURER'],
  List<String> permissions = paymentTreasurerPermissions,
}) {
  return MembershipContext(
    membershipId: 'm-treasurer',
    group: const GroupContext(
      groupId: 'g1',
      groupName: 'Umoja Wamama',
      groupStatus: 'ACTIVE',
    ),
    membershipStatus: 'ACTIVE',
    displayName: 'Treasurer Caller',
    roleCodes: roles,
    permissionCodes: permissions,
  );
}

/// Pumps the full [UmojaApp] signed in with [membership], with
/// [paymentRepositoryProvider]/[memberRepositoryProvider] overridden to
/// the supplied fakes, and returns the app's [GoRouter] so tests can
/// jump straight to any payments/wallet screen via `.go(path)`/`.push(path)`.
Future<GoRouter> pumpPaymentsApp(
  WidgetTester tester, {
  required FakePaymentRepository fakeRepo,
  FakeMemberRepository? fakeMemberRepo,
  FakeFinancialAccountRepository? fakeFinancialAccountRepo,
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
          profile: const AppUserProfile(id: 'u1', fullName: 'Treasurer Caller'),
          memberships: [membership ?? paymentMembership()],
        ),
      ),
      paymentRepositoryProvider.overrideWithValue(fakeRepo),
      memberRepositoryProvider.overrideWithValue(
        fakeMemberRepo ?? FakeMemberRepository(),
      ),
      financialAccountRepositoryProvider.overrideWithValue(
        fakeFinancialAccountRepo ??
            (FakeFinancialAccountRepository()
              ..nextAccountsPage = FinancialAccountPage(
                items: [
                  fakeFinancialAccount(id: 'account-1', name: 'Main Cash'),
                ],
                totalCount: 1,
                limit: 100,
                offset: 0,
              )),
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

  return container.read(routerProvider);
}

class _FixedLanguage extends LanguageNotifier {
  _FixedLanguage(this._language);

  final AppLanguage _language;

  @override
  AppLanguage build() => _language;
}
