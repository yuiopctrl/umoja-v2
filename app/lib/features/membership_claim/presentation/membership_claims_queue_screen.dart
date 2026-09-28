import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/kiswahili_date.dart';
import '../../../core/widgets/umoja_empty_state.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_list_tile.dart';
import '../../../core/widgets/umoja_loading_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../core/widgets/umoja_status_badge.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../domain/membership_claim.dart';
import '../domain/membership_claim_queue_item.dart';
import '../providers/membership_claims_queue_provider.dart';
import 'widgets/membership_claim_labels.dart';

const _defaultLimit = 20;

/// `/members/requests`: the officer-facing claim queue for the
/// currently selected group (Prompt 09G-B1-D3). `member.claim.approve`
/// -gated — reached only via the permission-gated entry point on
/// [MembersListScreen]; a deep link without the permission still fails
/// safely, since `rpc_list_membership_claims` itself re-checks it
/// server-side regardless of how this screen was reached.
class MembershipClaimsQueueScreen extends ConsumerStatefulWidget {
  const MembershipClaimsQueueScreen({super.key});

  @override
  ConsumerState<MembershipClaimsQueueScreen> createState() =>
      _MembershipClaimsQueueScreenState();
}

class _MembershipClaimsQueueScreenState
    extends ConsumerState<MembershipClaimsQueueScreen> {
  /// `null` means History (every status) — never a fabricated combined
  /// "resolved" server value; just how [MembershipClaimStatus.pending]
  /// is excluded from the display for that tab (§F: "without inventing
  /// client authority" — the underlying rows are exactly what the
  /// server returned for that history query, only their grouping is
  /// client-side).
  MembershipClaimStatus? _status = MembershipClaimStatus.pending;
  int _limit = _defaultLimit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedGroup = ref.watch(selectedGroupProvider);
    final groupId = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership.group.groupId
        : null;

    if (groupId == null) {
      // Unreachable via normal navigation (this route requires a
      // resolved group, like every other Members sub-route), but stay
      // safe rather than crash on a stale/edge-case rebuild.
      return UmojaPage(
        title: l10n.membershipRequestsTitle,
        backTo: AppRoutes.membersList,
        backLabel: l10n.membersTitle,
        body: const SizedBox.shrink(),
      );
    }

    final query = (groupId: groupId, status: _status, limit: _limit, offset: 0);
    final pageAsync = ref.watch(membershipClaimsQueueProvider(query));

    return UmojaPage(
      title: l10n.membershipRequestsTitle,
      scrollable: false,
      maxWidth: 900,
      backTo: AppRoutes.membersList,
      backLabel: l10n.membersTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: UmojaSpacing.sm,
            children: [
              ChoiceChip(
                label: Text(l10n.membershipRequestsPendingTab),
                selected: _status == MembershipClaimStatus.pending,
                onSelected: (_) => setState(() {
                  _status = MembershipClaimStatus.pending;
                  _limit = _defaultLimit;
                }),
              ),
              ChoiceChip(
                label: Text(l10n.membershipRequestsHistoryTab),
                selected: _status == null,
                onSelected: (_) => setState(() {
                  _status = null;
                  _limit = _defaultLimit;
                }),
              ),
            ],
          ),
          const SizedBox(height: UmojaSpacing.sm),
          Expanded(
            child: pageAsync.when(
              loading: () => const UmojaLoadingState(),
              error: (error, stackTrace) => UmojaErrorState(
                message: l10n.refreshFailedMessage,
                retryLabel: l10n.retryButton,
                onRetry: () =>
                    ref.invalidate(membershipClaimsQueueProvider(query)),
              ),
              data: (page) {
                // History shows every status; only PENDING is excluded
                // from ITS display, since that tab is "Pending" itself.
                final items = _status == null
                    ? page.items.where((item) => !item.isPending).toList()
                    : page.items;

                if (items.isEmpty) {
                  return UmojaEmptyState(
                    icon: Icons.assignment_ind_outlined,
                    title: _status == MembershipClaimStatus.pending
                        ? l10n.membershipRequestsEmptyPendingTitle
                        : l10n.membershipRequestsEmptyHistoryTitle,
                    message: _status == MembershipClaimStatus.pending
                        ? l10n.membershipRequestsEmptyPendingMessage
                        : null,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(membershipClaimsQueueProvider(query));
                    await ref.read(membershipClaimsQueueProvider(query).future);
                  },
                  child: ListView.separated(
                    itemCount: items.length + (page.hasMore ? 1 : 0),
                    separatorBuilder: (context, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index >= items.length) {
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
                      return _ClaimQueueRow(item: items[index]);
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

class _ClaimQueueRow extends StatelessWidget {
  const _ClaimQueueRow({required this.item});

  final MembershipClaimQueueItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subtitleParts = <String>[
      if (item.membershipDisplayName != null) item.membershipDisplayName!,
      if (item.membershipMemberNumber != null) item.membershipMemberNumber!,
    ];

    return UmojaListTile(
      title: item.claimantFullName ?? l10n.membershipRequestsUnknownClaimant,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (subtitleParts.isNotEmpty)
            Text(
              subtitleParts.join(' · '),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          if (item.requestedAt != null) ...[
            const SizedBox(height: 2),
            Text(
              '${l10n.submittedOnLabel}: ${formatKiswahiliDate(item.requestedAt!)}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ],
      ),
      trailing: UmojaStatusBadge(
        label: membershipClaimStatusLabel(l10n, item.status),
        semantic: membershipClaimStatusSemantic(item.status),
      ),
      onTap: () =>
          context.push(AppRoutes.membershipRequestDetailPath(item.claimId)),
    );
  }
}
