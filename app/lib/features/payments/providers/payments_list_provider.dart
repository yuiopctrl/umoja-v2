import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/payment_page.dart';
import 'payment_repository_provider.dart';

/// Query key for [paymentsListProvider] — the owning screen holds its
/// own search/pagination/filter state locally, matching the
/// contributions charges-list precedent.
typedef PaymentsQuery = ({
  String search,
  String? membershipId,
  String? status,
  int limit,
});

/// `.autoDispose`: once no screen is watching this query anymore, its
/// cached result is discarded, so re-entering the payments list
/// re-fetches rather than resurfacing a stale snapshot — the exact
/// staleness class of bug fixed for Financial Accounts in 08A-UAT-FIX-01.
/// Screens additionally force-invalidate this on `initState`.
final paymentsListProvider = FutureProvider.autoDispose
    .family<PaymentPage, PaymentsQuery>((ref, query) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) return PaymentPage.empty;

      final repository = ref.watch(paymentRepositoryProvider);
      return repository.listPayments(
        groupId: selectedGroup.membership.group.groupId,
        membershipId: query.membershipId,
        status: query.status,
        search: query.search,
        limit: query.limit,
      );
    });
