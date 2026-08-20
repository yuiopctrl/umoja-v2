import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../shared/widgets/responsive_center.dart';
import '../../auth/providers/selected_group_provider.dart';
import '../domain/group_member.dart';
import '../providers/members_list_provider.dart';
import '../providers/members_query_provider.dart';
import 'widgets/member_status_badge.dart';

const _statusFilters = <(String label, String? value)>[
  ('All', null),
  ('Active', 'ACTIVE'),
  ('Suspended', 'SUSPENDED'),
  ('Exited', 'EXITED'),
];

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

    final canCreate =
        selectedGroup is SelectedGroupResolved &&
        selectedGroup.membership.hasPermission('member.create');

    return Scaffold(
      appBar: AppBar(title: const Text('Members / Wanachama')),
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 900,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: const InputDecoration(
                        hintText: 'Search name, member number, phone',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  if (canCreate) ...[
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () => context.push(AppRoutes.memberNew),
                      icon: const Icon(Icons.person_add_alt),
                      label: const Text('Add Member'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final filter in _statusFilters)
                    ChoiceChip(
                      label: Text(filter.$1),
                      selected: query.status == filter.$2,
                      onSelected: (_) => ref
                          .read(membersQueryProvider.notifier)
                          .setStatus(filter.$2),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: membersAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => _MembersErrorState(
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
                        itemCount: page.items.length + (page.hasMore ? 1 : 0),
                        separatorBuilder: (context, _) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          if (index >= page.items.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: OutlinedButton(
                                  onPressed: () => ref
                                      .read(membersQueryProvider.notifier)
                                      .loadMore(),
                                  child: const Text('Load More'),
                                ),
                              ),
                            );
                          }
                          final member = page.items[index];
                          return _MemberListTile(
                            member: member,
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
        ),
      ),
    );
  }
}

class _MemberListTile extends StatelessWidget {
  const _MemberListTile({required this.member, required this.onTap});

  final GroupMember member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      if (member.memberNumber != null) member.memberNumber!,
      if (member.phone != null) member.phone!,
    ];

    return ListTile(
      onTap: onTap,
      title: Text(member.displayName),
      subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' · ')),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          MemberStatusBadge(status: member.status),
          if (member.roleCodes != null && member.roleCodes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              member.roleCodes!.join(', '),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              size: 40,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              hasActiveFilters
                  ? 'No members match your search.'
                  : 'No members yet.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (!hasActiveFilters && canCreate) ...[
              const SizedBox(height: 8),
              const Text(
                'Add your first member to get started.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => context.push(AppRoutes.memberNew),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Add Member'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MembersErrorState extends StatelessWidget {
  const _MembersErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            const Text('Unable to load members.'),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
