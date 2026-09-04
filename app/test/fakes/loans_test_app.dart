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
import 'package:umoja/features/loans/providers/loan_repository_provider.dart';
import 'package:umoja/features/members/providers/member_repository_provider.dart';

import 'fake_financial_account_repository.dart';
import 'fake_loan_repository.dart';
import 'fake_member_repository.dart';
import 'pin_bypass_overrides.dart';

/// Default full-access loans permission set (Prompt 09A section X,
/// extended 09B with the lifecycle permissions — matches ADMIN's full
/// grants from `20260903090000_create_loan_lifecycle_events.sql`).
const loanAdminPermissions = [
  'group.view',
  'loan_product.view',
  'loan_product.manage',
  'loan.view',
  'loan.create',
  'loan.edit',
  'loan_schedule.view',
  'loan_schedule.generate',
  'loan.submit',
  'loan.approve',
  'loan.reject',
  'loan.cancel',
  'loan.disburse',
  'financial_account.view',
  'loan_penalty.view',
  'loan_penalty.assess',
  'loan_opening.create',
  'loan.settle_early',
  'loan.prepay_principal',
  'loan.restructure',
];

/// CHAIRPERSON/SECRETARY's view-only grants — no `.manage`/`.create`/
/// `.edit`/`.generate` (Prompt 09A section X). `loan_penalty.view` only
/// (never `.assess` — Prompt 09D).
const loanViewOnlyPermissions = [
  'group.view',
  'loan_product.view',
  'loan.view',
  'loan_schedule.view',
  'loan_penalty.view',
];

/// TREASURER's 09B grants (section 23) — submit/disburse/cancel, but
/// deliberately NOT approve/reject (separation of duties: the actor
/// who submits/disburses is never the same one who decides approval).
/// Also holds all three 09E loan-servicing permissions — matches the
/// DB's actual role_permissions grant (ADMIN + TREASURER only; see
/// 20260913092000_create_loan_servicing_schema.sql).
const loanTreasurerPermissions = [
  'group.view',
  'loan_product.view',
  'loan_product.manage',
  'loan.view',
  'loan.create',
  'loan.edit',
  'loan_schedule.view',
  'loan_schedule.generate',
  'loan.submit',
  'loan.cancel',
  'loan.disburse',
  'financial_account.view',
  'loan_penalty.view',
  'loan_penalty.assess',
  'loan.settle_early',
  'loan.prepay_principal',
  'loan.restructure',
];

/// CHAIRPERSON's 09B grants (section 23) — approve/reject/cancel, but
/// deliberately NOT submit/disburse.
const loanChairpersonPermissions = [
  'group.view',
  'loan_product.view',
  'loan.view',
  'loan_schedule.view',
  'loan.approve',
  'loan.reject',
  'loan.cancel',
  'loan_penalty.view',
];

MembershipContext loanMembership({
  List<String> roles = const ['ADMIN'],
  List<String> permissions = loanAdminPermissions,
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
/// [loanRepositoryProvider]/[memberRepositoryProvider] overridden to
/// the supplied fakes, and returns the app's [GoRouter] so tests can
/// jump straight to any loans screen via `.go(path)`/`.push(path)`.
Future<GoRouter> pumpLoansApp(
  WidgetTester tester, {
  required FakeLoanRepository fakeRepo,
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
          profile: const AppUserProfile(id: 'u1', fullName: 'Admin Caller'),
          memberships: [membership ?? loanMembership()],
        ),
      ),
      loanRepositoryProvider.overrideWithValue(fakeRepo),
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
