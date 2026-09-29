import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations_x.dart';
import '../../../../core/theme/umoja_spacing.dart';
import '../../../../core/widgets/umoja_empty_state.dart';
import '../../../../core/widgets/umoja_error_state.dart';
import '../../../../core/widgets/umoja_list_tile.dart';
import '../../../../core/widgets/umoja_loading_state.dart';
import '../../../../core/widgets/umoja_search_field.dart';
import '../../../../core/widgets/umoja_status_badge.dart';
import '../../../auth/providers/selected_group_provider.dart';
import '../../../members/domain/group_member.dart';
import '../../../members/providers/member_repository_provider.dart';

/// A member search box + result list, reused by both the Record
/// Payment flow and the Member Wallet flow — the existing member
/// search RPC (`rpc_list_group_members`) is server-side, paginated,
/// and searches name/number/phone; this widget never loads every
/// member client-side. Deliberately searches across every status
/// (no status filter), so a SUSPENDED/EXITED member with historical
/// payable obligations can still be found and settled without
/// reactivating their membership.
class MemberSearchPicker extends ConsumerStatefulWidget {
  const MemberSearchPicker({
    super.key,
    required this.hintText,
    required this.onSelected,
    this.filter,
    this.emptyTitle,
    this.emptyMessage,
  });

  final String hintText;
  final ValueChanged<GroupMember> onSelected;

  /// When given, only members for which this returns `true` are shown
  /// — e.g. the member-invitation flow (Prompt 09G-B1-E2) restricts
  /// selection to ACTIVE, not-yet-login-linked members. `null` (the
  /// default) shows every member regardless of status, matching this
  /// picker's original Record Payment/Wallet behavior unchanged.
  final bool Function(GroupMember member)? filter;

  /// Overrides the empty-state copy shown when [filter] excludes every
  /// result — falls back to the generic "no member found" copy when
  /// omitted.
  final String? emptyTitle;
  final String? emptyMessage;

  @override
  ConsumerState<MemberSearchPicker> createState() => _MemberSearchPickerState();
}

class _MemberSearchPickerState extends ConsumerState<MemberSearchPicker> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _search = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() => _search = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedGroup = ref.watch(selectedGroupProvider);
    final groupId = selectedGroup is SelectedGroupResolved
        ? selectedGroup.membership.group.groupId
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UmojaSearchField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          hintText: widget.hintText,
        ),
        const SizedBox(height: UmojaSpacing.md),
        Expanded(
          child: groupId == null
              ? const SizedBox.shrink()
              : FutureBuilder(
                  future: ref
                      .read(memberRepositoryProvider)
                      .listMembers(
                        groupId: groupId,
                        search: _search,
                        limit: 25,
                      ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const UmojaLoadingState();
                    }
                    if (snapshot.hasError) {
                      return UmojaErrorState(
                        message: l10n.refreshFailedMessage,
                        retryLabel: l10n.retryButton,
                        onRetry: () => setState(() {}),
                      );
                    }
                    final allItems = snapshot.data?.items ?? const [];
                    final items = widget.filter == null
                        ? allItems
                        : allItems
                              .where(widget.filter!)
                              .toList(growable: false);
                    if (items.isEmpty) {
                      return UmojaEmptyState(
                        icon: Icons.person_search_outlined,
                        title: widget.emptyTitle ?? l10n.memberPickerEmptyTitle,
                        message:
                            widget.emptyMessage ??
                            l10n.memberPickerEmptyMessage,
                      );
                    }
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (context, _) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final member = items[index];
                        return UmojaListTile(
                          title: member.displayName,
                          subtitle: Text(
                            member.memberNumber ?? '',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          trailing: member.isActive
                              ? null
                              : UmojaStatusBadge(
                                  label: member.isSuspended
                                      ? l10n.filterSuspended
                                      : l10n.filterExited,
                                  semantic: UmojaStatusSemantic.neutral,
                                ),
                          onTap: () => widget.onSelected(member),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
