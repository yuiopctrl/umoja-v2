import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/amount_input_formatter.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../core/widgets/umoja_search_field.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../controllers/contribution_period_member_amount_controller.dart';
import '../data/contribution_member_amount_input.dart';
import '../providers/contribution_period_open_preview_provider.dart';

/// `/contributions/periods/:periodId/amounts`: the custom per-member
/// amount editor — DRAFT/SCHEDULED + CUSTOM_PER_MEMBER periods only.
/// Uses the eligible-members list from
/// `rpc_preview_contribution_period_open()` (the only server list that
/// already carries each eligible member's currently-configured amount)
/// rather than a separate, paginated members fetch — the eligible
/// roster for one period is expected to be small enough to edit inline
/// in one screen. Every edited row batches into one
/// `rpc_set_contribution_period_member_amounts` call.
class ContributionPeriodAmountsScreen extends ConsumerStatefulWidget {
  const ContributionPeriodAmountsScreen({super.key, required this.periodId});

  final String periodId;

  @override
  ConsumerState<ContributionPeriodAmountsScreen> createState() =>
      _ContributionPeriodAmountsScreenState();
}

class _ContributionPeriodAmountsScreenState
    extends ConsumerState<ContributionPeriodAmountsScreen> {
  final _searchController = TextEditingController();
  final Map<String, TextEditingController> _amountControllers = {};
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    for (final controller in _amountControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String membershipId, double? initial) {
    return _amountControllers.putIfAbsent(
      membershipId,
      () => TextEditingController(
        text: initial == null ? '' : formatAmount(initial),
      ),
    );
  }

  Future<void> _save(String groupId) async {
    final amounts = _amountControllers.entries
        .map(
          (entry) => ContributionMemberAmountInput(
            membershipId: entry.key,
            amount: parseAmountInput(entry.value.text),
          ),
        )
        .toList(growable: false);

    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final success = await ref
        .read(contributionPeriodMemberAmountControllerProvider.notifier)
        .setAmounts(
          groupId: groupId,
          periodId: widget.periodId,
          amounts: amounts,
        );
    if (success && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.customAmountSavedMessage)),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewAsync = ref.watch(
      contributionPeriodOpenPreviewProvider(widget.periodId),
    );
    final selectedGroup = ref.watch(selectedGroupProvider);
    final formState = ref.watch(
      contributionPeriodMemberAmountControllerProvider,
    );
    final l10n = context.l10n;
    final groupId = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership.group.groupId
        : null;

    return UmojaPage(
      title: l10n.customAmountEditorTitle,
      maxWidth: 700,
      scrollable: false,
      backTo: AppRoutes.contributionPeriodDetailPath(widget.periodId),
      backLabel: l10n.contributionPeriodDetailTitle,
      body: previewAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => UmojaErrorState(
          message: l10n.refreshFailedMessage,
          retryLabel: l10n.retryButton,
          onRetry: () => ref.invalidate(
            contributionPeriodOpenPreviewProvider(widget.periodId),
          ),
        ),
        data: (preview) {
          final query = _search.trim().toLowerCase();
          final members = preview.eligibleMembers
              .where(
                (m) =>
                    query.isEmpty ||
                    m.displayName.toLowerCase().contains(query) ||
                    (m.memberNumber?.toLowerCase().contains(query) ?? false),
              )
              .toList(growable: false);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UmojaSearchField(
                controller: _searchController,
                hintText: l10n.customAmountSearchHint,
                onChanged: (value) => setState(() => _search = value),
              ),
              const SizedBox(height: UmojaSpacing.md),
              Expanded(
                child: ListView.separated(
                  itemCount: members.length,
                  separatorBuilder: (context, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final controller = _controllerFor(
                      member.membershipId,
                      member.amount,
                    );
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: UmojaSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(member.displayName)),
                          const SizedBox(width: UmojaSpacing.md),
                          SizedBox(
                            width: 140,
                            child: TextField(
                              controller: controller,
                              enabled: !formState.isSubmitting,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: const [
                                ThousandsInputFormatter(),
                              ],
                              decoration: InputDecoration(
                                labelText: l10n.customAmountFieldLabel,
                                hintText: controller.text.isEmpty
                                    ? l10n.customAmountMissingBadge
                                    : null,
                                isDense: true,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (formState.errorType != null) ...[
                const SizedBox(height: UmojaSpacing.sm),
                Text(
                  contributionFailureMessage(l10n, formState.errorType!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: UmojaSpacing.md),
              UmojaPrimaryButton(
                label: l10n.customAmountSaveAction,
                expand: true,
                isLoading: formState.isSubmitting,
                onPressed: groupId == null ? null : () => _save(groupId),
              ),
            ],
          );
        },
      ),
    );
  }
}
