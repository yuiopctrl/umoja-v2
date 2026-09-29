import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_breakpoints.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/utils/title_case.dart';
import '../../../core/widgets/umoja_empty_state.dart';
import '../../../core/widgets/umoja_error_state.dart';
import '../../../core/widgets/umoja_initials_avatar.dart';
import '../../../core/widgets/umoja_list_tile.dart';
import '../../../core/widgets/umoja_loading_state.dart';
import '../../../core/widgets/umoja_page.dart';
import '../../../core/widgets/umoja_search_field.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../domain/group_member.dart';
import '../providers/members_list_provider.dart';
import '../providers/members_query_provider.dart';
import 'widgets/member_role_label.dart';
import 'widgets/member_status_badge.dart';

/// Bottom clearance so the last row can scroll fully clear of the
/// floating "Ongeza Mwanachama" FAB (prompt 05A §15 — the FAB must
/// never permanently cover the last member row).
const _fabScrollClearance = 96.0;

/// `/members`: searchable, filterable, paginated member list for the
/// currently selected group.
class MembersListScreen extends ConsumerStatefulWidget {
  const MembersListScreen({super.key});

  @override
  ConsumerState<MembersListScreen> createState() => _MembersListScreenState();
}

class _MembersListScreenState extends ConsumerState<MembersListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(membersQueryProvider.notifier).setSearch(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedGroup = ref.watch(selectedGroupProvider);
    final membersAsync = ref.watch(membersListProvider);
    final query = ref.watch(membersQueryProvider);
    final l10n = context.l10n;

    final canCreate =
        selectedGroup is SelectedGroupResolved &&
        selectedGroup.membership.hasPermission('member.create');
    final canEdit =
        selectedGroup is SelectedGroupResolved &&
        selectedGroup.membership.hasPermission('member.edit');
    // Prompt 09G-B1-D3: gated on the exact permission the backend RPCs
    // enforce (`member.claim.approve`) — never a role name. Nav
    // visibility only; `rpc_list_membership_claims` re-checks this
    // itself regardless of how the screen is reached.
    final canReviewClaims =
        selectedGroup is SelectedGroupResolved &&
        selectedGroup.membership.hasPermission('member.claim.approve');
    // Prompt 09G-B1-E1/E2: invitation is now the PREFERRED officer-
    // driven onboarding path; the claim workflow above remains the
    // member-driven fallback — neither is removed or weakened.
    final canInvite =
        selectedGroup is SelectedGroupResolved &&
        selectedGroup.membership.hasPermission('member.invite');

    final statusFilters = <(String label, String? value)>[
      (l10n.filterAll, null),
      (l10n.filterActive, 'ACTIVE'),
      (l10n.filterSuspended, 'SUSPENDED'),
      (l10n.filterExited, 'EXITED'),
    ];

    // Prompt 09G-B1-E2 §A/§J: physical UAT found the previous icon-only
    // "Membership Requests" button too hard to discover. Every action
    // here is now explicitly text-labelled, never icon-only, on every
    // breakpoint — on narrow mobile they collapse into a single
    // overflow menu whose items still show their full text label (see
    // [_MembersHeaderActions] below), never just icons.
    final headerActionItems = <_HeaderActionItem>[
      if (canInvite)
        _HeaderActionItem(
          key: 'inviteMemberNavAction',
          label: l10n.inviteMemberAction,
          icon: Icons.person_add_outlined,
          onPressed: () => context.push(AppRoutes.membershipInvite),
        ),
      if (canInvite)
        _HeaderActionItem(
          key: 'membershipInvitationsNavAction',
          label: l10n.membershipInvitationsTitle,
          icon: Icons.mail_outline,
          onPressed: () => context.push(AppRoutes.membershipInvitationsList),
        ),
      if (canReviewClaims)
        _HeaderActionItem(
          key: 'membershipRequestsNavAction',
          label: l10n.membershipRequestsTitle,
          icon: Icons.assignment_ind_outlined,
          onPressed: () => context.push(AppRoutes.membershipRequestsList),
        ),
      if (canCreate)
        _HeaderActionItem(
          key: 'addMemberNavAction',
          label: l10n.addMemberAction,
          icon: Icons.person_add_alt,
          onPressed: () => context.push(AppRoutes.memberNew),
        ),
    ];

    return UmojaPage(
      title: l10n.membersTitle,
      scrollable: false,
      maxWidth: 900,
      headerTrailing: headerActionItems.isEmpty
          ? null
          : _MembersHeaderActions(items: headerActionItems),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.memberNew),
              icon: const Icon(Icons.person_add_alt),
              label: Text(l10n.addMemberAction),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UmojaSearchField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            hintText: l10n.membersSearchHint,
          ),
          const SizedBox(height: UmojaSpacing.md),
          Wrap(
            spacing: UmojaSpacing.sm,
            children: [
              for (final filter in statusFilters)
                ChoiceChip(
                  label: Text(filter.$1),
                  selected: query.status == filter.$2,
                  onSelected: (_) => ref
                      .read(membersQueryProvider.notifier)
                      .setStatus(filter.$2),
                ),
            ],
          ),
          const SizedBox(height: UmojaSpacing.sm),
          Expanded(
            child: membersAsync.when(
              loading: () => const UmojaLoadingState(),
              error: (error, stackTrace) => UmojaErrorState(
                message: l10n.refreshFailedMessage,
                retryLabel: l10n.retryButton,
                onRetry: () => ref.invalidate(membersListProvider),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return _MembersEmptyState(
                    hasActiveFilters:
                        query.search.isNotEmpty || query.status != null,
                    canCreate: canCreate,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.read(membersQueryProvider.notifier).resetPageSize();
                    ref.invalidate(membersListProvider);
                    await ref.read(membersListProvider.future);
                  },
                  child: ListView.separated(
                    padding: EdgeInsets.only(
                      bottom: canCreate ? _fabScrollClearance : 0,
                    ),
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
                              onPressed: () => ref
                                  .read(membersQueryProvider.notifier)
                                  .loadMore(),
                              child: Text(l10n.loadMoreAction),
                            ),
                          ),
                        );
                      }
                      final member = page.items[index];
                      return _MemberRow(
                        member: member,
                        canEdit: canEdit,
                        onTap: () => context.push(
                          AppRoutes.memberDetailPath(member.membershipId),
                        ),
                      );
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

