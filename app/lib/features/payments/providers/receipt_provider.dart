import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/receipt.dart';
import 'payment_repository_provider.dart';

final receiptProvider = FutureProvider.autoDispose.family<Receipt, String>((
  ref,
  paymentId,
) async {
  final selectedGroup = ref.watch(selectedGroupProvider);
  if (selectedGroup is! SelectedGroupResolved) {
    throw StateError('No resolved group selected');
  }

  final repository = ref.watch(paymentRepositoryProvider);
  return repository.getReceipt(
    groupId: selectedGroup.membership.group.groupId,
    paymentId: paymentId,
  );
});
