import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/widgets/umoja_empty_state.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_loading_state.dart';
import '../../../app/shell/member_child_scaffold.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../domain/member_loan.dart';
import '../providers/member_loan_providers.dart';
import 'widgets/member_loan_card.dart';
import 'widgets/member_loan_messages.dart';

/// `/me/loans`: the caller's OWN loan accounts in the selected group.
/// Backed only by rpc_get_my_loans. Each loan is an independent account, so
/// there is no portfolio total here. Gated on loan.self_view by the route
/// guard (UX only). The backend enforces ownership.
class MyLoansScreen extends ConsumerWidget {
  const MyLoansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selectedGroup = ref.watch(selectedGroupProvider);
    final groupId = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership.group.groupId
        : null;

    return MemberChildScaffold(
      title: l10n.myLoansTitle,
      scrollable: false,
      body: groupId == null
          ? const UmojaLoadingState()
          // Keyed by group: a group switch discards every page accumulated
          // for the previous group, so no stale list can survive.
          : _MyLoansPages(key: ValueKey('myLoans_$groupId'), groupId: groupId),
    );
  }
}

class _MyLoansPages extends ConsumerStatefulWidget {
  const _MyLoansPages({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<_MyLoansPages> createState() => _MyLoansPagesState();
}

class _MyLoansPagesState extends ConsumerState<_MyLoansPages> {
  /// Offsets of the pages loaded so far. Starts with the first page only.
  final List<int> _offsets = [0];

  void _loadMore(MemberLoansPage lastPage) {
    setState(() {
      _offsets.add(lastPage.pagination.offset + lastPage.pagination.limit);
    });
  }

  Future<void> _refresh() async {
    for (final offset in _offsets) {
      ref.invalidate(
        memberLoansPageProvider((groupId: widget.groupId, offset: offset)),
      );
    }
    await ref.read(
      memberLoansPageProvider((groupId: widget.groupId, offset: 0)).future,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = <MemberLoanListItem>[];
    MemberLoansPage? lastPage;
    Object? firstError;

    for (final offset in _offsets) {
      final pageAsync = ref.watch(
        memberLoansPageProvider((groupId: widget.groupId, offset: offset)),
      );
      final page = pageAsync.value;
      if (page != null) {
        items.addAll(page.items);
        lastPage = page;
      } else if (pageAsync.hasError && offset == 0) {
        firstError = pageAsync.error;
      }
    }

    if (firstError != null) {
      return UmojaErrorState(
        message: memberLoansFailureMessage(
          l10n,
          firstError,
          isLoanScoped: false,
        ),
        retryLabel: l10n.retryButton,
        onRetry: () => ref.invalidate(
          memberLoansPageProvider((groupId: widget.groupId, offset: 0)),
        ),
      );
    }

    // The first page is still loading.
    if (lastPage == null) {
      return const UmojaLoadingState();
    }

    if (items.isEmpty) {
      return UmojaEmptyState(
        key: const Key('myLoansEmpty'),
        icon: Icons.account_balance_wallet_outlined,
        title: l10n.myLoansEmptyTitle,
      );
    }

    final lastOffset = _offsets.last;
    final lastPageAsync = ref.watch(
      memberLoansPageProvider((groupId: widget.groupId, offset: lastOffset)),
    );

    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: UmojaSpacing.xxl),
        child: Column(
          key: const Key('myLoansList'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in items) ...[
              MemberLoanCard(
                item: item,
                onTap: () => context.push(
                  AppRoutes.myLoanDetailPath(item.loanAccountId),
                ),
              ),
              const SizedBox(height: UmojaSpacing.md),
            ],
            if (lastPageAsync.hasError)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: UmojaSpacing.sm),
                child: Text(
                  l10n.myLoansLoadMoreFailedMessage,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (lastPage.pagination.hasMore && !lastPageAsync.isLoading)
              Center(
                child: OutlinedButton(
                  key: const Key('myLoansLoadMoreAction'),
                  onPressed: () => _loadMore(lastPage!),
                  child: Text(l10n.loadMoreAction),
                ),
              ),
            if (lastPageAsync.isLoading)
              const Padding(
                padding: EdgeInsets.all(UmojaSpacing.lg),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
          ],
        ),
      ),
    );
  }
}
