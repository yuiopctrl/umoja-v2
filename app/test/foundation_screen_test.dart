import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/app/app.dart';
import 'package:umoja/features/auth/models/app_context.dart';
import 'package:umoja/features/auth/models/app_user_profile.dart';
import 'package:umoja/features/auth/models/group_context.dart';
import 'package:umoja/features/auth/models/membership_context.dart';
import 'package:umoja/features/auth/providers/app_context_provider.dart';
import 'package:umoja/features/auth/providers/auth_session_provider.dart';

MembershipContext _membership(String id, String groupName) {
  return MembershipContext(
    membershipId: id,
    group: GroupContext(
      groupId: 'group-$id',
      groupName: groupName,
      groupStatus: 'ACTIVE',
    ),
    membershipStatus: 'ACTIVE',
    displayName: 'Test Member',
    roleCodes: const ['ADMIN'],
    permissionCodes: const ['group.view', 'member.view'],
  );
}

void main() {
  testWidgets(
    'shows a configuration-missing warning when Supabase is not configured',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionStatusProvider.overrideWithValue(
              AuthSessionStatus.configMissing,
            ),
          ],
          child: const UmojaApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Umoja v2'), findsOneWidget);
      expect(
        find.textContaining('Supabase configuration missing'),
        findsOneWidget,
      );
    },
  );

  testWidgets('shows a not-signed-in state when configured but signed out', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionStatusProvider.overrideWithValue(
            AuthSessionStatus.signedOut,
          ),
        ],
        child: const UmojaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not signed in'), findsOneWidget);
  });

  testWidgets(
    'shows "no group membership found" when signed in with zero memberships',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionStatusProvider.overrideWithValue(
              AuthSessionStatus.signedIn,
            ),
            appContextProvider.overrideWith(
              (ref) async => const AppContext(
                userId: 'u1',
                profile: AppUserProfile(id: 'u1', fullName: 'Amina'),
                memberships: [],
              ),
            ),
          ],
          child: const UmojaApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Signed in as Amina'), findsOneWidget);
      expect(find.text('No group membership found'), findsOneWidget);
    },
  );

  testWidgets(
    'auto-selects and shows the group when signed in with exactly one membership',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionStatusProvider.overrideWithValue(
              AuthSessionStatus.signedIn,
            ),
            appContextProvider.overrideWith(
              (ref) async => AppContext(
                userId: 'u1',
                profile: const AppUserProfile(id: 'u1', fullName: 'Amina'),
                memberships: [_membership('m1', 'Umoja Wamama')],
              ),
            ),
          ],
          child: const UmojaApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Group: Umoja Wamama'), findsOneWidget);
      expect(find.text('Foundation ready'), findsOneWidget);
      // A single membership must be auto-selected, not presented as a choice.
      expect(find.text('Select a group:'), findsNothing);
    },
  );

  testWidgets('requires selection when signed in with multiple memberships', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionStatusProvider.overrideWithValue(
            AuthSessionStatus.signedIn,
          ),
          appContextProvider.overrideWith(
            (ref) async => AppContext(
              userId: 'u1',
              profile: const AppUserProfile(id: 'u1', fullName: 'Amina'),
              memberships: [
                _membership('m1', 'Umoja Wamama'),
                _membership('m2', 'Umoja Vijana'),
              ],
            ),
          ),
        ],
        child: const UmojaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Select a group:'), findsOneWidget);
    expect(find.text('Umoja Wamama'), findsOneWidget);
    expect(find.text('Umoja Vijana'), findsOneWidget);
    expect(find.text('Foundation ready'), findsNothing);
  });
}
