import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/financial_position.dart';
import 'financial_account_repository_provider.dart';

/// Query key for [financialPositionProvider]. `null` bounds are
/// unbounded — any "current month" default lives in the date-range
/// picker UI only, never assumed here or server-side.
typedef FinancialPositionQuery = ({DateTime? dateFrom, DateTime? dateTo});

/// Hali ya Fedha / Financial Position (Prompt 08B) — deliberately NOT a
/// full accounting balance sheet. `.autoDispose` for the same
/// freshness reason as every other Prompt 07/08 report provider.
final financialPositionProvider = FutureProvider.autoDispose
    .family<FinancialPosition, FinancialPositionQuery>((ref, query) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) {
        throw StateError('No resolved group selected');
      }

      final repository = ref.watch(financialAccountRepositoryProvider);
      return repository.getFinancialPosition(
        groupId: selectedGroup.membership.group.groupId,
        dateFrom: query.dateFrom,
        dateTo: query.dateTo,
      );
    });