/// One officer action offered from the Members header — always
/// rendered with an explicit text [label], never icon-only, on any
/// breakpoint (Prompt 09G-B1-E2 §A).
class _HeaderActionItem {
  const _HeaderActionItem({
    required this.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String key;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
}

/// Renders [items] as clearly labelled desktop/tablet buttons
/// (>= [UmojaBreakpoints.mobile]), or collapses them into a single
/// overflow menu on small mobile — whose entries still show their
/// full text label, never just an icon, per the physical-UAT
/// discoverability fix.
class _MembersHeaderActions extends StatelessWidget {
  const _MembersHeaderActions({required this.items});

  final List<_HeaderActionItem> items;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isMobile = UmojaBreakpoints.isMobile(
      MediaQuery.sizeOf(context).width,
    );

    if (!isMobile) {
      // Every header action is an equal-weight secondary button — the
      // one true primary CTA ("Add Member") already has its own
      // FloatingActionButton, so no single header item needs FilledButton
      // styling (and which one "should" get it would otherwise depend
      // on which optional permissions the caller happens to hold).
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, item) in items.indexed) ...[
            if (i > 0) const SizedBox(width: UmojaSpacing.sm),
            OutlinedButton.icon(
              key: Key(item.key),
              onPressed: item.onPressed,
              icon: Icon(item.icon),
              label: Text(item.label),
            ),
          ],
        ],
      );
    }

    return PopupMenuButton<VoidCallback>(
      key: const Key('membersHeaderOverflowAction'),
      tooltip: l10n.moreActionsTooltip,
      onSelected: (action) => action(),
      itemBuilder: (context) => [
        for (final item in items)
          PopupMenuItem<VoidCallback>(
            key: Key(item.key),
            value: item.onPressed,
            child: Row(
              children: [
                Icon(item.icon, size: 20),
                const SizedBox(width: UmojaSpacing.sm),
                // Prompt 09G-B1-F2 §E/§Y: a long label ("Membership
                // Requests"/"Invitations") plus the icon can overflow
                // PopupMenuItem's own narrow default width on a small
                // (360px) mobile screen — never exercised until F2's
                // own responsive test actually opened this menu with a
                // non-empty member list. Flexible+ellipsis, never a
                // truncated/hidden action.
                Flexible(
                  child: Text(item.label, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.more_horiz),
          const SizedBox(width: 4),
          Text(l10n.moreActionsTooltip),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.canEdit,
    required this.onTap,
  });

  final GroupMember member;
  final bool canEdit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subtitleParts = <String>[
      if (member.memberNumber != null) member.memberNumber!,
      if (member.phone != null) member.phone!,
    ];

    return UmojaListTile(
      leading: UmojaInitialsAvatar(name: toTitleCase(member.displayName)),
      title: toTitleCase(member.displayName),
      onTap: onTap,
      trailing: canEdit
          ? PopupMenuButton<void>(
              icon: const Icon(Icons.more_vert, size: 20),
              tooltip: '',
              itemBuilder: (_) => [
                PopupMenuItem<void>(
                  onTap: () => context.push(
                    AppRoutes.memberEditPath(member.membershipId),
                  ),
                  child: Text(l10n.editAction),
                ),
              ],
            )
          : null,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (subtitleParts.isNotEmpty)
            Text(
              subtitleParts.join(' · '),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MemberStatusBadge(status: member.status),
              if (member.roleCodes != null && member.roleCodes!.isNotEmpty) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '• ${member.roleCodes!.map((code) => memberRoleLabel(l10n, code)).join(', ')}',
                    style: Theme.of(context).textTheme.labelSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MembersEmptyState extends StatelessWidget {
  const _MembersEmptyState({
    required this.hasActiveFilters,
    required this.canCreate,
  });

  final bool hasActiveFilters;
  final bool canCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (hasActiveFilters) {
      return UmojaEmptyState(
        icon: Icons.search_off,
        title: l10n.membersEmptyFilteredTitle,
        message: l10n.membersEmptyFilteredMessage,
      );
    }
    return UmojaEmptyState(
      icon: Icons.people_outline,
      title: l10n.membersEmptyTitle,
      message: l10n.membersEmptyMessage,
      action: canCreate
          ? FilledButton.icon(
              onPressed: () => context.push(AppRoutes.memberNew),
              icon: const Icon(Icons.person_add_alt),
              label: Text(l10n.addMemberAction),
            )
          : null,
    );
  }
}
