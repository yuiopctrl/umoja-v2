import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/kiswahili_date.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/umoja_card.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../core/widgets/umoja_section.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../domain/contribution_charge_component.dart';
import '../domain/contribution_charge_detail.dart';
import '../providers/contribution_charge_detail_provider.dart';
import 'widgets/contribution_component_labels.dart';

/// `/contributions/charges/:chargeId`: full per-component breakdown for
/// one charge — Base/Penalty/Adjustment/Waiver/Opening Balance/Net
/// Assessed, plus Add Adjustment/Waive Obligation actions gated by
/// permission (Prompt 06C). No raw enum names shown anywhere.
class ContributionChargeDetailScreen extends ConsumerWidget {
  const ContributionChargeDetailScreen({super.key, required this.chargeId});

  final String chargeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(contributionChargeDetailProvider(chargeId));
    final selectedGroup = ref.watch(selectedGroupProvider);
    final l10n = context.l10n;

    final membership = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership
        : null;

    return UmojaPage(
      title: l10n.chargeDetailTitle,
      maxWidth: 700,
      body: detailAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 64),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => UmojaErrorState(
          message: l10n.refreshFailedMessage,
          retryLabel: l10n.retryButton,
          onRetry: () =>
              ref.invalidate(contributionChargeDetailProvider(chargeId)),
        ),
        data: (detail) => _ChargeDetailBody(
          detail: detail,
          groupId: membership?.group.groupId,
          canAdjust:
              membership?.hasPermission('contribution.adjustment.create') ??
              false,
          canWaive:
              membership?.hasPermission('contribution.waiver.create') ?? false,
        ),
      ),
    );
  }
}

class _ChargeDetailBody extends StatelessWidget {
  const _ChargeDetailBody({
    required this.detail,
    required this.groupId,
    required this.canAdjust,
    required this.canWaive,
  });

  final ContributionChargeDetail detail;
  final String? groupId;
  final bool canAdjust;
  final bool canWaive;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          detail.memberNameSnapshot,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(
          detail.memberNumberSnapshot,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: UmojaSpacing.xxl),
        UmojaCard(
          padding: const EdgeInsets.symmetric(
            horizontal: UmojaSpacing.lg,
            vertical: UmojaSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UmojaSection(
                title: l10n.sectionChargeBreakdown,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final component in detail.components)
                      _ComponentRow(component: component),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: UmojaSpacing.sm),
                      child: Divider(height: 1),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            l10n.contributionNetAssessedLabel,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          formatAmount(detail.netAssessed),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (canAdjust || canWaive) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: UmojaSpacing.lg),
                  child: Divider(height: 1),
                ),
                UmojaSection(
                  title: l10n.sectionActions,
                  child: Wrap(
                    spacing: UmojaSpacing.md,
                    runSpacing: UmojaSpacing.md,
                    children: [
                      if (canAdjust)
                        OutlinedButton.icon(
                          onPressed: () => context.push(
                            AppRoutes.contributionChargeAdjustPath(
                              detail.chargeId,
                            ),
                          ),
                          icon: const Icon(Icons.exposure_outlined, size: 18),
                          label: Text(l10n.addAdjustmentAction),
                        ),
                      if (canWaive)
                        OutlinedButton.icon(
                          onPressed: () => context.push(
                            AppRoutes.contributionChargeWaivePath(
                              detail.chargeId,
                            ),
                          ),
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            size: 18,
                          ),
                          label: Text(l10n.waiveObligationAction),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ComponentRow extends StatelessWidget {
  const _ComponentRow({required this.component});

  final ContributionChargeComponent component;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: UmojaSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contributionComponentTypeLabel(l10n, component.componentType),
                  style: textTheme.bodyLarge,
                ),
                Text(
                  '${l10n.contributionComponentDateLabel}: '
                  '${formatKiswahiliDate(component.effectiveAt)}',
                  style: textTheme.bodySmall,
                ),
                if (component.reason != null && component.reason!.isNotEmpty)
                  Text(
                    '${l10n.contributionComponentReasonLabel}: '
                    '${component.reason}',
                    style: textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          Text(
            formatAmount(component.amount),
            style: textTheme.bodyLarge?.copyWith(
              color: component.amount < 0
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
