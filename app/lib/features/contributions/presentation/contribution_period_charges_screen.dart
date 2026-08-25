import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/kiswahili_date.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/umoja_empty_state.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_list_tile.dart';
import '../../../core/widgets/umoja_loading_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../core/widgets/umoja_search_field.dart';
import '../domain/member_contribution_charge.dart';
import '../providers/contribution_period_charges_provider.dart';

const _defaultLimit = 10;

/// `/contributions/periods/:periodId/charges`: posted member
/// contribution charges for an OPEN/CLOSED period — member, member
/// number, base amount ("Kiasi Kilichowekwa"), due date. Deliberately
/// shows no paid/unpaid/balance status anywhere: there is no payments
/// module yet (see docs/accounting/invariants.md).
class ContributionPeriodChargesScreen extends ConsumerStatefulWidget {
  const ContributionPeriodChargesScreen({super.key, required this.periodId});

  final String periodId;

  @override
  ConsumerState<ContributionPeriodChargesScreen> createState() =>
      _ContributionPeriodChargesScreenState();
}

class _ContributionPeriodChargesScreenState
    extends ConsumerState<ContributionPeriodChargesScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _search = '';
  int _limit = _defaultLimit;

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
    final query = (periodId: widget.periodId, search: _search, limit: _limit);
    final chargesAsync = ref.watch(contributionPeriodChargesProvider(query));
    final l10n = context.l10n;

    return UmojaPage(
      title: l10n.chargesListTitle,
      scrollable: false,
      maxWidth: 900,
      backTo: AppRoutes.contributionPeriodDetailPath(widget.periodId),
      backLabel: l10n.contributionPeriodDetailTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UmojaSearchField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            hintText: l10n.chargesSearchHint,
          ),
          const SizedBox(height: UmojaSpacing.md),
          Expanded(
            child: chargesAsync.when(
              loading: () => const UmojaLoadingState(),
              error: (error, stackTrace) => UmojaErrorState(
                message: l10n.refreshFailedMessage,
                retryLabel: l10n.retryButton,
                onRetry: () =>
                    ref.invalidate(contributionPeriodChargesProvider(query)),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return UmojaEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: l10n.chargesEmptyTitle,
                    message: l10n.chargesEmptyMessage,
                  );
                }
                return ListView.separated(
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
                    return _ChargeRow(charge: page.items[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChargeRow extends StatelessWidget {
  const _ChargeRow({required this.charge});

  final MemberContributionCharge charge;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return UmojaListTile(
      title: charge.memberNameSnapshot,
      subtitle: Text(
        '${charge.memberNumberSnapshot} · '
        '${l10n.contributionDueDateLabel}: ${formatKiswahiliDate(charge.dueDate)}',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      // Prompt 06B: only shown once a penalty has actually been posted
      // for this charge — a charge with no penalty just shows its base
      // amount, exactly like before 06B existed.
      trailing: charge.penaltyCount > 0
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatAmount(charge.totalAmount),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '${l10n.chargePenaltyAmountLabel}: '
                  '${formatAmount(charge.penaltyAmount)}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
              ],
            )
          : Text(
              formatAmount(charge.baseAmount),
              style: Theme.of(context).textTheme.titleSmall,
            ),
    );
  }
}
