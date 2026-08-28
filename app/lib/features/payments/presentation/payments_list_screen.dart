import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/kiswahili_date.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_empty_state.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_list_tile.dart';
import '../../../core/widgets/umoja_loading_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../core/widgets/umoja_search_field.dart';
import '../../../core/widgets/umoja_status_badge.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../domain/payment.dart';
import '../providers/payments_list_provider.dart';
import 'widgets/payment_labels.dart';

const _defaultLimit = 10;

/// `/payments`: group-wide, paginated, searchable payment history
/// (Malipo). Gated by `payment.view` — MEMBER does not hold this
/// permission in this phase (see `docs/product/payments.md`).
class PaymentsListScreen extends ConsumerStatefulWidget {
  const PaymentsListScreen({super.key});

  @override
  ConsumerState<PaymentsListScreen> createState() => _PaymentsListScreenState();
}

class _PaymentsListScreenState extends ConsumerState<PaymentsListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _search = '';
  int _limit = _defaultLimit;

  @override
  void initState() {
    super.initState();
    // Force a refetch on every screen entry — never repeat the 08A
    // stale-cache bug (payment list must refetch on re-entry/resume,
    // no full-restart requirement).
    ref.invalidate(paymentsListProvider);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() {
        _search = value;
        _limit = _defaultLimit;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedGroup = ref.watch(selectedGroupProvider);
    final membership = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership
        : null;
    final canCreate = membership?.hasPermission('payment.create') ?? false;

    final query = (
      search: _search,
      membershipId: null,
      status: null,
      limit: _limit,
    );
    final pageAsync = ref.watch(paymentsListProvider(query));

    return UmojaPage(
      title: l10n.paymentsTitle,
      scrollable: false,
      maxWidth: 900,
      headerTrailing: canCreate
          ? UmojaPrimaryButton(
              label: l10n.recordPaymentAction,
              onPressed: () => context.push(AppRoutes.paymentRecord),
            )
          : null,
      floatingActionButton: canCreate
          ? FloatingActionButton(
              key: const Key('paymentRecordFab'),
              onPressed: () => context.push(AppRoutes.paymentRecord),
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UmojaSearchField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            hintText: l10n.paymentsSearchHint,
          ),
          const SizedBox(height: UmojaSpacing.md),
          Expanded(
            child: pageAsync.when(
              loading: () => const UmojaLoadingState(),
              error: (error, stackTrace) => UmojaErrorState(
                message: l10n.refreshFailedMessage,
                retryLabel: l10n.retryButton,
                onRetry: () => ref.invalidate(paymentsListProvider(query)),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return UmojaEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: l10n.paymentsEmptyTitle,
                    message: l10n.paymentsEmptyMessage,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(paymentsListProvider(query));
                    await ref.read(paymentsListProvider(query).future);
                  },
                  child: ListView.separated(
                    itemCount: page.items.length + (page.hasMore ? 1 : 0),
                    separatorBuilder: (context, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index >= page.items.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: UmojaSpacing.lg,
                          ),
                          child: Center(
                            child: OutlinedButton(
                              onPressed: () =>
                                  setState(() => _limit += _defaultLimit),
                              child: Text(l10n.loadMoreAction),
                            ),
                          ),
                        );
                      }
                      return _PaymentRow(payment: page.items[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return UmojaListTile(
      title: payment.memberDisplayName,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${formatKiswahiliDate(payment.effectiveAt)} · ${paymentMethodLabel(l10n, payment.paymentMethod)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            payment.receiptNumber,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatAmount(payment.amount),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: UmojaSpacing.xs),
          if (payment.isReversed)
            UmojaStatusBadge(
              label: paymentStatusLabel(l10n, payment.status),
              semantic: UmojaStatusSemantic.neutral,
            ),
        ],
      ),
      onTap: () => context.push(AppRoutes.paymentDetailPath(payment.paymentId)),
    );
  }
}
