import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/kiswahili_date.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_card.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../controllers/financial_entry_reversal_controller.dart';
import '../providers/financial_manual_entry_detail_provider.dart';

/// `/finance/entries/:entryId/reverse` (Prompt 08B, section 13-14):
/// reverse a posted manual income/expense entry. The original entry is
/// never edited — a compensating cashbook entry is posted instead. A
/// wrong entry is corrected by reversing it here, then posting a new,
/// correct one — there is no in-place edit anywhere.
class FinancialEntryReversalScreen extends ConsumerStatefulWidget {
  const FinancialEntryReversalScreen({super.key, required this.entryId});

  final String entryId;

  @override
  ConsumerState<FinancialEntryReversalScreen> createState() =>
      _FinancialEntryReversalScreenState();
}

class _FinancialEntryReversalScreenState
    extends ConsumerState<FinancialEntryReversalScreen> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _confirm(String groupId, String accountId) async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) return;

    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final success = await ref
        .read(financialEntryReversalControllerProvider.notifier)
        .reverse(
          groupId: groupId,
          entryId: widget.entryId,
          financialAccountId: accountId,
          reversalReason: reason,
        );
    if (success && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.entryReversalSuccessMessage)),
      );
      context.go(AppRoutes.financialAccountDetailPath(accountId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedGroup = ref.watch(selectedGroupProvider);
    final groupId = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership.group.groupId
        : null;
    final detailAsync = ref.watch(
      financialManualEntryDetailProvider(widget.entryId),
    );
    final reversalState = ref.watch(financialEntryReversalControllerProvider);

    return UmojaPage(
      title: l10n.entryReversalTitle,
      maxWidth: 600,
      body: detailAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 64),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => UmojaErrorState(
          message: l10n.refreshFailedMessage,
          retryLabel: l10n.retryButton,
          onRetry: () => ref.invalidate(
            financialManualEntryDetailProvider(widget.entryId),
          ),
        ),
        data: (detail) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UmojaCard(
              padding: const EdgeInsets.all(UmojaSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.categoryName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${formatKiswahiliDate(detail.effectiveAt)} · '
                    '${formatAmount(detail.amount)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (detail.isReversed) ...[
                    const SizedBox(height: UmojaSpacing.sm),
                    Text(
                      l10n.entryAlreadyReversedMessage,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!detail.isReversed) ...[
              const SizedBox(height: UmojaSpacing.lg),
              TextField(
                key: const Key('entryReversalReasonField'),
                controller: _reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.reversalReasonLabel,
                ),
              ),
              if (reversalState.errorType != null) ...[
                const SizedBox(height: UmojaSpacing.sm),
                Text(
                  financialAccountFailureMessage(
                    l10n,
                    reversalState.errorType!,
                  ),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: UmojaSpacing.xxl),
              UmojaDangerButton(
                key: const Key('entryReversalConfirmAction'),
                label: l10n.entryReversalConfirmAction,
                expand: true,
                isLoading: reversalState.isSubmitting,
                onPressed: groupId == null
                    ? null
                    : () => _confirm(groupId, detail.financialAccountId),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
