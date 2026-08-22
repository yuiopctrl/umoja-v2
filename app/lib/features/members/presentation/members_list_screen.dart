import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
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

    final statusFilters = <(String label, String? value)>[
      (l10n.filterAll, null),
      (l10n.filterActive, 'ACTIVE'),
      (l10n.filterSuspended, 'SUSPENDED'),
      (l10n.filterExited, 'EXITED'),
    ];

    return UmojaPage(
      title: l10n.membersTitle,
      scrollable: false,
      maxWidth: 900,
      headerTrailing: canCreate
          ? FilledButton.icon(
              onPressed: () => context.push(AppRoutes.memberNew),
              icon: const Icon(Icons.person_add_alt),
              label: Text(l10n.addMemberAction),
            )
          : null,
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
