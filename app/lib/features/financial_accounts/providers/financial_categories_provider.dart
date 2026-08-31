import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/financial_category.dart';
import 'financial_account_repository_provider.dart';

/// Query key for [financialCategoriesProvider].
typedef FinancialCategoriesQuery = ({String? categoryType, bool? isActive});

/// The group's financial categories (Prompt 08B) — never a raw enum
/// list hardcoded in Flutter; the backend is the source of truth for
/// which categories exist. `.autoDispose` for the same freshness
/// reason as every other Prompt 08 list provider.
final financialCategoriesProvider = FutureProvider.autoDispose
    .family<List<FinancialCategory>, FinancialCategoriesQuery>((
      ref,
      query,
    ) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) return const [];

      final repository = ref.watch(financialAccountRepositoryProvider);
      return repository.listFinancialCategories(
        groupId: selectedGroup.membership.group.groupId,
        categoryType: query.categoryType,
        isActive: query.isActive,
      );
    });
