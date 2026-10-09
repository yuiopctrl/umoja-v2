import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/my_payment.dart';
import 'my_payments_repository_provider.dart';

/// One payment's member-safe detail, for the CURRENTLY SELECTED group
/// (Prompt 09G-B6-C). Keyed by payment id and watching
/// [selectedGroupProvider], so a group switch rebuilds it for the new
/// group and the previous group's detail cannot survive into it. The
/// backend remains the sole authority on ownership — a payment id from
/// another group or another member always resolves to the same
/// not-found outcome here, never a leaked detail.
final myPaymentDetailProvider = FutureProvider.autoDispose
    .family<MyPaymentDetail, String>((ref, paymentId) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) {
        throw StateError('No selected group.');
      }

      final repository = ref.watch(myPaymentsRepositoryProvider);
      return repository.getMyPaymentDetail(
        groupId: selectedGroup.membership.group.groupId,
        paymentId: paymentId,
      );
    });
