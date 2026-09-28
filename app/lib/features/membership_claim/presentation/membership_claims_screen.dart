import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/kiswahili_date.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../core/widgets/umoja_empty_state.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_loading_state.dart';
import '../../../core/widgets/umoja_status_badge.dart';
import '../../../shared/widgets/responsive_center.dart';
import '../../auth/providers/app_context_provider.dart';
import '../controllers/membership_claim_controller.dart';
import '../domain/membership_claim.dart';
import '../providers/my_membership_claims_provider.dart';
import 'widgets/membership_claim_labels.dart';

/// `/membership/claims`: the claimant's own claim status — always
/// re-read from `rpc_list_my_membership_claims`, never inferred or
/// fabricated client-side. Handles the officer-approves-elsewhere
/// case (Prompt 09G-B1-D2 §L): once an APPROVED claim is observed, the
/// real session/context is refreshed via [appContextProvider]; the
/// router then takes over (redirecting to `/home` once resolved, or
/// `/select-group` if the user has more than one eligible group) —
/// this screen never constructs `AppSession`/group state from claim
/// JSON itself.
class MembershipClaimsScreen extends ConsumerWidget {
  const MembershipClaimsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claimsAsync = ref.watch(myMembershipClaimsProvider);
    final l10n = context.l10n;

    ref.listen(myMembershipClaimsProvider, (previous, next) {
      final claims = next.value;
      if (claims == null) return;
      final hasApproved = claims.any((claim) => claim.isApproved);
      if (hasApproved) {
        ref.invalidate(appContextProvider);
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.membershipClaimsTitle)),
      body: SafeArea(
        child: claimsAsync.when(
          loading: () => const UmojaLoadingState(),
          error: (error, stackTrace) => UmojaErrorState(
            message: l10n.refreshFailedMessage,
            retryLabel: l10n.retryButton,
            onRetry: () => ref.invalidate(myMembershipClaimsProvider),
          ),
          data: (claims) {
            if (claims.isEmpty) {
              return ResponsiveCenter(
                child: UmojaEmptyState(
                  icon: Icons.link_off,
                  title: l10n.membershipClaimsEmptyTitle,
                  message: l10n.membershipClaimsEmptyMessage,
                  action: UmojaPrimaryButton(
                    key: const Key('membershipClaimsEmptyLinkAction'),
                    label: l10n.linkMyMembershipAction,
                    onPressed: () => context.push(AppRoutes.membershipLink),
                  ),
                ),
              );
            }

            final sorted = [...claims]
              ..sort((a, b) {
                final aTime = a.requestedAt;
                final bTime = b.requestedAt;
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return bTime.compareTo(aTime);
              });

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(myMembershipClaimsProvider);
                await ref.read(myMembershipClaimsProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.all(UmojaSpacing.lg),
                children: [
                  ResponsiveCenter(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final claim in sorted) ...[
                          _ClaimCard(claim: claim),
                          const SizedBox(height: UmojaSpacing.md),
                        ],
                        const SizedBox(height: UmojaSpacing.sm),
                        UmojaSecondaryButton(
                          key: const Key('linkAnotherMembershipAction'),
                          label: l10n.linkAnotherMembershipAction,
                          onPressed: () =>
                              context.push(AppRoutes.membershipLink),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ClaimCard extends ConsumerWidget {
  const _ClaimCard({required this.claim});

  final MembershipClaim claim;

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.cancelMembershipClaimConfirmTitle),
        content: Text(l10n.cancelMembershipClaimConfirmMessage),
        actions: [
          TextButton(
            key: const Key('membershipClaimCancelDismissAction'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            key: const Key('membershipClaimCancelConfirmAction'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.cancelMembershipClaimAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final success = await ref
        .read(membershipClaimControllerProvider.notifier)
        .cancel(claimId: claim.claimId);
    if (!context.mounted) return;
    if (!success) {
      final errorType = ref.read(membershipClaimControllerProvider).errorType;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorType == null
                ? l10n.memberErrorUnexpected
                : membershipClaimFailureMessage(l10n, errorType),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controllerState = ref.watch(membershipClaimControllerProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(UmojaSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                UmojaStatusBadge(
                  label: membershipClaimStatusLabel(l10n, claim.status),
                  semantic: membershipClaimStatusSemantic(claim.status),
                ),
              ],
            ),
            const SizedBox(height: UmojaSpacing.sm),
            if (claim.requestedAt != null)
              Text(
                '${l10n.submittedOnLabel}: '
                '${formatKiswahiliDate(claim.requestedAt!)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            if (claim.isRejected && claim.rejectionReason != null) ...[
              const SizedBox(height: UmojaSpacing.sm),
              Text(
                claim.rejectionReason!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (claim.isPending) ...[
              const SizedBox(height: UmojaSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: UmojaSecondaryButton(
                  key: const Key('membershipClaimCancelAction'),
                  label: l10n.cancelMembershipClaimAction,
                  isLoading: controllerState.isCancelling,
                  onPressed: controllerState.isCancelling
                      ? null
                      : () => _confirmCancel(context, ref),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
