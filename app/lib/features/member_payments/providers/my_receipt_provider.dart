import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/my_payment.dart';
import 'my_payments_repository_provider.dart';

/// One payment's member-safe receipt, for the CURRENTLY SELECTED group
/// (Prompt 09G-B6-C §W). Backed only by `rpc_get_my_receipt` — never the
/// officer `rpc_get_receipt`, never `payment.receipt.view`. Keyed by
/// payment id and watching [selectedGroupProvider], same group-isolation
/// treatment as [myPaymentDetailProvider].
final myReceiptProvider = FutureProvider.autoDispose.family<MyReceipt, String>((
  ref,
  paymentId,
) async {
  final selectedGroup = ref.watch(selectedGroupProvider);
  if (selectedGroup is! SelectedGroupResolved) {
    throw StateError('No selected group.');
  }

  final repository = ref.watch(myPaymentsRepositoryProvider);
  return repository.getMyReceipt(
    groupId: selectedGroup.membership.group.groupId,
    paymentId: paymentId,
  );
});
