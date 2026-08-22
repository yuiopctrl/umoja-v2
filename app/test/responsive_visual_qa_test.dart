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
import 'package:umoja/features/members/domain/group_member.dart';
import 'package:umoja/features/members/domain/group_member_page.dart';
import 'package:umoja/features/members/providers/member_repository_provider.dart';

import 'fakes/pin_bypass_overrides.dart';
import 'fakes/fake_member_repository.dart';

/// No visual/screenshot tooling is available in this environment, so
/// this file operationalizes prompt 05 §46's "manually inspect at
/// representative widths" requirement as automated overflow detection
/// instead: `flutter test` already fails a test when a widget throws
/// during build/layout (a `RenderFlex overflowed` error included), so
/// pumping every redesigned screen at each representative width and
/// asserting no exception was thrown is a faithful, repeatable stand-in
/// for a manual look.
const _widths = [360.0, 390.0, 600.0, 800.0, 1200.0, 1440.0];
const _height = 800.0;

MembershipContext _membership() {
  return const MembershipContext(
    membershipId: 'm-admin',
    group: GroupContext(
      groupId: 'g1',
      groupName: 'Umoja Wamama Wanavikundi',
      groupStatus: 'ACTIVE',
    ),
    membershipStatus: 'ACTIVE',
    displayName: 'Admin Caller',
    roleCodes: ['ADMIN'],
    permissionCodes: [
      'member.view',
      'member.create',
      'member.edit',
      'member.change_status',
      'role.view',
      'role.assign',
    ],
  );
}

GroupMember _member() {
  return GroupMember(
    membershipId: 'mem-1',
    groupId: 'g1',
    displayName: 'Fredrick Mrema Mwanachama',
    memberNumber: 'M-001',
    phone: '+255712345678',
    status: 'ACTIVE',
    createdAt: DateTime.utc(2026, 1, 15),
    joinedAt: DateTime.utc(2026, 1, 15),
    isLoginLinked: false,
    roleCodes: const ['ADMIN', 'TREASURER'],
  );
}

Future<void> _pumpAt(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, _height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final fakeRepo = FakeMemberRepository()
    ..nextListResult = GroupMemberPage(
      items: [_member()],
      totalCount: 1,
      limit: 25,
      offset: 0,
    )
    ..nextMemberResult = _member();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...pinBypassOverrides(),
        authSessionStatusProvider.overrideWithValue(AuthSessionStatus.signedIn),
        appContextProvider.overrideWith(
          (ref) async => AppContext(
            userId: 'u1',
            profile: const AppUserProfile(id: 'u1', fullName: 'Fredrick Mrema'),
            memberships: [_membership()],
          ),
        ),
        memberRepositoryProvider.overrideWithValue(fakeRepo),
      ],
      child: const UmojaApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final width in _widths) {
    testWidgets('Home renders without overflow at ${width.toInt()}px', (
      tester,
    ) async {
      await _pumpAt(tester, width);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Members list renders without overflow at ${width.toInt()}px', (
      tester,
    ) async {
      await _pumpAt(tester, width);
      await tester.tap(find.byKey(const Key('homeMembersShortcut')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Member detail renders without overflow at ${width.toInt()}px',
      (tester) async {
        await _pumpAt(tester, width);
        await tester.tap(find.byKey(const Key('homeMembersShortcut')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Fredrick Mrema Mwanachama'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Member create form renders without overflow at ${width.toInt()}px',
      (tester) async {
        await _pumpAt(tester, width);
        await tester.tap(find.byKey(const Key('homeMembersShortcut')));
        await tester.pumpAndSettle();
        // Desktop/tablet exposes the add action in the page header instead
        // of a FAB; find whichever is present.
        final headerButton = find.text('Ongeza Mwanachama');
        await tester.tap(headerButton.first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('More renders without overflow at ${width.toInt()}px', (
      tester,
    ) async {
      await _pumpAt(tester, width);
      final navBarMore = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Zaidi'),
      );
      if (navBarMore.evaluate().isNotEmpty) {
        await tester.tap(navBarMore);
      } else {
        await tester.tap(find.text('Zaidi').first);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
