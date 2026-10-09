import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/my_payment.dart';
import 'my_payments_query_provider.dart';
import 'my_payments_repository_provider.dart';

/// The caller's own EXTERNAL payments for the CURRENTLY SELECTED group
/// (Prompt 09G-B6-C). Watches [selectedGroupProvider] directly, so a
/// group switch always refetches for the new group and can never show
/// the previous group's rows. Also watches [myPaymentsQueryProvider],
/// so changing a filter or page size refetches naturally. A wallet
/// application (payment_id IS NULL) has no `payments` row at all, so it
/// can never appear here — this provider only ever reflects what the
/// backend's `rpc_get_my_payments` itself returns.
final myPaymentsProvider = FutureProvider.autoDispose<MyPaymentsPage>((
  ref,
) async {
  final selectedGroup = ref.watch(selectedGroupProvider);
  if (selectedGroup is! SelectedGroupResolved) {
    // Only reachable through the guarded route, which requires a
    // resolved group — a transient fallback, not a real state.
    throw StateError('No selected group.');
  }

  final query = ref.watch(myPaymentsQueryProvider);
  final repository = ref.watch(myPaymentsRepositoryProvider);

  return repository.getMyPayments(
    groupId: selectedGroup.membership.group.groupId,
    status: query.status,
    fromDate: query.fromDate,
    toDate: query.toDate,
    limit: query.limit,
    offset: 0,
  );
});
