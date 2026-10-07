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
import 'package:umoja/features/member_loans/data/member_loans_repository.dart';
import 'package:umoja/features/member_loans/domain/member_loan.dart';
import 'package:umoja/features/member_loans/providers/member_loans_repository_provider.dart';

import 'fake_member_loans_repository.dart';
import 'member_loans_test_app.dart';
import 'pin_bypass_overrides.dart';

/// Routes each call to the fake for its selected group, so two groups can
/// return different data even for the same loan id. That is the exact
/// condition a stale cached provider would expose.
class GroupScopedMemberLoansRepository implements MemberLoansRepository {
  GroupScopedMemberLoansRepository(this.byGroup);

  final Map<String, FakeMemberLoansRepository> byGroup;

  /// Every (group, call) pair in order, for isolation assertions.
  final List<String> trace = [];

  FakeMemberLoansRepository _forGroup(String groupId) {
    trace.add(groupId);
    final repo = byGroup[groupId];
    if (repo == null) {
      throw StateError('no fixture for group $groupId');
    }
    return repo;
  }

  @override
  Future<MemberLoansPage> getMyLoans({
    required String groupId,
    required int limit,
    required int offset,
  }) =>
      _forGroup(groupId)
          .getMyLoans(groupId: groupId, limit: limit, offset: offset);

  @override
  Future<MemberLoanDetail> getMyLoanDetail({
    required String groupId,
    required String loanAccountId,
  }) =>
      _forGroup(groupId)
          .getMyLoanDetail(groupId: groupId, loanAccountId: loanAccountId);

  @override
  Future<MemberLoanSchedule> getMyLoanSchedule({
    required String groupId,
    required String loanAccountId,
  }) =>
      _forGroup(groupId)
          .getMyLoanSchedule(groupId: groupId, loanAccountId: loanAccountId);

  @override
  Future<MemberLoanTimelinePage> getMyLoanTimeline({
    required String groupId,
    required String loanAccountId,
    required int limit,
    required int offset,
  }) => _forGroup(groupId).getMyLoanTimeline(
    groupId: groupId,
    loanAccountId: loanAccountId,
    limit: limit,
    offset: offset,
  );
}

MembershipContext memberLoansGroupMembership({
  required String membershipId,
  required String groupId,
  required String groupName,
}) {
  return MembershipContext(
    membershipId: membershipId,
    group: GroupContext(
      groupId: groupId,
      groupName: groupName,
      groupStatus: 'ACTIVE',
    ),
    membershipStatus: 'ACTIVE',
    displayName: 'Member Caller',
    roleCodes: const ['MEMBER'],
    permissionCodes: memberBaselinePermissions,
  );
}

/// Pumps the app signed in to several groups. Returns the container so a
/// test can switch the selected group through the real notifier.
Future<ProviderContainer> pumpMemberLoansMultiGroup(
  WidgetTester tester, {
  required MemberLoansRepository repository,
  required List<MembershipContext> memberships,
  AppLanguage language = AppLanguage.english,
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
          memberships: memberships,
        ),
      ),
      memberLoansRepositoryProvider.overrideWithValue(repository),
      languageProvider.overrideWith(() => FixedLanguageForLoans(language)),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const UmojaApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

class FixedLanguageForLoans extends LanguageNotifier {
  FixedLanguageForLoans(this._language);

  final AppLanguage _language;

  @override
  AppLanguage build() => _language;
}
