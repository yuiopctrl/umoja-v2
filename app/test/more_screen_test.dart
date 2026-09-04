import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/app.dart';
import 'package:umoja/features/auth/models/app_context.dart';
import 'package:umoja/features/auth/models/app_user_profile.dart';
import 'package:umoja/features/auth/models/group_context.dart';
import 'package:umoja/features/auth/models/membership_context.dart';
import 'package:umoja/features/auth/providers/app_context_provider.dart';
import 'package:umoja/features/auth/providers/auth_session_provider.dart';
import 'package:umoja/features/members/providers/member_repository_provider.dart';

import 'fakes/pin_bypass_overrides.dart';
import 'fakes/fake_member_repository.dart';

Future<void> _pumpMoreScreen(
  WidgetTester tester, {
  List<String> roleCodes = const ['ADMIN'],
}) async {
  tester.view.physicalSize = const Size(390, 844);
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
            profile: const AppUserProfile(
              id: 'u1',
              fullName: 'Fredrick Mrema',
              phone: '+255712345678',
            ),
            memberships: [
              MembershipContext(
                membershipId: 'm-admin',
                group: const GroupContext(
                  groupId: 'g1',
                  groupName: 'Umoja Wamama',
                  groupStatus: 'ACTIVE',
                ),
                membershipStatus: 'ACTIVE',
                displayName: 'Fredrick Mrema',
                roleCodes: roleCodes,
                permissionCodes: const [
                  'member.view',
                  'member.create',
                  'member.edit',
                  'member.change_status',
                  'role.view',
                  'role.assign',
                ],
              ),
            ],
          ),
        ),
        memberRepositoryProvider.overrideWithValue(FakeMemberRepository()),
      ],
      child: const UmojaApp(),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Zaidi'),
    ),
  );
  await tester.pumpAndSettle();

  // "Zaidi" opens a modal listing modules plus an "Akaunti" entry —
  // account info/current group/language/Sign Out now live inside that
  // account sheet, not directly in the top-level More sheet.
  await tester.tap(find.byKey(const Key('moreSheetAccount')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('More shows account info, current group, and the Toka action', (
    tester,
  ) async {
    await _pumpMoreScreen(tester);

    expect(find.text('Fredrick Mrema'), findsWidgets);
    expect(find.text('+255712345678'), findsOneWidget);
    // Also shown in the persistent top bar's title behind the sheet.
    expect(find.text('Umoja Wamama'), findsWidgets);
    // Prompt 05C §2: exactly one normal exit action, labeled "Toka" —
    // never "Funga programu"/"Toka kabisa" terminology.
    expect(find.text('Toka'), findsOneWidget);
    expect(find.text('Funga programu'), findsNothing);
    expect(find.text('Toka kabisa'), findsNothing);
  });

  testWidgets('More never shows a raw permission count or auth internals', (
    tester,
  ) async {
    await _pumpMoreScreen(tester);

    expect(find.textContaining('Permissions:'), findsNothing);
    expect(find.textContaining('u1'), findsNothing);
    expect(find.textContaining('m-admin'), findsNothing);
  });

  testWidgets(
    'More does not show a switch-group action with only one eligible group',
    (tester) async {
      await _pumpMoreScreen(tester);

      expect(find.text('Badili Kikundi'), findsNothing);
    },
  );
}
