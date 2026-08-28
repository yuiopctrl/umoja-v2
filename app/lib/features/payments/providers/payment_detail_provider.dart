import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/payment_detail.dart';
import 'payment_repository_provider.dart';

/// `.autoDispose`, keyed by paymentId — matches the financial account
/// detail provider's freshness convention.
final paymentDetailProvider = FutureProvider.autoDispose
    .family<PaymentDetail, String>((ref, paymentId) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) {
        throw StateError('No resolved group selected');
      }

      final repository = ref.watch(paymentRepositoryProvider);
      return repository.getPaymentDetail(
        groupId: selectedGroup.membership.group.groupId,
        paymentId: paymentId,
      );
    });
