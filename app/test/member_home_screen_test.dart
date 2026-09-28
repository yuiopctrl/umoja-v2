import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/app.dart';
import 'package:umoja/core/localization/language_provider.dart';
import 'package:umoja/features/auth/models/app_context.dart';
import 'package:umoja/features/auth/models/app_user_profile.dart';
import 'package:umoja/features/auth/models/group_context.dart';
import 'package:umoja/features/auth/models/membership_context.dart';
import 'package:umoja/features/auth/providers/app_context_provider.dart';
import 'package:umoja/features/auth/providers/auth_session_provider.dart';

import 'fakes/pin_bypass_overrides.dart';

class _FixedLanguage extends LanguageNotifier {
  _FixedLanguage(this._language);

  final AppLanguage _language;

  @override
  AppLanguage build() => _language;
}

/// Prompt 09G-B1-D4 §R items 24-36, 44-46: Member Home content (an
/// ordinary linked member with zero operational permissions) versus
/// the unchanged existing officer/admin dashboard, and dual-role
/// behavior — all rendered from the SAME `/home` route/screen (see
/// `HomeScreen`'s own doc comment for why: no second landing route,
/// no new redirect surface).
MembershipContext _plainMember({
  String id = 'm1',
  String groupName = 'Umoja Wamama',
  String membershipStatus = 'ACTIVE',
}) {
  return MembershipContext(
    membershipId: id,
    group: GroupContext(
      groupId: 'g-$id',
      groupName: groupName,
      groupStatus: 'ACTIVE',
    ),
    membershipStatus: membershipStatus,
    displayName: 'Amina Hassan',
    roleCodes: const ['MEMBER'],
    // A plain MEMBER role: none of HomeScreen's operational
    // permissions (see `_operationalPermissions`) — matches the real
    // role_permissions grants confirmed in 09G-B1-D3's pgTAP suite.
    permissionCodes: const ['group.view'],
  );
}

MembershipContext _officer({
  String id = 'm-officer',
  String groupName = 'Umoja Wamama',
}) {
  return MembershipContext(
    membershipId: id,
    group: GroupContext(
      groupId: 'g-$id',
      groupName: groupName,
      groupStatus: 'ACTIVE',
    ),
    membershipStatus: 'ACTIVE',
    displayName: 'Officer One',
    roleCodes: const ['ADMIN'],
    permissionCodes: const [
      'group.view',
      'member.view',
      'member.claim.approve',
      'contribution.view',
      'payment.view',
      'financial_account.view',
      'loan.view',
    ],
  );
}

Future<void> _pumpHome(
  WidgetTester tester,
  MembershipContext membership, {
  Size viewSize = const Size(390, 844),
}) async {
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...pinBypassOverrides(),
        authSessionStatusProvider.overrideWithValue(AuthSessionStatus.signedIn),
        appContextProvider.overrideWith(
          (ref) async => AppContext(
            userId: 'u1',
            profile: const AppUserProfile(id: 'u1', fullName: 'Amina Hassan'),
            memberships: [membership],
          ),
        ),
        languageProvider.overrideWith(
          () => _FixedLanguage(AppLanguage.english),
        ),
      ],
      child: const UmojaApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Member Home content (§R 24-32)', () {
    testWidgets('24/25/27: shows the member display name, group name, and '
        'membership status from the authoritative context', (tester) async {
      await _pumpHome(tester, _plainMember());

      expect(find.textContaining('Amina'), findsWidgets);
      expect(find.text('Umoja Wamama'), findsWidgets);
      expect(find.text('Member Home'), findsOneWidget);
    });

    testWidgets('29/30/31: no fake future-module cards (Contributions/Loans/'
        'Finance/Payments shortcuts, which a plain member has no '
        'permission for) are rendered', (tester) async {
      await _pumpHome(tester, _plainMember());

      expect(find.byKey(const Key('homeContributionsShortcut')), findsNothing);
      expect(find.byKey(const Key('homeLoansShortcut')), findsNothing);
      expect(find.byKey(const Key('homeFinanceShortcut')), findsNothing);
      expect(find.byKey(const Key('homePaymentsShortcut')), findsNothing);
      expect(find.byKey(const Key('homeMembersShortcut')), findsNothing);
    });

    testWidgets('32: no claimant-onboarding CTA ("Link my membership") once '
        'already linked', (tester) async {
      await _pumpHome(tester, _plainMember());

      expect(find.text('Link My Membership'), findsNothing);
      expect(find.text('Create a new group instead'), findsNothing);
    });

    testWidgets('the real, already-implemented claim-history quick access is '
        'shown and navigates to /membership/claims', (tester) async {
      await _pumpHome(tester, _plainMember());

      final shortcut = find.byKey(const Key('memberHomeClaimHistoryShortcut'));
      expect(shortcut, findsOneWidget);

      await tester.tap(shortcut);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('Dual-role behavior (§R 33-36)', () {
    testWidgets('33/34/35/36: an officer/admin (holds operational permissions, '
        'including member.claim.approve) keeps the existing operational '
        'dashboard — never the Member Home content — using permission '
        'checks, never a role-name comparison', (tester) async {
      await _pumpHome(tester, _officer());

      // "Home" appears twice for an officer: the shell's own bottom-nav
      // tab label (always "Home", regardless of page content) and the
      // page title itself — unlike "Member Home", which only ever
      // appears as the page title.
      expect(find.text('Home'), findsNWidgets(2));
      expect(find.text('Member Home'), findsNothing);
      expect(find.byKey(const Key('homeMembersShortcut')), findsOneWidget);
      expect(
        find.byKey(const Key('homeContributionsShortcut')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('homeLoansShortcut')), findsOneWidget);
      expect(find.byKey(const Key('homeFinanceShortcut')), findsOneWidget);
      expect(find.byKey(const Key('homePaymentsShortcut')), findsOneWidget);
      expect(
        find.byKey(const Key('memberHomeClaimHistoryShortcut')),
        findsNothing,
      );
    });
  });

  group('Responsive (§R 44-46)', () {
    for (final size in [
      const Size(360, 800), // phone portrait
      const Size(1024, 768), // tablet
      const Size(1440, 900), // desktop/web
    ]) {
      testWidgets('44-46: Member Home renders at ${size.width.toInt()}x'
          '${size.height.toInt()} without overflow', (tester) async {
        await _pumpHome(tester, _plainMember(), viewSize: size);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
