import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/loan_product.dart';
import 'loan_repository_provider.dart';

/// A single loan product's detail. `.family` keyed on productId.
/// `.autoDispose` so leaving the detail/edit screen and returning
/// later refetches rather than showing a stale snapshot.
final loanProductDetailProvider = FutureProvider.autoDispose
    .family<LoanProduct, String>((ref, productId) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) {
        throw StateError('No resolved group context.');
      }

      final repository = ref.watch(loanRepositoryProvider);
      return repository.getLoanProduct(
        groupId: selectedGroup.membership.group.groupId,
        productId: productId,
      );
    });
