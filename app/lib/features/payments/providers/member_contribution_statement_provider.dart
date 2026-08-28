import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/member_contribution_statement.dart';
import 'payment_repository_provider.dart';

/// The authoritative "before payment" summary (UAT-FIX-01) — member
/// identity, total outstanding debt, wallet balance, and the specific
/// obligations making up that debt. `.autoDispose`, keyed by
/// membershipId — matches every other Prompt 07 detail provider's
/// freshness convention (re-entering the record-payment flow for the
/// same member later must never show a stale snapshot).
final memberContributionStatementProvider = FutureProvider.autoDispose
    .family<MemberContributionStatement, String>((ref, membershipId) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) {
        throw StateError('No resolved group selected');
      }

      final repository = ref.watch(paymentRepositoryProvider);
      return repository.getMemberContributionStatement(
        groupId: selectedGroup.membership.group.groupId,
        membershipId: membershipId,
      );
    });
